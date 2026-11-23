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
        // An empty list and no Pro, so the free limit is part of what's tested.
        app.launchArguments = ["--uitesting", "--demo-inbox", "--empty-demo-data", "-AppleLanguages", "(en)",
                               "-debug_premium_override", "NO", "-debug_free_pro", "NO"] + (reset ? ["--reset-inbox"] : [])
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

    /// Saves what's on screen when TEST_RUNNER_PAUSELY_TOUR_DIR is set, so each stage can be looked at.
    private func snap(_ name: String) {
        guard let directory = ProcessInfo.processInfo.environment["PAUSELY_TOUR_DIR"] else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("inbox-\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
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
        snap("1-start")
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
        snap("2-wrong-password")

        // 3. The right password connects, and the search starts by itself: no second tap.
        focus(secret)
        secret.typeText(password)
        app.buttons["imapConnect"].tap()
        // A server on this Mac answers so fast that the whole search can be over within the
        // second, and the line that says it is searching is gone before it can be looked for
        // (seen 2026-11-17: 138 messages read and "We found 19 subscriptions" two seconds after
        // the tap). The line or the results: either shows that connecting started the search.
        let searching = app.staticTexts["scanStatus"]
        let results = app.buttons["importSelectedButton"]
        let started = expectation(for: NSPredicate { _, _ in searching.exists || results.exists }, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 30), .completed, "connecting starts the search")
        Thread.sleep(forTimeInterval: 3)
        snap("3-searching")

        // 4. Results list the expected subscriptions. Confirmed ones come preselected; "likely" ones
        // wait for the person to pick them, so pick any expected one that isn't selected yet.
        let firstExpected = row(app, startingWith: expected.first ?? "")
        XCTAssertTrue(firstExpected.waitForExistence(timeout: 180), "the search should list \(expected)")
        snap("4-results")
        for name in expected {
            let item = row(app, startingWith: name)
            XCTAssertTrue(item.exists, "\(name) should be listed")
            // Chosen or not is the row's Selected trait (VoiceOver says it), no longer a word in the label.
            if !item.isSelected { item.tap() }
            let selected = expectation(for: NSPredicate { _, _ in item.isSelected }, evaluatedWith: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, "\(name) should be selected: \(item.label)")
        }
        let importButton = app.buttons["importSelectedButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "selected subscriptions can be added")
        XCTAssertTrue(importButton.label.hasPrefix("Add "), importButton.label)
        // More were chosen than the free list holds: that is said before the tap.
        let limitNote = app.staticTexts["freeLimitNote"]
        let overLimit = limitNote.exists
        app.swipeUp()
        snap("5-results-list")
        if overLimit { XCTAssertTrue(limitNote.label.contains("Free tracks"), limitNote.label) }

        // 5. Add. The screen says what was added and what waits; nothing is dropped unsaid.
        importButton.tap()
        XCTAssertTrue(app.buttons["importDoneButton"].waitForExistence(timeout: 20), "adding should finish")
        let title = app.staticTexts["importOutcomeTitle"]
        XCTAssertTrue(title.exists)
        snap("6-added")
        XCTAssertTrue(title.label.contains("added to your list") || title.label.contains("is on your list"), title.label)
        if overLimit {
            XCTAssertTrue(app.buttons["importSeeProButton"].exists, "what waits is said, with the way to watch it")
        }

        // 6. Relaunch: the inbox is remembered, and what it found comes back without searching again.
        // Disconnect removes it.
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(app.buttons["scanInboxesButton"].waitForExistence(timeout: 15), "the inbox survives a relaunch")
        XCTAssertTrue(row(app, startingWith: expected.first ?? "").exists, "what was found is shown again, with no search")
        // For VoiceOver the row is one element (address and state, with Reconnect and Disconnect as
        // actions); its menu button is still there to tap. It sits under the findings: scrolled to first.
        let inbox = app.descendants(matching: .any)["inboxRow"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 5), "the connected inbox is listed")
        let options = app.buttons["inboxOptions"]
        for _ in 0..<6 where !options.isHittable { app.swipeUp() }
        XCTAssertTrue(inbox.label.hasPrefix(user), "the row is read by its address: \(inbox.label)")
        snap("7-connected")
        let disconnect = app.buttons["disconnectInbox"]
        for _ in 0..<3 where !disconnect.exists {
            options.tap()   // a tap while the screen is still settling can be dropped
            _ = disconnect.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(disconnect.exists, "the options menu offers Disconnect")
        disconnect.tap()
        // Disconnect asks first: it signs out and forgets what was found.
        let confirm = app.buttons["Disconnect"].firstMatch   // the menu has closed; this is the question's button
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Disconnect asks before it erases anything")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "forgets what it found there")).firstMatch.exists,
                      "the question says what is erased")
        confirm.tap()
        XCTAssertTrue(app.buttons["connect-other"].waitForExistence(timeout: 15), "after disconnecting, the providers show again")
    }
}
