//
//  VenueChatConnection.swift
//  HotMess
//

import Foundation
import os

/// A live connection to one venue's chat room.
///
/// Speaks the Action Cable protocol over `URLSessionWebSocketTask`, replacing
/// the Starscream dependency and the `RealtimeService` singleton whose
/// `didReceive(event:client:)` was an empty stub — meaning no message had
/// actually arrived since the Starscream 4 upgrade.
actor VenueChatConnection {
    enum Event: Sendable {
        case connected
        case received(VenueMessage)
        case disconnected(String?)
    }

    private static let channelName = "RealtimeChannel"

    private let url: URL
    private let venueID: UUID
    private let token: String?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private nonisolated let continuation: AsyncStream<Event>.Continuation

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    /// Every frame this connection produces, in order. The stream finishes on
    /// `disconnect()`, so a reconnect means a new `VenueChatConnection`.
    nonisolated let events: AsyncStream<Event>

    init(venueID: UUID, url: URL, token: String?, session: URLSession = .hotMess) {
        self.venueID = venueID
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

    /// Sends a line to the room. The message is echoed back by the server, so
    /// the caller does not append it locally.
    func send(_ body: String, from userID: UUID, avatarURL: URL?) async throws {
        let payload = OutgoingMessage(message: body, userID: userID, avatarURL: avatarURL)
        let data = try encoder.encode(payload)

        try await write(
            OutgoingFrame(
                command: "message",
                identifier: identifier,
                data: String(decoding: data, as: UTF8.self)
            )
        )
    }

    // MARK: - Private

    /// Action Cable identifies a subscription by a JSON *string*, not an object.
    private var identifier: String {
        let subscription = ["channel": Self.channelName, "venue_id": "chat_\(venueID.uuidString)"]

        guard let data = try? JSONSerialization.data(withJSONObject: subscription) else {
            return "{}"
        }

        return String(decoding: data, as: UTF8.self)
    }

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
        case "welcome", "confirm_subscription":
            continuation.yield(.connected)
        case "disconnect":
            continuation.yield(.disconnected(nil))
        case "ping":
            break
        case .none:
            // A frame with no `type` and a `message` object is a chat line.
            if let payload = frame.message {
                continuation.yield(.received(VenueMessage(payload: payload)))
            }
        default:
            break
        }
    }

    // MARK: - Wire format

    /// The chat line itself, nested inside a frame's `data` field as a string.
    private struct OutgoingMessage: Encodable {
        let type = "outgoing"
        let message: String
        let userID: UUID
        let avatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case type, message
            case userID = "user_id"
            case avatarURL = "avatar_url"
        }
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

        enum CodingKeys: String, CodingKey {
            case type, identifier, message
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            type = try? container.decodeIfPresent(String.self, forKey: .type)
            identifier = try? container.decodeIfPresent(String.self, forKey: .identifier)
            message = try? container.decodeIfPresent(VenueMessage.Payload.self, forKey: .message)
        }
    }
}
