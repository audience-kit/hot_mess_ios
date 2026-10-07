//
//  VenueChatViewModel.swift
//  HotMess
//

import Foundation
import Observation

@MainActor
@Observable
final class VenueChatViewModel {
    enum ConnectionState: Equatable, Sendable {
        case connecting
        case connected
        /// The room is only for people at the venue (or out in the locale), and
        /// the API doesn't have the user there. Reconnecting won't help until they are; "Try again" does.
        case notPresent
        case disconnected(String?)
    }

    /// How often to tell the API the user is still here while the room is open.
    /// The API counts a position as present for 15 minutes.
    static let presenceInterval: Duration = .seconds(240)

    private(set) var messages: [VenueMessage] = []
    private(set) var connectionState: ConnectionState = .connecting
    /// The user is in the room from outside its place, which only admins can do.
    private(set) var isOutOfRange = false
    var draft: String = ""

    let room: ChatRoom

    private let url: URL?
    private let token: String?
    private let userID: UUID?
    private let reportPresence: @MainActor () async -> Void
    private var connection: VenueChatConnection?
    private var presenceTask: Task<Void, Never>?

    /// - Parameter reportPresence: reports the device's position, so the API
    ///   lets the user into the room and keeps them in it.
    init(
        room: ChatRoom,
        configuration: AppConfiguration,
        userID: UUID?,
        token: String?,
        reportPresence: @escaping @MainActor () async -> Void = {}
    ) {
        self.room = room
        self.userID = userID
        self.token = token
        self.reportPresence = reportPresence
        url = configuration.realtimeURL
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && connectionState == .connected
            && userID != nil
    }

    func isOutgoing(_ message: VenueMessage) -> Bool {
        message.isOutgoing(for: userID)
    }

    /// Reports the position, connects, and streams messages until the room
    /// closes or the server says the user isn't in the room's place. While it's open,
    /// the position is reported again every few minutes.
    func run() async {
        guard let url else {
            connectionState = .disconnected(String(localized: "Chat isn't available for this build."))
            return
        }

        connectionState = .connecting
        await reportPresence()
        startReportingPresence()

        let connection = VenueChatConnection(room: room, url: url, token: token)
        self.connection = connection
        await connection.connect()

        for await event in connection.events {
            switch event {
            case .connected:
                connectionState = .connected
            case let .received(message):
                messages.append(message)
            case let .range(outOfRange):
                isOutOfRange = outOfRange
            case .notPresent:
                connectionState = .notPresent
                await stop()
            case let .disconnected(reason):
                connectionState = .disconnected(reason)
            }
        }
    }

    /// After "only for people at …": report the position again and reconnect.
    func retry() async {
        await stop()
        await run()
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !body.isEmpty, let connection, userID != nil else { return }

        draft = ""

        do {
            try await connection.send(body)
        } catch {
            // Put the text back so the user doesn't lose what they typed.
            draft = body
            connectionState = .disconnected(error.localizedDescription)
        }
    }

    func stop() async {
        presenceTask?.cancel()
        presenceTask = nil
        await connection?.disconnect()
        connection = nil
    }

    private func startReportingPresence() {
        presenceTask?.cancel()
        presenceTask = Task { [reportPresence] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.presenceInterval)
                guard !Task.isCancelled else { return }
                await reportPresence()
            }
        }
    }
}
