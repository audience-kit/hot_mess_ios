//
//  APIClient.swift
//  HotMess
//

import Foundation

/// Decodes to nothing, for calls whose response body the app ignores.
struct EmptyResponse: Decodable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws {}
}

/// The app's HTTP layer.
///
/// Replaces `RequestService`, which dispatched callbacks onto arbitrary queues
/// and presented a `UIAlertController` from a background thread whenever a
/// request failed. Transport concerns live here; presentation lives in views.
actor APIClient {
    private nonisolated let configuration: AppConfiguration
    private let credentials: Keychain
    private let session: URLSession
    private let decoder = JSONDecoder.hotMess
    private let encoder = JSONEncoder.hotMess
    private nonisolated let unauthorizedContinuation: AsyncStream<Void>.Continuation

    /// Fires whenever the server rejects the stored token, so the session store
    /// can drop it and send the user back to the login screen.
    nonisolated let unauthorizedEvents: AsyncStream<Void>

    init(
        configuration: AppConfiguration = AppConfiguration(),
        credentials: Keychain = .shared,
        session: URLSession = .hotMess
    ) {
        self.configuration = configuration
        self.credentials = credentials
        self.session = session

        let (stream, continuation) = AsyncStream<Void>.makeStream()
        unauthorizedEvents = stream
        unauthorizedContinuation = continuation
    }

    deinit {
        unauthorizedContinuation.finish()
    }

    nonisolated var baseURL: URL { configuration.baseURL }

    @discardableResult
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let data = try await data(for: endpoint)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func data<Response>(for endpoint: Endpoint<Response>) async throws -> Data {
        let request = try urlRequest(for: endpoint)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError(urlError: error)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(String(localized: "The server sent an unexpected response."))
        }

        switch http.statusCode {
        case 200 ..< 300:
            return data
        case 401, 403:
            unauthorizedContinuation.yield()
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            throw APIError.server(status: http.statusCode)
        }
    }

    private func urlRequest<Response>(for endpoint: Endpoint<Response>) throws -> URLRequest {
        var request = URLRequest(url: try endpoint.url(relativeTo: configuration.baseURL))
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuthentication, let token = credentials.string(for: .sessionToken) {
            request.setValue("JWT \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try body.encode(encoder)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}

extension URLSession {
    /// Waits for connectivity rather than failing instantly when the device is
    /// briefly offline — the old client surfaced an alert in that case.
    nonisolated(unsafe) static let hotMess: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120

        return URLSession(configuration: configuration)
    }()
}
