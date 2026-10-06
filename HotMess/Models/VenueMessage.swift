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
    /// The sender's first name, as the server sends it.
    let name: String?
    let avatarURL: URL?
    let sentAt: Date

    init(
        id: UUID = UUID(),
        body: String,
        userID: UUID,
        name: String? = nil,
        avatarURL: URL? = nil,
        sentAt: Date = .now
    ) {
        self.id = id
        self.body = body
        self.userID = userID
        self.name = name
        self.avatarURL = avatarURL
        self.sentAt = sentAt
    }

    func isOutgoing(for currentUserID: UUID?) -> Bool {
        userID == currentUserID
    }
}

extension VenueMessage {
    /// A chat line as the server broadcasts it.
    struct Payload: Codable, Sendable {
        let message: String
        let userID: UUID
        let name: String?
        let avatarURL: URL?
        let sentAt: Date?

        enum CodingKeys: String, CodingKey {
            case message, name
            case userID = "user_id"
            case avatarURL = "avatar_url"
            case sentAt = "sent_at"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = try container.decode(String.self, forKey: .message)
            userID = try container.decode(UUID.self, forKey: .userID)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            avatarURL = try container.decodeURLIfPresent(forKey: .avatarURL)
            sentAt = (try? container.decodeIfPresent(String.self, forKey: .sentAt))
                .flatMap { try? Date($0, strategy: .iso8601) }
        }
    }

    init(payload: Payload) {
        self.init(
            body: payload.message,
            userID: payload.userID,
            name: payload.name,
            avatarURL: payload.avatarURL,
            sentAt: payload.sentAt ?? .now
        )
    }
}
