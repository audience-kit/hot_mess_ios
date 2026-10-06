//
//  FacebookSignInUITests.swift
//  HotMessUITests
//

import XCTest

/// Drives "Continue with Facebook" from a signed-out launch and records each
/// screen Facebook shows, so a failure says which side refused.
///
/// On a device with the Facebook app signed in, Facebook asks to continue as
/// that account and the test taps through. Elsewhere (the simulator, or no
/// Facebook app) login opens in a web sheet. The test only gets past that
/// sheet when HOTMESS_UITEST_FB_EMAIL and HOTMESS_UITEST_FB_PASSWORD hold a
/// Facebook test user, and is skipped otherwise.
@MainActor
final class FacebookSignInUITests: XCTestCase {
    private var facebook: XCUIApplication { XCUIApplication(bundleIdentifier: "com.facebook.Facebook") }
    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    override func setUp() async throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSignsInWithFacebook() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-HotMessUITestSignedOut"]
        app.launch()

        let button = app.buttons["login.facebook"]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "The login screen didn't appear")
        snapshot("Login screen")
        button.tap()

        // iOS asks before an app opens Facebook's login in a web sheet.
        let allow = springboard.buttons["Continue"]
        if allow.waitForExistence(timeout: 5) {
            snapshot("Permission to use facebook.com")
            allow.tap()
        }

        if facebook.wait(for: .runningForeground, timeout: 10) {
            try continueInFacebookApp()
        } else {
            try continueInWebSheet(app)
        }

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "Facebook didn't return to Hot Mess")

        let failure = app.alerts["Sign In Failed"]
        let tabs = app.descendants(matching: .any)["main.tabs"]
        if failure.waitForExistence(timeout: 20) {
            snapshot("Sign-in failed")
            XCTFail("Sign in failed: \(failure.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " "))")
        }
        XCTAssertTrue(tabs.waitForExistence(timeout: 20), "Hot Mess didn't reach its tabs after Facebook")
        snapshot("Signed in")
    }

    /// The Facebook app asks to continue as its signed-in account.
    @MainActor
    private func continueInFacebookApp() throws {
        sleep(3)
        snapshot("Facebook app")
        try failOnFacebookError(in: facebook)

        let proceed = facebook.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Continue'")).firstMatch
        XCTAssertTrue(proceed.waitForExistence(timeout: 15), "The Facebook app didn't offer to continue")
        proceed.tap()
    }

    /// Facebook's web login, in a sheet over Hot Mess.
    @MainActor
    private func continueInWebSheet(_ app: XCUIApplication) throws {
        let page = app.webViews.firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 20), "Facebook's login page didn't open")
        sleep(3)
        snapshot("Facebook login page")
        try failOnFacebookError(in: app)

        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["HOTMESS_UITEST_FB_EMAIL"], !email.isEmpty,
              let password = environment["HOTMESS_UITEST_FB_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("Set HOTMESS_UITEST_FB_EMAIL and HOTMESS_UITEST_FB_PASSWORD to a Facebook test user to sign in")
        }

        let emailField = page.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = page.secureTextFields.firstMatch
        passwordField.tap()
        passwordField.typeText(password + "\n")

        let proceed = page.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Continue'")).firstMatch
        if proceed.waitForExistence(timeout: 15) {
            snapshot("Facebook consent")
            proceed.tap()
        }
    }

    /// Facebook shows "Something went wrong" (and the reason beneath it) as page text.
    @MainActor
    private func failOnFacebookError(in container: XCUIApplication) throws {
        let error = container.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'went wrong'")).firstMatch
        guard error.exists else { return }

        let page = container.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
        XCTFail("Facebook refused the login: \(page.joined(separator: " | "))")
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
