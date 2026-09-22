//
//  APIError.swift
//  HotMess
//

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
