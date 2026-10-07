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
    /// Test builds only: the venue the app is pretending to be at. While it's
    /// set, the venue's position is reported instead of the device's.
    var simulatedVenueName: String? { tracker.simulatedVenueName }

    private var tracker: PositionTracker

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
        tracker = PositionTracker(simulationAllowed: configuration.isTestBuild)

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
            guard let resolved = try await api.closestLocale(to: coordinates),
                  resolved.id != locale?.id else { return }

            locale = resolved
            Self.persist(resolved)
        } catch {
            Log.location.error("Locale lookup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Testing

    /// Reports `coordinate` as the device's position until `stopSimulating()`,
    /// so a test build can be "at" a venue from anywhere. The API puts the
    /// user at whichever venue's envelope contains the point.
    /// Returns once the position is reported, so the caller can reload.
    func simulate(at coordinate: CLLocationCoordinate2D, venueName: String) async {
        guard tracker.simulate(latitude: coordinate.latitude, longitude: coordinate.longitude, venueName: venueName)
        else { return }

        coordinates = tracker.current
        await refreshLocale()
        await reportPosition()
    }

    /// Goes back to the device's real position.
    func stopSimulating() async {
        guard tracker.stopSimulating() else { return }

        coordinates = tracker.current
        guard coordinates != nil else { return }

        await refreshLocale()
        await reportPosition()
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
        guard tracker.deviceFix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        else { return }

        coordinates = tracker.current
        Task {
            await refreshLocale()
            await reportPosition()
        }
    }

    fileprivate func update(beacons: [CLBeacon]) {
        guard let nearest = beacons.first else { return }

        // A beacon can be heard before the first significant-change fix.
        if tracker.current == nil, let location = manager.location {
            tracker.deviceFix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        guard tracker.beacon(major: nearest.major.intValue, minor: nearest.minor.intValue) else { return }

        coordinates = tracker.current
        Task { await reportPosition() }
    }

    /// Reports the current position now. Venue chat calls this so the API
    /// knows the user is still at the venue.
    func reportCurrentPosition() async {
        await reportPosition()
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
