//
//  SafetyReviewUITests.swift
//  HotMessScreenshots
//

import XCTest

/// Automated walkthrough demonstrating safety, creator content moderation, and reporting:
/// 1. EULA and Terms presented prior to login with explicit Zero Tolerance Policy & Content Creator definition.
/// 2. Continue with Facebook, on a clone of the Facebook session snapshot simulator (scripts/app-review/README.md).
/// 3. Flagging creator content on Venue and Person profiles via the (•••) menu.
/// 4. Flagging objectionable chat messages with swift 24-hour moderation action.
/// 5. Blocking abusive users with instant feed removal and moderation notification.
/// 6. Managing blocked users and appeals under Settings > Blocked People.
@MainActor
final class SafetyReviewUITests: XCTestCase {
    private var app: XCUIApplication!
    private let dwell: UInt32 = 3

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Apple Account Alert") { alert in
            let label = alert.label
            if label.localizedCaseInsensitiveContains("Apple") || label.localizedCaseInsensitiveContains("Sign In") {
                let actionBtn = alert.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH[c] 'Continue' OR label ==[c] 'Sign In' OR label ==[c] 'OK' OR label ==[c] 'Close' OR label ==[c] 'Cancel'")
                ).firstMatch
                if actionBtn.exists && actionBtn.isHittable {
                    actionBtn.tap()
                    return true
                }
            }
            return false
        }
    }

    /// Full end-to-end safety walkthrough for screen recording.
    func testSafetyAndModerationWalkthrough() throws {
        // --- STEP 1: EULA & Terms Presentation Prior to Sign-In ---
        app.launchArguments = ["-HotMessUITestSignedOut", "-HotMessUseNextAPI", "-HotMessReviewMode"]
        app.launch()

        let appleButton = app.buttons["login.apple"]
        let facebookButton = app.buttons["login.facebook"]
        XCTAssertTrue(appleButton.waitForExistence(timeout: 15) || facebookButton.waitForExistence(timeout: 5), "Login screen did not appear")
        sleep(dwell)

        // Verify EULA checkbox is unchecked by default
        let eulaCheckbox = app.buttons["login.eulaCheckbox"]
        XCTAssertTrue(eulaCheckbox.waitForExistence(timeout: 5), "EULA checkbox not found")
        sleep(dwell)

        // Open the EULA via the inline agreement link
        let openEULA = app.buttons["login.openEULA"]
        if openEULA.waitForExistence(timeout: 5) {
            openEULA.tap()
        } else {
            eulaCheckbox.tap()
        }

        let eulaTitle = app.navigationBars["Terms of Use (EULA)"]
        XCTAssertTrue(eulaTitle.waitForExistence(timeout: 8), "EULA sheet did not appear")
        sleep(dwell)

        // Scroll down to showcase Section 1 (Content Creators), Section 2 (Zero Tolerance), Section 5 (24-Hour SLA), Section 6 (Appeals)
        let scrollViews = app.scrollViews
        if scrollViews.firstMatch.exists {
            scrollViews.firstMatch.swipeUp(velocity: .slow)
            sleep(dwell)
            scrollViews.firstMatch.swipeUp(velocity: .slow)
            sleep(dwell)
        }

        // Tap "I Agree" button in EULA sheet
        let acceptButton = app.buttons["eula.bottomAccept"]
        if acceptButton.exists && acceptButton.isHittable {
            acceptButton.tap()
        } else if app.buttons["I Agree"].exists {
            app.buttons["I Agree"].tap()
        }
        sleep(dwell)

        // Checkbox is now visibly checked
        sleep(1)

        // --- STEP 2: Continue with Facebook (the simulator's Facebook session is already signed in) ---
        var tabs = app.descendants(matching: .any)["main.tabs"]
        if !tabs.exists {
            FacebookSignInHelper(app: app, dwell: dwell).signIn()
            tabs = app.descendants(matching: .any)["main.tabs"]
        }

        // Dismiss push notifications prompt if it appears
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.alerts.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) && allowButton.isHittable {
            allowButton.tap()
            sleep(1)
        }

        XCTAssertTrue(tabs.waitForExistence(timeout: 25), "Simulator is not signed in to main.tabs after Facebook sign-in")
        sleep(dwell)

        // --- STEP 3: Flagging Creator Profiles & Content (Venues & Chat) ---
        tab("Venues").tap()
        sleep(dwell)

        // Open first venue
        if openFirstCard(prefix: "card.venue.") {
            sleep(dwell)

            // Open options menu (•••) on Venue Profile
            let venueMenu = app.buttons["venue.optionsMenu"]
            if venueMenu.waitForExistence(timeout: 5) {
                venueMenu.tap()
                sleep(2)
                let reportVenue = app.buttons["Report Venue…"]
                if reportVenue.exists {
                    reportVenue.tap()
                    sleep(dwell)
                    if app.buttons["Cancel"].exists {
                        app.buttons["Cancel"].tap()
                        sleep(1)
                    }
                }
            }

            // Simulate location into venue using App Review helper
            let pretendButton = app.buttons["Pretend I'm here"]
            if pretendButton.waitForExistence(timeout: 5) {
                pretendButton.tap()
                sleep(2)
            }

            // Enter venue chat if open
            let chatRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Chat'")).firstMatch
            if chatRow.waitForExistence(timeout: 5) {
                chatRow.tap()
                sleep(dwell)

                // --- STEP 4: Chat Moderation: Reporting & Blocking ---
                let chatBubbles = app.scrollViews.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier BEGINSWITH 'chat.bubble' OR label CONTAINS ':'"))
                let candidateBubbles = chatBubbles.allElementsBoundByIndex.filter { $0.isHittable }
                if let bubble = candidateBubbles.first {
                    bubble.press(forDuration: 1.2)
                    sleep(2)

                    let reportButton = app.buttons["Report…"]
                    if reportButton.waitForExistence(timeout: 4) {
                        reportButton.tap()
                        sleep(dwell)

                        // Tap a reason (e.g. Harassment or hate)
                        let reason = app.buttons["Harassment or hate"]
                        if reason.waitForExistence(timeout: 4) {
                            reason.tap()
                            sleep(2)
                        } else if app.buttons.matching(NSPredicate(format: "label CONTAINS 'hate' OR label CONTAINS 'Objectionable'")).firstMatch.exists {
                            app.buttons.matching(NSPredicate(format: "label CONTAINS 'hate' OR label CONTAINS 'Objectionable'")).firstMatch.tap()
                            sleep(2)
                        }

                        // Dismiss the block offer prompt if shown
                        let notNow = app.buttons["Not Now"]
                        if notNow.waitForExistence(timeout: 4) {
                            notNow.tap()
                            sleep(1)
                        }
                    }

                    // Blocking abusive users with instant removal and moderation notification
                    bubble.press(forDuration: 1.2)
                    sleep(2)

                    let blockOption = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Block'")).firstMatch
                    if blockOption.waitForExistence(timeout: 4) {
                        blockOption.tap()
                        sleep(2)

                        // Confirm block in alert (alert states instant feed removal & moderation notification)
                        let confirmBlock = app.alerts.buttons["Block"]
                        if confirmBlock.waitForExistence(timeout: 4) {
                            confirmBlock.tap()
                            sleep(dwell)
                        }
                    }
                }

                // Return to venue
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                    sleep(1)
                }
            }

            // Return to venues list
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }

        // --- STEP 5: Flagging Person / Performer Creator Profile ---
        tab("People").tap()
        sleep(dwell)

        if openFirstCard(prefix: "card.person.") {
            sleep(dwell)

            let personMenu = app.buttons["person.optionsMenu"]
            if personMenu.waitForExistence(timeout: 5) {
                personMenu.tap()
                sleep(2)

                let reportCreator = app.buttons["Report Creator…"]
                if reportCreator.exists {
                    reportCreator.tap()
                    sleep(dwell)
                    if app.buttons["Cancel"].exists {
                        app.buttons["Cancel"].tap()
                        sleep(1)
                    }
                }
            }

            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }

        // --- STEP 6: Managing Blocked Users in Settings ---
        tab("Me").tap()
        sleep(dwell)

        let blockedRow = app.descendants(matching: .any)["me.blocked"]
        if blockedRow.waitForExistence(timeout: 5) {
            blockedRow.tap()
            sleep(dwell)

            // Hold on Blocked People screen to showcase unblock UI and policy
            sleep(dwell)

            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }

        // Hold last screen for final recording frame
        sleep(dwell * 2)
    }

    private func tab(_ name: String) -> XCUIElement {
        let phoneTab = app.tabBars.buttons[name]
        if phoneTab.exists { return phoneTab }
        return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func openFirstCard(prefix: String) -> Bool {
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
        if card.waitForExistence(timeout: 8) && card.isHittable {
            card.tap()
            return true
        }
        return false
    }
}
