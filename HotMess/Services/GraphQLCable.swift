//
//  GraphQLCable.swift
//  HotMess
//

import Foundation
import os

/// GraphQL subscriptions over Action Cable (`GraphQLChannel`), the way every
/// realtime feature of the API is carried: the wire format, and a socket that
/// runs one operation.
///
/// The socket subscribes the channel with the audience and an ID of its own,
/// and once the server confirms it, executes the operation. Each result after
/// that is `{ identifier, message: { result: { data, errors }, more } }`.
enum GraphQLCable {
    /// `GraphQLChannel`'s identifier. Action Cable identifies a subscription by
    /// a JSON *string*, not an object, so the keys are sorted to make it the
    /// same every time.
    static func identifier(audienceID: String, channelID: String) -> String {
        let subscription = ["channel": "GraphQLChannel", "audience_id": audienceID, "channelId": channelID]
        return json(subscription) ?? "{}"
    }

    /// `execute`'s data, a JSON string inside the `message` command: the
    /// operation and its variables.
    static func executeData(operationName: String, query: String, variables: [String: Any] = [:]) -> String {
        let data: [String: Any] = [
            "action": "execute",
            "operationName": operationName,
            "query": query,
            "variables": variables,
        ]
        return json(data) ?? "{}"
    }

    static func json(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// What one incoming frame means to a connection.
    enum Incoming<Event: Sendable>: Sendable {
        /// The server confirmed `GraphQLChannel`: time to execute the operation.
        case confirmed
        case events([Event])
    }

    /// The Action Cable side of one frame, before its result means anything.
    enum Frame<Result: Decodable> {
        case confirmed
        /// `reject_subscription`: another audience's token, or someone the
        /// audience banned.
        case rejected
        /// The server is closing the socket.
        case disconnect
        /// A result of the operation; `more: false` ends it.
        case result(Result, more: Bool)
        /// A welcome, a ping, something unreadable.
        case ignored

        init(data: Data) {
            guard let frame = try? JSONDecoder().decode(Wire.self, from: data) else {
                self = .ignored
                return
            }

            switch frame.type {
            case "confirm_subscription": self = .confirmed
            case "reject_subscription": self = .rejected
            case "disconnect": self = .disconnect
            case .none:
                if let result = frame.result {
                    self = .result(result, more: frame.more ?? true)
                } else {
                    self = .ignored
                }
            default: self = .ignored
            }
        }

        /// An Action Cable frame. Its `message` is a GraphQL result for a frame
        /// with no `type`, and Action Cable's keep-alive counter for a ping, so
        /// it's decoded leniently.
        private struct Wire: Decodable {
            let type: String?
            let result: Result?
            let more: Bool?

            enum CodingKeys: String, CodingKey {
                case type, message
            }

            private struct Envelope: Decodable {
                let result: Result?
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
    }

    /// A result's `errors`, as their messages. Empty when there are none.
    static func errors<Key: CodingKey>(in container: KeyedDecodingContainer<Key>, forKey key: Key) -> [String] {
        ((try? container.decodeIfPresent([Lenient<ErrorWire>].self, forKey: key)) ?? nil)?
            .map { $0.value?.message ?? "error" } ?? []
    }

    private struct ErrorWire: Decodable { let message: String? }

    /// Decodes as `nil` instead of throwing, so one malformed array element
    /// doesn't fail the whole array.
    struct Lenient<Value: Decodable>: Decodable {
        let value: Value?

        init(from decoder: any Decoder) throws {
            value = try? Value(from: decoder)
        }
    }
}

/// One socket running one GraphQL operation over `GraphQLChannel`, turning its
/// frames into `Event`s with the parser it's given. It finishes `events` on
/// `disconnect()`, so a reconnect means a new socket.
actor GraphQLCableSocket<Event: Sendable> {
    typealias Parser = @Sendable (Data) -> GraphQLCable.Incoming<Event>

    private let url: URL
    private let token: String?
    private let session: URLSession
    private let encoder = JSONEncoder()
    /// Built once: Action Cable matches every command to its subscription by
    /// this exact string.
    private let identifier: String
    private let executeData: String
    private let parse: Parser
    private let confirmedEvent: Event?
    private let closedEvent: @Sendable (String?) -> Event
    private let name: String
    private nonisolated let continuation: AsyncStream<Event>.Continuation

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    /// When the server last sent anything. Action Cable pings every 3
    /// seconds, so a long silence means the socket is dead even if it looks open
    /// (a Wi-Fi to cellular handoff, say).
    private var lastHeard = ContinuousClock.now

    /// How long without a frame before the socket counts as gone.
    static var silenceLimit: Duration { .seconds(12) }

    /// Every event this socket produces, in order.
    nonisolated let events: AsyncStream<Event>

    /// - Parameters:
    ///   - identifier: from `GraphQLCable.identifier(audienceID:channelID:)`.
    ///   - executeData: from `GraphQLCable.executeData(operationName:query:variables:)`.
    ///   - confirmed: sent once the operation has gone out, if anything.
    ///   - closed: what the socket closing (with the reason, if known) means.
    ///   - name: names the socket in the log.
    init(
        url: URL,
        token: String?,
        identifier: String,
        executeData: String,
        session: URLSession = .realtime,
        name: String,
        confirmed: Event? = nil,
        closed: @escaping @Sendable (String?) -> Event,
        parse: @escaping Parser
    ) {
        self.url = url
        self.token = token
        self.identifier = identifier
        self.executeData = executeData
        self.session = session
        self.name = name
        confirmedEvent = confirmed
        closedEvent = closed
        self.parse = parse

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

        Task { await self.write(command: "subscribe", data: nil) }
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

    // MARK: - Private

    private func write(command: String, data: String?) async {
        guard let socket else { return }

        do {
            let frame = try encoder.encode(OutgoingFrame(command: command, identifier: identifier, data: data))
            try await socket.send(.string(String(decoding: frame, as: UTF8.self)))
        } catch {
            continuation.yield(closedEvent(error.localizedDescription))
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let socket = self.socket {
            do {
                let message = try await socket.receive()
                await handle(message)
            } catch {
                guard !Task.isCancelled else { return }

                Log.realtime.error("\(self.name, privacy: .public) socket closed: \(error.localizedDescription, privacy: .public)")
                continuation.yield(closedEvent(error.localizedDescription))
                return
            }
        }
    }

    /// Ends a socket that has gone quiet, so its owner can reconnect.
    private func watchForSilence() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, socket != nil else { return }
            guard ContinuousClock.now - lastHeard > Self.silenceLimit else { continue }

            Log.realtime.error("\(self.name, privacy: .public) socket went quiet; closing it")
            receiveTask?.cancel()
            receiveTask = nil
            socket?.cancel(with: .goingAway, reason: nil)
            socket = nil
            continuation.yield(closedEvent(nil))
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

        switch parse(data) {
        case .confirmed:
            // The server ignores commands for a subscription it hasn't confirmed.
            await write(command: "message", data: executeData)
            if let confirmedEvent { continuation.yield(confirmedEvent) }
        case let .events(events):
            for event in events {
                continuation.yield(event)
            }
        }
    }

    private struct OutgoingFrame: Encodable {
        let command: String
        let identifier: String
        let data: String?
    }
}
