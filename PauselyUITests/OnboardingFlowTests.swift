import XCTest

/// A first launch: the onboarding pages, then Get Started leads to the age check and sign-up.
@MainActor
final class OnboardingFlowTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "-AppleLanguages", "(en)"]
        app.launch()
    }

    /// Waits until the element can be tapped (onboarding sits under the splash screen at first).
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: element)
        return XCTWaiter.wait(for: [hittable], timeout: timeout) == .completed
    }

    func testOnboardingCanBeDismissed() {
        let getStarted = app.buttons["getStartedButton"]
        XCTAssertTrue(waitUntilHittable(getStarted), "onboarding shows Get Started")
        getStarted.tap()

        // "Get Started" goes straight to creating an account, which starts with the age check (16+).
        let ageCheck = app.staticTexts["Confirm your age"]
        let signIn = app.buttons["signInButton"]
        XCTAssertTrue(ageCheck.waitForExistence(timeout: 10) || signIn.waitForExistence(timeout: 2),
                      "Get Started should lead to the age check and sign-up, not another carousel")
    }

    func testSwipingShowsEachPageAndKeepsGetStarted() {
        let first = app.staticTexts["Know every renewal before it hits"]
        XCTAssertTrue(waitUntilHittable(first), "the first page shows")
        for title in ["Keep it or cancel it, in one tap", "See exactly what you saved"] {
            app.swipeLeft()
            XCTAssertTrue(waitUntilHittable(app.staticTexts[title], timeout: 5), "\(title) should show after a swipe")
        }
        XCTAssertTrue(app.buttons["getStartedButton"].isHittable, "Get Started stays on every page")
    }
}
