//
//  FacebookSignInTests.swift
//  HotMessTests
//

import AppTrackingTransparency
import FacebookLogin
import Foundation
import Testing

@testable import HotMess

@Suite("Facebook sign-in")
@MainActor
struct FacebookSignInTests {
    @Test("Requests ATT tracking permission before starting login when not determined")
    func requestsTrackingWhenNotDetermined() async throws {
        var requestedTracking = false
        var loginActionCalled = false

        let login = FacebookSignIn(
            appID: "1",
            permissions: ["public_profile"],
            trackingStatus: { .notDetermined },
            requestTracking: {
                requestedTracking = true
                return .authorized
            },
            loginAction: { configuration in
                #expect(requestedTracking, "ATT tracking must be requested before starting login")
                loginActionCalled = true
                return .accessToken("mock-token")
            }
        )

        let result = try await login.authorize()
        #expect(requestedTracking)
        #expect(loginActionCalled)
        #expect(result == .accessToken("mock-token"))
    }

    @Test("Skips requesting ATT when already authorized")
    func skipsTrackingWhenAlreadyAuthorized() async throws {
        var requestedTracking = false
        var loginActionCalled = false

        let login = FacebookSignIn(
            appID: "1",
            permissions: ["public_profile"],
            trackingStatus: { .authorized },
            requestTracking: {
                requestedTracking = true
                return .authorized
            },
            loginAction: { configuration in
                loginActionCalled = true
                return .accessToken("mock-token")
            }
        )

        let result = try await login.authorize()
        #expect(!requestedTracking, "Should not request tracking if already authorized")
        #expect(loginActionCalled)
        #expect(result == .accessToken("mock-token"))
    }

    @Test("Skips requesting ATT when already denied")
    func skipsTrackingWhenAlreadyDenied() async throws {
        var requestedTracking = false
        var loginActionCalled = false

        let login = FacebookSignIn(
            appID: "1",
            permissions: ["public_profile"],
            trackingStatus: { .denied },
            requestTracking: {
                requestedTracking = true
                return .denied
            },
            loginAction: { configuration in
                loginActionCalled = true
                return .accessToken("mock-token")
            }
        )

        let result = try await login.authorize()
        #expect(!requestedTracking, "Should not prompt if already denied")
        #expect(loginActionCalled)
        #expect(result == .accessToken("mock-token"))
    }

    @Test("Propagates cancellation from login flow")
    func propagatesCancellation() async throws {
        let login = FacebookSignIn(
            appID: "1",
            permissions: ["public_profile"],
            trackingStatus: { .authorized },
            loginAction: { _ in
                throw SessionError.cancelled
            }
        )

        await #expect(throws: SessionError.self) {
            try await login.authorize()
        }
    }

    @Test("Propagates missing token error")
    func propagatesMissingToken() async throws {
        let login = FacebookSignIn(
            appID: "1",
            permissions: ["public_profile"],
            trackingStatus: { .authorized },
            loginAction: { _ in
                throw SessionError.missingFacebookToken
            }
        )

        await #expect(throws: SessionError.self) {
            try await login.authorize()
        }
    }

    @Test("canUseSDK is always true when using only the Facebook SDK")
    func canUseSDKIsTrue() {
        let login = FacebookSignIn(appID: "1", configID: nil, permissions: ["public_profile"])
        #expect(login.canUseSDK)
    }

    @Test("redirectURI is formatted with the Facebook App ID")
    func redirectURIFormat() {
        let login = FacebookSignIn(appID: "123456789", permissions: ["public_profile"])
        #expect(login.redirectURI == "fb123456789://authorize/")
    }
}
