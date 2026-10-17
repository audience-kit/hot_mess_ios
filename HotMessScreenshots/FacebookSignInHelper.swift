//
//  FacebookSignInHelper.swift
//  HotMessScreenshots
//

import XCTest

/// Signs in with Facebook on a simulator whose Facebook web session is already signed in, such as a clone of the
/// "Hot Mess Store - Facebook session snapshot" simulators (scripts/app-review/README.md). Agrees to the terms,
/// taps Continue with Facebook, then taps through iOS's prompts and Facebook's "Continue as" dialog until
/// Hot Mess shows its tabs.
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
            // Facebook asking for a password means the simulator's Facebook session is gone.
            if app.webViews.secureTextFields.firstMatch.exists {
                XCTFail("Facebook isn't signed in on this simulator. Run on a clone of the Facebook session snapshot " +
                        "(scripts/app-review/README.md), or sign Facebook in on it once.")
                return false
            }
            let permission = [
                springboard.alerts.buttons["Allow Tracking"],
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
}
