import XCTest

/// Captures the real production UI with the simulator's existing signed-in session.
@MainActor
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["main.tabs"].waitForExistence(timeout: 30),
                      "Sign in to Hot Mess on this simulator before capturing store screenshots.")
        dismissLocationUpgrade()
        tab("Venues").tap()
        XCTAssertTrue(app.navigationBars["Seattle"].waitForExistence(timeout: 30),
                      "Set the screenshot simulator location to Seattle and allow location access.")
    }

    func testNow() { open("Now"); snapshot("01-now") }
    func testEvents() { open("Events"); requireCard("event"); snapshot("02-events") }
    func testVenues() { open("Venues"); requireCard("venue"); snapshot("03-venues") }
    func testPeople() { everyone(); requireCard("person"); snapshot("04-people") }
    func testEvent() { open("Events"); openCard("event"); snapshot("05-event") }
    func testVenue() { open("Venues"); openCard("venue"); snapshot("06-venue") }
    func testPerson() {
        everyone()
        let performer = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@",
                                                         "card.person.", "Agony Ray")).firstMatch
        for _ in 0..<15 {
            if performer.exists && performer.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(performer.exists && performer.isHittable, "Agony Ray must be visible for the profile capture.")
        performer.tap()
        settle()
        snapshot("07-person")
    }

    private func dismissLocationUpgrade() {
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let keep = system.buttons["Keep Only While Using"]
        if keep.exists { keep.tap() }
    }

    private func everyone() {
        open("People")
        app.buttons["Everyone"].tap()
        settle()
    }

    private func tab(_ name: String) -> XCUIElement {
        let phoneTab = app.tabBars.buttons[name]
        if phoneTab.exists { return phoneTab }
        // iPad floating tabs are exposed as cells/other elements on iOS 27.
        return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func open(_ tab: String) {
        let button = self.tab(tab)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        settle()
    }

    @discardableResult
    private func requireCard(_ kind: String) -> XCUIElement {
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "card.\(kind).")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No \(kind) cards loaded; choose a city with listings.")
        return card
    }

    private func openCard(_ kind: String) {
        requireCard(kind).tap()
        settle()
    }

    private func settle() {
        let spinner = app.activityIndicators.firstMatch
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: spinner)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 30), .completed)
        // Give remote photos and the navigation animation time to render.
        sleep(3)
        XCTAssertFalse(app.staticTexts["Something went wrong"].exists,
                       app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " / "))
        dismissLocationUpgrade()
        XCTAssertFalse(app.alerts.firstMatch.exists, "Dismiss permission prompts before capture.")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
