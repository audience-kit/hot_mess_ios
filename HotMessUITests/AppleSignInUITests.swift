import XCTest

/// Exercises Apple's real authorization sheet and the API's resulting app session, with the sandbox Apple Account
/// from `HOTMESS_UITEST_APPLE_EMAIL` and `HOTMESS_UITEST_APPLE_PASSWORD` (AppleTestCredentials).
@MainActor
final class AppleSignInUITests: XCTestCase {
    func testSignsInWithApple() throws {
        continueAfterFailure = false
        try XCTSkipUnless(XCUIApplication.hasRunnerAPI,
                          "Signs in for real against scripts/ui-tests.py's API (mise run hotmess-ios:apple-test)")
        SimulatorAppleAccount.ensureSignedIn(email: AppleTestCredentials.email, password: AppleTestCredentials.password)

        let app = XCUIApplication()
        app.launchArguments = ["-HotMessUITestSignedOut", "-hasAgreedToEULA", "NO"]
        app.useRunnerAPI()
        app.launch()
        XCTAssertTrue(app.buttons["login.eulaCheckbox"].waitForExistence(timeout: 15))

        XCTAssertTrue(try AppleSignInHelper(app: app).signIn(timeout: 120),
                      "Apple sign-in didn't reach the app's tabs. Check the simulator account, the sheet, and the API.")
    }
}
