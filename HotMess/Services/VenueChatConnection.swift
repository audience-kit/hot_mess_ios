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
        case disconnected(String?)
    }

    private let url: URL
    private let room: ChatRoom
    private let token: String?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
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

        guard let frame = try? decoder.decode(IncomingFrame.self, from: data) else { return }

        switch frame.type {
        case "welcome":
            // The socket is open, but the room isn't joined until the server
            // confirms the subscription.
            break
        case "confirm_subscription":
            continuation.yield(.connected)
        case "reject_subscription":
            continuation.yield(.notPresent)
        case "disconnect":
            continuation.yield(.disconnected(nil))
        case "ping":
            break
        case .none:
            // A frame with no `type` carries what the channel sent in `message`:
            // a chat line, `{"type":"left"}` once the user's presence lapses, or
            // `{"type":"range","out_of_range":…}`.
            if frame.messageType == "left" {
                continuation.yield(.notPresent)
            } else if frame.messageType == "range" {
                continuation.yield(.range(outOfRange: frame.outOfRange ?? false))
            } else if let payload = frame.message {
                continuation.yield(.received(VenueMessage(payload: payload)))
            }
        default:
            break
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

        enum CodingKeys: String, CodingKey {
            case type, identifier, message
        }

        private struct Typed: Decodable {
            let type: String?
            let outOfRange: Bool?

            enum CodingKeys: String, CodingKey {
                case type
                case outOfRange = "out_of_range"
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
        }
    }
}
