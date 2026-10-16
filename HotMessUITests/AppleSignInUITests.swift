//
//  AppleSignInUITests.swift
//  HotMessUITests
//

import XCTest

/// Drives "Sign in with Apple" from a signed-out launch using the Sandbox Apple ID
/// email `tom_test_me@hotmess.social` and password `I_am_1_test_user`.
@MainActor
final class AppleSignInUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-HotMessUITestSignedOut", "-HotMessUseNextAPI"]
        app.launch()
    }

    func testSignsInWithApple() throws {
        let loginScreen = app.buttons["login.apple"]
        XCTAssertTrue(loginScreen.waitForExistence(timeout: 15), "The login screen with Apple Sign-In didn't appear")
        snapshot("01-login-screen")

        let helper = AppleSignInHelper(app: app)
        let signedIn = try helper.signIn()
        XCTAssertTrue(signedIn, "Failed to sign in with Apple sandbox account")
        snapshot("02-signed-in")

        let tabs = app.descendants(matching: .any)["main.tabs"]
        XCTAssertTrue(tabs.exists, "Main tabs not visible after Sign in with Apple")

        // Verify Me tab is accessible
        let meTab = app.tabBars.buttons["Me"]
        if meTab.waitForExistence(timeout: 5) {
            meTab.tap()
            sleep(2)
            snapshot("03-me-tab")
        }
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
