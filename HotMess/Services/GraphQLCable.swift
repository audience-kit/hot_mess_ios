//
//  GraphQLCable.swift
//  HotMess
//

import AudienceKit
import Foundation

/// Reading the results of the GraphQL subscriptions the app follows over its
/// one `AudienceCable` (see `AppModel.cable`). The cable carries every
/// realtime feature of the API on a single socket; each feature turns its
/// operation's `AudienceCable.Event`s into its own.
enum GraphQLCable {
    /// The cable's address for the app's API: `AppConfiguration.realtimeURL`,
    /// else the API's own default.
    static func url(for configuration: AppConfiguration) -> URL {
        configuration.realtimeURL ?? AudienceCable.url(for: configuration.baseURL)
    }

    /// A result's `errors`, as their messages. Empty when there are none.
    static func errors<Key: CodingKey>(in container: KeyedDecodingContainer<Key>, forKey key: Key) -> [String] {
        ((try? container.decodeIfPresent([Lenient<ErrorWire>].self, forKey: key)) ?? nil)?
            .map { $0.value?.message ?? "error" } ?? []
    }

    private struct ErrorWire: Decodable { let message: String? }

    /// Decodes as `nil` instead of throwing, so one malformed array element
    /// doesn't fail the whole array.
    struct Lenient<Value: Decodable>: Decodable {
        let value: Value?

        init(from decoder: any Decoder) throws {
            value = try? Value(from: decoder)
        }
    }
}
