import XCTest

/// The whole "Find in Email" workflow through the screens, against a real IMAP server (the local test server).
/// Run with TEST_RUNNER_PAUSELY_LOCAL_IMAP_UI=host:port:user:password and, optionally,
/// TEST_RUNNER_PAUSELY_LOCAL_IMAP_UI_EXPECT="Name A,Name B" (subscriptions the mailbox must show).
/// It imports what it finds into the app on that simulator, so use a test simulator.
final class InboxWorkflowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-inbox", "-AppleLanguages", "(en)"] + (reset ? ["--reset-inbox"] : [])
        app.launch()
        return app
    }

    /// Taps until the field has keyboard focus (a tap during the keyboard's animation can be lost).
    private func focus(_ field: XCUIElement) {
        for _ in 0..<4 {
            field.tap()
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func row(_ app: XCUIApplication, startingWith name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    func testIMAPWorkflowThroughTheScreens() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let spec = environment["PAUSELY_LOCAL_IMAP_UI"]?.split(separator: ":").map(String.init), spec.count == 4 else {
            throw XCTSkip("set PAUSELY_LOCAL_IMAP_UI=host:port:user:password")
        }
        let (host, port, user, password) = (spec[0], spec[1], spec[2], spec[3])
        let expected = (environment["PAUSELY_LOCAL_IMAP_UI_EXPECT"] ?? "").split(separator: ",").map(String.init)

        var app = launch(reset: true)

        // 1. Choose "Other email" and fill in the server.
        let other = app.buttons["connect-other"]
        XCTAssertTrue(other.waitForExistence(timeout: 15))
        other.tap()
        let address = app.textFields["imapAddress"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        focus(address)
        address.typeText(user)
        let secret = app.secureTextFields["imapPassword"]
        focus(secret)
        secret.typeText("not-the-password")
        let hostField = app.textFields["imapHost"]
        let domain = user.split(separator: "@").last.map(String.init) ?? ""
        XCTAssertEqual(hostField.placeholderValue, "imap.\(domain)", "the usual server name is suggested")

        // 1b. Left empty, the suggestion is tried; a server that doesn't exist is reported at once.
        if domain.hasSuffix(".test") || domain.hasSuffix(".invalid") {
            app.buttons["imapConnect"].tap()
            let error = app.staticTexts["imapError"]
            XCTAssertTrue(error.waitForExistence(timeout: 10), "a missing server must be reported quickly")
            XCTAssertTrue(error.label.contains("No server by that name"), error.label)
        }
        focus(hostField)
        hostField.typeText(host)
        let portField = app.textFields["imapPort"]
        focus(portField)
        portField.typeText(port)

        // 2. A wrong password is refused with a clear message, and nothing is saved.
        app.buttons["imapConnect"].tap()
        let error = app.staticTexts.matching(NSPredicate(format: "identifier == 'imapError' AND label CONTAINS %@", "wasn't accepted")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 30), "a wrong password must say so: \(app.staticTexts["imapError"].label)")

        // 3. The right password connects and returns to the inbox screen.
        focus(secret)
        secret.typeText(password)
        app.buttons["imapConnect"].tap()
        let scan = app.buttons["scanInboxesButton"]
        XCTAssertTrue(scan.waitForExistence(timeout: 30), "connected inboxes show the search button")
        XCTAssertTrue(app.staticTexts[user].exists)

        // 4. Scan: results list the expected subscriptions. Confirmed ones come preselected; "likely" ones
        // wait for the person to pick them, so pick any expected one that isn't selected yet.
        scan.tap()
        let firstExpected = row(app, startingWith: expected.first ?? "")
        XCTAssertTrue(firstExpected.waitForExistence(timeout: 120), "the scan should list \(expected)")
        for name in expected {
            let item = row(app, startingWith: name)
            XCTAssertTrue(item.exists, "\(name) should be listed")
            if item.label.hasSuffix(", not selected") { item.tap() }
            let selected = expectation(for: NSPredicate(format: "label ENDSWITH ', selected'"), evaluatedWith: item)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, "\(name) should be selected: \(item.label)")
        }
        let importButton = app.buttons["importSelectedButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "selected subscriptions can be imported")
        XCTAssertTrue(importButton.label.hasPrefix("Import "), importButton.label)

        // 5. Import.
        importButton.tap()
        XCTAssertTrue(app.buttons["importDoneButton"].waitForExistence(timeout: 15), "the import should finish")
        XCTAssertTrue(app.staticTexts["Import complete"].exists)

        // 6. Relaunch: the inbox is remembered. Disconnect removes it.
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(app.buttons["scanInboxesButton"].waitForExistence(timeout: 15), "the inbox survives a relaunch")
        let options = app.buttons["Options for \(user)"]
        let disconnect = app.buttons["disconnectInbox"]
        for _ in 0..<3 where !disconnect.exists {
            options.tap()   // a tap while the screen is still settling can be dropped
            _ = disconnect.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(disconnect.exists, "the options menu offers Disconnect")
        disconnect.tap()
        XCTAssertTrue(app.buttons["connect-other"].waitForExistence(timeout: 15), "after disconnecting, the providers show again")
    }
}
