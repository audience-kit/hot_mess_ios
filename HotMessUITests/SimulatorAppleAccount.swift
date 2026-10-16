//
//  SimulatorAppleAccount.swift
//  HotMessUITests
//

import XCTest

/// Signs the simulator in to an Apple Account in Settings, which Sign in with Apple needs: without one, iOS shows
/// "Sign in to your Apple Account" instead of the authorization sheet. Does nothing when Settings already has an
/// account. An account that asks for a phone number or verification code (two-factor authentication) can't be
/// signed in here; the test fails saying so, and someone signs the simulator in by hand once.
@MainActor
enum SimulatorAppleAccount {
    static func ensureSignedIn(email: String, password: String, timeout: TimeInterval = 120) {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        settings.launch()

        let signInRow = settings.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Sign in to access' OR label BEGINSWITH[c] 'Sign in to your'")).firstMatch
        guard signInRow.waitForExistence(timeout: 10) else {
            settings.terminate()
            return
        }
        snapshot(settings, "Settings before Apple Account sign-in")
        signInRow.tap()

        var typedEmail = false
        var typedPassword = false
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if typedPassword, !signInRow.exists, settings.state == .runningForeground,
               !settings.secureTextFields.firstMatch.exists, !settings.textFields.firstMatch.exists {
                snapshot(settings, "Settings after Apple Account sign-in")
                settings.terminate()
                return
            }
            let code = settings.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] 'verification code' OR label CONTAINS[c] 'Two-Factor' OR " +
                                        "label CONTAINS[c] 'verify your identity with'")).firstMatch
            // Only after the password: the "Sign in Manually" card itself mentions verifying your identity.
            if typedPassword, code.exists {
                snapshot(settings, "Apple Account wants a verification code")
                XCTFail("\(email) needs a phone number or verification code; " +
                        "sign it in to Settings on this simulator by hand once.")
                return
            }
            if settings.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'password is incorrect'")).firstMatch.exists {
                snapshot(settings, "Apple Account password refused")
                XCTFail("Apple says the password for \(email) is incorrect")
                return
            }
            // Offers on the way: sign in another way, keep data separate, skip extras, and decline the two-factor
            // upgrade (Other Options → Don't Upgrade) rather than add a phone number.
            // "Sign in Manually" is a card whose label runs on into its description, so match its start.
            let detour = settings.descendants(matching: .any).matching(NSPredicate(format:
                "label BEGINSWITH[c] 'Sign in Manually' OR label ==[c] 'Use Email or Phone' OR label ==[c] 'Don’t Merge' OR " +
                "label ==[c] 'Don\\'t Merge' OR label ==[c] 'Not Now' OR label ==[c] 'Skip' OR label ==[c] 'Later' OR " +
                "label ==[c] 'Agree' OR label ==[c] 'Other Options' OR label ==[c] 'Don’t Upgrade' OR " +
                "label ==[c] 'Don\\'t Upgrade'")).firstMatch
            if detour.exists, detour.isHittable {
                detour.tap()
                sleep(2)
                continue
            }
            let secure = settings.secureTextFields.firstMatch
            if !typedPassword, secure.exists, secure.isHittable {
                secure.tap()
                secure.typeText(password + "\n")
                typedPassword = true
                sleep(3)
                continue
            }
            let field = settings.textFields.firstMatch
            if !typedEmail, field.exists, field.isHittable {
                field.tap()
                field.typeText(email + "\n")
                typedEmail = true
                sleep(3)
                continue
            }
            let next = settings.buttons.matching(NSPredicate(format:
                "label ==[c] 'Continue' OR label ==[c] 'Next' OR label ==[c] 'Sign In' OR label ==[c] 'Done'")).firstMatch
            if next.exists, next.isHittable, typedEmail {
                next.tap()
                sleep(2)
                continue
            }
            sleep(1)
        }
        snapshot(settings, "Apple Account sign-in timed out")
        XCTFail("Couldn't sign the simulator in to \(email) in Settings")
    }

    private static func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: name) { $0.add(attachment) }
    }
}
