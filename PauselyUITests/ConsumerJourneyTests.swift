import XCTest

/// A new person's first session, start to finish: onboarding, adding subscriptions from the catalog
/// and by hand, hitting the free plan's limit, editing, cancelling, and the other tabs. Saves a
/// screenshot and the accessibility tree of every step for review, and asserts what a person would
/// expect to see. Runs only with `TEST_RUNNER_PAUSELY_JOURNEY_DIR` set.
@MainActor
final class ConsumerJourneyTests: XCTestCase {

    private var outputDir: URL!
    private var step = 0

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["PAUSELY_JOURNEY_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set PAUSELY_JOURNEY_DIR to run the consumer journey")
        outputDir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        continueAfterFailure = true
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        step += 1
        let base = String(format: "%02d-%@", step, name)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: outputDir.appendingPathComponent(base + ".png"))
        try? app.debugDescription.write(to: outputDir.appendingPathComponent(base + ".txt"), atomically: true, encoding: .utf8)
    }

    private func waitHittable(_ element: XCUIElement, _ timeout: TimeInterval = 8) -> Bool {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: element)
        return XCTWaiter.wait(for: [hittable], timeout: timeout) == .completed
    }

    private func card(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func tapIfThere(_ app: XCUIApplication, _ labels: [String], timeout: TimeInterval = 2) -> Bool {
        for label in labels {
            let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@", label, label)).firstMatch
            if button.waitForExistence(timeout: timeout), button.isHittable { button.tap(); return true }
        }
        return false
    }

    /// Searches the catalog, opens the service, and adds it with its default plan.
    @discardableResult
    private func addFromCatalog(_ app: XCUIApplication, _ query: String, shot: String) -> Bool {
        let search = app.textFields["catalogSearchField"]
        guard search.waitForExistence(timeout: 5) else { return false }
        search.tap()
        if let current = search.value as? String, !current.isEmpty, current != search.placeholderValue {
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        search.typeText(query)
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", query)).firstMatch
        guard result.waitForExistence(timeout: 5) else { capture(app, shot + "-no-result"); return false }
        capture(app, shot + "-search")
        result.tap()
        let add = app.buttons["tierAddButton"]
        guard add.waitForExistence(timeout: 5) else { capture(app, shot + "-no-plan-sheet"); return false }
        capture(app, shot + "-plan")
        add.tap()
        return true
    }

    func testANewPersonsFirstSession() throws {
        // 1. Onboarding, as on a fresh install.
        var app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "-AppleLanguages", "(en)"]
        app.launch()
        let getStarted = app.buttons["getStartedButton"]
        XCTAssertTrue(waitHittable(getStarted, 12))
        capture(app, "onboarding-1")
        app.swipeLeft(); capture(app, "onboarding-2")
        app.swipeLeft(); capture(app, "onboarding-3")
        getStarted.tap()
        _ = app.staticTexts["Confirm your age"].waitForExistence(timeout: 8)
        capture(app, "age-check")
        app.terminate()

        // 2. The app with nothing in it yet (sign-up needs a real account, so this runs in demo mode).
        app = XCUIApplication()
        // The free plan, whatever this simulator's debug switches say.
        app.launchArguments = ["--uitesting", "--demo-mode", "--empty-demo-data", "-AppleLanguages", "(en)",
                               "-debug_free_pro", "NO", "-debug_premium_override", "NO"]
        app.launch()
        XCTAssertTrue(waitHittable(app.buttons["tabHome"].firstMatch, 15), "the app opens past the splash")
        sleep(1)
        capture(app, "home-empty")
        app.buttons["tabSubscriptions"].firstMatch.tap()
        sleep(1)   // let the tab switch finish
        capture(app, "subs-empty")

        // 3. Add three from the catalog (the header's + button).
        let addButton = app.buttons.matching(NSPredicate(format: "identifier == 'addSubscriptionButton' AND label == 'Add subscription'")).firstMatch
        XCTAssertTrue(waitHittable(addButton, 6), "the list offers an add button")
        addButton.tap()
        XCTAssertTrue(app.textFields["catalogSearchField"].waitForExistence(timeout: 8), "the catalog opens")
        capture(app, "catalog")
        XCTAssertTrue(addFromCatalog(app, "Netflix", shot: "netflix"))
        capture(app, "netflix-added")
        XCTAssertTrue(addFromCatalog(app, "Spotify", shot: "spotify"))
        XCTAssertTrue(addFromCatalog(app, "Disney", shot: "disney"))

        // 4. One by hand.
        app.buttons["Custom"].firstMatch.tap()
        let name = app.textFields["serviceNameTextField"]
        if name.waitForExistence(timeout: 5) {
            name.tap(); name.typeText("Gym membership")
            let amount = app.textFields["amountTextField"]
            amount.tap(); amount.typeText("45")
            capture(app, "custom-filled")
            app.buttons["addSubscriptionButton"].firstMatch.tap()
        }
        capture(app, "custom-added")

        // 5. The fifth fills the free plan; the sixth should explain the limit.
        XCTAssertTrue(addFromCatalog(app, "Notion", shot: "notion"))
        addFromCatalog(app, "Hulu", shot: "sixth")
        sleep(1)
        capture(app, "sixth-result")
        let notice = app.staticTexts["freeLimitNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 4), "a sixth subscription on the free plan should explain the limit")
        XCTAssertEqual(notice.label, "Free covers 5 subscriptions. Pro tracks all of them.")
        // Back out to the list, whatever is showing.
        for _ in 0..<4 {
            if app.buttons["tabSubscriptions"].firstMatch.isHittable { break }
            if !tapIfThere(app, ["OK", "Not now", "Maybe later", "Close", "Done"], timeout: 1) { app.swipeDown(velocity: .fast) }
        }

        // 6. The list.
        XCTAssertTrue(card(app, "Netflix").waitForExistence(timeout: 8), "Netflix is on the list")
        capture(app, "list")
        XCTAssertFalse(card(app, "Hulu").exists, "the sixth isn't added on the free plan")

        // 7. Open one, edit its price.
        card(app, "Netflix").tap()
        XCTAssertTrue(app.buttons["removeSubscriptionButton"].waitForExistence(timeout: 6), "tapping a card opens it")
        capture(app, "detail")
        let edit = app.buttons["editSubscriptionButton"]
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            capture(app, "edit")
            let price = app.textFields.matching(NSPredicate(format: "identifier CONTAINS[c] 'amount' OR identifier CONTAINS[c] 'price'")).firstMatch
            if price.waitForExistence(timeout: 3) {
                price.tap()
                price.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "19.99")
                capture(app, "edit-price")
            }
            app.buttons.matching(NSPredicate(format: "label == 'Save' OR identifier CONTAINS[c] 'save'")).firstMatch.tap()
            capture(app, "after-edit")
        }

        // 8. Cancel it.
        let cancel = app.buttons["cancelSubscriptionButton"]
        for _ in 0..<5 where !(cancel.exists && cancel.isHittable) { app.swipeUp() }
        if cancel.exists {
            cancel.tap()
            capture(app, "cancel-flow")
            _ = tapIfThere(app, ["I cancelled it"], timeout: 4)
            sleep(2)
            capture(app, "celebration")
            if tapIfThere(app, ["Rate How Hard It Was →", "Rate How Hard It Was"], timeout: 3) {
                sleep(1)
                capture(app, "rate")
                _ = tapIfThere(app, ["Super Easy"])
                _ = tapIfThere(app, ["Submit Rating", "Skip"])
            }
            sleep(1)
            capture(app, "after-cancel")
        }
        for _ in 0..<4 {
            if app.buttons["tabHome"].firstMatch.isHittable { break }
            if !tapIfThere(app, ["subscriptionDoneButton", "Done", "Close"], timeout: 1) { app.swipeDown(velocity: .fast) }
        }

        // 9. The other tabs.
        XCTAssertTrue(waitHittable(app.buttons["tabHome"].firstMatch, 6), "back on the tabs")
        app.buttons["tabHome"].firstMatch.tap()
        sleep(1)
        capture(app, "home")
        app.swipeUp(); capture(app, "home-scrolled")
        app.buttons["tabAnalysis"].firstMatch.tap()
        capture(app, "analysis")
        app.buttons["tabProfile"].firstMatch.tap()
        capture(app, "profile")
        let receipt = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Savings Receipt'")).firstMatch
        if receipt.waitForExistence(timeout: 3) {
            receipt.tap()
            sleep(1)
            capture(app, "savings-receipt")
        }
    }
}
