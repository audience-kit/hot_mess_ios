//
//  HotMessUITests.swift
//  HotMessUITests
//

import XCTest

/// A smoke test that the app launches and puts something on screen.
///
/// Anything past this point needs a signed-in session, so the interesting
/// coverage lives in the unit tests instead.
final class HotMessUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
