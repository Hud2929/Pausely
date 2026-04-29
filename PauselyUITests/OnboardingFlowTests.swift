import XCTest

@MainActor
final class OnboardingFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    func testOnboardingCanBeDismissed() throws {
        let app = XCUIApplication()

        // Onboarding carousel has a "Get Started" button
        let getStarted = app.buttons["getStartedButton"]

        if getStarted.waitForExistence(timeout: 5) {
            getStarted.tap()
        }

        // After tapping Get Started, we should see the auth flow or main UI
        // (since --uitesting without --demo-mode still shows auth)
        let loginButton = app.buttons["Sign In"]
        let homeTab = app.tabBars.buttons["tabHome"]

        XCTAssertTrue(
            loginButton.waitForExistence(timeout: 5) || homeTab.waitForExistence(timeout: 5),
            "App should reach auth or main UI after onboarding"
        )
    }

    func testOnboardingCarouselSwipe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()

        // Onboarding carousel uses a TabView with paging
        // Swipe left to advance through pages
        let carousel = app.scrollViews.firstMatch
        if carousel.waitForExistence(timeout: 5) {
            carousel.swipeLeft()
            carousel.swipeLeft()
        }

        // After swiping, the Get Started button should still be present
        let ctaButton = app.buttons["getStartedButton"]
        XCTAssertTrue(
            ctaButton.waitForExistence(timeout: 3),
            "Get Started button should remain visible after swiping"
        )
    }
}
