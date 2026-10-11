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
    /// Test builds and App Review only: the venue the app is pretending to be
    /// at. While it's set, the venue's position is reported instead of the
    /// device's.
    var simulatedVenueName: String? { tracker.simulatedVenueName }

    private var tracker: PositionTracker

    private let api: HotMessAPI
    private let configuration: AppConfiguration
    private let manager = CLLocationManager()
    private let delegate = Delegate()
    private var beaconConstraint: CLBeaconIdentityConstraint?
    private var beaconRegion: CLBeaconRegion?
    private var isMonitoring = false

    /// Callers waiting on `refreshPosition()`, resumed by the next fix, a
    /// failure, or their timeout.
    private var pendingFixes: [UUID: CheckedContinuation<Void, Never>] = [:]
    /// Re-reads the position every `refreshInterval` while the app is open.
    private var refreshTask: Task<Void, Never>?

    /// Watches the nearest venues' envelopes. See `GeofencePlan`.
    private var monitor: CLMonitor?
    private var monitorTask: Task<Void, Never>?
    private var geofencePlan: GeofencePlan?
    private var venueFences: [VenueFence] = []
    private var venueFencesFetchedAt: Date?
    private var isPlanningGeofences = false

    /// Fixes, beacons, geofences, chat and the Now screen all report the
    /// position; they share one request per place. See `now(sentAfter:)`.
    private var reportThrottle = ReportThrottle(
        minimumDistance: LocationProvider.reportDistance,
        maximumAge: LocationProvider.reportMaxAge
    )
    private var report: Report?
    /// The locale is looked up once per place, however often it's asked.
    private var localeThrottle = ReportThrottle(minimumDistance: LocationProvider.localeLookupDistance)
    private var localeLookup: Task<Void, Never>?

    /// The latest position report, in flight or answered.
    private struct Report {
        let sentAt: Date
        let task: Task<Now, any Error>
    }

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
    /// CLMonitor names must be alphanumeric: a dot throws "Monitor name is not
    /// valid" when the monitor is created, crashing the app at launch.
    static let monitorName = "HotMessVenues"
    static let recenterIdentifier = "recenter"
    static let venueIdentifierPrefix = "venue:"

    /// How often the position is re-read while the app is open. Presence on
    /// the API lasts two hours, so this keeps it current without keeping GPS on.
    static let refreshInterval: Duration = .seconds(5 * 60)
    /// How long `refreshPosition()` waits for Core Location before giving up.
    static let fixTimeout: Duration = .seconds(10)
    /// A fix this recent is used as is when the app comes back.
    static let freshFixAge: TimeInterval = 60
    /// Venue envelopes are downloaded again after this long.
    static let venueFencesMaxAge: TimeInterval = 6 * 60 * 60
    /// The position is reported again once it's moved this far…
    static let reportDistance: CLLocationDistance = 50
    /// …or the last report is this old.
    static let reportMaxAge: TimeInterval = 60
    /// Locales are cities: the locale is looked up again once the position
    /// has moved this far.
    static let localeLookupDistance: CLLocationDistance = 500

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

        refreshTask?.cancel()
        refreshTask = nil
        manager.stopMonitoringSignificantLocationChanges()

        if let beaconConstraint {
            manager.stopRangingBeacons(satisfying: beaconConstraint)
        }
        if let beaconRegion {
            manager.stopMonitoring(for: beaconRegion)
        }

        isMonitoring = false
    }

    /// Asks Core Location for a fresh fix and returns once it's in and
    /// reported, Core Location gives up, or `fixTimeout` passes. Pull to
    /// refresh calls this, so a refresh never reloads around a stale position.
    func refreshPosition() async {
        guard isAuthorized else { return }

        let id = UUID()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.fixTimeout)
            self?.resumeFix(id)
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // One request answers everyone waiting: geofence events tend to
            // arrive several at once, and each asked for its own fix.
            let isAsking = !pendingFixes.isEmpty
            pendingFixes[id] = continuation
            if !isAsking { manager.requestLocation() }
        }
    }

    private func resumeFix(_ id: UUID) {
        pendingFixes.removeValue(forKey: id)?.resume()
    }

    private func resumePendingFixes() {
        let waiting = pendingFixes.values
        pendingFixes.removeAll()
        waiting.forEach { $0.resume() }
    }

    /// Asks the API which locale the current position belongs to, once per
    /// place: a lookup in flight is waited on rather than repeated, and the
    /// position must move `localeLookupDistance` before it's asked again.
    func refreshLocale() async {
        if let localeLookup { await localeLookup.value }
        guard let coordinates, localeThrottle.isDue(coordinates) else { return }

        localeThrottle.sent(coordinates)
        let lookup = Task { @MainActor [api, weak self] in
            do {
                let resolved = try await api.closestLocale(to: coordinates)
                guard let self, let resolved, resolved.id != locale?.id else { return }

                locale = resolved
                LocationProvider.persist(resolved)
            } catch {
                // Ask again next time rather than wait to move.
                self?.localeThrottle.reset()
                Log.location.error("Locale lookup failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        localeLookup = lookup
        await lookup.value
        if localeLookup == lookup { localeLookup = nil }
    }

    // MARK: - Testing

    /// Reports `coordinate` as the device's position until `stopSimulating()`,
    /// so a test build can be "at" a venue from anywhere. The API puts the
    /// user at whichever venue's envelope contains the point.
    /// Returns once the position is reported, so the caller can reload.
    /// `allowed` lets a release build do it too, for App Review.
    func simulate(at coordinate: CLLocationCoordinate2D, venueName: String, allowed: Bool = false) async {
        guard tracker.simulate(latitude: coordinate.latitude, longitude: coordinate.longitude,
                               venueName: venueName, allowed: allowed)
        else { return }

        coordinates = tracker.current
        await refreshLocale()
        await reportPosition(force: true)
    }

    /// Goes back to the device's real position.
    func stopSimulating() async {
        guard tracker.stopSimulating() else { return }

        coordinates = tracker.current
        guard coordinates != nil else { return }

        await refreshLocale()
        await reportPosition(force: true)
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

        // A recent cached fix shows something at once; an old one would be
        // reported as where the user is now, so it waits for a fresh one.
        if let location = manager.location,
           Date.now.timeIntervalSince(location.timestamp) < Self.freshFixAge {
            update(with: location)
        } else {
            Task { await refreshPosition() }
        }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.refreshInterval)
                guard !Task.isCancelled else { return }
                await self?.refreshPosition()
            }
        }

        startGeofencing()
    }

    fileprivate func authorizationChanged(to status: CLAuthorizationStatus) {
        authorizationStatus = status

        if isAuthorized {
            beginMonitoring()
        }
    }

    fileprivate func update(with location: CLLocation) {
        // Geofences follow the device, even while pretending to be elsewhere.
        Task { await planGeofences(around: location) }

        guard tracker.deviceFix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        else {
            resumePendingFixes()
            return
        }

        coordinates = tracker.current
        // A refresh waits for the locale too, so a pulled list reloads in the right city.
        Task {
            await refreshLocale()
            await reportPosition()
            resumePendingFixes()
        }
    }

    fileprivate func fixFailed() {
        resumePendingFixes()
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

    /// Reports the current position, unless it was reported from about here
    /// in the last minute. Venue chat calls this so the API knows the user is
    /// still at the venue.
    func reportCurrentPosition() async {
        await reportPosition()
    }

    /// What's happening where the user is, from reporting the position, or
    /// `nil` with no position yet.
    ///
    /// Everything that reports the position comes through here and shares
    /// one request: a report sent from within `reportDistance` in the last
    /// `reportMaxAge`, in flight or answered, is used again rather than sent
    /// again or cancelled, unless it was sent before `sentAfter` (a pull to
    /// refresh, or Pings that changed since).
    func now(sentAfter: Date? = nil) async throws -> Now? {
        guard let coordinates else { return nil }

        if let report, !reportThrottle.isDue(coordinates),
           sentAfter.map({ report.sentAt >= $0 }) ?? true {
            return try await report.task.value
        }

        let sentAt = Date.now
        reportThrottle.sent(coordinates, at: sentAt)
        let task = Task { @MainActor [api, weak self] () throws -> Now in
            do {
                return try await api.now(near: coordinates)
            } catch {
                // The next caller tries again rather than sharing the failure.
                if let self, report?.sentAt == sentAt {
                    report = nil
                    reportThrottle.reset()
                }
                throw error
            }
        }
        report = Report(sentAt: sentAt, task: task)
        return try await task.value
    }

    /// Reports the position. `force` sends it even if about here was reported
    /// recently: pretending moves the user into a venue's envelope that may be
    /// only metres away.
    private func reportPosition(force: Bool = false) async {
        do {
            _ = try await now(sentAfter: force ? .now : nil)
        } catch {
            Log.location.error("Location report failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Geofences

    /// Starts watching venue envelopes. The monitor outlives the app's
    /// launches, so its regions from last time are still there; the first fix
    /// replaces them.
    private func startGeofencing() {
        guard monitorTask == nil else { return }

        monitorTask = Task { @MainActor [weak self] in
            let monitor = await CLMonitor(Self.monitorName)
            self?.monitor = monitor
            if let location = self?.manager.location {
                await self?.planGeofences(around: location)
            }

            do {
                for try await event in await monitor.events {
                    await self?.geofenceChanged(event.identifier, inside: event.state == .satisfied)
                }
            } catch {
                Log.location.error("Geofence monitoring stopped: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Entering or leaving a venue means presence changed: read the position
    /// and report it. Leaving the re-center circle means unwatched venues may
    /// be close now, so the regions are planned again from the new fix.
    private func geofenceChanged(_ identifier: String, inside: Bool) async {
        if identifier == Self.recenterIdentifier {
            guard !inside else { return }
            geofencePlan = nil
        } else if !identifier.hasPrefix(Self.venueIdentifierPrefix) {
            return
        }

        Log.location.info("Geofence \(identifier, privacy: .public) \(inside ? "entered" : "left", privacy: .public)")
        await refreshPosition()
    }

    /// Picks the regions to watch from `location`, downloading the venues'
    /// envelopes when they're missing or old. Does nothing while the device
    /// is still well inside the current re-center circle.
    private func planGeofences(around location: CLLocation) async {
        guard let monitor, isAuthorized, !isPlanningGeofences else { return }

        if let geofencePlan {
            let center = CLLocation(latitude: geofencePlan.recenterLatitude, longitude: geofencePlan.recenterLongitude)
            let fencesFresh = venueFencesFetchedAt.map { Date.now.timeIntervalSince($0) < Self.venueFencesMaxAge } ?? false
            if fencesFresh, location.distance(from: center) < geofencePlan.recenterRadius / 2 { return }
        }

        isPlanningGeofences = true
        defer { isPlanningGeofences = false }

        let position = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        if venueFencesFetchedAt.map({ Date.now.timeIntervalSince($0) >= Self.venueFencesMaxAge }) ?? true {
            do {
                venueFences = try await api.venueFences(near: position)
                venueFencesFetchedAt = .now
            } catch {
                Log.location.error("Venue envelopes failed: \(error.localizedDescription, privacy: .public)")
                // Try again on the next fix; keep watching what we had.
                if venueFencesFetchedAt == nil { return }
            }
        }

        let plan = GeofencePlan(around: position, venues: venueFences)
        await apply(plan, to: monitor)
        geofencePlan = plan
    }

    private func apply(_ plan: GeofencePlan, to monitor: CLMonitor) async {
        // The radius is part of the identifier, so a venue whose envelope
        // changed is replaced rather than kept.
        let wanted = Dictionary(
            plan.venues.map { ("\(Self.venueIdentifierPrefix)\($0.id.uuidString.lowercased()):\(Int($0.radius))", $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let existing = Set(await monitor.identifiers)

        for identifier in existing where wanted[identifier] == nil {
            await monitor.remove(identifier)
        }

        for (identifier, fence) in wanted where !existing.contains(identifier) {
            await monitor.add(
                CLMonitor.CircularGeographicCondition(center: fence.center, radius: fence.radius),
                identifier: identifier,
                assuming: .unsatisfied
            )
        }

        await monitor.add(
            CLMonitor.CircularGeographicCondition(center: plan.recenterCenter, radius: plan.recenterRadius),
            identifier: Self.recenterIdentifier,
            assuming: .satisfied
        )

        Log.location.info("Watching \(wanted.count) venues, re-center radius \(Int(plan.recenterRadius))m")
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

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Log.location.error("Core Location failed: \(error.localizedDescription, privacy: .public)")
        owner?.fixFailed()
    }
}
