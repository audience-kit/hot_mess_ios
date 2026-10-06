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
        sleep(2)
        snapshot("After tapping Continue with Facebook")

        // Walk whatever Facebook shows until Hot Mess is signed in or says why it isn't: iOS's
        // permission to use facebook.com, the Facebook app, or the web sheet's "Continue as …".
        let failure = app.alerts["Sign In Failed"]
        let tabs = app.descendants(matching: .any)["main.tabs"]
        var tapped = Set<String>()
        let deadline = Date().addingTimeInterval(120)

        while Date() < deadline {
            if tabs.exists {
                snapshot("Signed in")
                return
            }
            if failure.exists {
                snapshot("Sign-in failed")
                XCTFail("Sign in failed: \(failure.label)")
                return
            }
            for container in [facebook, app] where container.state == .runningForeground {
                try failOnFacebookError(in: container)
            }
            if let (name, button) = nextContinueButton(app), !tapped.contains(name) || name == "sheet" {
                snapshot("Before tapping \(name) Continue")
                button.tap()
                tapped.insert(name)
                sleep(2)
                continue
            }
            sleep(1)
        }

        snapshot("Timed out")
        try continueInWebSheet(app)
        XCTAssertTrue(tabs.waitForExistence(timeout: 30), "Hot Mess didn't reach its tabs after Facebook")
    }

    /// The next "Continue" to tap: iOS's permission alert, the Facebook app, or Facebook's page in the
    /// web sheet, which runs in SafariViewService.
    @MainActor
    private func nextContinueButton(_ app: XCUIApplication) -> (String, XCUIElement)? {
        let continuing = NSPredicate(format: "label BEGINSWITH[c] 'Continue'")
        var candidates: [(String, XCUIElement)] = [
            ("permission", springboard.alerts.buttons["Continue"]),
            ("permission", app.alerts.buttons["Continue"]),
            ("sheet", app.webViews.buttons.matching(continuing).firstMatch),
        ]
        // Asking an app in the background for its elements fails the test, so only ask the one in front.
        if facebook.state == .runningForeground {
            candidates.append(("Facebook app", facebook.buttons.matching(continuing).firstMatch))
        }
        return candidates.first { $0.1.exists && $0.1.isHittable }
    }

    @MainActor
    private func continueInWebSheet(_ app: XCUIApplication) throws {
        let candidates = [app.webViews.firstMatch]
        let deadline = Date().addingTimeInterval(20)
        var found: XCUIElement?
        while found == nil, Date() < deadline {
            found = candidates.first { $0.exists }
            if found == nil { sleep(1) }
        }
        snapshot("Waiting for Facebook's login page")
        let page = try XCTUnwrap(found, "Facebook's login page didn't open")
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

    /// Facebook shows its refusals ("Something went wrong", "Given URL is not allowed by the Application
    /// configuration", "App not active") as page text.
    @MainActor
    private func failOnFacebookError(in container: XCUIApplication) throws {
        let error = container.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'went wrong' OR label CONTAINS[c] 'not allowed by the Application configuration' OR label CONTAINS[c] 'app not active'")).firstMatch
        guard error.exists else { return }

        snapshot("Facebook error")
        // The page's text is in the screenshot; its elements can vanish while it reloads.
        XCTFail("Facebook refused the login: \(error.label)")
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
