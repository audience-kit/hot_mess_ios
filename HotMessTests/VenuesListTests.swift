//
//  VenuesListTests.swift
//  HotMessTests
//

import AudienceKit
import Foundation
import Testing

@testable import HotMess

@Suite("Venues list")
struct VenueCollectionLocaleTests {
    private let seattle = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let portland = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func venue(_ name: String, locale: UUID, order: Int = 0, hidden: Bool = false) throws -> AudienceKit.Venue {
        let json = """
        {"id": "\(UUID().uuidString)", "name": "\(name)", "hidden": \(hidden), "order": \(order),
         "locale": {"id": "\(locale.uuidString)", "name": "Locale"}}
        """
        return try JSONDecoder().decode(AudienceKit.Venue.self, from: Data(json.utf8))
    }

    @Test("Shows only venues in the current locale")
    func filtersToLocale() throws {
        let venues = [
            try venue("Neighbours", locale: seattle, order: 2),
            try venue("Crush", locale: portland),
            try venue("Hidden", locale: seattle, hidden: true),
            try venue("R Place", locale: seattle, order: 1)
        ]

        let collection = VenueCollection(audienceVenues: venues, localeID: seattle) { _ in nil }

        #expect(collection.venues.map(\.name) == ["R Place", "Neighbours"])
    }

    @Test("Shows every visible venue until the locale is known")
    func showsAllWithoutLocale() throws {
        let venues = [try venue("Neighbours", locale: seattle), try venue("Crush", locale: portland)]

        let collection = VenueCollection(audienceVenues: venues, localeID: nil) { _ in nil }

        #expect(collection.venues.count == 2)
    }
}
