//
//  PingTests.swift
//  HotMessTests
//

import AudienceKit
import Foundation
import Testing

@testable import HotMess

private enum PingFixtures {
    static let jordan = "3d4e5f60-7182-4930-9c4d-5e6f7a8b9c0d"
    static let sam = "4e5f6071-8293-4a41-8d5e-6f7a8b9c0d1e"
    static let alex = "5f607182-93a4-4b52-9e6f-7a8b9c0d1e2f"
    static let wildrose = "6f1c2c1e-4d2a-4f6b-9a37-0c1d2e3f4a5b"
    static let bingo = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d"

    static let venue = """
    {"id":"\(wildrose)","name":"The Wildrose","address":"1021 E Pike St","phone":null,"distance":null,
     "point":null,"facebook_id":null,"photo_url":null,"hero_url":null,"is_liked":false}
    """

    static let event = """
    {"id":"\(bingo)","name":"Drag Bingo","start_at":"2026-10-09T21:00:00-07:00","end_at":null,
     "facebook_id":null,"cover_photo_url":null,"is_featured":false,"rsvp":"UNSURE","venue":\(venue)}
    """

    /// Jordan's Ping for Drag Bingo or The Wildrose: Sam is in for bingo,
    /// Alex for the night as a whole. The viewer sees it through Sam.
    static let ping = """
    {
      "id":"ping-1","note":"who's coming 🙃","created_at":"2026-10-09T21:46:00-07:00",
      "expires_at":"2026-10-10T05:00:00-07:00","is_mine":false,"joined":false,"reach":"FRIENDS_OF_CIRCLE",
      "user":{"id":"\(jordan)","name":"Jordan Rivers","facebook_id":null},
      "via":{"id":"\(sam)","name":"Sam Chatter","facebook_id":"4242"},
      "targets":[
        {"id":"target-1","venue":null,"event":\(event),
         "joins":[{"id":"join-1","target_id":"target-1","user":{"id":"\(sam)","name":"Sam Chatter","facebook_id":null}}]},
        {"id":"target-2","venue":\(venue),"event":null,"joins":[]}
      ],
      "joins":[
        {"id":"join-1","target_id":"target-1","user":{"id":"\(sam)","name":"Sam Chatter","facebook_id":null}},
        {"id":"join-2","target_id":null,"user":{"id":"\(alex)","name":"Alex Friend","facebook_id":null}}
      ]
    }
    """

    static let anywhere = """
    {
      "id":"ping-2","note":"  ","created_at":"2026-10-09T21:30:00-07:00",
      "expires_at":"2026-10-10T05:00:00-07:00","is_mine":true,"joined":false,"reach":"FRIENDS",
      "user":{"id":"\(alex)","name":"Alex Friend","facebook_id":null},"via":null,
      "targets":[],"joins":[]
    }
    """

    static func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
        try JSONDecoder.hotMess.decode(type, from: Data(json.utf8))
    }

    static func uuid(_ text: String) -> UUID { UUID(uuidString: text)! }

    static func friend(_ id: String, _ name: String) -> HotMess.Friend { HotMess.Friend(id: uuid(id), name: name) }
}

@Suite("Ping decoding")
struct PingDecodingTests {
    @Test("Decodes a Ping with its picks, joins, reach and via")
    func decodesPing() throws {
        let ping = try PingFixtures.decode(Ping.self, PingFixtures.ping)

        #expect(ping.id == "ping-1")
        #expect(ping.user.name == "Jordan Rivers")
        #expect(ping.note == "who's coming 🙃")
        #expect(ping.reach == .friendsOfCircle)
        #expect(ping.via?.firstName == "Sam")
        #expect(ping.viaText == "via Sam")
        #expect(!ping.isMine)
        #expect(ping.targets.map(\.name) == ["Drag Bingo", "The Wildrose"])
        #expect(ping.targets[0].event?.venue?.name == "The Wildrose")
        #expect(ping.targets[0].joins.map(\.user.firstName) == ["Sam"])
        #expect(ping.joins.map(\.targetID) == ["target-1", nil])
        #expect(ping.expiresAt > ping.createdAt)
        #expect(ping.places == [.event(PingFixtures.uuid(PingFixtures.bingo)), .venue(PingFixtures.uuid(PingFixtures.wildrose))])
    }

    @Test("Treats a blank note as none and defaults the reach to friends")
    func decodesAnywherePing() throws {
        let ping = try PingFixtures.decode(Ping.self, PingFixtures.anywhere)

        #expect(ping.note == nil)
        #expect(ping.isMine)
        #expect(ping.reach == .friends)
        #expect(ping.via == nil)
        #expect(ping.targets.isEmpty)
        #expect(ping.placesSummary == nil)
        #expect(ping.peopleSummary == nil)
    }

    @Test("Reads an unknown reach as friends")
    func unknownReach() throws {
        let json = PingFixtures.anywhere.replacingOccurrences(of: "\"FRIENDS\"", with: "\"EVERYONE\"")

        #expect(try PingFixtures.decode(Ping.self, json).reach == .friends)
    }

    @Test("Decodes the user's Ping and friends' Pings into Now")
    func decodesNowPings() throws {
        let json = """
        {"reportLocation":{"now":{"title":"Now","venue":null,"venues":[],"events":[],"friends":[],
          "my_ping":\(PingFixtures.anywhere),"friend_pings":[\(PingFixtures.ping)]}}}
        """

        let now = try PingFixtures.decode(ReportLocationResponse.self, json).reportLocation.now

        #expect(now.myPing?.id == "ping-2")
        #expect(now.friendPings.map(\.id) == ["ping-1"])
    }

    @Test("Leaves Pings empty when Now doesn't carry them")
    func nowWithoutPings() throws {
        let now = try PingFixtures.decode(Now.self, Fixtures.nowWithFriends)

        #expect(now.myPing == nil)
        #expect(now.friendPings.isEmpty)
    }

    @Test("Decodes the Pings query with no Ping of your own")
    func decodesPingsQuery() throws {
        let response = try PingFixtures.decode(PingsResponse.self, #"{"my_ping":null,"friend_pings":[\#(PingFixtures.ping)]}"#)

        #expect(response.myPing == nil)
        #expect(response.friendPings.count == 1)
    }

    @Test("Decodes friends' Pings on a venue and an event")
    func decodesPlacePings() throws {
        let venueJSON = PingFixtures.venue.dropLast(1) + #","chat_open":false,"friend_pings":[\#(PingFixtures.ping)]}"#
        let venue = try PingFixtures.decode(VenueResponse.self, #"{"venue":\#(venueJSON)}"#)
        #expect(venue.venue?.friendPings.first?.user.firstName == "Jordan")

        let eventJSON = PingFixtures.event.dropLast(1) + #","people":[],"friend_pings":[\#(PingFixtures.ping)]}"#
        let event = try PingFixtures.decode(EventResponse.self, #"{"event":\#(eventJSON)}"#)
        #expect(event.event?.friendPings.count == 1)
        #expect(event.event?.event.name == "Drag Bingo")
    }

    @Test("Decodes the mutation payloads")
    func decodesMutations() throws {
        let sent = try PingFixtures.decode(SendPingResponse.self, #"{"sendPing":{"ping":\#(PingFixtures.anywhere)}}"#)
        #expect(sent.sendPing.ping.isMine)

        let joined = try PingFixtures.decode(JoinPingResponse.self, #"{"joinPing":{"ping":\#(PingFixtures.ping)}}"#)
        #expect(joined.joinPing.ping.id == "ping-1")

        let left = try PingFixtures.decode(LeavePingResponse.self, #"{"leavePing":{"ping":\#(PingFixtures.ping)}}"#)
        #expect(left.leavePing.ping.id == "ping-1")

        let ended = try PingFixtures.decode(EndPingResponse.self, #"{"endPing":{"ended":true}}"#)
        #expect(ended.endPing.ended)

        let registered = try PingFixtures.decode(RegisterDeviceResponse.self, #"{"registerDevice":{"registered":true}}"#)
        #expect(registered.registerDevice.registered)
    }
}

@Suite("Ping display")
struct PingDisplayTests {
    private let ping: Ping
    private let sam = PingFixtures.uuid(PingFixtures.sam)
    private let alex = PingFixtures.uuid(PingFixtures.alex)

    init() throws {
        ping = try PingFixtures.decode(Ping.self, PingFixtures.ping)
    }

    @Test("Names the picks in order")
    func placesSummary() {
        #expect(ping.placesSummary == "Drag Bingo · The Wildrose")
    }

    @Test("The circle is the sender, then everyone in, once each")
    func circle() {
        #expect(ping.circle.map(\.firstName) == ["Jordan", "Sam", "Alex"])
        #expect(ping.people.map(\.firstName) == ["Sam", "Alex"])
        #expect(ping.peopleSummary?.hasSuffix("are in") == true)
        #expect(Ping.inSummary([PingFixtures.friend(PingFixtures.sam, "Sam Chatter")]) == "Sam is in")
    }

    @Test("Knows which pick a user is in on")
    func joinedTargets() {
        #expect(ping.isJoined(ping.targets[0], by: sam))
        #expect(!ping.isJoined(ping.targets[1], by: sam))
        #expect(!ping.isJoinedAsWhole(by: sam))
        #expect(ping.isJoinedAsWhole(by: alex))
        #expect(!ping.isJoined(ping.targets[0], by: nil))
    }

    @Test("Finds the picks at a venue, its events included")
    func targetsAtVenue() {
        let venueID = PingFixtures.uuid(PingFixtures.wildrose)

        #expect(ping.targets(atVenue: venueID).map(\.id) == ["target-1", "target-2"])
        #expect(ping.target(forEvent: PingFixtures.uuid(PingFixtures.bingo))?.id == "target-1")
        #expect(ping.targets(atVenue: UUID()).isEmpty)
    }

    @Test("Shows friends' running Pings newest first, leaving out your own")
    func friendFeed() {
        let user = PingFixtures.friend(PingFixtures.jordan, "Jordan")
        let base = Date(timeIntervalSince1970: 1_000_000)
        let older = Ping(id: "older", user: user, createdAt: base, expiresAt: base + 3600)
        let newer = Ping(id: "newer", user: user, createdAt: base + 60, expiresAt: base + 3600)
        let expired = Ping(id: "expired", user: user, createdAt: base + 120, expiresAt: base + 10)
        let mine = Ping(id: "mine", user: user, createdAt: base + 180, expiresAt: base + 3600, isMine: true)

        let feed = Ping.friendFeed([older, expired, mine, newer], at: base + 30)

        #expect(feed.map(\.id) == ["newer", "older"])
    }

    @Test("Swaps an updated Ping into Now")
    func replacingInNow() {
        let user = PingFixtures.friend(PingFixtures.jordan, "Jordan")
        let date = Date(timeIntervalSince1970: 0)
        let friendPing = Ping(id: "a", user: user, createdAt: date, expiresAt: date + 60)
        let now = Now(title: "Now", friendPings: [friendPing])

        let joined = Ping(id: "a", user: user, createdAt: date, expiresAt: date + 60, joined: true)
        #expect(now.replacing(joined).friendPings.first?.joined == true)

        let mine = Ping(id: "b", user: user, createdAt: date, expiresAt: date + 60, isMine: true)
        let withMine = now.replacing(mine)
        #expect(withMine.myPing?.id == "b")
        #expect(withMine.friendPings.count == 1)
        #expect(withMine.removingMyPing().myPing == nil)
    }

    @Test("A place's I'm in covers every friend's Ping there")
    func placeJoin() {
        let venueID = PingFixtures.uuid(PingFixtures.wildrose)
        let targets: (Ping) -> [PingTarget] = { $0.targets(atVenue: venueID) }

        #expect(PingPlaceJoin.isJoined([ping], userID: sam, targets: targets))
        #expect(!PingPlaceJoin.isJoined([ping], userID: alex, targets: targets))
        #expect(!PingPlaceJoin.isJoined([], userID: sam, targets: targets))
        #expect(PingPlaceJoin.pendingJoins([ping], userID: sam, targets: targets).isEmpty)
        #expect(PingPlaceJoin.pendingJoins([ping], userID: alex, targets: targets).map(\.target.id) == ["target-1"])
    }
}

@Suite("Ping sending")
struct PingSendingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
    }

    private func event(_ name: String, _ start: String) -> Event {
        Event(id: UUID(), name: name, startDate: date(start))
    }

    @Test("Offers tonight's events, small hours included, earliest first")
    func tonight() {
        let events = [
            event("Late", "2026-10-10T01:00:00-07:00"),
            event("Bingo", "2026-10-09T21:00:00-07:00"),
            event("Tomorrow", "2026-10-10T21:00:00-07:00"),
            event("Yesterday", "2026-10-08T22:00:00-07:00"),
        ]

        let evening = PingChoices.tonight(events, at: date("2026-10-09T22:00:00-07:00"), calendar: calendar)
        #expect(evening.map(\.name) == ["Bingo", "Late"])

        // At 2am it is still the same night.
        let smallHours = PingChoices.tonight(events, at: date("2026-10-10T02:00:00-07:00"), calendar: calendar)
        #expect(smallHours.map(\.name) == ["Bingo", "Late"])
    }

    @Test("Puts a seeded place at the top when the lists lack it")
    func seededChoices() {
        let listed = Venue(id: UUID(), name: "Neighbours")
        let seeded = Venue(id: UUID(), name: "The Wildrose")
        let choices = PingChoices(venues: [listed])

        #expect(choices.including(PingSeed.venue(seeded)).venues.map(\.name) == ["The Wildrose", "Neighbours"])
        #expect(choices.including(PingSeed.venue(listed)).venues.map(\.name) == ["Neighbours"])
    }

    @Test("Splits picks into venue and event IDs, with the locale and reach")
    func sendPingVariables() {
        let venueID = PingFixtures.uuid(PingFixtures.wildrose)
        let eventID = PingFixtures.uuid(PingFixtures.bingo)
        let localeID = UUID()

        let variables = HotMessAPI.sendPingVariables(
            places: [.event(eventID), .venue(venueID)],
            note: "  who's coming  ",
            localeID: localeID,
            reach: .friendsOfCircle
        )

        #expect(variables["venueIds"] == [.string(PingFixtures.wildrose)])
        #expect(variables["eventIds"] == [.string(PingFixtures.bingo)])
        #expect(variables["note"] == "who's coming")
        #expect(variables["localeId"] == .string(localeID.uuidString.lowercased()))
        #expect(variables["reach"] == "FRIENDS_OF_CIRCLE")
    }

    @Test("Sends no note, no picks and no locale as nulls and empty lists")
    func anywhereVariables() {
        let variables = HotMessAPI.sendPingVariables(places: [], note: " ", localeID: nil, reach: .friends)

        #expect(variables["venueIds"] == [])
        #expect(variables["eventIds"] == [])
        #expect(variables["note"] == .null)
        #expect(variables["localeId"] == .null)
        #expect(variables["reach"] == "FRIENDS")
    }
}

@Suite("Ping push")
struct PingPushTests {
    @Test("Reads the kind and Ping ID from a push payload")
    func parsesPayload() {
        let ping = PingNotification(userInfo: ["aps": ["category": "PING"], "kind": "ping", "ping_id": "ping-1"])
        #expect(ping == PingNotification(kind: .ping, pingID: "ping-1"))

        let join = PingNotification(userInfo: ["kind": "ping_join", "ping_id": 42])
        #expect(join == PingNotification(kind: .pingJoin, pingID: "42"))

        #expect(PingNotification(userInfo: ["kind": "chat"]) == nil)
        #expect(PingNotification(userInfo: [:]) == nil)
    }

    @Test("Registers the device with its bundle ID and APNs environment")
    func registerDeviceVariables() {
        let variables = HotMessAPI.registerDeviceVariables(token: "0aff01", appID: "social.hotmess.Development", sandbox: true)

        #expect(variables == [
            "notificationToken": "0aff01",
            "appId": "social.hotmess.Development",
            "sandbox": true,
        ])
        #expect(HotMessAPI.registerDeviceVariables(token: "0a", appID: nil, sandbox: false)["appId"] == .null)
    }

    @Test("Takes the APNs environment from the build's entitlement")
    func pushSandbox() {
        let base = AppConfiguration.defaultBaseURL

        #expect(AppConfiguration(baseURL: base, apnsEnvironment: "development").isPushSandbox)
        #expect(!AppConfiguration(baseURL: base, apnsEnvironment: "production").isPushSandbox)
    }
}
