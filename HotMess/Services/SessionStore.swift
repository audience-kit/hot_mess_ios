//
//  SessionStore.swift
//  HotMess
//

import AudienceKit
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
    case facebook(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            String(localized: "Sign in was cancelled.")
        case .configurationUnavailable:
            String(localized: "Facebook login isn't configured for this build.")
        case .missingFacebookToken:
            String(localized: "Facebook didn't return an access token.")
        case let .facebook(reason):
            reason
        }
    }
}

/// Owns authentication: the Facebook handshake and the signed-in user.
///
/// The app runs Facebook Login; the AudienceKit SDK exchanges the Facebook
/// token for a session, keeps it in the keychain, and reports when the API
/// ends it (sign-out elsewhere, Facebook deauthorization).
@MainActor
@Observable
final class SessionStore {
    /// Permissions requested at sign-in, on the Hot Mess Consumer app.
    ///
    /// `user_friends` shows friends who also use the app at the same venue, and
    /// needs App Review on the Facebook app; `public_profile` and `email` don't.
    static let requestedPermissions = ["public_profile", "email", "user_friends"]

    /// Where the session token lives. Same service and account as the app's
    /// previous keychain wrapper, so existing installs stay signed in.
    static let tokenStore = KeychainTokenStore(service: "social.hotmess.account", account: "token")

    private(set) var state: AuthenticationState = .restoring
    private(set) var user: User?
    private(set) var versionRequirement: VersionInfo?

    private let api: HotMessAPI
    private let audienceKit: AudienceKitClient
    private let brand: BrandStore
    private let configuration: AppConfiguration
    private let loginManager = LoginManager()
    private var sessionMonitor: Task<Void, Never>?

    init(api: HotMessAPI, audienceKit: AudienceKitClient, brand: BrandStore, configuration: AppConfiguration) {
        self.api = api
        self.audienceKit = audienceKit
        self.brand = brand
        self.configuration = configuration

        watchForEndedSessions()
    }

    var isSignedIn: Bool { state == .signedIn }

    var userID: UUID? { user?.id }

    /// The session token. Needed outside the SDK in exactly one place: the
    /// chat websocket handshake.
    var bearerToken: String? { try? Self.tokenStore.loadToken() }

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
        // A stored session is enough on its own; only fall back to the
        // Facebook handshake when there isn't one.
        if await audienceKit.isSignedIn {
            do {
                user = try await currentUser()
                state = .signedIn
                return
            } catch AudienceKitError.unauthorized {
                // The SDK has already dropped the token.
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
            let login = try await facebookWebLogin()
            let result = try await login.authorize()
            await exchange { device in
                try await self.audienceKit.signIn(facebookCode: result.code, redirectURI: result.redirectURI,
                                                  device: device)
            }
        } catch SessionError.cancelled {
            Log.session.info("Facebook sign-in cancelled")
            state = .signedOut
        } catch {
            Log.session.error("Facebook sign-in failed: \(String(describing: error), privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    func signOut() {
        loginManager.logOut()
        AccessToken.current = nil
        user = nil
        state = .signedOut

        Task { await audienceKit.signOut() }
    }

    /// Wipes cached defaults and images, leaving credentials alone.
    func resetLocalData() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
    }

    func registerForPushNotifications(deviceToken: Data) async {
        do {
            try await api.registerForPush(
                deviceToken: deviceToken,
                appID: Bundle.main.bundleIdentifier,
                sandbox: configuration.isPushSandbox
            )
        } catch {
            // Push registration is best-effort; a failure must not block the UI.
            Log.session.error("Push registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshUser() async {
        guard isSignedIn else { return }
        if let refreshed = try? await currentUser() { user = refreshed }
    }

    // MARK: - Private

    /// The signed-in user, from the audience's GraphQL `me`.
    private func currentUser() async throws -> User? {
        guard let me = try await audienceKit.me() else { return nil }
        return User(me)
    }

    private func exchange(facebookToken: String) async {
        await exchange { device in
            try await self.audienceKit.signIn(facebookAccessToken: facebookToken, device: device)
        }
    }

    private func exchange(_ signIn: (DeviceDescription) async throws -> SignInResult) async {
        let device = DeviceInfo.description(for: configuration)

        do {
            let session = try await signIn(device)
            user = User(id: session.user.id, name: session.user.name)
            state = .signedIn

            if user == nil {
                user = try? await currentUser()
            }

            await PushNotifications.requestAuthorizationAndRegister()
        } catch {
            Log.session.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }

    private func refreshVersionRequirement() async {
        let device = DeviceInfo.description(for: configuration)
        versionRequirement = try? await api.serviceManifest(device: device)
    }

    /// Facebook's login dialog for this build's Facebook app. A Business-type
    /// app needs the Login for Business configuration from the audience's
    /// branding, so branding is loaded first when it hasn't arrived yet. The
    /// configuration is only used when it belongs to the same app.
    private func facebookWebLogin() async throws -> FacebookWebLogin {
        guard let appID = configuration.facebookAppID, !appID.isEmpty else {
            throw SessionError.configurationUnavailable
        }
        if brand.branding == nil { await brand.load() }

        let branding = brand.branding
        let configID = branding?.facebookAppID == appID ? branding?.facebookLoginConfigID : nil
        return FacebookWebLogin(appID: appID, configID: configID, permissions: Self.requestedPermissions)
    }

    /// Signs out as soon as the API ends the session, wherever in the app the
    /// rejected call was made.
    private func watchForEndedSessions() {
        let events = audienceKit.sessionEvents

        sessionMonitor = Task { [weak self] in
            for await event in events where event == .sessionEnded {
                guard let self else { return }
                self.handleEndedSession()
            }
        }
    }

    private func handleEndedSession() {
        guard state != .signedOut else { return }

        user = nil
        state = .signedOut
    }
}
