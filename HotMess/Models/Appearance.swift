//
//  Appearance.swift
//  HotMess
//

import Foundation

/// Someone on at a venue: hosting, DJing, performing or MCing, with or
/// without an event. GraphQL's `Venue.onNow` lists the ones on right now.
struct Appearance: Hashable, Sendable, Identifiable {
    let id: UUID
    let person: Person
    /// What they're doing. `nil` for a role this build doesn't know.
    let role: Role?
    let startsAt: Date?
    /// When they finish; `nil` until the night ends.
    let endsAt: Date?

    enum Role: String, Hashable, Sendable {
        case host, dj, performer, mc

        /// GraphQL sends `DJ`, the lineup's own records `dj`.
        init?(wire: String) {
            self.init(rawValue: wire.lowercased())
        }

        /// Under their name in an On now row.
        var label: String {
            switch self {
            case .host: String(localized: "Hosting")
            case .dj: String(localized: "DJ")
            case .performer: String(localized: "Performing")
            case .mc: String(localized: "MC")
            }
        }
    }

    /// The role and, when they have one, the time they finish: "DJ · until 1 AM".
    var detail: String? {
        let until = endsAt.map { String(localized: "until \($0.formatted(date: .omitted, time: .shortened))") }
        let parts = [role?.label, until].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    init(id: UUID, person: Person, role: Role?, startsAt: Date? = nil, endsAt: Date? = nil) {
        self.id = id
        self.person = person
        self.role = role
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}

extension Appearance: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, person, role
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }

    /// Only `id` and a `person` with a name are required; an unknown role or
    /// a malformed time is dropped rather than failing the appearance.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        person = try container.decode(Person.self, forKey: .person)
        role = (try? container.decodeIfPresent(String.self, forKey: .role)).flatMap { Role(wire: $0) }
        startsAt = Self.date(in: container, forKey: .startsAt)
        endsAt = Self.date(in: container, forKey: .endsAt)
    }

    /// GraphQL's ISO 8601, with or without the decoder's date strategy.
    private static func date(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        (try? container.decodeIfPresent(String.self, forKey: key))
            .flatMap { try? Date($0, strategy: .iso8601) }
    }
}

extension KeyedDecodingContainer {
    /// A venue's `on_now`, each appearance decoded on its own so one bad entry
    /// (a person with no name yet) drops only itself. A missing or malformed
    /// list, as from an API without the field, is empty.
    func decodeAppearances(forKey key: Key) -> [Appearance] {
        (try? decodeIfPresent([LenientAppearance].self, forKey: key))?
            .compactMap(\.appearance) ?? []
    }
}

private struct LenientAppearance: Decodable {
    let appearance: Appearance?

    init(from decoder: any Decoder) throws {
        appearance = try? Appearance(from: decoder)
    }
}
