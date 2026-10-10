//
//  APIError.swift
//  HotMess
//

import AudienceKit
import Foundation

enum APIError: Error, Equatable, Sendable, LocalizedError {
    /// The device has no usable connection, or the request timed out.
    case offline
    /// The server rejected our credentials; the session needs re-establishing.
    case unauthorized
    case notFound
    case server(status: Int)
    case decoding(String)
    case invalidURL
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            String(localized: "You appear to be offline. Check your connection and try again.")
        case .unauthorized:
            String(localized: "Your session expired. Sign in again to continue.")
        case .notFound:
            String(localized: "That isn't available any more.")
        case let .server(status):
            String(localized: "The server had a problem (\(status)). Try again in a moment.")
        case .decoding:
            String(localized: "The server sent something we didn't understand.")
        case .invalidURL:
            String(localized: "That request couldn't be built.")
        case let .transport(message):
            message
        }
    }

    /// Whether offering a "Try again" button makes sense.
    var isRetryable: Bool {
        switch self {
        case .offline, .server, .transport: true
        case .unauthorized, .notFound, .decoding, .invalidURL: false
        }
    }

    /// Maps the SDK's errors onto the ones the screens know how to show.
    init(_ error: AudienceKitError) {
        switch error {
        case .notSignedIn, .unauthorized, .signInRejected:
            self = .unauthorized
        case .forbidden:
            self = .transport(error.localizedDescription)
        case .notFound:
            self = .notFound
        case let .http(status):
            self = .server(status: status)
        case let .network(urlError):
            self = APIError(urlError: urlError)
        case let .decoding(detail):
            self = .decoding(detail)
        case .signInFailed, .graphQL, .missingConfiguration, .tokenStorage, .updateRequired:
            self = .transport(error.localizedDescription)
        }
    }

    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .dataNotAllowed,
             .cannotConnectToHost, .cannotFindHost, .internationalRoamingOff:
            self = .offline
        default:
            self = .transport(urlError.localizedDescription)
        }
    }
}
