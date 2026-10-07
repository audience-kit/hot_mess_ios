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

    /// A line the user sent that the room hasn't echoed back yet.
    struct PendingMessage: Identifiable, Equatable, Sendable {
        enum State: Equatable, Sendable {
            /// Waiting to join the room, or sent and waiting for the echo.
            case sending
            /// No echo in time, or the room closed. The user can retry.
            case failed
        }

        let id: UUID
        let body: String
        let createdAt: Date
        var state: State
        /// Counts writes, so a timeout from an earlier try can't fail a resend.
        var attempt = 0
    }

    /// How often to tell the API the user is still here while the room is open.
    /// The API counts a position as present for 15 minutes.
    static let presenceInterval: Duration = .seconds(240)

    /// How long a sent line waits for the room to echo it before it's shown as failed.
    static let echoTimeout: Duration = .seconds(10)

    private(set) var messages: [VenueMessage] = []
    /// The user's own lines, in the order sent, until the room echoes each one.
    /// They show at the end of the transcript, marked as sending or failed.
    private(set) var pending: [PendingMessage] = []
    private(set) var connectionState: ConnectionState = .connecting
    /// The user is in the room from outside its place, which only admins can do.
    private(set) var isOutOfRange = false
    var draft: String = ""

    let room: ChatRoom

    private let url: URL?
    private let token: String?
    let userID: UUID?
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

    /// Lines typed while the room is still joining wait in `pending` and go out
    /// once it's joined.
    var canSend: Bool {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, userID != nil else { return false }

        switch connectionState {
        case .connecting, .connected: return true
        case .notPresent, .disconnected: return false
        }
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
                await sendPending()
            case let .received(message):
                receive(message)
            case let .range(outOfRange):
                isOutOfRange = outOfRange
            case .notPresent:
                connectionState = .notPresent
                failPending()
                await stop()
            case let .disconnected(reason):
                connectionState = .disconnected(reason)
                failPending()
            }
        }
    }

    /// After "only for people at …": report the position again and reconnect.
    func retry() async {
        await stop()
        await run()
    }

    /// Shows the line straight away as sending. It goes out now if the room is
    /// joined, or as soon as it is.
    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard canSend, !body.isEmpty else { return }

        draft = ""

        let message = PendingMessage(id: UUID(), body: body, createdAt: .now, state: .sending)
        pending.append(message)

        if connectionState == .connected {
            await deliver(message.id)
        }
    }

    /// Tries a failed line again, reconnecting first if the room has closed.
    func resend(_ id: UUID) async {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }

        pending[index].state = .sending

        switch connectionState {
        case .connected:
            await deliver(id)
        case .connecting:
            break
        case .disconnected, .notPresent:
            // `run()` sends every pending line once the room is joined again.
            await reconnect()
        }
    }

    func stop() async {
        presenceTask?.cancel()
        presenceTask = nil
        await connection?.disconnect()
        connection = nil
    }

    // MARK: - Sending

    private func reconnect() async {
        await stop()
        Task { await run() }
    }

    private func sendPending() async {
        for message in pending where message.state == .sending {
            await deliver(message.id)
        }
    }

    /// Writes the line and fails it if the room hasn't echoed it in time.
    private func deliver(_ id: UUID) async {
        guard let connection, let index = pending.firstIndex(where: { $0.id == id }) else { return }

        pending[index].attempt += 1
        let attempt = pending[index].attempt
        let body = pending[index].body

        do {
            try await connection.send(body)
        } catch {
            markFailed(id, attempt: attempt)
            return
        }

        Task { [weak self] in
            try? await Task.sleep(for: Self.echoTimeout)
            self?.markFailed(id, attempt: attempt)
        }
    }

    /// The server sends nothing to identify the sender's own copy beyond who
    /// sent it, so the echo settles the oldest pending line with the same text.
    private func receive(_ message: VenueMessage) {
        if isOutgoing(message), let index = pending.firstIndex(where: { $0.body == message.body }) {
            pending.remove(at: index)
        }

        messages.append(message)
    }

    private func markFailed(_ id: UUID, attempt: Int) {
        guard let index = pending.firstIndex(where: { $0.id == id }),
              pending[index].state == .sending,
              pending[index].attempt == attempt
        else { return }

        pending[index].state = .failed
    }

    private func failPending() {
        for index in pending.indices where pending[index].state == .sending {
            pending[index].state = .failed
        }
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
