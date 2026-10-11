//
//  ReportThrottle.swift
//  HotMess
//

import CoreLocation
import Foundation

/// Decides whether a position is worth another request, so one place sends
/// one request however many fixes, beacons, geofence events and screens ask
/// about it.
///
/// A position is due when nothing has been sent yet, when it's at least
/// `minimumDistance` from the last one sent, when its beacon names another
/// locale (the API reads only `beaconMajor`), or, with a `maximumAge`, once
/// the last one sent is that old.
struct ReportThrottle: Sendable {
    let minimumDistance: CLLocationDistance
    let maximumAge: TimeInterval?

    private(set) var lastSent: Coordinates?
    private(set) var lastSentAt: Date?

    init(minimumDistance: CLLocationDistance, maximumAge: TimeInterval? = nil) {
        self.minimumDistance = minimumDistance
        self.maximumAge = maximumAge
    }

    func isDue(_ coordinates: Coordinates, at date: Date = .now) -> Bool {
        guard let lastSent, let lastSentAt else { return true }

        if let maximumAge, date.timeIntervalSince(lastSentAt) >= maximumAge { return true }
        if coordinates.beaconMajor != lastSent.beaconMajor { return true }
        return coordinates.distance(from: lastSent) >= minimumDistance
    }

    /// Records a request for `coordinates`, sent at `date`.
    mutating func sent(_ coordinates: Coordinates, at date: Date = .now) {
        lastSent = coordinates
        lastSentAt = date
    }

    /// Forgets the last request, so the next position is due: for one that
    /// failed.
    mutating func reset() {
        lastSent = nil
        lastSentAt = nil
    }
}

extension Coordinates {
    /// Metres between two positions; beacons don't count.
    func distance(from other: Coordinates) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
