//
//  ChatPresenceTests.swift
//  HotMessTests
//

import AudienceKit
import Foundation
import Testing

@testable import HotMess

private let me = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
private let aurora = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
private let sam = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
private let jo = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
private let alex = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

/// One subscription result, the way the cable hands it on.
private func result(_ room: String) -> AudienceCable.Event {
    .result(Data(#"{ "data": { "room": \#(room) } }"#.utf8))
}

private func events(_ room: String) -> [VenueChatConnection.Event] {
    VenueChatConnection.events(from: result(room))
}

/// A `ChatMessagePosted`'s line, aliased as the subscription selects it.
private func line(_ text: String, from sender: UUID, id: UUID = UUID(), extra: String = "") -> String {
    #"{ "id": "\#(id)", "message": "\#(text)", "body": "\#(text)", "user_id": "\#(sender)", "sent_at": "2026-10-11T04:00:00Z", "kind": "TEXT", "pinned": false, "posted_as_venue": false, "posted_as_person": false\#(extra) }"#
}

@Suite("Chat room events")
struct ChatPresenceFrameTests {
    @Test("A live venue announcement is delivered without reopening history")
    func liveAnnouncement() throws {
        let events = events("""
        { "__typename": "ChatMessagePosted", "sender_presence": null,
          "message": { "id": "\(UUID())", "user_id": "\(me)",
            "message": "Announcement: Doors open", "body": "Welcome in",
            "name": "The Venue", "role": "VENUE", "kind": "ANNOUNCEMENT",
            "title": "Doors open", "pinned": false, "posted_as_venue": false } }
        """)
        guard case let .received(message) = try #require(events.first), events.count == 1 else {
            Issue.record("Expected a live message")
            return
        }
        #expect(message.kind == .announcement)
        #expect(message.title == "Doors open")
        #expect(message.written == "Welcome in")
        #expect(message.isFromPlace)
        #expect(message.presence == nil)
    }

    @Test("An automatic \"On now\" announcement shows as the venue's card")
    func onNowAnnouncement() throws {
        // Posted as the venue by its announcer, a venue-device user who is
        // never in the room.
        let announcer = UUID()
        let events = events("""
        { "__typename": "ChatMessagePosted", "sender_presence": null,
          "message": { "id": "\(UUID())", "user_id": "\(announcer)",
            "message": "Announcement: On now\\nTrixie Mattel is on the decks", "body": "Trixie Mattel is on the decks",
            "name": "The Stud", "avatar_url": null, "sent_at": "2026-10-11T04:00:00Z",
            "role": "VENUE", "kind": "ANNOUNCEMENT", "title": "On now", "photo_url": null,
            "event": null, "ends_at": null, "pinned": false, "posted_as_venue": true,
            "posted_as_person": false, "person": null } }
        """)
        guard case let .received(message) = try #require(events.first) else {
            Issue.record("Expected a live message")
            return
        }
        let thread = message.threadMessage(currentUserID: me, online: [me, aurora])

        #expect(message.isFromPlace)
        #expect(message.isShowing())
        #expect(message.sentAt == Date(timeIntervalSince1970: 1_791_691_200))
        #expect(thread.authorName == "The Stud")
        #expect(thread.isOwn == false)
        #expect(thread.presence == nil)
        #expect(thread.rich == .announcement(
            title: "On now", body: "Trixie Mattel is on the decks", photoURL: nil, isPinned: false
        ))
    }

    @Test("A posted line takes its sender's presence in the room")
    func senderPresence() throws {
        let pushed = events(#"{ "__typename": "ChatMessagePosted", "sender_presence": "PUSH", "message": \#(line("hi", from: sam)) }"#)
        let here = events(#"{ "__typename": "ChatMessagePosted", "sender_presence": "ONLINE", "message": \#(line("yo", from: aurora)) }"#)

        guard case let .received(first) = try #require(pushed.first),
              case let .received(second) = try #require(here.first)
        else {
            Issue.record("Expected two lines")
            return
        }
        #expect(first.presence == .push)
        #expect(first.userID == sam)
        #expect(first.body == "hi")
        #expect(second.presence == .online)
    }

    @Test("Joining connects, then brings range, roster and history")
    func joined() throws {
        let pinnedID = UUID()
        let events = events("""
        {
          "__typename": "ChatJoined",
          "out_of_range": true,
          "roster": {
            "people": [
              { "user_id": "\(me)", "name": "Rick Mark", "avatar_url": "https://example.com/me.jpg", "friend": false },
              { "user_id": "\(aurora)", "name": "Aurora Bell", "avatar_url": "https://example.com/a.jpg", "friend": true },
              { "user_id": "\(sam)", "name": "Sam K.", "avatar_url": null, "friend": false }
            ],
            "friends": [
              { "user_id": "\(aurora)", "name": "Aurora Bell" },
              { "user_id": "\(alex)", "name": "Alex Rivera" }
            ]
          },
          "history": [
            { "sender_presence": "PUSH", "message": \(line("first", from: sam)) },
            { "sender_presence": null, "message": { "message": "no sender" } },
            { "sender_presence": "ONLINE", "message": \(line("second", from: aurora, extra: #", "role": "STAFF""#)) }
          ],
          "pinnedMessage": { "sender_presence": null, "message": { "id": "\(pinnedID)", "message": "Announcement: Doors at 9",
            "body": "", "user_id": "\(alex)", "kind": "ANNOUNCEMENT", "title": "Doors at 9", "pinned": true } }
        }
        """)

        #expect(events.count == 4)
        guard events.count == 4,
              case .connected = events[0],
              case let .range(outOfRange) = events[1],
              case let .roster(online, people, friends) = events[2],
              case let .history(messages, pinned) = events[3]
        else {
            Issue.record("Expected connected, range, roster, history")
            return
        }

        #expect(outOfRange)

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

        #expect(messages.map(\.body) == ["first", "second"])
        #expect(messages.first?.presence == .push)
        #expect(messages.last?.role == .staff)
        #expect(messages.last?.presence == .online)
        #expect(pinned?.id == pinnedID)
        #expect(pinned?.title == "Doors at 9")
        #expect(pinned?.kind == .announcement)
    }

    @Test("An empty room joins with nobody else and no lines")
    func emptyJoin() throws {
        let events = events(#"{ "__typename": "ChatJoined", "out_of_range": false, "roster": { "people": [], "friends": [] }, "history": [], "pinnedMessage": null }"#)

        guard events.count == 4,
              case let .range(outOfRange) = events[1],
              case let .roster(online, people, friends) = events[2],
              case let .history(messages, pinned) = events[3]
        else {
            Issue.record("Expected a join")
            return
        }
        #expect(!outOfRange)
        #expect(online.isEmpty)
        #expect(people.isEmpty)
        #expect(friends.isEmpty)
        #expect(messages.isEmpty)
        #expect(pinned == nil)
    }

    @Test("One malformed person or friend drops only itself")
    func malformedEntries() throws {
        let events = events("""
        {
          "__typename": "ChatJoined", "out_of_range": false, "history": [], "pinnedMessage": null,
          "roster": {
            "people": [{ "user_id": "nope", "name": "Bad" }, { "user_id": "\(jo)", "name": 7, "friend": "yes" }],
            "friends": [{ "user_id": "\(alex)" }, { "user_id": "\(aurora)", "name": "Aurora Bell" }]
          }
        }
        """)

        guard events.count == 4, case let .roster(online, people, friends) = events[2] else {
            Issue.record("Expected a roster")
            return
        }

        #expect(online == [jo])
        #expect(people.map(\.id) == [jo])
        #expect(people.first?.name == nil)
        #expect(people.first?.isFriend == false)
        #expect(friends.map(\.id) == [aurora])
    }

    @Test("An edited announcement arrives as the line, updated")
    func updated() throws {
        let id = UUID()
        let events = events("""
        { "__typename": "ChatMessageUpdated",
          "message": { "id": "\(id)", "message": "2 for 1: Wells", "body": "Wells", "user_id": "\(alex)",
            "kind": "SPECIAL", "title": "2 for 1", "ends_at": "2026-10-11T06:00:00Z", "pinned": false } }
        """)

        guard case let .received(message) = try #require(events.first) else {
            Issue.record("Expected the updated line")
            return
        }
        #expect(message.id == id)
        #expect(message.kind == .special)
        #expect(message.title == "2 for 1")
        #expect(message.endsAt == Date(timeIntervalSince1970: 1_791_698_400))
    }

    @Test("A join carries a name and avatar")
    func onlinePresence() throws {
        let events = events(#"{ "__typename": "ChatPresenceChanged", "user_id": "\#(sam)", "presence": "ONLINE", "name": "Sam K.", "avatar_url": "https://example.com/s.jpg" }"#)

        guard case let .presence(userID, online, name, avatarURL) = try #require(events.first) else {
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
        let events = events(#"{ "__typename": "ChatPresenceChanged", "user_id": "\#(sam)", "presence": "OFFLINE", "name": null, "avatar_url": null }"#)

        guard case let .presence(userID, online, name, avatarURL) = try #require(events.first) else {
            Issue.record("Expected presence")
            return
        }

        #expect(userID == sam)
        #expect(!online)
        #expect(name == nil)
        #expect(avatarURL == nil)
    }

    @Test("A friend who left but gets notifications is reachable")
    func pushPresence() throws {
        let events = events(#"{ "__typename": "ChatPresenceChanged", "user_id": "\#(sam)", "presence": "PUSH" }"#)

        guard case let .reachable(userID) = try #require(events.first) else {
            Issue.record("Expected reachable")
            return
        }

        #expect(userID == sam)
    }

    @Test("An admin crossing the room's edge changes the range")
    func range() throws {
        guard case let .range(outOfRange) = try #require(events(#"{ "__typename": "ChatRangeChanged", "out_of_range": true }"#).first) else {
            Issue.record("Expected range")
            return
        }
        #expect(outOfRange)
    }

    @Test("Pins carry the announcement; unpins only its ID")
    func pins() throws {
        let id = UUID()
        let pin = events(#"{ "__typename": "ChatPinChanged", "message_id": "\#(id)", "is_pinned": true, "announcement": { "id": "\#(id)", "message": "Announcement: Doors", "body": "", "user_id": "\#(alex)", "kind": "ANNOUNCEMENT", "title": "Doors", "pinned": true } }"#)
        let unpin = events(#"{ "__typename": "ChatPinChanged", "message_id": "\#(id)", "is_pinned": false, "announcement": null }"#)

        guard case let .pin(pinnedID, announcement) = try #require(pin.first) else {
            Issue.record("Expected pin")
            return
        }
        #expect(pinnedID == id)
        #expect(announcement?.title == "Doors")
        #expect(announcement?.isPinned == true)

        guard case let .pin(unpinnedID, nothing) = try #require(unpin.first) else {
            Issue.record("Expected unpin")
            return
        }
        #expect(unpinnedID == id)
        #expect(nothing == nil)
    }

    @Test("Admins' removals name the message; clearing the room names none")
    func removals() throws {
        let id = UUID()
        let removed = events(#"{ "__typename": "ChatMessageRemoved", "message_id": "\#(id)" }"#)
        let cleared = events(#"{ "__typename": "ChatRoomCleared", "cleared_at": "2026-10-09T04:00:00.123Z" }"#)

        guard case let .removed(removedID) = try #require(removed.first) else {
            Issue.record("Expected removed")
            return
        }
        #expect(removedID == id)

        guard case .cleared = try #require(cleared.first) else {
            Issue.record("Expected cleared")
            return
        }
    }

    @Test("Leaving the room, for any reason, is not being there")
    func left() throws {
        for reason in ["AWAY", "BANNED", "REMOVED"] {
            let events = events(#"{ "__typename": "ChatLeft", "reason": "\#(reason)" }"#)
            #expect(events.count == 1)
            guard case .notPresent = try #require(events.first) else {
                Issue.record("Expected notPresent for \(reason)")
                return
            }
        }
    }

    @Test("A refused subscription, or a rejected channel, is not being there")
    func refused() throws {
        let refused = AudienceCable.Event.result(Data(#"{ "data": null, "errors": [{ "message": "You're not at this venue" }] }"#.utf8))
        let refusedEvents = VenueChatConnection.events(from: refused)
        #expect(refusedEvents.count == 1)
        guard case .notPresent = try #require(refusedEvents.first) else {
            Issue.record("Expected notPresent")
            return
        }

        guard case .notPresent = try #require(VenueChatConnection.events(from: .rejected).first) else {
            Issue.record("Expected notPresent")
            return
        }
    }

    @Test("A dropped socket is a drop the cable recovers from; a refused session isn't")
    func dropped() throws {
        guard case let .disconnected(_, reconnects) = try #require(VenueChatConnection.events(from: .disconnected(reason: "lost", reconnects: true)).first) else {
            Issue.record("Expected disconnected")
            return
        }
        #expect(reconnects)

        guard case let .disconnected(reason, again) = try #require(VenueChatConnection.events(from: .disconnected(reason: "unauthorized", reconnects: false)).first) else {
            Issue.record("Expected disconnected")
            return
        }
        #expect(reason == "unauthorized" && !again)
    }

    @Test("The confirmation, unknown events and unreadable results mean nothing")
    func housekeeping() {
        #expect(VenueChatConnection.events(from: .subscribed).isEmpty)
        #expect(VenueChatConnection.events(from: .result(Data("not json".utf8))).isEmpty)
        #expect(events(#"{ "__typename": "ChatSomethingNew" }"#).isEmpty)
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

    @Test("History replaces the lines, and pins move the pinned announcement")
    @MainActor
    func viewModelHistoryAndPins() {
        let viewModel = makeViewModel(friends: FriendDirectory())
        var old = VenueMessage(id: UUID(), body: "Doors at 9", userID: alex, name: "Alex R.", avatarURL: nil, sentAt: .now)
        old.kind = .announcement
        old.isPinned = true
        var line = VenueMessage(id: UUID(), body: "hi", userID: sam, name: "Sam K.", avatarURL: nil, sentAt: .now)
        line.presence = .push

        viewModel.applyHistory([line], pinned: old)
        #expect(viewModel.messages.map(\.id) == [line.id])
        #expect(viewModel.pinnedAnnouncement?.id == old.id)
        #expect(viewModel.reachableUserIDs == [sam])

        viewModel.applyPin(id: old.id, announcement: nil)
        #expect(viewModel.pinnedAnnouncement == nil)

        viewModel.applyPresence(userID: sam, online: true, name: nil, avatarURL: nil)
        #expect(viewModel.reachableUserIDs.isEmpty)
    }

    @Test("Removed lines go, and clearing the room takes every line and the pin")
    @MainActor
    func viewModelRemovals() {
        let viewModel = makeViewModel(friends: FriendDirectory())
        var pinned = VenueMessage(id: UUID(), body: "Doors at 9", userID: alex, name: "Alex R.", avatarURL: nil, sentAt: .now)
        pinned.kind = .announcement
        pinned.isPinned = true
        let rude = VenueMessage(id: UUID(), body: "rude", userID: sam, name: "Sam K.", avatarURL: nil, sentAt: .now)
        let kind = VenueMessage(id: UUID(), body: "kind", userID: sam, name: "Sam K.", avatarURL: nil, sentAt: .now)

        viewModel.applyHistory([pinned, rude, kind], pinned: pinned)
        viewModel.applyRemoval(id: rude.id)
        #expect(viewModel.messages.map(\.id) == [pinned.id, kind.id])

        viewModel.applyRemoval(id: pinned.id)
        #expect(viewModel.messages.map(\.id) == [kind.id])
        #expect(viewModel.pinnedAnnouncement == nil)

        viewModel.applyHistory([kind], pinned: pinned)
        viewModel.applyClear()
        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.pinnedAnnouncement == nil)
    }
}

@Suite("Sending chat lines")
struct ChatSendTests {
    @MainActor
    private func makeViewModel() -> VenueChatViewModel {
        VenueChatViewModel(
            room: ChatRoom(kind: .venue, id: UUID(), name: "The Eagle"),
            configuration: AppConfiguration(baseURL: URL(string: "https://api.hotmess.social")!),
            userID: me
        )
    }

    @Test("The mutation's answer shows the line; its echo only updates it")
    @MainActor
    func mutationFirst() {
        let viewModel = makeViewModel()
        let sent = VenueMessage(id: UUID(), body: "hi", userID: me)
        var echo = sent
        echo.presence = .online

        viewModel.settle(UUID(), with: sent)
        viewModel.receive(echo)

        #expect(viewModel.messages.map(\.id) == [sent.id])
        #expect(viewModel.messages.first?.presence == .online)
    }

    @Test("Without the API, nothing can be sent")
    @MainActor
    func noAPI() async {
        let viewModel = makeViewModel()
        await viewModel.run()

        #expect(viewModel.connectionState == .disconnected("Chat isn't available for this build."))
        await viewModel.stop()
    }
}

@Suite("Chat room reconnecting")
struct ChatReconnectTests {
    @Test("Waits a second after a joined room drops, then doubles up to half a minute")
    func reconnectDelay() {
        #expect(VenueChatViewModel.reconnectDelay(afterFailures: 0) == .seconds(1))
        #expect(VenueChatViewModel.reconnectDelay(afterFailures: 1) == .seconds(2))
        #expect(VenueChatViewModel.reconnectDelay(afterFailures: 4) == .seconds(16))
        #expect(VenueChatViewModel.reconnectDelay(afterFailures: 9) == .seconds(30))
    }

    @Test("Chat sockets don't share the API's two-minute resource timeout")
    func realtimeSession() {
        #expect(URLSession.realtime.configuration.timeoutIntervalForResource > 3600)
    }
}
