import XCTest

/// A first launch: guess, tally and reveal, then Keep my list leads to the age check and sign-up.
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

    func testGuessTallyRevealThenAccount() {
        let guess = app.buttons["getStartedButton"]
        XCTAssertTrue(waitUntilHittable(guess), "the first screen asks for a guess")
        XCTAssertTrue(app.staticTexts["What do you think you pay for subscriptions each month?"].exists)
        guess.tap()

        let netflix = app.buttons["Netflix"]
        XCTAssertTrue(netflix.waitForExistence(timeout: 5), "the tally offers common services")
        XCTAssertFalse(app.buttons["showTotalButton"].exists, "no total to show while the slip is empty")
        netflix.tap()
        app.buttons["Spotify"].tap()

        let showTotal = app.buttons["showTotalButton"]
        XCTAssertTrue(waitUntilHittable(showTotal, timeout: 5))
        showTotal.tap()

        let keep = app.buttons["keepListButton"]
        XCTAssertTrue(waitUntilHittable(keep, timeout: 8), "the reveal offers to keep the list")
        for name in ["Netflix", "Spotify"] {
            let line = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            XCTAssertTrue(line.waitForExistence(timeout: 5), "\(name) is printed on the slip")
        }
        keep.tap()

        // Keeping the list leads to creating an account, which starts with the age check (16+).
        let ageCheck = app.staticTexts["Confirm your age"]
        let signIn = app.buttons["signInButton"]
        XCTAssertTrue(ageCheck.waitForExistence(timeout: 10) || signIn.waitForExistence(timeout: 2),
                      "Keep my list should lead to the age check and sign-up")
    }

    func testSignInSkipsTheTally() {
        let signIn = app.buttons["firstRunSignIn"]
        XCTAssertTrue(waitUntilHittable(signIn))
        signIn.tap()
        XCTAssertTrue(app.buttons["signInButton"].waitForExistence(timeout: 10), "Sign in opens the sign-in screen")
        XCTAssertFalse(app.sliders["guessSlider"].exists, "the guess screen is gone")
    }
}
