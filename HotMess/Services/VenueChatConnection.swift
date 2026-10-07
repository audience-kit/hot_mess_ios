//
//  VenueChatConnection.swift
//  HotMess
//

import Foundation
import os

/// A live connection to one chat room: a venue's, or a locale's (see `ChatRoom`).
///
/// A venue's room is only open to people at the venue, and a locale's to people
/// out in the locale away from its venues: the server rejects the
/// subscription otherwise, and sends `{"type":"left"}` when someone's presence
/// lapses. Either way the connection reports `.notPresent` instead of retrying.
/// Admins can join from anywhere; the server tells everyone whether they're
/// out of range when they join, and admins again whenever that changes.
/// The server adds the sender's ID, name, avatar and time to each line itself.
///
/// Speaks the Action Cable protocol over `URLSessionWebSocketTask`, replacing
/// the Starscream dependency and the `RealtimeService` singleton whose
/// `didReceive(event:client:)` was an empty stub — meaning no message had
/// actually arrived since the Starscream 4 upgrade.
actor VenueChatConnection {
    enum Event: Sendable {
        /// The server confirmed the subscription; lines can be sent.
        case connected
        case received(VenueMessage)
        /// The server turned the subscription away, or ended it, because the
        /// user isn't in the room's place (by the last position they reported).
        case notPresent
        /// Whether the user is outside the room's place. Only admins are let in
        /// from outside, so `true` means they're there because they're an admin.
        case range(outOfRange: Bool)
        /// Everyone in the room now, the user included, sent on joining.
        /// `people` names them (empty from servers that only send IDs), and
        /// `friends` is every one of the user's friends, by full name, in the
        /// room or not.
        case roster(online: Set<UUID>, people: [RoomPerson], friends: [Friend])
        /// Someone's first socket joined the room (`true`) or their last one
        /// left. A join carries their name and avatar when the server sends them.
        case presence(userID: UUID, online: Bool, name: String?, avatarURL: URL?)
        case disconnected(String?)
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

    /// Every frame this connection produces, in order. The stream finishes on
    /// `disconnect()`, so a reconnect means a new `VenueChatConnection`.
    nonisolated let events: AsyncStream<Event>

    init(room: ChatRoom, url: URL, token: String?, session: URLSession = .hotMess) {
        self.room = room
        identifier = Self.identifier(for: room)
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

        receiveTask = Task { await self.receiveLoop() }

        Task { await self.subscribe() }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        continuation.finish()
    }

    /// Sends a line to the room. The server echoes it back to everyone in the
    /// room, the sender included. Call it only after `.connected`: the server
    /// silently drops a line for a subscription it hasn't confirmed.
    func send(_ body: String) async throws {
        let data = try encoder.encode(OutgoingMessage(message: body))

        try await write(
            OutgoingFrame(
                command: "message",
                identifier: identifier,
                data: String(decoding: data, as: UTF8.self)
            )
        )
    }

    /// Action Cable identifies a subscription by a JSON *string*, not an object,
    /// so the keys are sorted to make it the same every time.
    static func identifier(for room: ChatRoom) -> String {
        let subscription = ["channel": room.channelName, room.subscriptionKey: room.id.uuidString.lowercased()]

        guard let data = try? JSONSerialization.data(withJSONObject: subscription, options: .sortedKeys) else {
            return "{}"
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

    private func write(_ frame: OutgoingFrame) async throws {
        guard let socket else { return }

        let data = try encoder.encode(frame)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let socket = self.socket {
            do {
                let message = try await socket.receive()
                handle(message)
            } catch {
                guard !Task.isCancelled else { return }

                Log.realtime.error("Chat socket closed: \(error.localizedDescription, privacy: .public)")
                continuation.yield(.disconnected(error.localizedDescription))
                return
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case let .string(text):
            data = Data(text.utf8)
        case let .data(payload):
            data = payload
        @unknown default:
            return
        }

        if let event = Self.event(from: data) {
            continuation.yield(event)
        }
    }

    /// The event one incoming frame means, or `nil` for one that means
    /// nothing to the room (a welcome, a ping, something unreadable).
    static func event(from data: Data) -> Event? {
        guard let frame = try? JSONDecoder().decode(IncomingFrame.self, from: data) else { return nil }

        switch frame.type {
        case "welcome":
            // The socket is open, but the room isn't joined until the server
            // confirms the subscription.
            return nil
        case "confirm_subscription":
            return .connected
        case "reject_subscription":
            return .notPresent
        case "disconnect":
            return .disconnected(nil)
        case "ping":
            return nil
        case .none:
            // A frame with no `type` carries what the channel sent in `message`:
            // a chat line, `{"type":"left"}` once the user's presence lapses,
            // `{"type":"range","out_of_range":…}`, the `roster` of who's in the
            // room on joining, or a `presence` change.
            if frame.messageType == "left" {
                return .notPresent
            } else if frame.messageType == "range" {
                return .range(outOfRange: frame.outOfRange ?? false)
            } else if frame.messageType == "roster" {
                return .roster(
                    online: Set(frame.online ?? []),
                    people: frame.people ?? [],
                    friends: frame.friends ?? []
                )
            } else if frame.messageType == "presence" {
                guard let userID = frame.presenceUserID, let presence = frame.presence else { return nil }
                return .presence(
                    userID: userID,
                    online: presence == "online",
                    name: frame.presenceName,
                    avatarURL: frame.presenceAvatarURL
                )
            } else if let payload = frame.message {
                return .received(VenueMessage(payload: payload))
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Wire format

    /// The chat line itself, nested inside a frame's `data` field as a string.
    /// The server fills in who sent it.
    private struct OutgoingMessage: Encodable {
        let message: String
    }

    private struct OutgoingFrame: Encodable {
        let command: String
        let identifier: String
        let data: String?
    }

    /// Action Cable reuses the `message` key for both chat payloads and its own
    /// keep-alive counter, so every field is decoded leniently.
    private struct IncomingFrame: Decodable {
        let type: String?
        let identifier: String?
        let message: VenueMessage.Payload?
        /// The `type` inside `message`, e.g. `left`.
        let messageType: String?
        /// `out_of_range` inside a `range` message.
        let outOfRange: Bool?
        /// `online` inside a `roster` message.
        let online: [UUID]?
        /// `people` and `friends` inside a `roster` message, from servers that send them.
        let people: [RoomPerson]?
        let friends: [Friend]?
        /// `user_id`, `presence`, `name` and `avatar_url` inside a `presence` message.
        let presenceUserID: UUID?
        let presence: String?
        let presenceName: String?
        let presenceAvatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case type, identifier, message
        }

        private struct Typed: Decodable {
            let type: String?
            let outOfRange: Bool?
            let online: [UUID]?
            let userID: UUID?
            let presence: String?
            let name: String?
            let avatarURL: URL?
            let people: [RoomPerson]?
            let friends: [Friend]?

            enum CodingKeys: String, CodingKey {
                case type, online, presence, name, people, friends
                case outOfRange = "out_of_range"
                case userID = "user_id"
                case avatarURL = "avatar_url"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                type = try? container.decodeIfPresent(String.self, forKey: .type)
                outOfRange = try? container.decodeIfPresent(Bool.self, forKey: .outOfRange)
                // One malformed ID shouldn't drop everyone else.
                online = (try? container.decodeIfPresent([String].self, forKey: .online))
                    .map { $0.compactMap(UUID.init(uuidString:)) }
                userID = try? container.decodeIfPresent(UUID.self, forKey: .userID)
                presence = try? container.decodeIfPresent(String.self, forKey: .presence)
                name = (try? container.decodeIfPresent(String.self, forKey: .name)).flatMap({ $0.nonBlank })
                avatarURL = (try? container.decodeIfPresent(String.self, forKey: .avatarURL)).flatMap({ $0.nonBlankURL })
                // Each person and friend on their own, so one bad entry drops only itself.
                people = (try? container.decodeIfPresent([Lenient<PersonWire>].self, forKey: .people))
                    .map { $0.compactMap { $0.value?.person } }
                friends = (try? container.decodeIfPresent([Lenient<FriendWire>].self, forKey: .friends))
                    .map { $0.compactMap { $0.value?.friend } }
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

        /// One of `people` in a roster.
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

        /// One of `friends` in a roster: an ID and a full name.
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

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            type = try? container.decodeIfPresent(String.self, forKey: .type)
            identifier = try? container.decodeIfPresent(String.self, forKey: .identifier)
            message = try? container.decodeIfPresent(VenueMessage.Payload.self, forKey: .message)
            let typed = (try? container.decodeIfPresent(Typed.self, forKey: .message)) ?? nil
            messageType = typed?.type
            outOfRange = typed?.outOfRange
            online = typed?.online
            people = typed?.people
            friends = typed?.friends
            presenceUserID = typed?.userID
            presence = typed?.presence
            presenceName = typed?.name
            presenceAvatarURL = typed?.avatarURL
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
