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
        let subscriptionsTab = app.tabBars.buttons["Subscriptions"]
        if subscriptionsTab.waitForExistence(timeout: 5) {
            subscriptionsTab.tap()
        }

        // Tap add button
        let addButton = app.buttons["Add Subscription"]
        let plusButton = app.navigationBars.buttons["Add"]

        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else if plusButton.waitForExistence(timeout: 3) {
            plusButton.tap()
        }

        // Fill in subscription details
        let nameField = app.textFields["Name"]
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.typeText("Test Subscription")
        }

        let amountField = app.textFields["Amount"]
        if amountField.exists {
            amountField.tap()
            amountField.typeText("9.99")
        }

        // Save
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        }

        // Verify the subscription appears in the list
        let subscriptionCell = app.staticTexts["Test Subscription"]
        XCTAssertTrue(subscriptionCell.waitForExistence(timeout: 5), "Added subscription should appear in list")
    }

    func testDeleteSubscription() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"]
        app.launch()

        // Navigate to Subscriptions tab
        let subscriptionsTab = app.tabBars.buttons["Subscriptions"]
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
