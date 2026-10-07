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

    @Test("`point` maps x to longitude and y to latitude")
    func coordinate() throws {
        let venue = try decode(Venue.self, from: Fixtures.venue)
        let coordinate = try #require(venue.coordinate)

        #expect(coordinate.latitude == 37.7726)
        #expect(coordinate.longitude == -122.4099)
    }

    @Test("`point` also decodes as a GeoJSON point")
    func geoJSONCoordinate() throws {
        let point = try decode(GeoPoint.self, from: #"{ "type": "Point", "coordinates": [-122.4099, 37.7726] }"#)

        #expect(point.coordinate.latitude == 37.7726)
        #expect(point.coordinate.longitude == -122.4099)
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
        #expect(event.subtitle.hasSuffix(Event.toBeAnnounced))
    }

    @Test("Maps RSVPs onto the GraphQL enum and reads it back")
    func rsvpGraphQL() throws {
        #expect(RSVP.declined.state == .declined)
        #expect(try JSONDecoder().decode(RSVP.self, from: Data(#""MAYBE""#.utf8)) == .maybe)
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

    @Test("Splits tip links from social profiles")
    func tipLinks() throws {
        let detail = try decode(PersonDetail.self, from: """
        { "id": "0A1B2C3D-4E5F-4A6B-8C9D-0E1F2A3B4C5D", "name": "Trixie",
          "social_links": [
            { "id": "1A1B2C3D-4E5F-4A6B-8C9D-0E1F2A3B4C5D", "handle": "trixie", "provider": "instagram",
              "url": "https://instagram.com/trixie" },
            { "id": "2A1B2C3D-4E5F-4A6B-8C9D-0E1F2A3B4C5D", "handle": "TrixieTips", "provider": "cashapp",
              "url": "https://cash.app/$TrixieTips" },
            { "id": "3A1B2C3D-4E5F-4A6B-8C9D-0E1F2A3B4C5D", "handle": "trixie-tips", "provider": "venmo",
              "url": "https://venmo.com/u/trixie-tips" }
          ] }
        """)

        #expect(detail.tipLinks.compactMap(\.tipApp) == ["Cash App", "Venmo"])
        #expect(detail.profileLinks.map(\.provider) == ["instagram"])
    }

    @Test("Reads the people a person is made of and part of")
    func membersAndGroups() throws {
        let detail = try decode(PersonDetail.self, from: Fixtures.personDetail)

        #expect(detail.members.map(\.name) == ["Ada Lovelace"])
        #expect(detail.members.first?.pictureURL?.lastPathComponent == "ada.jpg")
        #expect(detail.groups.map(\.name) == ["The Haus of Mess"])
        #expect(detail.groups.first?.pictureURL == nil)
    }

    @Test("Leaves collections empty when the API omits them")
    func missingCollections() throws {
        let detail = try decode(PersonDetail.self, from: """
        { "id": "0A1B2C3D-4E5F-4A6B-8C9D-0E1F2A3B4C5D", "name": "Nobody" }
        """)

        #expect(detail.events.isEmpty)
        #expect(detail.tracks.isEmpty)
        #expect(detail.socialLinks.isEmpty)
        #expect(detail.members.isEmpty)
        #expect(detail.groups.isEmpty)
    }
}

@Suite("Venue detail")
struct VenueDetailTests {
    @Test("Reads the venue's links elsewhere")
    func socialLinks() throws {
        let detail = try decode(VenueWithEvents.self, from: Fixtures.venueDetail)

        #expect(detail.venue.name == "The Stud")
        #expect(detail.chatOpen)
        #expect(detail.events.count == 1)
        #expect(detail.socialLinks.count == 1)
        #expect(detail.socialLinks.first?.assetName == "Instagram")
        #expect(detail.socialLinks.first?.url?.host() == "instagram.com")
    }

    @Test("Leaves links empty when the API omits them")
    func missingSocialLinks() throws {
        let detail = try decode(VenueWithEvents.self, from: Fixtures.minimalVenue)

        #expect(detail.socialLinks.isEmpty)
        #expect(detail.events.isEmpty)
        #expect(detail.chatOpen == false)
    }
}

@Suite("Chat wire format")
struct VenueMessageTests {
    @Test("Decodes an inbound Action Cable message")
    func inbound() throws {
        let payload = try JSONDecoder().decode(VenueMessage.Payload.self, from: Data("""
        {
          "type": "incoming",
          "message": "who's here",
          "user_id": "6c4d2e80-3a19-4b7f-9e5c-1d0a8b2f3e44",
          "name": "Rick",
          "avatar_url": "https://cdn.hotmess.social/rick",
          "sent_at": "2026-10-06T22:10:00Z"
        }
        """.utf8))

        let message = VenueMessage(payload: payload)

        #expect(message.body == "who's here")
        #expect(message.name == "Rick")
        #expect(message.sentAt == Date(timeIntervalSince1970: 1_791_324_600))
        #expect(message.isOutgoing(for: payload.userID))
        #expect(message.isOutgoing(for: UUID()) == false)
        #expect(message.isOutgoing(for: nil) == false)
        #expect(message.role == nil)
        #expect(message.kind == .text)
        #expect(message.isPinned == false)
        #expect(message.richContent == nil)
    }

    @Test("Decodes a rich message from someone with a role")
    func richFrame() throws {
        let payload = try JSONDecoder().decode(VenueMessage.Payload.self, from: Data("""
        {
          "type": "incoming",
          "id": "1b2c3d4e-5f60-4718-9a2b-3c4d5e6f7a8b",
          "message": "Shared an event: Sunset Social\\nCome through",
          "user_id": "6c4d2e80-3a19-4b7f-9e5c-1d0a8b2f3e44",
          "name": "Kiko M.",
          "avatar_url": null,
          "sent_at": "2026-10-06T22:10:00Z",
          "role": "host",
          "kind": "event",
          "title": null,
          "body": "Come through",
          "photo_url": null,
          "event": { "id": "0a1e0aac-1d01-42d1-9de5-f0279842d9c0", "name": "Sunset Social", "start_at": "2026-10-10T02:00:00Z" },
          "ends_at": null,
          "pinned": false
        }
        """.utf8))

        let message = VenueMessage(payload: payload)

        #expect(message.body == "Shared an event: Sunset Social\nCome through")
        #expect(message.role == .host)
        #expect(message.kind == .event)
        #expect(message.written == "Come through")
        #expect(message.event?.name == "Sunset Social")
        #expect(message.event?.startAt == Date(timeIntervalSince1970: 1_791_597_600))
        #expect(message.isFromPlace == false)
        guard case let .event(event, caption) = message.richContent else {
            Issue.record("Expected an event")
            return
        }
        #expect(event.id == UUID(uuidString: "0A1E0AAC-1D01-42D1-9DE5-F0279842D9C0"))
        #expect(caption == "Come through")
    }

    @Test("Reads GraphQL's uppercase enums")
    func graphQLEnums() throws {
        let payload = try JSONDecoder().decode(VenueMessage.Payload.self, from: Data("""
        {
          "message": "Announcement: Coat check closes at midnight",
          "body": "",
          "user_id": "6c4d2e80-3a19-4b7f-9e5c-1d0a8b2f3e44",
          "name": "Neighbours",
          "role": "VENUE",
          "kind": "ANNOUNCEMENT",
          "title": "Coat check closes at midnight",
          "pinned": true,
          "posted_as_venue": true,
          "presence": "ONLINE",
          "event": null
        }
        """.utf8))

        let message = VenueMessage(payload: payload)

        #expect(message.role == .venue)
        #expect(message.kind == .announcement)
        #expect(message.isPinned)
        #expect(message.postedAsVenue)
        #expect(message.isFromPlace)
        #expect(message.presence == .online)
        #expect(message.richContent == .announcement(
            title: "Coat check closes at midnight", body: nil, photoURL: nil, isPinned: true
        ))
    }

    @Test("Shows an unknown or incomplete rich message as its summary")
    func unknownKind() throws {
        let payload = try JSONDecoder().decode(VenueMessage.Payload.self, from: Data("""
        {
          "message": "Shared a photo",
          "user_id": "6c4d2e80-3a19-4b7f-9e5c-1d0a8b2f3e44",
          "role": "dj",
          "kind": "photo",
          "photo_url": "",
          "pinned": "yes"
        }
        """.utf8))

        let message = VenueMessage(payload: payload)

        #expect(message.role == nil)
        #expect(message.kind == .photo)
        #expect(message.isPinned == false)
        #expect(message.richContent == nil)
        #expect(message.threadMessage(currentUserID: nil).text == "Shared a photo")
    }

    @Test("A special stops showing at its end")
    func specialEnds() {
        var message = VenueMessage(body: "Special: Two for one", userID: UUID())
        message.kind = .special
        message.title = "Two for one"
        message.endsAt = Date(timeIntervalSince1970: 1_000)

        #expect(message.isShowing(at: Date(timeIntervalSince1970: 999)))
        #expect(message.isShowing(at: Date(timeIntervalSince1970: 1_000)) == false)
    }

    @Test("Shows friends by their full name, and who's online in the room")
    func friendNamesAndPresence() throws {
        let userID = UUID()
        let message = VenueMessage(body: "hi", userID: userID, name: "Aurora B.")
        let friend = HotMess.Friend(id: userID, name: "Aurora Borealis")

        let stranger = message.threadMessage(currentUserID: nil, online: [])
        let known = message.threadMessage(currentUserID: nil, friends: [userID: friend], online: [userID])

        #expect(stranger.authorName == "Aurora B.")
        #expect(stranger.presence == nil)
        #expect(known.authorName == "Aurora Borealis")
        #expect(known.presence == .online)
    }

    @Test("A post as the venue keeps the venue's name and has no presence")
    func placeKeepsItsName() {
        let userID = UUID()
        var message = VenueMessage(body: "Doors at 9", userID: userID, name: "Neighbours")
        message.role = .venue
        let friend = HotMess.Friend(id: userID, name: "Aurora Borealis")

        let thread = message.threadMessage(currentUserID: nil, friends: [userID: friend], online: [userID])

        #expect(thread.authorName == "Neighbours")
        #expect(thread.presence == nil)
        #expect(thread.isFromPlace)
        #expect(thread.authorID != userID.uuidString)
    }

    @Test("Rich messages stand alone in the thread")
    func richMessagesStandAlone() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        func message(_ id: String, rich: ChatRichContent? = nil, minutes: Double) -> ChatThreadMessage {
            ChatThreadMessage(
                id: id, authorID: "kiko", authorName: "Kiko", avatarURL: nil, text: id,
                sentAt: start.addingTimeInterval(minutes * 60), isOwn: false, rich: rich
            )
        }

        let rows = ChatThreadRow.rows(for: [
            message("a", minutes: 0),
            message("b", rich: .special(title: "Two for one", body: nil, endsAt: nil), minutes: 1),
            message("c", minutes: 2),
            message("d", minutes: 3),
        ])

        #expect(rows.map(\.isFirstInGroup) == [true, true, true, false])
        #expect(rows.map(\.isLastInGroup) == [true, true, false, true])
    }

    @Test("Reads a friend's presence")
    func friendPresence() throws {
        let friends = try decode([HotMess.Friend].self, from: """
        [
          {"id":"6c4d2e80-3a19-4b7f-9e5c-1d0a8b2f3e44","name":"Aurora Borealis","presence":"ONLINE"},
          {"id":"0a1e0aac-1d01-42d1-9de5-f0279842d9c0","name":"Sam Oak","presence":"PUSH"},
          {"id":"1b2c3d4e-5f60-4718-9a2b-3c4d5e6f7a8b","name":"Jo","presence":"OFFLINE"},
          {"id":"2b2c3d4e-5f60-4718-9a2b-3c4d5e6f7a8b","name":"Older API"}
        ]
        """)

        #expect(friends.map(\.presence) == [.online, .push, nil, nil])
    }
}

@Test func musicLinksNameTheirService() {
    let spotify = SocialLink(id: UUID(), handle: "artist/4Z8W4fKeB5YxbusRsdQVPb", provider: "spotify")
    let appleMusic = SocialLink(id: UUID(), handle: "us/artist/1", provider: "apple_music")
    let soundCloud = SocialLink(id: UUID(), handle: "dj-dugan", provider: "soundcloud")

    #expect(spotify.label == "Spotify")
    #expect(appleMusic.label == "Apple Music")
    #expect(soundCloud.label == "/dj-dugan")
    #expect(spotify.systemImage == "music.note")
    #expect(soundCloud.systemImage == "link")
}
