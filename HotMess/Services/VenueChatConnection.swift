//
//  VenueChatConnection.swift
//  HotMess
//

import Foundation
import os

/// A live connection to one chat room: a venue's, or a locale's (see `ChatRoom`).
///
/// Realtime on the API is GraphQL subscriptions carried over Action Cable
/// (`GraphQLChannel`). The connection subscribes the channel with the
/// audience and an ID of its own, and once the server confirms it, executes
/// the room's `venueChat` / `localeChat` subscription. Every result that
/// follows is one `ChatRoomEvent`, which this turns into the room's `Event`s.
///
/// A venue's room is only open to people at the venue, and a locale's to people
/// out in the locale away from its venues: the server refuses the subscription
/// otherwise (an error and no data), and ends it with `ChatLeft` when someone's
/// presence lapses. Either way the connection reports `.notPresent` instead of
/// retrying. Admins can join from anywhere; `ChatJoined` says whether they're
/// out of range, and `ChatRangeChanged` whenever that changes.
///
/// Lines are sent with the `sendMyChatMessage` mutation (see `HotMessAPI`),
/// not over this socket; they come back here as `ChatMessagePosted` like
/// everyone else's.
actor VenueChatConnection {
    enum Event: Sendable {
        /// The room was joined (its `ChatJoined` arrived); lines can be sent.
        case connected
        case received(VenueMessage)
        /// The server turned the subscription away, or ended it, because the
        /// user isn't in the room's place (by the last position they reported),
        /// or was banned or removed from it.
        case notPresent
        /// Whether the user is outside the room's place. Only admins are let in
        /// from outside, so `true` means they're there because they're an admin.
        case range(outOfRange: Bool)
        /// Everyone in the room now, the user included, sent on joining.
        /// `people` names them, and `friends` is every one of the user's
        /// friends, by full name, in the room or not.
        case roster(online: Set<UUID>, people: [RoomPerson], friends: [Friend])
        /// Someone's first socket joined the room (`true`) or their last one
        /// left. A join carries their name and avatar when the server sends them.
        case presence(userID: UUID, online: Bool, name: String?, avatarURL: URL?)
        /// Someone left the room (or was never in it) but a notification still
        /// reaches them: the server only says so about the user's friends, and
        /// to admins. Drawn as a yellow dot.
        case reachable(userID: UUID)
        /// The room's recent messages, oldest first, and the announcement
        /// pinned under its title (however old), sent on joining.
        case history(messages: [VenueMessage], pinned: VenueMessage?)
        /// An announcement was pinned (with it), or unpinned (`nil`).
        case pin(id: UUID, announcement: VenueMessage?)
        /// An admin removed a message; nobody sees it again.
        case removed(id: UUID)
        /// An admin cleared the room: every message so far is gone.
        case cleared
        case disconnected(String?)
    }

    /// What one incoming frame means to the connection.
    enum Incoming: Sendable {
        /// The server confirmed `GraphQLChannel`: time to execute the subscription.
        case confirmed
        case events([Event])
    }

    private let url: URL
    private let room: ChatRoom
    private let token: String?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private nonisolated let continuation: AsyncStream<Event>.Continuation

    /// Built once: Action Cable matches every command to its subscription by
    /// this exact string, and a Swift dictionary serializes its keys in a
    /// different order from one instance to the next.
    private let identifier: String
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    /// When the server last sent anything. Action Cable pings every 3
    /// seconds, so a long silence means the socket is dead even if it looks open
    /// (a Wi-Fi to cellular handoff, say).
    private var lastHeard = ContinuousClock.now

    /// How long without a frame before the socket counts as gone.
    static let silenceLimit: Duration = .seconds(12)

    /// Every event this connection produces, in order. The stream finishes on
    /// `disconnect()`, so a reconnect means a new `VenueChatConnection`.
    nonisolated let events: AsyncStream<Event>

    /// - Parameters:
    ///   - audienceID: the audience the subscription runs in, as for
    ///     `/v1/audience/<id>/graphql`.
    ///   - channelID: keeps this operation's identifier apart from others on
    ///     the same account; random unless a test pins it.
    init(
        room: ChatRoom,
        url: URL,
        token: String?,
        audienceID: String,
        channelID: String = UUID().uuidString.lowercased(),
        session: URLSession = .realtime
    ) {
        self.room = room
        identifier = Self.identifier(audienceID: audienceID, channelID: channelID)
        self.url = url
        self.token = token
        self.session = session

        let (stream, continuation) = AsyncStream<Event>.makeStream()
        events = stream
        self.continuation = continuation
    }

    func connect() {
        guard socket == nil else { return }

        var request = URLRequest(url: url)
        if let token {
            request.setValue("JWT \(token)", forHTTPHeaderField: "Authorization")
        }

        let socket = session.webSocketTask(with: request)
        self.socket = socket
        socket.resume()

        lastHeard = .now
        receiveTask = Task { await self.receiveLoop() }
        watchdogTask = Task { await self.watchForSilence() }

        Task { await self.subscribe() }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        continuation.finish()
    }

    /// `GraphQLChannel`'s identifier. Action Cable identifies a subscription by
    /// a JSON *string*, not an object, so the keys are sorted to make it the
    /// same every time.
    static func identifier(audienceID: String, channelID: String) -> String {
        let subscription = ["channel": "GraphQLChannel", "audience_id": audienceID, "channelId": channelID]
        return json(subscription) ?? "{}"
    }

    /// The room's subscription, aliased to `room` whichever field it is, with
    /// its fields aliased to the keys the app's models decode.
    static func subscriptionDocument(for room: ChatRoom) -> String {
        let line = HotMessAPI.Documents.roomMessageFields
        return """
        subscription ChatRoom($id: ID!) {
          room: \(room.channelName)(\(room.subscriptionKey): $id) {
            __typename
            ... on ChatJoined {
              out_of_range: outOfRange
              roster { people { user_id: userId name avatar_url: avatarUrl friend } friends { user_id: userId name } }
              history { ...Posted }
              pinnedMessage { ...Posted }
            }
            ... on ChatMessagePosted { ...Posted }
            ... on ChatMessageUpdated { message { ...Line } }
            ... on ChatMessageRemoved { message_id: messageId }
            ... on ChatPinChanged { message_id: messageId is_pinned: pinned announcement { ...Line } }
            ... on ChatRoomCleared { cleared_at: clearedAt }
            ... on ChatPresenceChanged { user_id: userId presence name avatar_url: avatarUrl }
            ... on ChatRangeChanged { out_of_range: outOfRange }
            ... on ChatLeft { reason }
          }
        }
        fragment Posted on ChatMessagePosted { sender_presence: senderPresence message { ...Line } }
        fragment Line on ChatMessage { \(line) }
        """
    }

    /// `execute`'s data, a JSON string inside the `message` command: the
    /// room's subscription and its variables.
    static func executeData(for room: ChatRoom) -> String {
        let data: [String: Any] = [
            "action": "execute",
            "operationName": "ChatRoom",
            "query": subscriptionDocument(for: room),
            "variables": ["id": room.id.uuidString.lowercased()],
        ]
        return json(data) ?? "{}"
    }

    private static func json(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Private

    private func subscribe() async {
        do {
            try await write(OutgoingFrame(command: "subscribe", identifier: identifier, data: nil))
        } catch {
            continuation.yield(.disconnected(error.localizedDescription))
        }
    }

    /// Runs the room's subscription, once the channel is confirmed: the
    /// server ignores commands for a subscription it hasn't confirmed.
    private func execute() async {
        do {
            try await write(OutgoingFrame(command: "message", identifier: identifier, data: Self.executeData(for: room)))
        } catch {
            continuation.yield(.disconnected(error.localizedDescription))
        }
    }

    private func write(_ frame: OutgoingFrame) async throws {
        guard let socket else { return }

        let data = try encoder.encode(frame)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let socket = self.socket {
            do {
                let message = try await socket.receive()
                await handle(message)
            } catch {
                guard !Task.isCancelled else { return }

                Log.realtime.error("Chat socket closed: \(error.localizedDescription, privacy: .public)")
                continuation.yield(.disconnected(error.localizedDescription))
                return
            }
        }
    }

    /// Ends a socket that has gone quiet, so the room can reconnect.
    private func watchForSilence() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, socket != nil else { return }
            guard ContinuousClock.now - lastHeard > Self.silenceLimit else { continue }

            Log.realtime.error("Chat socket went quiet; closing it")
            receiveTask?.cancel()
            receiveTask = nil
            socket?.cancel(with: .goingAway, reason: nil)
            socket = nil
            continuation.yield(.disconnected(nil))
            return
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        lastHeard = .now
        let data: Data

        switch message {
        case let .string(text):
            data = Data(text.utf8)
        case let .data(payload):
            data = payload
        @unknown default:
            return
        }

        switch Self.incoming(from: data) {
        case .confirmed:
            await execute()
        case let .events(events):
            for event in events {
                continuation.yield(event)
            }
        }
    }

    /// The events one incoming frame means; none for a frame that means
    /// nothing to the room (a welcome, a ping, the confirmation, something
    /// unreadable).
    static func events(from data: Data) -> [Event] {
        switch incoming(from: data) {
        case .confirmed: []
        case let .events(events): events
        }
    }

    static func incoming(from data: Data) -> Incoming {
        guard let frame = try? JSONDecoder().decode(IncomingFrame.self, from: data) else { return .events([]) }

        switch frame.type {
        case "confirm_subscription":
            return .confirmed
        case "reject_subscription":
            // Another audience's token, or someone the audience banned.
            return .events([.notPresent])
        case "disconnect":
            return .events([.disconnected(nil)])
        case .none:
            guard let result = frame.result else { return .events([]) }
            return .events(events(from: result, more: frame.more ?? true))
        default:
            // "welcome", "ping".
            return .events([])
        }
    }

    /// One `{ result: { data, errors }, more }`. A result with errors and no
    /// event is the server refusing the subscription (not at the venue,
    /// banned). `more: false` ends it; anything but `ChatLeft` or a refusal
    /// ending it counts as the socket dropping, so the room reconnects.
    private static func events(from result: GraphQLResult, more: Bool) -> [Event] {
        var events: [Event]
        if let room = result.room {
            events = room.events
        } else if result.hasErrors {
            Log.realtime.error("Chat subscription refused: \(result.errorSummary, privacy: .public)")
            events = [.notPresent]
        } else {
            events = []
        }

        if !more, !events.contains(where: \.isTerminal) {
            events.append(.disconnected(nil))
        }
        return events
    }

    // MARK: - Wire format

    private struct OutgoingFrame: Encodable {
        let command: String
        let identifier: String
        let data: String?
    }

    /// An Action Cable frame. Its `message` is a GraphQL result for a frame
    /// with no `type`, and Action Cable's keep-alive counter for a ping, so
    /// it's decoded leniently.
    private struct IncomingFrame: Decodable {
        let type: String?
        let result: GraphQLResult?
        let more: Bool?

        enum CodingKeys: String, CodingKey {
            case type, message
        }

        private struct Envelope: Decodable {
            let result: GraphQLResult?
            let more: Bool?
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try? container.decodeIfPresent(String.self, forKey: .type)
            let envelope = (try? container.decodeIfPresent(Envelope.self, forKey: .message)) ?? nil
            result = envelope?.result
            more = envelope?.more
        }
    }

    /// `{ data: { room }, errors }`.
    private struct GraphQLResult: Decodable {
        let room: RoomEvent?
        let errors: [String]

        var hasErrors: Bool { !errors.isEmpty }
        var errorSummary: String { errors.joined(separator: "; ") }

        enum CodingKeys: String, CodingKey { case data, errors }
        private enum DataKeys: String, CodingKey { case room }
        private struct ErrorWire: Decodable { let message: String? }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
            room = (try? data?.decodeIfPresent(RoomEvent.self, forKey: .room)) ?? nil
            errors = ((try? container.decodeIfPresent([Lenient<ErrorWire>].self, forKey: .errors)) ?? nil)?
                .map { $0.value?.message ?? "error" } ?? []
        }
    }

    /// One `ChatRoomEvent`, by its `__typename`, as the events it means.
    private struct RoomEvent: Decodable {
        let events: [Event]

        enum CodingKeys: String, CodingKey {
            case typename = "__typename"
            case outOfRange = "out_of_range"
            case roster, history, pinnedMessage, message, announcement, presence, name, reason
            case isPinned = "is_pinned"
            case messageID = "message_id"
            case clearedAt = "cleared_at"
            case userID = "user_id"
            case avatarURL = "avatar_url"
        }

        private enum RosterKeys: String, CodingKey { case people, friends }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typename = (try? container.decodeIfPresent(String.self, forKey: .typename)) ?? nil

            switch typename {
            case "ChatJoined":
                let roster = try? container.nestedContainer(keyedBy: RosterKeys.self, forKey: .roster)
                // Each person, friend and line on its own, so one bad entry drops only itself.
                let people = ((try? roster?.decodeIfPresent([Lenient<PersonWire>].self, forKey: .people)) ?? nil)?
                    .compactMap { $0.value?.person } ?? []
                let friends = ((try? roster?.decodeIfPresent([Lenient<FriendWire>].self, forKey: .friends)) ?? nil)?
                    .compactMap { $0.value?.friend } ?? []
                let history = ((try? container.decodeIfPresent([Lenient<Posted>].self, forKey: .history)) ?? nil)?
                    .compactMap { $0.value?.message } ?? []
                let pinned = ((try? container.decodeIfPresent(Posted.self, forKey: .pinnedMessage)) ?? nil)?.message
                let outOfRange = ((try? container.decodeIfPresent(Bool.self, forKey: .outOfRange)) ?? nil) ?? false

                events = [
                    .connected,
                    .range(outOfRange: outOfRange),
                    .roster(online: Set(people.map(\.id)), people: people, friends: friends),
                    .history(messages: history, pinned: pinned),
                ]
            case "ChatMessagePosted":
                events = (try? Posted(from: decoder).message).map { [.received($0)] } ?? []
            case "ChatMessageUpdated":
                events = Self.message(in: container, forKey: .message).map { [.received($0)] } ?? []
            case "ChatMessageRemoved":
                events = Self.id(in: container, forKey: .messageID).map { [.removed(id: $0)] } ?? []
            case "ChatPinChanged":
                guard let id = Self.id(in: container, forKey: .messageID) else {
                    events = []
                    return
                }
                let isPinned = ((try? container.decodeIfPresent(Bool.self, forKey: .isPinned)) ?? nil) ?? false
                let announcement = isPinned ? Self.message(in: container, forKey: .announcement) : nil
                events = [.pin(id: id, announcement: announcement)]
            case "ChatRoomCleared":
                events = [.cleared]
            case "ChatPresenceChanged":
                guard let userID = Self.id(in: container, forKey: .userID),
                      let presence = ((try? container.decodeIfPresent(String.self, forKey: .presence)) ?? nil)?.uppercased()
                else {
                    events = []
                    return
                }
                if presence == "PUSH" {
                    events = [.reachable(userID: userID)]
                } else {
                    events = [.presence(
                        userID: userID,
                        online: presence == "ONLINE",
                        name: ((try? container.decodeIfPresent(String.self, forKey: .name)) ?? nil)?.nonBlank,
                        avatarURL: ((try? container.decodeIfPresent(String.self, forKey: .avatarURL)) ?? nil)?.nonBlankURL
                    )]
                }
            case "ChatRangeChanged":
                let outOfRange = ((try? container.decodeIfPresent(Bool.self, forKey: .outOfRange)) ?? nil) ?? false
                events = [.range(outOfRange: outOfRange)]
            case "ChatLeft":
                // AWAY, BANNED or REMOVED: out of the room either way.
                events = [.notPresent]
            default:
                events = []
            }
        }

        private static func id(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> UUID? {
            ((try? container.decodeIfPresent(String.self, forKey: key)) ?? nil).flatMap(UUID.init(uuidString:))
        }

        private static func message(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> VenueMessage? {
            ((try? container.decodeIfPresent(VenueMessage.Payload.self, forKey: key)) ?? nil)
                .map(VenueMessage.init(payload:))
        }
    }

    /// A `ChatMessagePosted`: the line, with its sender's presence in the
    /// room (`ONLINE`, `PUSH`, or null) as the line's `presence`.
    private struct Posted: Decodable {
        let message: VenueMessage?

        enum CodingKeys: String, CodingKey {
            case message
            case senderPresence = "sender_presence"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var message = ((try? container.decodeIfPresent(VenueMessage.Payload.self, forKey: .message)) ?? nil)
                .map(VenueMessage.init(payload:))
            message?.presence = ((try? container.decodeIfPresent(String.self, forKey: .senderPresence)) ?? nil)
                .flatMap { PresenceState(wire: $0) }
            self.message = message
        }
    }

    /// Decodes as `nil` instead of throwing, so one malformed array element
    /// doesn't fail the whole array.
    private struct Lenient<Value: Decodable>: Decodable {
        let value: Value?

        init(from decoder: any Decoder) throws {
            value = try? Value(from: decoder)
        }
    }

    /// One of the roster's `people`.
    private struct PersonWire: Decodable {
        let person: RoomPerson?

        enum CodingKeys: String, CodingKey {
            case name, friend
            case userID = "user_id"
            case avatarURL = "avatar_url"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let id = try? container.decodeIfPresent(UUID.self, forKey: .userID) else {
                person = nil
                return
            }
            person = RoomPerson(
                id: id,
                name: (try? container.decodeIfPresent(String.self, forKey: .name)).flatMap({ $0.nonBlank }),
                avatarURL: (try? container.decodeIfPresent(String.self, forKey: .avatarURL)).flatMap({ $0.nonBlankURL }),
                isFriend: (try? container.decodeIfPresent(Bool.self, forKey: .friend)) ?? false
            )
        }
    }

    /// One of the roster's `friends`: an ID and a full name.
    private struct FriendWire: Decodable {
        let friend: Friend?

        enum CodingKeys: String, CodingKey {
            case name
            case userID = "user_id"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let id = try? container.decodeIfPresent(UUID.self, forKey: .userID),
                  let name = (try? container.decodeIfPresent(String.self, forKey: .name)).flatMap({ $0.nonBlank })
            else {
                friend = nil
                return
            }
            friend = Friend(id: id, name: name)
        }
    }
}

private extension VenueChatConnection.Event {
    /// The room is over for this connection.
    var isTerminal: Bool {
        switch self {
        case .notPresent, .disconnected: true
        default: false
        }
    }
}

/// Someone in a chat room, as its roster and presence frames name them.
struct RoomPerson: Hashable, Sendable, Identifiable {
    let id: UUID
    /// "First L." for strangers, a full name for the user's friends. `nil`
    /// when the server didn't say.
    var name: String?
    var avatarURL: URL?
    /// The server says they're one of the user's friends.
    var isFriend = false
}

private extension String {
    /// `nil` for an empty or all-whitespace string.
    var nonBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }

    var nonBlankURL: URL? {
        nonBlank.flatMap(URL.init(string:))
    }
}
