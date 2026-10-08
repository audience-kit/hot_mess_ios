//
//  FacebookWebLogin.swift
//  HotMess
//

import AuthenticationServices
import Foundation
import UIKit

/// Signs in through Facebook's OAuth dialog in a web authentication sheet,
/// and returns the code for the API to exchange.
///
/// The Facebook SDK can't do this for a Business-type Facebook app. Such an
/// app only accepts a dialog opened with its Login for Business `config_id`,
/// and when tracking isn't allowed the SDK switches to Limited Login, which
/// returns no access token. The redirect goes to `fb<app ID>://authorize/`, which
/// has to be listed in the app's Valid OAuth Redirect URIs.
@MainActor
final class FacebookWebLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct Result: Sendable {
        let code: String
        let redirectURI: String
    }

    private let appID: String
    private let configID: String?
    private let permissions: [String]
    private var session: ASWebAuthenticationSession?

    /// - Parameters:
    ///   - configID: the Login for Business configuration. Without one the
    ///     dialog asks for `permissions` instead, as a Consumer app expects.
    init(appID: String, configID: String?, permissions: [String]) {
        self.appID = appID
        self.configID = configID
        self.permissions = permissions
    }

    var redirectURI: String { "fb\(appID)://authorize/" }

    /// The dialog URL. `state` ties the redirect to this request.
    func dialogURL(state: String) -> URL {
        var components = URLComponents(string: "https://www.facebook.com/v26.0/dialog/oauth")!
        var items = [
            URLQueryItem(name: "client_id", value: appID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
        ]
        if let configID {
            items.append(URLQueryItem(name: "config_id", value: configID))
        } else {
            items.append(URLQueryItem(name: "scope", value: permissions.joined(separator: ",")))
        }
        components.queryItems = items
        return components.url!
    }

    func authorize() async throws -> Result {
        let state = UUID().uuidString
        let url = dialogURL(state: state)

        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "fb\(appID)") { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: SessionError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? SessionError.missingFacebookToken)
                }
            }
            // Share Safari's cookies, so someone already signed in to Facebook there just continues.
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            self.session = session

            if !session.start() {
                continuation.resume(throwing: SessionError.configurationUnavailable)
            }
        }
        session = nil

        return try Self.result(from: callback, state: state, redirectURI: redirectURI)
    }

    /// Reads the code from the redirect, or the reason Facebook gave instead.
    nonisolated static func result(from callback: URL, state: String, redirectURI: String) throws -> Result {
        // Facebook sends the parameters in the query, and sometimes the fragment too.
        var items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let fragment = callback.fragment {
            items += URLComponents(string: "?" + fragment)?.queryItems ?? []
        }
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let reason = value("error_description") ?? value("error_message") ?? value("error") {
            if value("error_reason") == "user_denied" { throw SessionError.cancelled }
            throw SessionError.facebook(reason.replacingOccurrences(of: "+", with: " "))
        }
        guard value("state") == state else { throw SessionError.facebook("The login response didn't match the request.") }
        guard let code = value("code"), !code.isEmpty else { throw SessionError.missingFacebookToken }

        return Result(code: code, redirectURI: redirectURI)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
