//
//  AppleSignInHelper.swift
//  HotMessUITests
//

import XCTest

enum AppleTestCredentials {
    static let defaultEmail = "tom_test_user@hotmess.social"
    static let defaultPassword = "I_am_1_test_user"

    static var email: String {
        let env = ProcessInfo.processInfo.environment["HOTMESS_UITEST_APPLE_EMAIL"]
        return (env != nil && !env!.isEmpty) ? env! : defaultEmail
    }

    static var password: String {
        let env = ProcessInfo.processInfo.environment["HOTMESS_UITEST_APPLE_PASSWORD"]
        return (env != nil && !env!.isEmpty) ? env! : defaultPassword
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

        // 1. Agree to the terms (and confirm 18+) before tapping Sign in with Apple
        app.agreeToLoginTerms()

        // 2. Locate and tap "Sign in with Apple"
        let appleButton = app.buttons["login.apple"]
        XCTAssertTrue(appleButton.waitForExistence(timeout: 10), "Sign in with Apple button (login.apple) not found")
        appleButton.tap()
        sleep(dwell)

        // 3. Drive the system Apple authorization flow until Hot Mess tabs appear
        let deadline = Date().addingTimeInterval(timeout)
        var typedEmail = false
        var typedPassword = false

        while Date() < deadline {
            if tabs.exists {
                return true
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

            // Look for confirmation / Continue / Share My Email / Sign In buttons in system sheets
            let buttonPredicate = NSPredicate(
                format: "label BEGINSWITH[c] 'Continue' OR label ==[c] 'Sign In' OR label ==[c] 'Done' OR label ==[c] 'Share My Email' OR label ==[c] 'OK'"
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

extension XCUIApplication {
    /// Points the app at the API the test runner started (`HOTMESS_API_URL`, passed to xcodebuild as
    /// `TEST_RUNNER_HOTMESS_API_URL`), if there is one; otherwise the build's own API.
    @MainActor
    func useRunnerAPI() {
        if let api = ProcessInfo.processInfo.environment["HOTMESS_API_URL"], !api.isEmpty {
            launchEnvironment["HOTMESS_API_URL"] = api
        }
    }

    /// Ticks the login screen's "I agree to the Terms of Use" and, until the device has a confirmation,
    /// "I confirm I am 18 or older", so a sign-in button starts signing in rather than opening the terms.
    @MainActor
    func agreeToLoginTerms() {
        let eulaCheckbox = buttons["login.eulaCheckbox"]
        if eulaCheckbox.waitForExistence(timeout: 3) && eulaCheckbox.isHittable {
            let isChecked = (eulaCheckbox.value as? String == "1") || (eulaCheckbox.value as? String == "checked")
            if !isChecked {
                eulaCheckbox.tap()
                sleep(1)
            }
        }

        // The 18+ confirmation shows until the device has one.
        let ageCheckbox = buttons["login.ageCheckbox"]
        if ageCheckbox.waitForExistence(timeout: 2) && ageCheckbox.isHittable && ageCheckbox.value as? String != "1" {
            ageCheckbox.tap()
            sleep(1)
        }
    }
}
