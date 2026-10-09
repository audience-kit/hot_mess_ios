//
//  GeofencePlanTests.swift
//  HotMessTests
//

import CoreLocation
import Foundation
import Testing

@testable import HotMess

@Suite("Venue geofences")
struct GeofencePlanTests {
    private let here = Coordinates(latitude: 47.6575, longitude: -117.4148)

    /// A venue `metres` north of `here`. A degree of latitude is about 111 km.
    private func venue(_ metres: Double, radius: Double = 250) -> VenueFence {
        VenueFence(id: UUID(), latitude: here.latitude + metres / 111_000, longitude: here.longitude, radius: radius)
    }

    @Test("Watches the nearest 19 venues and stops the re-center circle short of the 20th")
    func nearestVenues() {
        let venues = (1...30).map { venue(Double($0) * 1_000) }.shuffled()
        let plan = GeofencePlan(around: here, venues: venues)

        #expect(plan.venues.count == GeofencePlan.regionLimit - 1)
        let watched = Set(plan.venues.map(\.id))
        let nearest = venues.sorted { $0.latitude < $1.latitude }.prefix(19)
        #expect(watched == Set(nearest.map(\.id)))

        // The 20th venue is 20 km north; its envelope starts 250 m sooner.
        #expect(abs(plan.recenterRadius - 19_750) < 100)
        #expect(plan.recenterLatitude == here.latitude && plan.recenterLongitude == here.longitude)
    }

    @Test("A big venue nearby counts by its edge, not its center")
    func edgeDistance() {
        let small = venue(600, radius: 50)
        let big = venue(900, radius: 600)
        let plan = GeofencePlan(around: here, venues: [small, big], regionLimit: 2)

        #expect(plan.venues == [big])
        #expect(plan.recenterRadius >= GeofencePlan.minimumRecenterRadius)
        #expect(abs(plan.recenterRadius - 550) < 20)
    }

    @Test("With every venue watched, the re-center circle is as large as it gets")
    func fewVenues() {
        let plan = GeofencePlan(around: here, venues: [venue(500), venue(2_000)])

        #expect(plan.venues.count == 2)
        #expect(plan.recenterRadius == GeofencePlan.maximumRecenterRadius)
    }

    @Test("Never shrinks the re-center circle below the minimum, even next to an unwatched venue")
    func minimumRadius() {
        let plan = GeofencePlan(around: here, venues: [venue(10), venue(20)], regionLimit: 2)

        #expect(plan.venues.count == 1)
        #expect(plan.recenterRadius == GeofencePlan.minimumRecenterRadius)
    }

    @Test("Decodes envelopes from the venues query, skipping venues without a point")
    func decoding() throws {
        let json = Data("""
        {"venues": [
          {"id": "6f1c1f5e-2d47-4c5e-9f4b-1f2a3b4c5d6e", "point": "POINT (-117.41 47.65)", "distance_tolerance": 120},
          {"id": "7a2d2f6e-3e58-4d6f-8a5c-2a3b4c5d6e7f", "point": null, "distance_tolerance": 250}
        ]}
        """.utf8)

        let response = try JSONDecoder.hotMess.decode(VenueFencesResponse.self, from: json)

        #expect(response.venues.count == 1)
        let fence = try #require(response.venues.first)
        #expect(fence.latitude == 47.65 && fence.longitude == -117.41 && fence.radius == 120)
    }
}
