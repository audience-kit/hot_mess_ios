//
//  LocationProvider.swift
//  HotMess
//

import CoreLocation
import Foundation
import Observation
import os

/// Tracks where the device is and which locale (city) that maps to.
///
/// Replaces `LocationService`, which mixed Core Location, HTTP calls, two
/// notification names and a `UIAlertController` into one singleton — and which
/// assigned the beacon *minor* value to `beaconMajor` twice, so ranging never
/// reported a usable pair.
@MainActor
@Observable
final class LocationProvider {
    private(set) var coordinates: Coordinates?
    private(set) var locale: AppLocale?
    private(set) var authorizationStatus: CLAuthorizationStatus

    private let api: HotMessAPI
    private let configuration: AppConfiguration
    private let manager = CLLocationManager()
    private let delegate = Delegate()
    private var beaconConstraint: CLBeaconIdentityConstraint?
    private var beaconRegion: CLBeaconRegion?
    private var isMonitoring = false

    /// Remembered so the first launch after a cold start has a locale to work
    /// with before Core Location produces a fix.
    private static let storedLocaleIDKey = "localeId"
    private static let storedLocaleNameKey = "localeName"

    init(api: HotMessAPI, configuration: AppConfiguration) {
        self.api = api
        self.configuration = configuration
        authorizationStatus = manager.authorizationStatus

        locale = Self.restoreLocale()

        if let beaconUUID = configuration.beaconUUID {
            beaconConstraint = CLBeaconIdentityConstraint(uuid: beaconUUID)
            beaconRegion = CLBeaconRegion(uuid: beaconUUID, identifier: Self.beaconIdentifier)
        }

        manager.delegate = delegate
        manager.pausesLocationUpdatesAutomatically = true
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        delegate.owner = self
    }

    static let beaconIdentifier = "social.hotmess.beacon"

    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    /// True once the user has been asked and said no — the cue to offer a
    /// link into Settings instead of asking again.
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Control

    func start() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            beginMonitoring()
        default:
            break
        }
    }

    func stop() {
        guard isMonitoring else { return }

        manager.stopMonitoringSignificantLocationChanges()

        if let beaconConstraint {
            manager.stopRangingBeacons(satisfying: beaconConstraint)
        }
        if let beaconRegion {
            manager.stopMonitoring(for: beaconRegion)
        }

        isMonitoring = false
    }

    /// Asks the API which locale the current position belongs to.
    func refreshLocale() async {
        do {
            let resolved = try await api.closestLocale(to: coordinates)

            guard resolved.id != locale?.id else { return }

            locale = resolved
            Self.persist(resolved)
        } catch {
            Log.location.error("Locale lookup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Delegate plumbing

    private func beginMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        manager.startMonitoringSignificantLocationChanges()

        if let beaconRegion {
            manager.startMonitoring(for: beaconRegion)
        }
        if let beaconConstraint {
            manager.startRangingBeacons(satisfying: beaconConstraint)
        }

        if let location = manager.location {
            update(with: location)
        }

        Task { await refreshLocale() }
    }

    fileprivate func authorizationChanged(to status: CLAuthorizationStatus) {
        authorizationStatus = status

        if isAuthorized {
            beginMonitoring()
        }
    }

    fileprivate func update(with location: CLLocation) {
        coordinates = Coordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            beaconMajor: coordinates?.beaconMajor,
            beaconMinor: coordinates?.beaconMinor
        )

        Task {
            await refreshLocale()
            await reportPosition()
        }
    }

    fileprivate func update(beacons: [CLBeacon]) {
        guard let nearest = beacons.first else { return }

        // Only attach beacon identifiers to a position we actually have; the
        // original fell back to (0, 0) and reported the Gulf of Guinea.
        let position = coordinates ?? manager.location.map {
            Coordinates(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        guard let position else { return }

        coordinates = Coordinates(
            latitude: position.latitude,
            longitude: position.longitude,
            beaconMajor: nearest.major.intValue,
            beaconMinor: nearest.minor.intValue
        )

        Task { await reportPosition() }
    }

    private func reportPosition() async {
        guard let coordinates else { return }

        do {
            try await api.reportLocation(coordinates)
        } catch {
            Log.location.error("Location report failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Persistence

    private static func restoreLocale() -> AppLocale? {
        let defaults = UserDefaults.standard

        guard let idString = defaults.string(forKey: storedLocaleIDKey),
              let id = UUID(uuidString: idString),
              let name = defaults.string(forKey: storedLocaleNameKey) else { return nil }

        return AppLocale(id: id, name: name)
    }

    private static func persist(_ locale: AppLocale) {
        let defaults = UserDefaults.standard
        defaults.set(locale.id.uuidString, forKey: storedLocaleIDKey)
        defaults.set(locale.name, forKey: storedLocaleNameKey)
    }
}

// MARK: - Core Location delegate

/// Core Location's delegate protocol predates Swift concurrency. The manager is
/// created on the main actor and therefore calls back on it, so the conformance
/// is marked `@preconcurrency` and the class pinned to `@MainActor` rather than
/// hopping queues by hand in every callback.
@MainActor
private final class Delegate: NSObject, @preconcurrency CLLocationManagerDelegate {
    weak var owner: LocationProvider?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        owner?.authorizationChanged(to: manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        owner?.update(with: location)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying constraint: CLBeaconIdentityConstraint
    ) {
        owner?.update(beacons: beacons)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let owner else { return }
        Task { await owner.refreshLocale() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Log.location.error("Core Location failed: \(error.localizedDescription, privacy: .public)")
    }
}
