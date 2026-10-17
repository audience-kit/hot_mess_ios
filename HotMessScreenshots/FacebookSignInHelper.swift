//
//  FacebookSignInHelper.swift
//  HotMessScreenshots
//

import XCTest

/// Signs in with Facebook on a simulator whose Facebook web session is already signed in, such as a clone of the
/// "Hot Mess Store - Facebook session snapshot" simulators (scripts/app-review/README.md), or logs in to
/// Facebook's web form as the test user when it isn't. Agrees to the terms, taps Continue with Facebook, then
/// taps through iOS's prompts and Facebook's "Continue as" dialog until Hot Mess shows its tabs.
@MainActor
final class FacebookSignInHelper {
    private let app: XCUIApplication
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let facebook = XCUIApplication(bundleIdentifier: "com.facebook.Facebook")
    private let dwell: UInt32

    init(app: XCUIApplication, dwell: UInt32 = 2) {
        self.app = app
        self.dwell = dwell
    }

    @discardableResult
    func signIn(timeout: TimeInterval = 120) -> Bool {
        let tabs = app.descendants(matching: .any)["main.tabs"]
        if tabs.exists {
            return true
        }

        // Agree to the terms (and confirm 18+) before tapping Continue with Facebook.
        let eulaCheckbox = app.buttons["login.eulaCheckbox"]
        if eulaCheckbox.waitForExistence(timeout: 3) && eulaCheckbox.isHittable && eulaCheckbox.value as? String != "1" {
            eulaCheckbox.tap()
            sleep(1)
        }
        let ageCheckbox = app.buttons["login.ageCheckbox"]
        if ageCheckbox.waitForExistence(timeout: 2) && ageCheckbox.isHittable && ageCheckbox.value as? String != "1" {
            ageCheckbox.tap()
            sleep(1)
        }

        let login = app.buttons["login.facebook"]
        XCTAssertTrue(login.waitForExistence(timeout: 10), "Continue with Facebook (login.facebook) not found")
        login.tap()
        sleep(dwell)

        let continuing = NSPredicate(format: "label BEGINSWITH[c] 'Continue' OR label ==[c] 'Save' OR label ==[c] 'Got it'")
        let deadline = Date().addingTimeInterval(timeout)
        while !tabs.exists, Date() < deadline {
            if app.alerts["Sign In Failed"].exists {
                XCTFail("Facebook sign-in failed: \(app.alerts.firstMatch.label)")
                return false
            }
            // Facebook asks for a password when the simulator has no Facebook session: log in as the test user.
            if app.webViews.secureTextFields.firstMatch.exists {
                guard logIn() else { return false }
                continue
            }
            // After the password iOS offers to save it and Facebook offers to remember the login; decline both.
            let notNow = [springboard, app].lazy
                .map { $0.buttons.matching(NSPredicate(format: "label ==[c] 'Not now'")).firstMatch }
                .first { $0.exists && $0.isHittable }
            if let notNow {
                notNow.tap()
                sleep(2)
                continue
            }
            let permission = [
                springboard.alerts.buttons["Continue"],
                app.alerts.buttons["Continue"],
            ].first { $0.exists && $0.isHittable }
            if let permission {
                sleep(1)
                permission.tap()
                sleep(2)
                continue
            }
            var buttons = [app.webViews.buttons.matching(continuing).firstMatch]
            if facebook.state == .runningForeground {
                buttons.append(facebook.buttons.matching(continuing).firstMatch)
            }
            if let button = buttons.first(where: { $0.exists && $0.isHittable }) {
                // Hold Facebook's dialog on screen so the recording shows what it asks for.
                sleep(dwell)
                button.tap()
                sleep(3)
                continue
            }
            sleep(1)
        }
        XCTAssertTrue(tabs.waitForExistence(timeout: 5), "Hot Mess tabs did not appear after Facebook sign-in")
        return tabs.exists
    }

    /// Fills Facebook's web login with HOTMESS_UITEST_FB_EMAIL and HOTMESS_UITEST_FB_PASSWORD, which
    /// scripts/test-credentials.py passes to the test runner from FACEBOOK_TEST_EMAIL and FACEBOOK_TEST_PASSWORD.
    private func logIn() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["HOTMESS_UITEST_FB_EMAIL"], !email.isEmpty,
              let password = environment["HOTMESS_UITEST_FB_PASSWORD"], !password.isEmpty else {
            XCTFail("Facebook asked for a password but HOTMESS_UITEST_FB_EMAIL and HOTMESS_UITEST_FB_PASSWORD aren't set. " +
                    "Run through scripts/test-credentials.py with FACEBOOK_TEST_EMAIL and FACEBOOK_TEST_PASSWORD in .env.")
            return false
        }
        let page = app.webViews.firstMatch
        let passwordField = page.secureTextFields.firstMatch
        // Facebook can remember the account and ask only for its password.
        let emailField = page.textFields.firstMatch
        if emailField.exists, (emailField.value as? String)?.contains("@") != true {
            focus(emailField)
            emailField.typeText(email)
            // The keyboard's arrival can swallow a tap on the next field, so tab to it too.
            emailField.typeText("\t")
        }
        focus(passwordField)
        passwordField.typeText(password + "\n")
        // Return doesn't always submit Facebook's mobile form.
        let logIn = page.buttons["Log in"]
        if logIn.waitForExistence(timeout: 2), logIn.isHittable { logIn.tap() }
        sleep(5)
        if page.secureTextFields.firstMatch.exists, page.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'incorrect' OR label CONTAINS[c] 'went wrong'")).firstMatch.exists {
            XCTFail("Facebook rejected the test user's login")
            return false
        }
        return true
    }

    /// Taps a web form field until it takes the keyboard. A tap that lands while the keyboard is
    /// still animating in after the previous field leaves focus where it was.
    private func focus(_ field: XCUIElement) {
        for attempt in 0..<5 {
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return }
            if attempt.isMultiple(of: 2) {
                field.tap()
            } else {
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let deadline = Date().addingTimeInterval(2)
            while Date() < deadline {
                if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return }
                usleep(200_000)
            }
        }
    }
}
