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

        // Look for common onboarding indicators
        let getStarted = app.buttons["Get Started"]
        let skipButton = app.buttons["Skip"]
        let continueButton = app.buttons["Continue"]

        if getStarted.exists {
            getStarted.tap()
        } else if continueButton.exists {
            // Tap through any onboarding pages
            for _ in 0..<5 {
                if continueButton.exists {
                    continueButton.tap()
                } else {
                    break
                }
            }
        }

        // After onboarding, we should see the main UI (tabs or login)
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        let subscriptionsTab = app.tabBars.buttons["Subscriptions"]
        let loginButton = app.buttons["Sign In"]

        XCTAssertTrue(
            dashboardTab.exists || subscriptionsTab.exists || loginButton.exists,
            "App should reach main UI after onboarding"
        )
    }

    func testSkipOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()

        let skipButton = app.buttons["Skip"]
        if skipButton.exists {
            skipButton.tap()
        }

        // Verify we are past onboarding
        let mainUIExists = app.tabBars.buttons.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(mainUIExists, "Main UI should appear after skipping onboarding")
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

        // After swiping, the Get Started or Next button should still be present
        let ctaButton = app.buttons["Get Started"]
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(
            ctaButton.exists || nextButton.exists || app.buttons["Skip"].exists,
            "Onboarding controls should remain visible after swiping"
        )
    }
}
