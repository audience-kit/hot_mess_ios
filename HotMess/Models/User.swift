//
//  User.swift
//  HotMess
//

import AudienceKit
import Foundation

struct User: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
    /// Their profile photo, from `me { photo }`; `nil` until it's loaded or
    /// when they have none, and the avatar shows their initials.
    var avatarURL: URL?

    var firstName: String { name.firstNameForDisplay }

    var initials: String { name.initialsForDisplay }

    init(id: UUID, name: String, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
    }

    /// From the IDs and names AudienceKit sends, which are optional there.
    init?(id: String, name: String?) {
        guard let uuid = RecordID.uuid(id) else { return nil }
        self.init(id: uuid, name: name ?? "")
    }
}

/// AudienceKit GraphQL objects carry their record's UUID as `id`; `node(id:)`
/// uses Relay global IDs. The REST endpoints and deep links take the UUID.
enum RecordID {
    static func uuid(_ id: String) -> UUID? {
        UUID(uuidString: id) ?? GlobalID(id).flatMap { UUID(uuidString: $0.modelID) }
    }
}
