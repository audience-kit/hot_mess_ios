//
//  RSVP.swift
//  HotMess
//

import Foundation

/// A user's response to an event.
///
/// The original client sent `"decliend"` — a typo that meant a decline never
/// round-tripped, so the button never came back selected. The wire value is now
/// spelled correctly and the old spelling is still accepted when decoding so
/// historical rows keep working.
enum RSVP: String, Codable, Hashable, Sendable {
    case attending
    case maybe
    case declined
    case unsure

    static let selectable: [RSVP] = [.attending, .maybe, .declined]

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)

        if let value = RSVP(rawValue: raw) {
            self = value
        } else if raw == "decliend" {
            self = .declined
        } else {
            self = .unsure
        }
    }

    var title: String {
        switch self {
        case .attending: String(localized: "Going")
        case .maybe: String(localized: "Interested")
        case .declined: String(localized: "Not going")
        case .unsure: String(localized: "Undecided")
        }
    }

    var systemImage: String {
        switch self {
        case .attending: "checkmark.circle.fill"
        case .maybe: "star.circle.fill"
        case .declined: "xmark.circle.fill"
        case .unsure: "questionmark.circle"
        }
    }
}
