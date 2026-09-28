//
//  SessionStore.swift
//  HotMess
//

import FacebookCore
import FacebookLogin
import Foundation
import Observation
import os
import UIKit

enum AuthenticationState: Equatable, Sendable {
    /// Still working out whether there is a usable session.
    case restoring
    case signedOut
    case signingIn
    case signedIn
    case failed(String)
}

enum SessionError: Error, LocalizedError {
    case cancelled
    case configurationUnavailable
    case missingFacebookToken

    var errorDescription: String? {
        switch self {
        case .cancelled:
            String(localized: "Sign in was cancelled.")
        case .configurationUnavailable:
            String(localized: "Facebook login isn't configured for this build.")
        case .missingFacebookToken:
            String(localized: "Facebook didn't return an access token.")
        }
    }
}

/// Owns authentication: the Facebook handshake, the bearer token in the
/// keychain, and the signed-in user.
///
/// Replaces the `SessionService` grab-bag of static methods plus four
/// `NotificationCenter` names with one observable object the UI can read.
@MainActor
@Observable
final class SessionStore {
    /// Permissions requested at sign-in.
    ///
    /// The original also asked for `user_events` and `user_likes`; Facebook has
    /// since removed both from the Graph API. Anything here beyond
    /// `public_profile` and `email` needs App Review on the Facebook app.
    static let requestedPermissions = ["public_profile", "email", "user_friends"]

    private(set) var state: AuthenticationState = .restoring
    private(set) var user: User?
    private(set) var versionRequirement: VersionInfo?

    private let api: HotMessAPI
    private let keychain: Keychain
    private let configuration: AppConfiguration
    private let loginManager = LoginManager()
    private var unauthorizedMonitor: Task<Void, Never>?

    init(api: HotMessAPI, configuration: AppConfiguration, keychain: Keychain = .shared) {
        self.api = api
        self.configuration = configuration
        self.keychain = keychain

        watchForRejectedCredentials()
    }

    var isSignedIn: Bool { state == .signedIn }

    var userID: UUID? { user?.id }

    /// The bearer token. Needed outside the HTTP layer in exactly one place:
    /// the chat websocket handshake.
    var bearerToken: String? { keychain.string(for: .sessionToken) }

    /// True when the API refuses to serve this build any more.
    var requiresUpdate: Bool {
        guard let versionRequirement else { return false }
        return configuration.build < versionRequirement.minimumBuild
    }

    // MARK: - Lifecycle

    /// Called once at launch: checks the minimum supported build, then tries to
    /// turn an existing Facebook token into an API session.
    func start() async {
        await refreshVersionRequirement()

        guard !requiresUpdate else {
            state = .signedOut
            return
        }

        await restoreSession()
    }

    func restoreSession() async {
        // A stored bearer token is enough on its own; only fall back to the
        // Facebook handshake when there isn't one.
        if keychain.string(for: .sessionToken) != nil {
            do {
                user = try await api.me()
                state = .signedIn
                return
            } catch APIError.unauthorized {
                keychain.removeValue(for: .sessionToken)
            } catch {
                // A network blip shouldn't sign the user out; keep the token
                // and let the screens show their own error state.
                state = .signedIn
                return
            }
        }

        guard let facebookToken = AccessToken.current?.tokenString else {
            state = .signedOut
            return
        }

        await exchange(facebookToken: facebookToken)
    }

    // MARK: - Sign in and out

    func signIn() async {
        state = .signingIn

        do {
            let facebookToken = try await requestFacebookToken()
            await exchange(facebookToken: facebookToken)
        } catch SessionError.cancelled {
            state = .signedOut
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func signOut() {
        keychain.removeValue(for: .sessionToken)
        loginManager.logOut()
        AccessToken.current = nil
        user = nil
        state = .signedOut
    }

    /// Wipes cached defaults and images, leaving credentials alone.
    func resetLocalData() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
    }

    func registerForPushNotifications(deviceToken: Data) async {
        let identifier = DeviceInfo.vendorIdentifier

        do {
            try await api.registerForPush(deviceToken: deviceToken, vendorIdentifier: identifier)
        } catch {
            // Push registration is best-effort; a failure must not block the UI.
            Log.session.error("Push registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshUser() async {
        guard isSignedIn else { return }
        user = try? await api.me()
    }

    // MARK: - Private

    private func exchange(facebookToken: String) async {
        let device = DeviceInfo.description(for: configuration)

        do {
            let session = try await api.signIn(facebookToken: facebookToken, device: device)
            keychain.set(session.token, for: .sessionToken)
            user = session.user
            state = .signedIn

            if session.user == nil {
                user = try? await api.me()
            }

            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            keychain.removeValue(for: .sessionToken)
            state = .failed(error.localizedDescription)
        }
    }

    private func refreshVersionRequirement() async {
        let device = DeviceInfo.description(for: configuration)
        versionRequirement = try? await api.serviceManifest(device: device)
    }

    private func requestFacebookToken() async throws -> String {
        guard let loginConfiguration = LoginConfiguration(
            permissions: Self.requestedPermissions,
            tracking: .enabled
        ) else {
            throw SessionError.configurationUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            loginManager.logIn(viewController: nil, configuration: loginConfiguration) { result in
                switch result {
                case let .success(_, _, token):
                    if let tokenString = token?.tokenString {
                        continuation.resume(returning: tokenString)
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

    /// Signs out as soon as the API tells us the token is no longer good,
    /// wherever in the app that happened.
    private func watchForRejectedCredentials() {
        let events = api.client.unauthorizedEvents

        unauthorizedMonitor = Task { [weak self] in
            for await _ in events {
                guard let self else { return }
                self.handleRejectedCredentials()
            }
        }
    }

    private func handleRejectedCredentials() {
        guard state != .signedOut else { return }

        keychain.removeValue(for: .sessionToken)
        user = nil
        state = .signedOut
    }
}
