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
        #expect(!tracker.beacon(major: 1, minor: 2), "no beacon without a position")

        #expect(tracker.deviceFix(latitude: 47.61, longitude: -122.32))
        #expect(tracker.beacon(major: 1, minor: 2))
        #expect(!tracker.beacon(major: 1, minor: 2), "the same beacon again changes nothing")
        #expect(tracker.deviceFix(latitude: 47.62, longitude: -122.33))

        #expect(tracker.current == Coordinates(latitude: 47.62, longitude: -122.33, beaconMajor: 1, beaconMinor: 2))
    }

    @Test("Reports the venue while pretending, then the latest real position")
    func pretending() {
        var tracker = PositionTracker(simulationAllowed: true)
        tracker.deviceFix(latitude: 47.61, longitude: -122.32)

        #expect(tracker.simulate(latitude: nyne.latitude, longitude: nyne.longitude, venueName: "Nyne"))
        #expect(tracker.current == nyne)
        #expect(tracker.simulatedVenueName == "Nyne")

        #expect(!tracker.deviceFix(latitude: 47.70, longitude: -122.40), "device fixes aren't reported while pretending")
        #expect(!tracker.beacon(major: 3, minor: 4))
        #expect(tracker.current == nyne)

        #expect(tracker.stopSimulating())
        #expect(tracker.simulatedVenueName == nil)
        #expect(tracker.current == Coordinates(latitude: 47.70, longitude: -122.40, beaconMajor: 3, beaconMinor: 4))
        #expect(!tracker.stopSimulating())
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

        #expect(!tracker.simulate(latitude: nyne.latitude, longitude: nyne.longitude, venueName: "Nyne"))
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
