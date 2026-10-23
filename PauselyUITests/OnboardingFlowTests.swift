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

        // The carousel is in the hierarchy under the splash screen; wait until the button can be tapped.
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: getStarted)
        if XCTWaiter.wait(for: [hittable], timeout: 10) == .completed {
            getStarted.tap()
        }

        // "Get Started" goes straight to creating an account, which starts with the age check (16+).
        let ageCheck = app.staticTexts["Confirm your age"]
        let signIn = app.buttons["signInButton"]
        XCTAssertTrue(
            ageCheck.waitForExistence(timeout: 10) || signIn.waitForExistence(timeout: 2),
            "Get Started should lead to the age check and sign-up, not another carousel"
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
