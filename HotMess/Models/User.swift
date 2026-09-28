//
//  User.swift
//  HotMess
//

import Foundation

struct User: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String

    var firstName: String { name.firstNameForDisplay }

    var initials: String { name.initialsForDisplay }
}

/// `/v1/token` — the session handed back after a Facebook login.
struct AuthenticatedSession: Decodable, Sendable {
    let token: String
    let user: User?
}
