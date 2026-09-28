//
//  EventListing.swift
//  HotMess
//

import Foundation

/// A named group of events — "tonight", "this week", and so on.
struct EventSection: Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let events: [Event]
}

/// `/v1/locales/{id}/events` returns `sections` as a dictionary keyed by
/// section name. Dictionaries have no order, so sections are sorted by their
/// earliest event to give the list a stable, sensible order — the original
/// re-shuffled the screen on every refresh.
struct EventListing: Decodable, Hashable, Sendable {
    let sections: [EventSection]

    init(sections: [EventSection] = []) {
        self.sections = sections
    }

    private struct SectionPayload: Decodable {
        let title: String
        let events: [Event]

        enum CodingKeys: String, CodingKey {
            case title, events
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
            events = try container.decodeIfPresent([Event].self, forKey: .events) ?? []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case sections
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payload = try container.decodeIfPresent([String: SectionPayload].self, forKey: .sections) ?? [:]

        sections = payload
            .map { name, section in
                EventSection(
                    id: name,
                    title: section.title.isEmpty ? name.capitalized : section.title,
                    events: section.events.sorted { $0.startDate < $1.startDate }
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.events.first?.startDate, rhs.events.first?.startDate) {
                case let (left?, right?) where left != right:
                    return left < right
                case (nil, .some):
                    return false
                case (.some, nil):
                    return true
                default:
                    return lhs.id < rhs.id
                }
            }
    }

    var isEmpty: Bool { sections.allSatisfy(\.events.isEmpty) }
}
