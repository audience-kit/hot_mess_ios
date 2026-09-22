//
//  Decoding.swift
//  HotMess
//

import Foundation

/// Decoding helpers shared by every model.
///
/// `DateFormatter` and `ISO8601DateFormatter` are documented as thread-safe for
/// parsing, so the shared instances below are marked `nonisolated(unsafe)`
/// rather than being rebuilt on every decode.
enum HotMessDecoding {
    /// The API emits `2017-04-26T21:00:00.000-0700`. Some endpoints use plain
    /// ISO 8601 instead, so all three shapes are accepted.
    static var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)

            if let date = fractionalSeconds.date(from: text) { return date }
            if let date = iso8601WithFractionalSeconds.date(from: text) { return date }
            if let date = iso8601.date(from: text) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised date format: \(text)"
            )
        }
    }

    static var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractionalSeconds.string(from: date))
        }
    }

    /// `en_US_POSIX` keeps parsing stable on devices whose locale would
    /// otherwise reinterpret the fixed format — the original app omitted it.
    nonisolated(unsafe) private static let fractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Foundation.Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()

    nonisolated(unsafe) private static let iso8601 = ISO8601DateFormatter()

    nonisolated(unsafe) private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension JSONDecoder {
    /// A decoder configured the way every Hot Mess endpoint expects.
    static var hotMess: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = HotMessDecoding.dateDecodingStrategy
        return decoder
    }
}

extension JSONEncoder {
    static var hotMess: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = HotMessDecoding.dateEncodingStrategy
        return encoder
    }
}

extension KeyedDecodingContainer {
    /// Decodes a URL from a string, treating a malformed or empty string as
    /// absent instead of failing the whole payload.
    func decodeURLIfPresent(forKey key: Key) throws -> URL? {
        guard let text = try decodeIfPresent(String.self, forKey: key),
              !text.isEmpty else { return nil }
        return URL(string: text)
    }
}
