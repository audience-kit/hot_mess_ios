//
//  User.swift
//  HotMess
//

import AudienceKit
import Foundation

struct User: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String

    var firstName: String { name.firstNameForDisplay }

    var initials: String { name.initialsForDisplay }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    /// From the IDs and names AudienceKit sends, which are optional there.
    init?(id: String, name: String?) {
        guard let uuid = RecordID.uuid(id) else { return nil }
        self.init(id: uuid, name: name ?? "")
    }

    /// From the AudienceKit GraphQL `me`.
    init?(_ user: AudienceKit.User) {
        let name = user.name ?? [user.firstName, user.lastName].compactMap(\.self).joined(separator: " ")
        self.init(id: user.id, name: name)
    }
}

/// AudienceKit GraphQL objects carry their record's UUID as `id`; `node(id:)`
/// uses Relay global IDs. The REST endpoints and deep links take the UUID.
enum RecordID {
    static func uuid(_ id: String) -> UUID? {
        UUID(uuidString: id) ?? GlobalID(id).flatMap { UUID(uuidString: $0.modelID) }
    }
}
