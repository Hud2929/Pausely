import XCTest

/// Verifies the on-device screenshot import flow on the live app: ready screen, review slip
/// selection toggling, and adding detected subscriptions into the store.
@MainActor
final class ScreenshotImportUITests: XCTestCase {

    func testReadyScreenShowsPickAndAppleSubscriptionsActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-screenshot-import=ready", "-AppleLanguages", "(en)"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Import from screenshots"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["chooseScreenshotsButton"].exists)
        XCTAssertTrue(app.buttons["openAppleSubscriptionsButton"].exists)
    }

    func testReviewSlipTogglesSelectionAndAddsSubscriptionsToList() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode", "--empty-demo-data", "--demo-screenshot-import=results",
                               "-AppleLanguages", "(en)", "-debug_free_pro", "NO", "-debug_premium_override", "NO"]
        app.launch()

        let confirm = app.buttons["confirmScreenshotImportButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertEqual(confirm.label, "Add 3 to my list")

        // Untick Paramount+ and confirm count updates to 2, then tick back to 3.
        let paramount = app.buttons["screenshotRow_Paramount+"]
        XCTAssertTrue(paramount.waitForExistence(timeout: 5))
        XCTAssertTrue(paramount.tap(until: confirm.label == "Add 2 to my list"))
        XCTAssertTrue(paramount.tap(until: confirm.label == "Add 3 to my list"))

        // Inactive Hulu is shown below the active slip, never counted in the active total.
        XCTAssertTrue(app.staticTexts["Expired or cancelled"].exists)

        // Commit the 3 active subscriptions and confirm the outcome screen appears.
        let done = app.buttons["screenshotDoneButton"]
        XCTAssertTrue(confirm.tap(until: done.exists))
        XCTAssertTrue(app.staticTexts["Added to your list"].exists)
    }
}
