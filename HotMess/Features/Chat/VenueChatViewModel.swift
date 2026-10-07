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
    /// Who is in the room now, by user ID: the roster the room sends on
    /// joining, kept up to date by its presence frames. Empty while offline.
    private(set) var onlineUserIDs: Set<UUID> = []
    /// What the room has said about the people in it, by user ID: names and
    /// avatars from its roster and presence frames. Empty while offline, and
    /// from servers that only send IDs.
    private(set) var roomPeople: [UUID: RoomPerson] = [:]
    var draft: String = ""

    let room: ChatRoom

    private let url: URL?
    private let configuration: AppConfiguration
    private let token: String?
    let userID: UUID?
    /// The app's friends so far. The roster's full list of friends goes in,
    /// so friends show by full name everywhere.
    private let friends: FriendDirectory?
    /// Full names of the user's friends from the room's roster, for when
    /// there's no directory.
    private var rosterFriendNames: [UUID: String] = [:]
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
        friends: FriendDirectory? = nil,
        reportPresence: @escaping @MainActor () async -> Void = {}
    ) {
        self.room = room
        self.configuration = configuration
        self.userID = userID
        self.token = token
        self.friends = friends
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

    /// The announcement pinned under the room's title: the latest one the
    /// room sent marked as pinned.
    var pinnedAnnouncement: VenueMessage? {
        messages.last { $0.isPinned && $0.kind == .announcement }
    }

    /// Everyone else in the room now, for the Here now strip: friends first,
    /// then everyone else, each by name. A friend shows by their full name.
    /// Without names from the room (an older server), the name and avatar
    /// they last posted with.
    var hereNow: [HereNowPerson] {
        let directory = friends?.byID ?? [:]
        var ids = onlineUserIDs
        if let userID { ids.remove(userID) }

        let people = ids.map { id -> HereNowPerson in
            let person = roomPeople[id]
            let friendName = rosterFriendNames[id] ?? directory[id]?.name
            let posted = person?.name == nil || person?.avatarURL == nil
                ? messages.last(where: { $0.userID == id && !$0.isFromPlace })
                : nil

            return HereNowPerson(
                id: id,
                name: friendName ?? person?.name ?? posted?.name,
                avatarURL: person?.avatarURL ?? posted?.avatarURL ?? configuration.avatarURL(forUserID: id),
                isFriend: person?.isFriend == true || friendName != nil
            )
        }

        return HereNowPerson.sorted(people)
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
            case let .roster(online, people, friends):
                applyRoster(online: online, people: people, friends: friends)
            case let .presence(userID, online, name, avatarURL):
                applyPresence(userID: userID, online: online, name: name, avatarURL: avatarURL)
            case .notPresent:
                connectionState = .notPresent
                clearRoom()
                failPending()
                await stop()
            case let .disconnected(reason):
                connectionState = .disconnected(reason)
                clearRoom()
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

    // MARK: - Who's here

    /// The room's list of who's in it, sent on joining. Everyone it names is
    /// in the room, even if `online` (from an older server) left them out.
    func applyRoster(online: Set<UUID>, people: [RoomPerson], friends roster: [Friend]) {
        roomPeople = Dictionary(people.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        onlineUserIDs = online.union(people.map(\.id))

        for friend in roster {
            rosterFriendNames[friend.id] = friend.name
        }
        friends?.rememberNames(roster)
    }

    /// Someone joined or left. A join keeps what's already known about them
    /// unless the frame says otherwise.
    func applyPresence(userID: UUID, online: Bool, name: String?, avatarURL: URL?) {
        guard online else {
            onlineUserIDs.remove(userID)
            roomPeople[userID] = nil
            return
        }

        onlineUserIDs.insert(userID)
        var person = roomPeople[userID] ?? RoomPerson(id: userID)
        if let name { person.name = name }
        if let avatarURL { person.avatarURL = avatarURL }
        roomPeople[userID] = person
    }

    private func clearRoom() {
        onlineUserIDs = []
        roomPeople = [:]
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
