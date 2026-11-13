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

        // Keeping the list leads to creating an account, which starts with the age check (16+)
        // on a device that has not answered it yet, and with the form on one that has.
        let ageCheck = app.buttons["ageGateContinueButton"]
        let form = app.buttons["createAccountButton"]
        XCTAssertTrue(ageCheck.waitForExistence(timeout: 10) || form.waitForExistence(timeout: 3),
                      "Keep my list should lead to the age check and sign-up")

        // Leaving it puts the person back on their own total: the list they made is still there.
        let leave = ageCheck.exists ? app.buttons["ageGateCancelButton"] : app.buttons["cancelButton"]
        XCTAssertTrue(waitUntilHittable(leave, timeout: 5))
        leave.tap()
        XCTAssertTrue(waitUntilHittable(keep, timeout: 8), "closing the account step returns to the total")
        let netflix2 = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Netflix")).firstMatch
        XCTAssertTrue(netflix2.exists, "with the list still on it")

        // And the button works a second time.
        keep.tap()
        XCTAssertTrue(ageCheck.waitForExistence(timeout: 10) || form.waitForExistence(timeout: 3),
                      "Keep my list opens the account step again")
    }

    func testSignInSkipsTheTally() {
        let signIn = app.buttons["firstRunSignIn"]
        XCTAssertTrue(waitUntilHittable(signIn))
        signIn.tap()
        XCTAssertTrue(app.buttons["signInButton"].waitForExistence(timeout: 10), "Sign in opens the sign-in screen")
        XCTAssertFalse(app.sliders["guessSlider"].exists, "the guess screen is gone")
    }
}
