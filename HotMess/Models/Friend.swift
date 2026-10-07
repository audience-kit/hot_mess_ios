//
//  Friend.swift
//  HotMess
//

import Foundation

struct Friend: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let facebookID: FacebookID?
    /// Whether they can be reached now: in chat, by push, or neither (`nil`).
    /// The API only tells friends.
    var presence: PresenceState?

    var firstName: String { name.firstNameForDisplay }

    /// Opens a Messenger thread. `nil` when the friend has no Facebook ID,
    /// which the UI treats as "not reachable" rather than crashing.
    var messengerURL: URL? { facebookID?.messengerURL }

    enum CodingKeys: String, CodingKey {
        case id, name, presence
        case facebookID = "facebook_id"
    }

    init(id: UUID, name: String, facebookID: FacebookID? = nil, presence: PresenceState? = nil) {
        self.id = id
        self.name = name
        self.facebookID = facebookID
        self.presence = presence
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        facebookID = try container.decodeIfPresent(FacebookID.self, forKey: .facebookID)
        presence = (try? container.decodeIfPresent(String.self, forKey: .presence)).flatMap { PresenceState(wire: $0) }
    }
}

/// A venue where some of your friends have been lately, with how many, for
/// Now when you aren't in a venue yourself.
struct FriendVenue: Decodable, Hashable, Sendable, Identifiable {
    let venue: Venue
    let friendCount: Int
    let friends: [Friend]

    var id: UUID { venue.id }

    enum CodingKeys: String, CodingKey {
        case venue, friends
        case friendCount = "friend_count"
    }

    init(venue: Venue, friendCount: Int, friends: [Friend] = []) {
        self.venue = venue
        self.friendCount = friendCount
        self.friends = friends
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        venue = try container.decode(Venue.self, forKey: .venue)
        friends = try container.decodeIfPresent([Friend].self, forKey: .friends) ?? []
        friendCount = try container.decodeIfPresent(Int.self, forKey: .friendCount) ?? friends.count
    }
}
