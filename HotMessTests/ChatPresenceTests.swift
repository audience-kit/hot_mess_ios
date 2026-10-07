//
//  ChatPresenceTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

private let me = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
private let aurora = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let sam = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
private let jo = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
private let alex = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

/// Wraps what the channel sent the way Action Cable does.
private func frame(_ message: String) -> Data {
    Data(#"{ "identifier": "{\"channel\":\"RealtimeChannel\"}", "message": \#(message) }"#.utf8)
}

@Suite("Chat room presence frames")
struct ChatPresenceFrameTests {
    @Test("A roster names everyone in the room and lists every friend")
    func fullRoster() throws {
        let data = frame("""
        {
          "type": "roster",
          "online": ["\(me)", "\(aurora)", "\(sam)"],
          "people": [
            { "user_id": "\(me)", "name": "Rick Mark", "avatar_url": "https://example.com/me.jpg", "friend": false },
            { "user_id": "\(aurora)", "name": "Aurora Bell", "avatar_url": "https://example.com/a.jpg", "friend": true },
            { "user_id": "\(sam)", "name": "Sam K." }
          ],
          "friends": [
            { "user_id": "\(aurora)", "name": "Aurora Bell" },
            { "user_id": "\(alex)", "name": "Alex Rivera" }
          ]
        }
        """)

        guard case let .roster(online, people, friends) = try #require(VenueChatConnection.event(from: data)) else {
            Issue.record("Expected a roster")
            return
        }

        #expect(online == [me, aurora, sam])
        #expect(people.count == 3)

        let auroraHere = try #require(people.first { $0.id == aurora })
        #expect(auroraHere.name == "Aurora Bell")
        #expect(auroraHere.avatarURL?.absoluteString == "https://example.com/a.jpg")
        #expect(auroraHere.isFriend)

        let samHere = try #require(people.first { $0.id == sam })
        #expect(samHere.name == "Sam K.")
        #expect(samHere.avatarURL == nil)
        #expect(!samHere.isFriend)

        #expect(friends.map(\.id) == [aurora, alex])
        #expect(friends.map(\.name) == ["Aurora Bell", "Alex Rivera"])
    }

    @Test("A roster from an older server, with only `online`, still decodes")
    func onlineOnlyRoster() throws {
        let data = frame(#"{ "type": "roster", "online": ["\#(aurora)", "not-a-uuid"] }"#)

        guard case let .roster(online, people, friends) = try #require(VenueChatConnection.event(from: data)) else {
            Issue.record("Expected a roster")
            return
        }

        #expect(online == [aurora])
        #expect(people.isEmpty)
        #expect(friends.isEmpty)
    }

    @Test("One malformed person or friend drops only itself")
    func malformedEntries() throws {
        let data = frame("""
        {
          "type": "roster",
          "online": [],
          "people": [{ "user_id": "nope", "name": "Bad" }, { "user_id": "\(jo)", "name": 7, "friend": "yes" }],
          "friends": [{ "user_id": "\(alex)" }, { "user_id": "\(aurora)", "name": "Aurora Bell" }]
        }
        """)

        guard case let .roster(_, people, friends) = try #require(VenueChatConnection.event(from: data)) else {
            Issue.record("Expected a roster")
            return
        }

        #expect(people.map(\.id) == [jo])
        #expect(people.first?.name == nil)
        #expect(people.first?.isFriend == false)
        #expect(friends.map(\.id) == [aurora])
    }

    @Test("A join carries a name and avatar")
    func onlinePresence() throws {
        let data = frame(#"{ "type": "presence", "user_id": "\#(sam)", "presence": "online", "name": "Sam K.", "avatar_url": "https://example.com/s.jpg" }"#)

        guard case let .presence(userID, online, name, avatarURL) = try #require(VenueChatConnection.event(from: data)) else {
            Issue.record("Expected presence")
            return
        }

        #expect(userID == sam)
        #expect(online)
        #expect(name == "Sam K.")
        #expect(avatarURL?.absoluteString == "https://example.com/s.jpg")
    }

    @Test("A leave is only an ID")
    func offlinePresence() throws {
        let data = frame(#"{ "type": "presence", "user_id": "\#(sam)", "presence": "offline" }"#)

        guard case let .presence(userID, online, name, avatarURL) = try #require(VenueChatConnection.event(from: data)) else {
            Issue.record("Expected presence")
            return
        }

        #expect(userID == sam)
        #expect(!online)
        #expect(name == nil)
        #expect(avatarURL == nil)
    }
}

@Suite("Here now")
struct HereNowTests {
    @Test("Friends first, then everyone else, each by name")
    func friendsFirst() {
        let sorted = HereNowPerson.sorted([
            HereNowPerson(id: sam, name: "Sam K.", avatarURL: nil, isFriend: false),
            HereNowPerson(id: jo, name: nil, avatarURL: nil, isFriend: false),
            HereNowPerson(id: aurora, name: "Aurora Bell", avatarURL: nil, isFriend: true),
            HereNowPerson(id: me, name: "Billie J.", avatarURL: nil, isFriend: false),
            HereNowPerson(id: alex, name: "Alex Rivera", avatarURL: nil, isFriend: true),
        ])

        #expect(sorted.map(\.id) == [alex, aurora, me, sam, jo])
    }

    @Test("Reads as name, friend, here now")
    func accessibility() {
        #expect(HereNowPerson(id: aurora, name: "Aurora Bell", avatarURL: nil, isFriend: true).accessibilityLabel == "Aurora Bell, friend, here now")
        #expect(HereNowPerson(id: sam, name: "Sam K.", avatarURL: nil, isFriend: false).accessibilityLabel == "Sam K., here now")
    }

    @MainActor
    private func makeViewModel(friends: FriendDirectory) -> VenueChatViewModel {
        VenueChatViewModel(
            room: ChatRoom(kind: .venue, id: UUID(), name: "The Eagle"),
            configuration: AppConfiguration(baseURL: URL(string: "https://api.hotmess.social")!),
            userID: me,
            token: nil,
            friends: friends
        )
    }

    @Test("Leaves the user out and puts friends first, by full name")
    @MainActor
    func viewModelOrder() {
        let directory = FriendDirectory()
        let viewModel = makeViewModel(friends: directory)

        viewModel.applyRoster(
            online: [me, aurora, sam],
            people: [
                RoomPerson(id: me, name: "Rick Mark"),
                RoomPerson(id: aurora, name: "Aurora B."),
                RoomPerson(id: sam, name: "Sam K."),
                RoomPerson(id: jo, name: "Jo P.", isFriend: true),
            ],
            friends: [Friend(id: aurora, name: "Aurora Bell")]
        )

        let here = viewModel.hereNow
        #expect(here.map(\.id) == [aurora, jo, sam])
        #expect(here.first?.name == "Aurora Bell")
        #expect(here.first?.isFriend == true)
        #expect(here.last?.isFriend == false)
        // The roster's friends reach the rest of the app.
        #expect(directory.byID[aurora]?.name == "Aurora Bell")
    }

    @Test("Joins add people and leaves remove them")
    @MainActor
    func viewModelPresence() {
        let viewModel = makeViewModel(friends: FriendDirectory())

        viewModel.applyRoster(online: [me], people: [], friends: [])
        #expect(viewModel.hereNow.isEmpty)

        viewModel.applyPresence(userID: sam, online: true, name: "Sam K.", avatarURL: nil)
        #expect(viewModel.hereNow.map(\.name) == ["Sam K."])
        #expect(viewModel.onlineUserIDs.contains(sam))

        viewModel.applyPresence(userID: sam, online: false, name: nil, avatarURL: nil)
        #expect(viewModel.hereNow.isEmpty)
        #expect(viewModel.roomPeople[sam] == nil)
    }
}
