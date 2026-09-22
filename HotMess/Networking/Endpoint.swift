//
//  Endpoint.swift
//  HotMess
//

import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// A JSON request body, type-erased so `Endpoint` stays a simple value type.
struct JSONBody: Sendable {
    let encode: @Sendable (JSONEncoder) throws -> Data

    init<Value: Encodable & Sendable>(_ value: Value) {
        encode = { encoder in try encoder.encode(value) }
    }
}

/// A single API call, described as data. `Response` is what the caller gets
/// back once the body has been decoded.
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    var path: String
    var method: HTTPMethod
    var query: [URLQueryItem]
    var body: JSONBody?
    /// When `false` the request is sent without the stored bearer token —
    /// used by `/v1/token` itself, which is what mints it.
    var requiresAuthentication: Bool

    init(
        _ path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: JSONBody? = nil,
        requiresAuthentication: Bool = true
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.requiresAuthentication = requiresAuthentication
    }

    /// Builds the absolute URL for this call against a base.
    ///
    /// Paths are joined explicitly rather than with `appendingPathComponent`
    /// so a base URL with or without a trailing slash produces the same result.
    func url(relativeTo baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        let base = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        let suffix = path.hasPrefix("/") ? path : "/" + path

        components.path = base + suffix
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }
}

/// Where the device is, as the API wants it on the query string.
struct Coordinates: Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var beaconMajor: Int?
    var beaconMinor: Int?

    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
        ]

        if let beaconMajor, let beaconMinor, beaconMajor != 0, beaconMinor != 0 {
            items.append(URLQueryItem(name: "major", value: String(beaconMajor)))
            items.append(URLQueryItem(name: "minor", value: String(beaconMinor)))
        }

        return items
    }
}
