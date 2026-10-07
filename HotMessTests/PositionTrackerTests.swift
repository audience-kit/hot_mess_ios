//
//  PositionTrackerTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

@Suite("Pretend I'm here")
struct PositionTrackerTests {
    private let nyne = Coordinates(latitude: 47.6575451, longitude: -117.414777)

    @Test("Reports the device's position with its beacon")
    func devicePosition() {
        var tracker = PositionTracker(simulationAllowed: false)
        // #expect can't call mutating methods, so each result is taken first.
        let beaconWithoutFix = tracker.beacon(major: 1, minor: 2)
        #expect(!beaconWithoutFix, "no beacon without a position")

        let firstFix = tracker.deviceFix(latitude: 47.61, longitude: -122.32)
        #expect(firstFix)
        let firstBeacon = tracker.beacon(major: 1, minor: 2)
        #expect(firstBeacon)
        let sameBeacon = tracker.beacon(major: 1, minor: 2)
        #expect(!sameBeacon, "the same beacon again changes nothing")
        let secondFix = tracker.deviceFix(latitude: 47.62, longitude: -122.33)
        #expect(secondFix)

        #expect(tracker.current == Coordinates(latitude: 47.62, longitude: -122.33, beaconMajor: 1, beaconMinor: 2))
    }

    @Test("Reports the venue while pretending, then the latest real position")
    func pretending() {
        var tracker = PositionTracker(simulationAllowed: true)
        tracker.deviceFix(latitude: 47.61, longitude: -122.32)

        let started = tracker.simulate(latitude: nyne.latitude, longitude: nyne.longitude, venueName: "Nyne")
        #expect(started)
        #expect(tracker.current == nyne)
        #expect(tracker.simulatedVenueName == "Nyne")

        let fixWhilePretending = tracker.deviceFix(latitude: 47.70, longitude: -122.40)
        #expect(!fixWhilePretending, "device fixes aren't reported while pretending")
        let beaconWhilePretending = tracker.beacon(major: 3, minor: 4)
        #expect(!beaconWhilePretending)
        #expect(tracker.current == nyne)

        let stopped = tracker.stopSimulating()
        #expect(stopped)
        #expect(tracker.simulatedVenueName == nil)
        #expect(tracker.current == Coordinates(latitude: 47.70, longitude: -122.40, beaconMajor: 3, beaconMinor: 4))
        let stoppedAgain = tracker.stopSimulating()
        #expect(!stoppedAgain)
    }

    @Test("Reports nothing after stopping when there's no real fix yet")
    func stopWithoutFix() {
        var tracker = PositionTracker(simulationAllowed: true)
        tracker.simulate(latitude: nyne.latitude, longitude: nyne.longitude, venueName: "Nyne")
        tracker.stopSimulating()

        #expect(tracker.current == nil)
    }

    @Test("Store builds can't pretend")
    func storeBuilds() {
        var tracker = PositionTracker(simulationAllowed: false)
        tracker.deviceFix(latitude: 47.61, longitude: -122.32)

        let started = tracker.simulate(latitude: nyne.latitude, longitude: nyne.longitude, venueName: "Nyne")
        #expect(!started)
        #expect(tracker.simulatedVenueName == nil)
        #expect(tracker.current == Coordinates(latitude: 47.61, longitude: -122.32))
    }

    @Test("Only staging and debug builds are test builds")
    func testBuilds() {
        let base = URL(string: "https://api.audiencekit.com")!
        #expect(AppConfiguration(baseURL: base, environment: .staging).isTestBuild)
        #if !DEBUG
        #expect(!AppConfiguration(baseURL: base, environment: .production).isTestBuild)
        #endif
    }
}
