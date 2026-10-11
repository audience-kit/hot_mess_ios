//
//  ReportThrottleTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

@Suite("Location report throttle")
struct ReportThrottleTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let nyne = Coordinates(latitude: 47.6575451, longitude: -117.414777)

    /// `nyne` moved north by about `metres`.
    private func north(_ metres: Double, beaconMajor: Int? = nil) -> Coordinates {
        Coordinates(
            latitude: nyne.latitude + metres / 111_320,
            longitude: nyne.longitude,
            beaconMajor: beaconMajor
        )
    }

    @Test("The first position is always due")
    func first() {
        let throttle = ReportThrottle(minimumDistance: 50, maximumAge: 60)
        #expect(throttle.isDue(nyne, at: start))
    }

    @Test("Fixes about the same place within the minute share one report")
    func samePlace() {
        var throttle = ReportThrottle(minimumDistance: 50, maximumAge: 60)
        throttle.sent(nyne, at: start)

        #expect(!throttle.isDue(nyne, at: start))
        #expect(!throttle.isDue(north(20), at: start.addingTimeInterval(1)))
        #expect(!throttle.isDue(north(49), at: start.addingTimeInterval(59)))
    }

    @Test("Moving 50 m or waiting a minute makes it due")
    func movedOrAged() {
        var throttle = ReportThrottle(minimumDistance: 50, maximumAge: 60)
        throttle.sent(nyne, at: start)

        #expect(throttle.isDue(north(60), at: start.addingTimeInterval(1)))
        #expect(throttle.isDue(nyne, at: start.addingTimeInterval(60)))
    }

    @Test("A beacon from another locale is due; another beacon in the same one isn't")
    func beacons() {
        var throttle = ReportThrottle(minimumDistance: 50, maximumAge: 60)
        throttle.sent(north(0, beaconMajor: 1), at: start)

        var sameLocale = north(0, beaconMajor: 1)
        sameLocale.beaconMinor = 7
        #expect(!throttle.isDue(sameLocale, at: start.addingTimeInterval(1)))
        #expect(throttle.isDue(north(0, beaconMajor: 2), at: start.addingTimeInterval(1)))
        #expect(throttle.isDue(nyne, at: start.addingTimeInterval(1)), "leaving the beacon's range")
    }

    @Test("Without a maximum age only moving makes it due")
    func noMaximumAge() {
        var throttle = ReportThrottle(minimumDistance: 500)
        throttle.sent(nyne, at: start)

        #expect(!throttle.isDue(north(100), at: start.addingTimeInterval(24 * 60 * 60)))
        #expect(throttle.isDue(north(600), at: start.addingTimeInterval(1)))
    }

    @Test("A failed request is forgotten, so the next one is due")
    func reset() {
        var throttle = ReportThrottle(minimumDistance: 50, maximumAge: 60)
        throttle.sent(nyne, at: start)
        throttle.reset()

        #expect(throttle.isDue(nyne, at: start))
    }

    @Test("Another beacon in the same locale doesn't change what's reported")
    func trackerBeaconMinor() {
        var tracker = PositionTracker(simulationAllowed: false)
        tracker.deviceFix(latitude: nyne.latitude, longitude: nyne.longitude)

        let first = tracker.beacon(major: 1, minor: 2)
        #expect(first)
        let sameLocale = tracker.beacon(major: 1, minor: 3)
        #expect(!sameLocale)
        let otherLocale = tracker.beacon(major: 4, minor: 3)
        #expect(otherLocale)
    }
}
