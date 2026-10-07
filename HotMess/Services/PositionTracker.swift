//
//  PositionTracker.swift
//  HotMess
//

import Foundation

/// Which position the app reports: the device's, with the nearest beacon once
/// one is heard, or in a test build the venue the tester is pretending to be at
/// ("Pretend I'm here" on a venue). While pretending, device fixes and beacons
/// are kept but not reported, so stopping goes straight back to the real
/// position.
struct PositionTracker: Sendable {
    let simulationAllowed: Bool

    private var device: Coordinates?
    private var simulated: Coordinates?

    /// The venue being pretended at, if any.
    private(set) var simulatedVenueName: String?

    init(simulationAllowed: Bool) {
        self.simulationAllowed = simulationAllowed
    }

    /// What to report now.
    var current: Coordinates? { simulated ?? device }

    /// Records a fix from the device. True when it changes what's reported.
    @discardableResult
    mutating func deviceFix(latitude: Double, longitude: Double) -> Bool {
        device = Coordinates(
            latitude: latitude,
            longitude: longitude,
            beaconMajor: device?.beaconMajor,
            beaconMinor: device?.beaconMinor
        )
        return simulated == nil
    }

    /// Attaches the nearest beacon to the device's position. True when it
    /// changes what's reported.
    @discardableResult
    mutating func beacon(major: Int, minor: Int) -> Bool {
        // Only attach beacon identifiers to a position we actually have; the
        // original fell back to (0, 0) and reported the Gulf of Guinea.
        guard var position = device,
              position.beaconMajor != major || position.beaconMinor != minor else { return false }

        position.beaconMajor = major
        position.beaconMinor = minor
        device = position
        return simulated == nil
    }

    /// Reports this venue's position instead of the device's. False, and
    /// ignored, outside test builds.
    @discardableResult
    mutating func simulate(latitude: Double, longitude: Double, venueName: String) -> Bool {
        guard simulationAllowed else { return false }

        simulated = Coordinates(latitude: latitude, longitude: longitude)
        simulatedVenueName = venueName
        return true
    }

    /// Goes back to the device's position. True when the app was pretending.
    @discardableResult
    mutating func stopSimulating() -> Bool {
        guard simulated != nil else { return false }

        simulated = nil
        simulatedVenueName = nil
        return true
    }
}
