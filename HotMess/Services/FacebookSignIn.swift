//
//  FacebookSignIn.swift
//  HotMess
//

import AppTrackingTransparency
import FacebookCore
import FacebookLogin
import Foundation
import UIKit

/// Signs in with Facebook using only the Facebook SDK, requesting App
/// Tracking Transparency permission before starting the login flow.
///
/// Why not Limited Login: it returns only an OpenID Connect authentication
/// token (a JWT), with no Graph API access token, and the AudienceKit API
/// signs people in with a Graph access token (`POST /v1/token`
/// `facebook_token`, checked and used with the Graph API for the profile and
/// friends). So login stays classic (`tracking: .enabled`), the ATT prompt
/// comes first with an accurate `NSUserTrackingUsageDescription`, and the
/// privacy manifest declares tracking with the Facebook SDK's tracking domain.
/// The app sends Facebook no app events and no advertiser ID (`AppDelegate`,
/// Info.plist), whatever the person answers.
@MainActor
final class FacebookSignIn {
    enum Result: Sendable, Equatable {
        /// From the SDK.
        case accessToken(String)
        /// Retained for compatibility.
        case code(String, redirectURI: String)

        var accessToken: String? {
            switch self {
            case let .accessToken(token): token
            case .code: nil
            }
        }
    }

    typealias TrackingStatusProvider = @MainActor () -> ATTrackingManager.AuthorizationStatus
    typealias TrackingRequest = @MainActor () async -> ATTrackingManager.AuthorizationStatus
    typealias LoginAction = @MainActor (LoginConfiguration) async throws -> Result

    private let appID: String
    private let configID: String?
    private let permissions: [String]
    private let loginManager: LoginManager
    private let trackingStatus: TrackingStatusProvider
    private let requestTracking: TrackingRequest
    private let loginAction: LoginAction?

    init(
        appID: String,
        configID: String? = nil,
        permissions: [String],
        loginManager: LoginManager = LoginManager(),
        trackingStatus: TrackingStatusProvider? = nil,
        requestTracking: TrackingRequest? = nil,
        loginAction: LoginAction? = nil
    ) {
        self.appID = appID
        self.configID = configID
        self.permissions = permissions
        self.loginManager = loginManager
        self.trackingStatus = trackingStatus ?? { ATTrackingManager.trackingAuthorizationStatus }
        self.requestTracking = requestTracking ?? {
            await ATTrackingManager.requestTrackingAuthorization()
        }
        self.loginAction = loginAction
    }

    var redirectURI: String { "fb\(appID)://authorize/" }

    var canUseSDK: Bool { true }

    /// Requests ATT tracking authorization if not already determined, then
    /// starts the Facebook SDK login flow.
    func authorize() async throws -> Result {
        if trackingStatus() == .notDetermined {
            _ = await requestTracking()
        }

        return try await authorizeWithSDK()
    }

    /// Compatibility no-op; all URL handling is performed directly by the
    /// Facebook SDK's `ApplicationDelegate`.
    @discardableResult
    static func handle(_ url: URL) -> Bool { false }

    // MARK: - SDK

    private func authorizeWithSDK() async throws -> Result {
        guard let configuration = LoginConfiguration(permissions: permissions, tracking: .enabled, messengerPageId: nil) else {
            throw SessionError.configurationUnavailable
        }

        if let loginAction {
            return try await loginAction(configuration)
        }

        return try await withCheckedThrowingContinuation { continuation in
            loginManager.logIn(configuration: configuration) { result in
                switch result {
                case let .success(_, _, token):
                    if let token = token?.tokenString, !token.isEmpty {
                        continuation.resume(returning: .accessToken(token))
                    } else {
                        continuation.resume(throwing: SessionError.missingFacebookToken)
                    }
                case .cancelled:
                    continuation.resume(throwing: SessionError.cancelled)
                case let .failed(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
