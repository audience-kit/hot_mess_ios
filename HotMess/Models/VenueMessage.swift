//
//  VenueMessage.swift
//  HotMess
//

import Foundation

/// One line in a venue's chat room.
struct VenueMessage: Hashable, Sendable, Identifiable {
    let id: UUID
    let body: String
    let userID: UUID
    let avatarURL: URL?
    let sentAt: Date

    init(
        id: UUID = UUID(),
        body: String,
        userID: UUID,
        avatarURL: URL? = nil,
        sentAt: Date = .now
    ) {
        self.id = id
        self.body = body
        self.userID = userID
        self.avatarURL = avatarURL
        self.sentAt = sentAt
    }

    func isOutgoing(for currentUserID: UUID?) -> Bool {
        userID == currentUserID
    }
}

extension VenueMessage {
    /// The wire representation exchanged over the realtime channel.
    struct Payload: Codable, Sendable {
        let message: String
        let userID: UUID
        let avatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case message
            case userID = "user_id"
            case avatarURL = "avatar_url"
        }
    }

    init(payload: Payload) {
        self.init(
            body: payload.message,
            userID: payload.userID,
            avatarURL: payload.avatarURL
        )
    }
}
