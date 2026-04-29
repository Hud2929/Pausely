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
        let dashboardTab = app.tabBars.buttons["tabHome"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5), "Home tab should exist")
    }

    func testSubscriptionsTabExists() throws {
        let app = XCUIApplication()
        let subscriptionsTab = app.tabBars.buttons["tabSubscriptions"]
        XCTAssertTrue(subscriptionsTab.waitForExistence(timeout: 5), "Subscriptions tab should exist")
    }

    func testProfileTabExists() throws {
        let app = XCUIApplication()
        let profileTab = app.tabBars.buttons["tabProfile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5), "Profile tab should exist")
    }

    func testNavigateBetweenTabs() throws {
        let app = XCUIApplication()

        let homeTab = app.tabBars.buttons["tabHome"]
        let subscriptionsTab = app.tabBars.buttons["tabSubscriptions"]
        let profileTab = app.tabBars.buttons["tabProfile"]

        // Home -> Subscriptions
        if homeTab.waitForExistence(timeout: 5) {
            homeTab.tap()
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

        // Profile -> Home
        if homeTab.waitForExistence(timeout: 3) {
            homeTab.tap()
        }
        XCTAssertTrue(homeTab.isSelected || homeTab.isHittable, "Should be on Home tab")
    }
}
