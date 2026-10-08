//
//  Safety.swift
//  HotMess
//

import Foundation

/// Someone the user blocked. Chat rooms leave them out, and the API stops
/// sending the user their messages and presence.
struct BlockedUser: Decodable, Hashable, Sendable, Identifiable {
    let id: UUID
    /// The short form rooms show strangers ("Aurora B.").
    let name: String?
    let avatarURL: URL?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case avatarURL = "avatar_url"
    }

    init(id: UUID, name: String?, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
    }
}

/// What the API keeps about the user's own safety settings.
struct SafetyState: Decodable, Sendable {
    var termsAcceptedAt: Date?
    var blockedUsers: [BlockedUser]

    private enum CodingKeys: String, CodingKey {
        case termsAcceptedAt = "terms_accepted_at"
        case blockedUsers = "blocked_users"
    }

    init(termsAcceptedAt: Date? = nil, blockedUsers: [BlockedUser] = []) {
        self.termsAcceptedAt = termsAcceptedAt
        self.blockedUsers = blockedUsers
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        termsAcceptedAt = try container.decodeIfPresent(Date.self, forKey: .termsAcceptedAt)
        blockedUsers = try container.decodeIfPresent([BlockedUser].self, forKey: .blockedUsers) ?? []
    }
}

/// Why someone reports a chat message. The raw value is what the room's
/// admins read.
enum ChatReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam = "Spam"
    case harassment = "Harassment or hate"
    case sexual = "Sexual content"
    case danger = "Threats or danger"
    case other = "Something else"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: String(localized: "Spam")
        case .harassment: String(localized: "Harassment or hate")
        case .sexual: String(localized: "Sexual content")
        case .danger: String(localized: "Threats or danger")
        case .other: String(localized: "Something else")
        }
    }
}

/// The audience's legal pages, linked from Settings and the terms prompt.
enum LegalLinks {
    static let terms = URL(string: "https://audiencekit.com/terms/")!
    static let privacy = URL(string: "https://audiencekit.com/privacy/")!
}
