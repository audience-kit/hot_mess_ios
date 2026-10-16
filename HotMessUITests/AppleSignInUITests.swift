import XCTest

/// Exercises Apple's real authorization sheet and the API's resulting app session.
@MainActor
final class AppleSignInUITests: XCTestCase {
    func testSignsInWithApple() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        let user = try XCTUnwrap(environment["APPLE_TEST_USER"], "APPLE_TEST_USER is required")
        let password = try XCTUnwrap(environment["APPLE_TEST_PASSWORD"], "APPLE_TEST_PASSWORD is required")
        XCTAssertFalse(user.isEmpty)
        XCTAssertFalse(password.isEmpty)

        let app = XCUIApplication()
        app.launchArguments = ["-HotMessUITestSignedOut", "-hasAgreedToEULA", "NO"]
        app.launch()
        let agreement = app.buttons["login.eulaCheckbox"]
        XCTAssertTrue(agreement.waitForExistence(timeout: 15))
        agreement.tap()
        let signIn = app.buttons["login.apple"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(120)
        var enteredUser = false
        var enteredPassword = false
        var confirmedAccount = false
        while Date() < deadline {
            if app.descendants(matching: .any)["main.tabs"].exists {
                XCTAssertTrue(enteredUser || confirmedAccount,
                              "Apple signed in without confirming the configured test account. Use an isolated test simulator.")
                return
            }
            if app.alerts["Sign In Failed"].exists {
                XCTFail("Apple authorization did not establish an app session; inspect the test API logs.")
                return
            }
            for container in [app, system] {
                let account = container.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", user)).firstMatch
                if account.exists { confirmedAccount = true }
                let verification = container.staticTexts.matching(NSPredicate(
                    format: "label CONTAINS[c] 'verification code' OR label CONTAINS[c] 'two-factor authentication'"
                )).firstMatch
                if verification.exists {
                    XCTFail("Apple requires interactive account verification. Complete it for the test account on this simulator and rerun.")
                    return
                }
                let email = container.textFields.matching(NSPredicate(
                    format: "label CONTAINS[c] 'email' OR label CONTAINS[c] 'Apple' OR placeholderValue CONTAINS[c] 'email' OR placeholderValue CONTAINS[c] 'Apple'"
                )).firstMatch
                if !enteredUser, email.exists, email.isHittable {
                    email.tap()
                    email.typeText(user)
                    enteredUser = true
                }
                let secret = container.secureTextFields.matching(NSPredicate(
                    format: "label CONTAINS[c] 'password' OR placeholderValue CONTAINS[c] 'password'"
                )).firstMatch
                if !enteredPassword, secret.exists, secret.isHittable {
                    secret.tap()
                    secret.typeText(password)
                    enteredPassword = true
                }
                let button = container.buttons.matching(NSPredicate(
                    format: "label IN %@", ["Continue", "Sign In", "Sign in", "Next", "Continue with Password", "Use Password"]
                )).allElementsBoundByIndex.first { $0.exists && $0.isHittable }
                if let button, enteredUser || confirmedAccount {
                    button.tap()
                    break
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        XCTFail("Apple sign-in timed out before the authenticated app tabs appeared. Check the simulator account, authorization sheet, and API connectivity.")
    }
}
