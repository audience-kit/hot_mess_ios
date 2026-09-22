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
        case disconnected(String?)
    }

    private(set) var messages: [VenueMessage] = []
    private(set) var connectionState: ConnectionState = .connecting
    var draft: String = ""

    let venue: Venue

    private let connection: VenueChatConnection?
    private let userID: UUID?
    private let avatarURL: URL?

    init(venue: Venue, configuration: AppConfiguration, userID: UUID?, token: String?) {
        self.venue = venue
        self.userID = userID
        avatarURL = userID.map(configuration.avatarURL(forUserID:))

        if let url = configuration.realtimeURL {
            connection = VenueChatConnection(venueID: venue.id, url: url, token: token)
        } else {
            connection = nil
        }
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && connectionState == .connected
            && userID != nil
    }

    func isOutgoing(_ message: VenueMessage) -> Bool {
        message.isOutgoing(for: userID)
    }

    /// Connects and streams messages until the surrounding task is cancelled.
    func run() async {
        guard let connection else {
            connectionState = .disconnected(String(localized: "Chat isn't available for this build."))
            return
        }

        await connection.connect()

        for await event in connection.events {
            switch event {
            case .connected:
                connectionState = .connected
            case let .received(message):
                messages.append(message)
            case let .disconnected(reason):
                connectionState = .disconnected(reason)
            }
        }
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !body.isEmpty, let connection, let userID else { return }

        draft = ""

        do {
            try await connection.send(body, from: userID, avatarURL: avatarURL)
        } catch {
            // Put the text back so the user doesn't lose what they typed.
            draft = body
            connectionState = .disconnected(error.localizedDescription)
        }
    }

    func stop() async {
        await connection?.disconnect()
    }
}
