//
//  ModelDecodingTests.swift
//  HotMessTests
//

import CoreLocation
import Foundation
import Testing

@testable import HotMess

private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
    try JSONDecoder.hotMess.decode(type, from: Data(json.utf8))
}

/// Expected instants are written as UTC rather than epoch numbers so the
/// assertion says what it means.
private func instant(_ iso8601: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: iso8601))
}

@Suite("Venue decoding")
struct VenueDecodingTests {
    @Test("Reads every field the API sends")
    func fullPayload() throws {
        let venue = try decode(Venue.self, from: Fixtures.venue)

        #expect(venue.name == "The Stud")
        #expect(venue.address == "399 9th St")
        #expect(venue.subtitle == "Since 1966.")
        #expect(venue.isLiked)
        #expect(venue.distance == 412.5)
        #expect(venue.facebookID?.rawValue == "112233445566")
        #expect(venue.heroURL?.lastPathComponent == "stud-hero.jpg")
    }

    @Test("`point` maps x to latitude and y to longitude")
    func coordinate() throws {
        let venue = try decode(Venue.self, from: Fixtures.venue)
        let coordinate = try #require(venue.coordinate)

        #expect(coordinate.latitude == 37.7726)
        #expect(coordinate.longitude == -122.4099)
    }

    @Test("Survives a payload with only id and name")
    func minimalPayload() throws {
        let venue = try decode(Venue.self, from: Fixtures.minimalVenue)

        #expect(venue.name == "Pop-up")
        #expect(venue.address == nil)
        #expect(venue.coordinate == nil)
        #expect(venue.isLiked == false)
        #expect(venue.facebookURL == nil)
        // The old model substituted the literal string "unknown" here.
        #expect(venue.summary.isEmpty == false)
    }
}

@Suite("Event decoding")
struct EventDecodingTests {
    @Test("Parses the API's offset date format")
    func dates() throws {
        let event = try decode(Event.self, from: Fixtures.event)

        // 21:00 on the 26th at -0700 is 04:00 UTC on the 27th.
        let expectedStart = try instant("2017-04-27T04:00:00Z")
        let expectedEnd = try instant("2017-04-27T09:00:00Z")

        #expect(event.startDate == expectedStart)
        #expect(event.endDate == expectedEnd)
    }

    @Test("Also accepts plain ISO 8601")
    func iso8601Dates() throws {
        let event = try decode(Event.self, from: Fixtures.sparseEvent)

        let expectedStart = try instant("2017-04-27T06:30:00Z")

        #expect(event.startDate == expectedStart)
        #expect(event.endDate == nil)
    }

    @Test("Maps the legacy `decliend` spelling onto `declined`")
    func legacyRSVPSpelling() throws {
        let event = try decode(Event.self, from: Fixtures.event)

        #expect(event.rsvp == .declined)
    }

    @Test("Defaults a missing RSVP to undecided")
    func missingRSVP() throws {
        let event = try decode(Event.self, from: Fixtures.sparseEvent)

        #expect(event.rsvp == .unsure)
    }

    @Test("Builds a subtitle without a venue instead of crashing")
    func subtitleWithoutVenue() throws {
        let event = try decode(Event.self, from: Fixtures.sparseEvent)

        #expect(event.venue == nil)
        #expect(event.subtitle.isEmpty == false)
    }

    @Test("Writes the corrected RSVP spelling back to the API")
    func rsvpEncoding() throws {
        let body = try JSONEncoder().encode(RSVPRequest(state: .declined))

        #expect(String(decoding: body, as: UTF8.self).contains("\"declined\""))
    }
}

@Suite("Facebook IDs")
struct FacebookIDTests {
    @Test("Accepts a JSON number")
    func numeric() throws {
        let event = try decode(Event.self, from: Fixtures.event)

        #expect(event.facebookID?.rawValue == "998877665544")
    }

    @Test("Accepts a JSON string")
    func string() throws {
        let venue = try decode(Venue.self, from: Fixtures.venue)

        #expect(venue.facebookID?.rawValue == "112233445566")
    }

    @Test("Derives the links the UI needs")
    func derivedLinks() {
        let id = FacebookID("42")

        #expect(id.profileURL?.absoluteString == "https://facebook.com/42")
        #expect(id.eventURL?.absoluteString == "https://facebook.com/events/42")
        #expect(id.messengerURL?.absoluteString == "fb-messenger://user-thread/42")
    }
}

@Suite("Event listing")
struct EventListingTests {
    @Test("Turns the sections dictionary into an ordered list")
    func ordering() throws {
        let listing = try decode(EventListing.self, from: Fixtures.eventListing)

        // "tonight" starts first, "later" second, and the section with no
        // events sorts last — regardless of dictionary iteration order.
        #expect(listing.sections.map(\.id) == ["tonight", "later", "empty"])
        #expect(listing.sections.map(\.title) == ["Tonight", "Later This Week", "Nothing Here"])
    }

    @Test("Is not considered empty while any section has events")
    func emptiness() throws {
        let listing = try decode(EventListing.self, from: Fixtures.eventListing)

        #expect(listing.isEmpty == false)
        #expect(EventListing().isEmpty)
    }
}

@Suite("Now")
struct NowDecodingTests {
    @Test("A missing `venues` key means we don't know where the user is")
    func friendsVariant() throws {
        let now = try decode(Now.self, from: Fixtures.nowWithFriends)

        #expect(now.venues == nil)
        #expect(now.isNearVenues == false)
        #expect(now.friends.count == 1)
        #expect(now.friends.first?.firstName == "Ada")
    }

    @Test("A present `venues` key means we do, even when it is empty")
    func venuesVariant() throws {
        let now = try decode(Now.self, from: Fixtures.nowNearVenues)

        #expect(now.isNearVenues)
        #expect(now.venues?.count == 1)
        #expect(now.title == "Saturday in SoMa")
        #expect(now.region != nil)
    }
}

@Suite("Person detail")
struct PersonDetailTests {
    @Test("Flattens the person and its nested collections")
    func nestedCollections() throws {
        let detail = try decode(PersonDetail.self, from: Fixtures.personDetail)

        #expect(detail.name == "Rick Mark")
        #expect(detail.person.role == "Resident")
        #expect(detail.socialLinks.count == 1)
        #expect(detail.socialLinks.first?.assetName == "Instagram")
        #expect(detail.tracks.count == 1)
        #expect(detail.events.count == 1)
    }

    @Test("Leaves collections empty when the API omits them")
    func missingCollections() throws {
        let detail = try decode(PersonDetail.self, from: """
        { "id": "0A1B2C3D-4E5F-4A6B-8C9D-0E1F2A3B4C5D", "name": "Nobody" }
        """)

        #expect(detail.events.isEmpty)
        #expect(detail.tracks.isEmpty)
        #expect(detail.socialLinks.isEmpty)
    }
}

@Suite("Chat wire format")
struct VenueMessageTests {
    @Test("Decodes an inbound Action Cable message")
    func inbound() throws {
        let payload = try JSONDecoder().decode(VenueMessage.Payload.self, from: Data("""
        {
          "message": "who's here",
          "user_id": "6C4D2E80-3A19-4B7F-9E5C-1D0A8B2F3E44",
          "avatar_url": "https://api.hotmess.social/users/x/picture"
        }
        """.utf8))

        let message = VenueMessage(payload: payload)

        #expect(message.body == "who's here")
        #expect(message.isOutgoing(for: payload.userID))
        #expect(message.isOutgoing(for: UUID()) == false)
        #expect(message.isOutgoing(for: nil) == false)
    }
}
