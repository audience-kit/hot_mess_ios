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

    /// The cable's handshake as the API contract has it: `Authorization:
    /// Bearer <token>` (the SDK's cable still writes the `JWT` scheme, which
    /// the API no longer accepts) and the API version header every call
    /// carries. The token itself is passed through untouched.
    static func handshake(_ request: URLRequest) -> URLRequest {
        var request = request
        if let authorization = request.value(forHTTPHeaderField: "Authorization") {
            let token = authorization.hasPrefix("JWT ") ? String(authorization.dropFirst(4)) : authorization
            request.setValue(bearer(token), forHTTPHeaderField: "Authorization")
        }
        request.setValue(AudienceKitSDK.apiVersion, forHTTPHeaderField: AudienceKitSDK.apiVersionHeaderName)
        return request
    }

    /// `Bearer <token>`, for a token with or without a scheme already.
    static func bearer(_ token: String) -> String {
        token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
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
