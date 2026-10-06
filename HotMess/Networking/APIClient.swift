//
//  APIClient.swift
//  HotMess
//

import AudienceKit
import Foundation

/// Decodes to nothing, for calls whose response body the app ignores.
struct EmptyResponse: Decodable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws {}
}

/// The app's HTTP layer for the REST endpoints GraphQL doesn't cover yet (now,
/// events, RSVPs, locales, location reports).
///
/// Requests go through the AudienceKit SDK, which owns the session token: it
/// signs each call with `Authorization: JWT …` and, when the API rejects the
/// session, forgets it and tells `SessionStore` through `sessionEvents`.
actor APIClient {
    nonisolated let audienceKit: AudienceKitClient
    private let decoder = JSONDecoder.hotMess
    private let encoder = JSONEncoder.hotMess

    init(audienceKit: AudienceKitClient) {
        self.audienceKit = audienceKit
    }

    nonisolated var baseURL: URL { audienceKit.configuration.baseURL }

    @discardableResult
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = APIRequest(
            method: endpoint.method.rawValue,
            path: endpoint.path,
            queryItems: endpoint.query,
            body: try endpoint.body?.encode(encoder),
            authenticated: endpoint.requiresAuthentication
        )

        let data: Data
        do {
            data = try await audienceKit.data(for: request)
        } catch let error as AudienceKitError {
            throw APIError(error)
        }

        if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
            return empty
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}

extension URLSession {
    /// Waits for connectivity rather than failing instantly when the device is
    /// briefly offline — the old client surfaced an alert in that case.
    static let hotMess: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120

        return URLSession(configuration: configuration)
    }()
}
