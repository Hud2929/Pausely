import XCTest

/// Adding from the catalog and removing from a subscription's own screen, on the demo list
/// (`--fresh-demo-data` starts from it on every launch and never writes to the cloud).
@MainActor
final class SubscriptionManagementTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode", "--fresh-demo-data", "-AppleLanguages", "(en)"]
        app.launch()
        let tab = app.buttons["tabSubscriptions"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }

    private func card(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    func testAddOpensTheCatalog() {
        let add = app.buttons["addSubscriptionButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.textFields["catalogSearchField"].waitForExistence(timeout: 5), "the catalog opens, ready to search")
    }

    func testRemovingASubscriptionTakesItOffTheList() {
        let netflix = card("Netflix")
        XCTAssertTrue(netflix.waitForExistence(timeout: 10), "the demo list starts with Netflix")
        netflix.tap()

        let remove = app.buttons["removeSubscriptionButton"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        for _ in 0..<6 where !remove.isHittable { app.swipeUp() }
        remove.tap()
        let confirm = app.buttons["Remove"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "removing asks first")
        confirm.tap()

        // Offline-first: it's removed on this iPhone and queued for sync, with no error.
        XCTAssertFalse(app.alerts["Something went wrong"].waitForExistence(timeout: 2), "removing offline is not an error")
        XCTAssertTrue(waitUntilGone(netflix, timeout: 5), "Netflix leaves the list")
        XCTAssertTrue(card("Spotify").exists, "the rest of the list stays")
    }
}
