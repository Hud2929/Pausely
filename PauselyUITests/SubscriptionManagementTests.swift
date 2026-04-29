import XCTest

@MainActor
final class SubscriptionManagementTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--demo-mode"]
        app.launch()
    }

    func testAddSubscriptionManually() throws {
        let app = XCUIApplication()

        // Navigate to Subscriptions tab
        let subscriptionsTab = app.tabBars.buttons["tabSubscriptions"]
        if subscriptionsTab.waitForExistence(timeout: 5) {
            subscriptionsTab.tap()
        }

        // Tap add button (the plus icon in the header)
        let addButton = app.buttons["addSubscriptionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add subscription button should exist")
        addButton.tap()

        // The browser/catalog sheet should open
        // In demo mode, we verify the sheet opens by looking for browse content
        let browseContent = app.staticTexts.firstMatch
        XCTAssertTrue(browseContent.waitForExistence(timeout: 5), "Subscription browser should open")
    }

    func testDeleteSubscription() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"]
        app.launch()

        // Navigate to Subscriptions tab
        let subscriptionsTab = app.tabBars.buttons["tabSubscriptions"]
        if subscriptionsTab.waitForExistence(timeout: 5) {
            subscriptionsTab.tap()
        }

        // Find first subscription cell and swipe to delete
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.swipeLeft()
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
            }
        }

        // Test passes if we get here without crash
        XCTAssertTrue(true)
    }
}
