//
//  AppleSignInHelper.swift
//  HotMessScreenshots
//

import XCTest

enum AppleTestCredentials {
    static let defaultEmail = "tom_test_me@hotmess.social"
    static let defaultPassword = "I_am_1_test_user"

    /// `HOTMESS_UITEST_APPLE_*`, else the root .env's `APPLE_TEST_USER`/`APPLE_TEST_PASSWORD`, else the defaults.
    static var email: String {
        value("HOTMESS_UITEST_APPLE_EMAIL") ?? value("APPLE_TEST_USER") ?? defaultEmail
    }

    static var password: String {
        value("HOTMESS_UITEST_APPLE_PASSWORD") ?? value("APPLE_TEST_PASSWORD") ?? defaultPassword
    }

    private static func value(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }
}

@MainActor
final class AppleSignInHelper {
    private let app: XCUIApplication
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let authKit = XCUIApplication(bundleIdentifier: "com.apple.AuthKitUIService")
    private let dwell: UInt32

    init(app: XCUIApplication, dwell: UInt32 = 2) {
        self.app = app
        self.dwell = dwell
    }

    /// Complete Sign in with Apple automation using sandbox credentials.
    /// Handles EULA agreement, invokes the Sign in with Apple button,
    /// fills in the sandbox Apple ID email and password in the system sheets if prompted,
    /// approves the scopes (Share My Email / Continue), and waits for `main.tabs`.
    @discardableResult
    func signIn(
        email: String = AppleTestCredentials.email,
        password: String = AppleTestCredentials.password,
        timeout: TimeInterval = 90
    ) throws -> Bool {
        let tabs = app.descendants(matching: .any)["main.tabs"]
        if tabs.exists {
            return true
        }

        // 1. Ensure EULA checkbox is checked prior to tapping Sign in with Apple
        let eulaCheckbox = app.buttons["login.eulaCheckbox"]
        if eulaCheckbox.waitForExistence(timeout: 3) && eulaCheckbox.isHittable {
            let isChecked = (eulaCheckbox.value as? String == "1") || (eulaCheckbox.value as? String == "checked")
            if !isChecked {
                eulaCheckbox.tap()
                sleep(1)
            }
        }

        // The 18+ confirmation shows until the device has one.
        let ageCheckbox = app.buttons["login.ageCheckbox"]
        if ageCheckbox.waitForExistence(timeout: 2) && ageCheckbox.isHittable && ageCheckbox.value as? String != "1" {
            ageCheckbox.tap()
            sleep(1)
        }

        // 2. Locate and tap "Sign in with Apple"
        let appleButton = app.buttons["login.apple"]
        XCTAssertTrue(appleButton.waitForExistence(timeout: 10), "Sign in with Apple button (login.apple) not found")
        appleButton.tap()
        sleep(dwell)

        // 3. Drive the system Apple authorization flow until Hot Mess tabs appear
        let deadline = Date().addingTimeInterval(timeout)
        var typedEmail = false
        var typedPassword = false
        var choseEmail = false

        while Date() < deadline {
            if tabs.exists {
                return true
            }

            // With no Apple Account on the simulator, iOS sends the person to Settings instead of showing the sheet.
            if springboard.alerts["Sign in to your Apple Account"].exists {
                XCTFail("The simulator isn't signed in to an Apple Account. Sign it in to \(email) in Settings and rerun.")
                return false
            }
            if app.alerts["Sign In Failed"].exists {
                let msg = app.alerts.firstMatch.label
                XCTFail("Sign in with Apple failed: \(msg)")
                return false
            }

            // Check system alert dialogs (e.g. "Sign in to your Apple Account" on SpringBoard)
            if springboard.alerts.firstMatch.exists {
                let alert = springboard.alerts.firstMatch
                if !typedEmail && alert.textFields.firstMatch.exists && alert.textFields.firstMatch.isHittable {
                    alert.textFields.firstMatch.tap()
                    alert.textFields.firstMatch.typeText(email + "\n")
                    typedEmail = true
                    sleep(dwell)
                    continue
                }
                if !typedPassword && alert.secureTextFields.firstMatch.exists && alert.secureTextFields.firstMatch.isHittable {
                    alert.secureTextFields.firstMatch.tap()
                    alert.secureTextFields.firstMatch.typeText(password + "\n")
                    typedPassword = true
                    sleep(dwell)
                    continue
                }
                let alertAction = alert.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH[c] 'Continue' OR label ==[c] 'Sign In' OR label ==[c] 'Allow' OR label ==[c] 'OK'")
                ).firstMatch
                if alertAction.exists && alertAction.isHittable {
                    alertAction.tap()
                    sleep(dwell)
                    continue
                }
            }

            // Only inspect system AuthKit and SpringBoard containers for Apple dialog controls
            // (Do NOT include 'app' here so we never accidentally tap "Continue with Facebook")
            let systemContainers = [authKit, springboard]

            // Look for Apple ID / Email text field if not pre-filled
            if !typedEmail {
                for container in systemContainers where container.state == .runningForeground || container.state == .unknown {
                    let emailPredicate = NSPredicate(
                        format: "placeholderValue CONTAINS[c] 'Apple ID' OR placeholderValue CONTAINS[c] 'Email' OR label CONTAINS[c] 'Apple ID' OR label CONTAINS[c] 'Email' OR identifier == 'appleIdField'"
                    )
                    let emailField = container.textFields.matching(emailPredicate).firstMatch
                    if emailField.exists && emailField.isHittable {
                        emailField.tap()
                        emailField.typeText(email + "\n")
                        typedEmail = true
                        sleep(dwell)
                        break
                    }
                }
            }

            // Look for Password secure text field
            if !typedPassword {
                for container in systemContainers where container.state == .runningForeground || container.state == .unknown {
                    let passField = container.secureTextFields.firstMatch
                    if passField.exists && passField.isHittable {
                        passField.tap()
                        passField.typeText(password + "\n")
                        typedPassword = true
                        sleep(dwell)
                        break
                    }
                }
            }

            // A new account's sheet leaves Share My Email and Hide My Email unchosen, and Continue disabled until
            // one is. The option is a row whose label also holds the address, so match its start in any container.
            // The dimmed Continue still reports isEnabled, so choose Share My Email once rather than test the button.
            if !choseEmail, let shareEmail = [authKit, springboard, app].lazy
                .map({ $0.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH[c] 'Share My Email'")).firstMatch })
                .first(where: { $0.exists }) {
                shareEmail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                choseEmail = true
                sleep(1)
                continue
            }

            // Look for confirmation / Continue / Sign In buttons in system sheets
            let buttonPredicate = NSPredicate(
                format: "label BEGINSWITH[c] 'Continue' OR label ==[c] 'Sign In' OR label ==[c] 'Done' OR label ==[c] 'OK'"
            )
            for container in systemContainers where container.state == .runningForeground || container.state == .unknown {
                let actionButton = container.buttons.matching(buttonPredicate).firstMatch
                if actionButton.exists && actionButton.isHittable {
                    actionButton.tap()
                    sleep(dwell)
                    break
                }
            }

            sleep(1)
        }

        XCTAssertTrue(tabs.waitForExistence(timeout: 5), "Hot Mess tabs did not appear within timeout after Apple Sign-In")
        return tabs.exists
    }
}
