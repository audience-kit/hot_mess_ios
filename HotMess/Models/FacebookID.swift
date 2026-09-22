//
//  FacebookID.swift
//  HotMess
//

import Foundation

/// A Facebook object ID.
///
/// The API returns these as a JSON number on some endpoints and a JSON string
/// on others. Both are accepted and normalised to a string, which is all the
/// app ever needs — the previous `data["facebook_id"] as! Int64` crashed
/// whenever the server sent the other shape.
struct FacebookID: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let text = try? container.decode(String.self) {
            rawValue = text
        } else {
            rawValue = String(try container.decode(Int64.self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var description: String { rawValue }

    var profileURL: URL? { URL(string: "https://facebook.com/\(rawValue)") }

    var eventURL: URL? { URL(string: "https://facebook.com/events/\(rawValue)") }

    var messengerURL: URL? { URL(string: "fb-messenger://user-thread/\(rawValue)") }
}
