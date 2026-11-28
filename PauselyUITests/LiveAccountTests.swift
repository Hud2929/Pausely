import XCTest

/// The account path against the live project, on a fresh install of the Release build: a new person
/// signs up with a real address, types the code that was mailed to it, finds the list they made
/// before signing up, and deletes the account; and the account given to App Review signs in.
/// `scripts/live_account_proof.py` runs these before a submission. It hands over the address, reads
/// the mailed code back from the mail service, and looks at what reached the database.
/// Runs only with `TEST_RUNNER_PAUSELY_LIVE_DIR` set: a folder on the Mac for the pictures, the
/// address, the code and the review sign-in. No password is written into this file or the log.
@MainActor
final class LiveAccountTests: XCTestCase {

    private var folder: URL!
    private var app: XCUIApplication!
    private var step = 0

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["PAUSELY_LIVE_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set PAUSELY_LIVE_DIR to run against the live project")
        folder = URL(fileURLWithPath: path)
        continueAfterFailure = false
        app = XCUIApplication()
        // No test flags: the Release build has none, and this is the app as a person gets it.
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    private func capture(_ name: String) {
        step += 1
        let file = folder.appendingPathComponent(String(format: "%@-%02d-%@.png", self.name.contains("Review") ? "review" : "signup", step, name))
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
    }

    private func waitHittable(_ element: XCUIElement, _ timeout: TimeInterval = 15) -> Bool {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: element)
        return XCTWaiter.wait(for: [hittable], timeout: timeout) == .completed
    }

    /// A file the script on the Mac writes, once it is there and not empty.
    private func handedOver(_ file: String, within seconds: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if let text = try? String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            sleep(2)
        } while Date() < deadline
        return nil
    }

    private func tell(_ file: String) throws {
        try "now".write(to: folder.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    private func type(_ text: String, into id: String) {
        let plain = app.textFields[id], secure = app.secureTextFields[id]
        let field = plain.waitForExistence(timeout: 8) ? plain : secure
        XCTAssertTrue(field.waitForExistence(timeout: 8), "\(id) is on the screen")
        field.tap()
        field.typeText(text)
    }

    /// On a new-password box the system offers a password of its own, on a sheet over the form ("Use Strong
    /// Password?"), and what is typed under that sheet is thrown away: a first run left one character of 23
    /// in the box. A person who wants their own password closes the sheet first; so does this.
    private func typeNewPassword(_ password: String, until accepted: XCUIElement) {
        let field = app.secureTextFields["passwordTextField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the password box is on the screen")
        field.tap()
        if app.buttons["GenerateStrongPasswordButton"].waitForExistence(timeout: 5) {
            app.buttons["xmark"].firstMatch.tap()
            sleep(1)
            field.tap()
        }
        field.typeText(password)
        sleep(1)
        XCTAssertTrue(accepted.isEnabled, "a password that meets every rule makes Create account live")
    }

    /// The age check (16 and older) comes once per account: a year of birth is turned to and confirmed.
    private func passTheAgeCheckIfAsked(within seconds: TimeInterval) {
        let go = app.buttons["ageGateContinueButton"]
        guard go.waitForExistence(timeout: seconds), app.pickerWheels.count >= 3 else { return }
        app.pickerWheels.element(boundBy: 2).adjust(toPickerWheelValue: "1990")
        capture("age-check")
        XCTAssertTrue(waitHittable(go, 5), "a date of birth makes Continue live")
        go.tap()
    }

    /// Two things stand between a new account and the tabs. The system offers to save the password, on a
    /// sheet over the app; and after a sign-up Pausely asks three questions about what to watch for first.
    /// A person answers them or leaves them; "Not now" to both here, so nothing is kept on the simulator
    /// and the account path is all this test walks.
    private func landsInTheApp(within seconds: TimeInterval) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let home = app.tab("tabHome")
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            for host in [app!, springboard] {
                let notNow = host.buttons["Not Now"].firstMatch
                if notNow.exists { notNow.tap() }
            }
            let questions = app.buttons["curateCloseButton"].firstMatch
            if questions.exists, questions.isHittable { questions.tap() }
            if home.exists && home.isHittable { return true }
            sleep(1)
        }
        capture("not-in-the-app")
        return false
    }

    private func reach(_ element: XCUIElement) {
        for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable, "\(element.identifier) can be reached by scrolling")
    }

    func testANewPersonSignsUpTypesTheMailedCodeAndDeletesTheAccount() throws {
        let email = try XCTUnwrap(handedOver("signup_email.txt", within: 2), "signup_email.txt names the address")
        let password = "Pw-" + UUID().uuidString.prefix(20)   // the account is deleted again below

        // The first run: a guess, two services on the slip, the total, then "Keep my list".
        let guess = app.buttons["getStartedButton"]
        XCTAssertTrue(waitHittable(guess, 30), "a fresh install opens on the guess")
        let netflix = app.buttons["Netflix"]
        XCTAssertTrue(guess.tap(until: netflix.exists), "the tally offers common services")
        let spotify = app.buttons["Spotify"]
        XCTAssertTrue(netflix.tap(until: netflix.isSelected))
        XCTAssertTrue(spotify.tap(until: spotify.isSelected))
        let showTotal = app.buttons["showTotalButton"]
        XCTAssertTrue(waitHittable(showTotal, 8))
        let keep = app.buttons["keepListButton"]
        XCTAssertTrue(showTotal.tap(until: keep.exists, within: 8))
        XCTAssertTrue(waitHittable(keep, 10))
        let form = app.buttons["createAccountButton"]
        XCTAssertTrue(keep.tap(until: app.buttons["ageGateContinueButton"].exists || form.exists, within: 10))
        passTheAgeCheckIfAsked(within: 3)

        // The account, made with a real address on the live project.
        XCTAssertTrue(form.waitForExistence(timeout: 10), "the sign-up form follows the age check")
        type(email, into: "emailTextField")
        typeNewPassword(password, until: form)
        capture("sign-up-form")
        if !form.isHittable { app.typeText("\n") } else { form.tap() }
        let codeField = app.descendants(matching: .any).matching(identifier: "emailCodeField").firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 40), "the code screen follows a sign-up")
        capture("code-screen")

        // The code is in the email the live project just sent; the script reads it back.
        try tell("waiting_for_code")
        let code = try XCTUnwrap(handedOver("code.txt", within: 150), "the mailed code arrived")
        codeField.tap()
        app.typeText(code)
        let verify = app.buttons["verifyCodeButton"]
        if verify.exists, verify.isEnabled, verify.isHittable { verify.tap() }
        passTheAgeCheckIfAsked(within: 8)
        XCTAssertTrue(landsInTheApp(within: 60), "a confirmed account lands in the app")
        sleep(3)
        capture("home")

        // The slip made before signing up is the account's list, and it reaches the database.
        app.tab("tabSubscriptions").tap()
        for name in ["Netflix", "Spotify"] {
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 15), "\(name) from the first run is in the list")
        }
        capture("list")
        try tell("ready_for_server_check")
        XCTAssertNotNil(handedOver("server_checked.txt", within: 90), "the script looked at the database")

        // Profile, Privacy & security, Delete account: the way the review notes describe it.
        app.tab("tabProfile").tap()
        let privacy = app.buttons["privacySecurityButton"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 10))
        reach(privacy)
        privacy.tap()
        let delete = app.buttons["deleteAccountButton"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        reach(delete)
        capture("privacy-and-security")
        delete.tap()
        let confirm = app.alerts.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), "deleting asks first")
        confirm.tap()
        XCTAssertTrue(waitHittable(app.buttons["getStartedButton"], 60), "a deleted account returns to the first screen")
        capture("after-delete")
    }

    func testTheAccountGivenToAppReviewSignsIn() throws {
        let login = try XCTUnwrap(handedOver("review_login.txt", within: 2), "review_login.txt holds the sign-in").components(separatedBy: "\n")
        XCTAssertEqual(login.count, 2)
        let start = app.buttons["firstRunSignIn"]
        XCTAssertTrue(waitHittable(start, 30), "the first screen offers Sign in")
        let signIn = app.buttons["signInButton"]
        XCTAssertTrue(start.tap(until: signIn.exists, within: 10), "Sign in opens the sign-in screen")
        type(login[0], into: "signInEmailTextField")
        type(login[1], into: "signInPasswordTextField")
        if !signIn.isHittable { app.typeText("\n") } else { signIn.tap() }
        if handedOver("review_age_answered.txt", within: 1) == "yes" {
            // It answered the age check before, on another install. The question is not put again, not
            // even for the second it takes to read the answer: watched closely until the tabs are there.
            let question = app.buttons["ageGateContinueButton"], tabs = app.tabBars.firstMatch
            let deadline = Date().addingTimeInterval(60)
            var asked = false
            while Date() < deadline, !tabs.exists, !asked { asked = question.exists }
            if asked { capture("age-check-shown-again") }
            XCTAssertFalse(asked, "an account that has answered the age check is not asked again after signing in")
        } else {
            passTheAgeCheckIfAsked(within: 15)
        }
        XCTAssertTrue(landsInTheApp(within: 60), "the review account lands in the app")
        sleep(3)
        capture("home")
        app.tab("tabSubscriptions").tap()
        sleep(2)
        capture("list")
        app.tab("tabAnalysis").tap()
        sleep(2)
        capture("analysis")
        app.tab("tabProfile").tap()
        sleep(2)
        capture("profile")

        // Out again, so the simulator is left without a session.
        let signOut = app.buttons["signOutButton"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 10))
        reach(signOut)
        signOut.tap()
        let confirm = app.buttons["Sign out"].firstMatch
        if confirm.waitForExistence(timeout: 5) { confirm.tap() }
        XCTAssertTrue(waitHittable(app.buttons["getStartedButton"], 40), "signing out returns to the first screen")
    }
}
