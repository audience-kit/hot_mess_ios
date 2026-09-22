//
//  Friend.swift
//  HotMess
//

import Foundation

struct Friend: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let facebookID: FacebookID?

    var firstName: String { name.firstNameForDisplay }

    /// Opens a Messenger thread. `nil` when the friend has no Facebook ID,
    /// which the UI treats as "not reachable" rather than crashing.
    var messengerURL: URL? { facebookID?.messengerURL }

    enum CodingKeys: String, CodingKey {
        case id, name
        case facebookID = "facebook_id"
    }

    init(id: UUID, name: String, facebookID: FacebookID? = nil) {
        self.id = id
        self.name = name
        self.facebookID = facebookID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        facebookID = try container.decodeIfPresent(FacebookID.self, forKey: .facebookID)
    }
}
