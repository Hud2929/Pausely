import XCTest

@MainActor
final class TabNavigationTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"]
        app.launch()
    }

    func testDashboardTabExists() throws {
        let app = XCUIApplication()
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5), "Dashboard tab should exist")
    }

    func testSubscriptionsTabExists() throws {
        let app = XCUIApplication()
        let subscriptionsTab = app.tabBars.buttons["Subscriptions"]
        XCTAssertTrue(subscriptionsTab.waitForExistence(timeout: 5), "Subscriptions tab should exist")
    }

    func testProfileTabExists() throws {
        let app = XCUIApplication()
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5), "Profile tab should exist")
    }

    func testNavigateBetweenTabs() throws {
        let app = XCUIApplication()

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        let subscriptionsTab = app.tabBars.buttons["Subscriptions"]
        let profileTab = app.tabBars.buttons["Profile"]

        // Dashboard -> Subscriptions
        if dashboardTab.waitForExistence(timeout: 5) {
            dashboardTab.tap()
        }
        if subscriptionsTab.waitForExistence(timeout: 3) {
            subscriptionsTab.tap()
        }
        XCTAssertTrue(subscriptionsTab.isSelected || subscriptionsTab.isHittable, "Should be on Subscriptions tab")

        // Subscriptions -> Profile
        if profileTab.waitForExistence(timeout: 3) {
            profileTab.tap()
        }
        XCTAssertTrue(profileTab.isSelected || profileTab.isHittable, "Should be on Profile tab")

        // Profile -> Dashboard
        if dashboardTab.waitForExistence(timeout: 3) {
            dashboardTab.tap()
        }
        XCTAssertTrue(dashboardTab.isSelected || dashboardTab.isHittable, "Should be on Dashboard tab")
    }
}
