import XCTest

/// Walks through the app the way a new user would and saves a screenshot and the accessibility
/// tree of every screen. Used for design reviews and App Store screenshots.
///
/// Skipped unless `PAUSELY_TOUR_DIR` is set, for example:
///   TEST_RUNNER_PAUSELY_TOUR_DIR=/tmp/tour xcodebuild test -only-testing:PauselyUITests/ScreenTourTests ...
@MainActor
final class ScreenTourTests: XCTestCase {

    private var outputDir: URL!
    private var step = 0
    /// With `PAUSELY_TOUR_AUDIT=1`, every captured screen also goes through the system's accessibility
    /// audit (contrast, text clipping, hit regions, missing descriptions, Dynamic Type), and what it finds
    /// is appended to `audit.txt` in the tour folder. The gold standard asks for that file to be empty.
    private var auditing: Bool { ProcessInfo.processInfo.environment["PAUSELY_TOUR_AUDIT"] == "1" }

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["PAUSELY_TOUR_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set PAUSELY_TOUR_DIR to run the screen tour")
        outputDir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        continueAfterFailure = true
    }

    // MARK: - Tours

    /// Extra launch arguments for a variant of the tour: `PAUSELY_TOUR_VARIANT=ar` (Arabic, right
    /// to left) or `big` (the largest text size).
    private var variantArguments: [String] {
        switch ProcessInfo.processInfo.environment["PAUSELY_TOUR_VARIANT"] ?? "" {
        case "ar": return ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
        case "big": return ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        default: return []
        }
    }

    func testFirstLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"] + variantArguments
        app.launch()
        sleep(3)
        capture(app, "firstrun-guess")
        if tapFirst(app, ["getStartedButton"]) {
            sleep(1)
            var sawPriceSheet = false
            for name in ["Netflix", "Spotify", "Apple Music", "iCloud+"] where app.buttons[name].exists && app.buttons[name].isHittable {
                app.buttons[name].tap()
                // Where the catalog has no dated price in this currency, the slip asks for one.
                let price = app.textFields["priceField"]
                if price.waitForExistence(timeout: 1) {
                    if !sawPriceSheet { capture(app, "firstrun-price"); sawPriceSheet = true }
                    price.typeText("10")
                    app.buttons["priceSaveButton"].tap()
                    sleep(1)
                }
            }
            capture(app, "firstrun-tally")
            if tapFirst(app, ["showTotalButton"]) {
                sleep(3)
                capture(app, "firstrun-reveal")
                if tapFirst(app, ["keepListButton"]) {
                    sleep(2)
                    capture(app, "firstrun-account")
                }
            }
        }
    }

    func testMainTabs() throws {
        let app = launchDemo()
        capture(app, "dashboard")
        scrollCapture(app, "dashboard", times: 4)

        for (index, name) in ["subscriptions", "insights", "profile"].enumerated() {
            let app = launchDemo(tab: index + 1)
            capture(app, name)
            scrollCapture(app, name, times: 4)
        }
    }

    func testSubscriptionScreens() throws {
        let app = launchDemo(tab: 1)
        let firstRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Netflix' OR label CONTAINS[c] 'Spotify'")).firstMatch
        if firstRow.waitForExistence(timeout: 5) {
            firstRow.tap()
            sleep(2)
            capture(app, "subscription-detail")
            scrollCapture(app, "subscription-detail", times: 3)
            if tapFirst(app, ["Cancel subscription", "Cancel Subscription"]) {
                sleep(2)
                capture(app, "subscription-cancel")
                scrollCapture(app, "subscription-cancel", times: 2)
            }
        }
    }

    func testAddFlow() throws {
        let app = launchDemo()
        if tapFirst(app, ["Add subscription", "Add", "addSubscriptionButton", "plus"]) {
            sleep(2)
            capture(app, "add")
            scrollCapture(app, "add", times: 2)
        }
    }

    func testSingleScreens() throws {
        let screens: [(flags: [String], name: String)] = [
            (["--demo-verdict"], "verdict"), (["--demo-kept"], "kept"), (["--demo-cancelled"], "cancelled"),
            (["--demo-cancel"], "cancel"), (["--demo-receipt"], "receipt"),
            (["--demo-pause-plan"], "pauseplan"), (["--demo-pause-plan", "--demo-plan-active"], "pauseplan-active"),
            (["--demo-paywall"], "paywall"), (["--demo-browser"], "browser"), (["--demo-tier"], "plan"),
            (["--demo-custom-add"], "custom"), (["--demo-subscription"], "manage"), (["--demo-subscription-edit"], "edit"),
            (["--demo-price-history"], "pricehistory"),
            (["--demo-inbox"], "inbox"), (["--demo-gmail-results"], "inbox-results"), (["--demo-imap-connect"], "inbox-connect"),
            (["--demo-wrapped"], "year"), (["--demo-auth"], "welcome"), (["--demo-auth=signup"], "signup"),
            (["--demo-auth=signin"], "signin"), (["--demo-age-gate"], "age"),
            (["--demo-settings=notifications"], "notifications"), (["--demo-settings=privacy"], "privacy"),
            (["--demo-settings=help"], "help"), (["--demo-settings=currency"], "currency"),
            (["--demo-settings=export"], "export"), (["--demo-settings=language"], "language"),
            (["--demo-whats-new"], "whatsnew"), (["--demo-auth=verify"], "emailcode"),
            (["--demo-auth=reset"], "resetpassword"), (["--demo-auth=newpassword"], "newpassword"),
            (["--empty-demo-data", "--demo-tab=0"], "home-empty"), (["--empty-demo-data", "--demo-tab=1"], "list-empty"),
            (["--empty-demo-data", "--demo-tab=2"], "insights-empty"),
        ]
        // `PAUSELY_TOUR_ONLY=paywall,age` captures only those screens: a quick second look after a fix.
        let only = Set((ProcessInfo.processInfo.environment["PAUSELY_TOUR_ONLY"] ?? "").split(separator: ",").map(String.init))
        for screen in screens where only.isEmpty || only.contains(screen.name) {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "--demo-mode"] + screen.flags + variantArguments
            app.launch()
            sleep(3)
            capture(app, screen.name)
            scrollCapture(app, screen.name, times: 1)
        }
    }

    /// States no launch argument opens by itself: rows that depend on what is in the list, dialogs, a
    /// search with no match, the sheets behind a row. Each is opened here and captured like a screen.
    /// Nothing here reaches the network: sign-in, codes and purchases are left to their own tests.
    func testStates() throws {
        let varied = ["--varied-demo-data"]

        // What a list with one of everything shows on the tabs.
        for (tab, name) in [(0, "home-varied"), (1, "list-varied"), (2, "insights-varied")] {
            let app = launch(varied + ["--demo-tab=\(tab)"])
            capture(app, name)
            scrollCapture(app, name, times: 4)
        }

        // One subscription of each kind on its own screens, and the screens that read the list.
        let screens: [(flags: [String], name: String)] = [
            (varied + ["--demo-subscription=Disney+"], "manage-trial"),
            (varied + ["--demo-subscription=Hulu"], "manage-cancelled"),
            (varied + ["--demo-subscription=Adobe Creative Cloud"], "manage-undated"),
            (varied + ["--demo-subscription=Duolingo"], "manage-abroad"),
            (varied + ["--demo-verdict=Disney+"], "verdict-trial"),
            (varied + ["--demo-verdict=Spotify"], "verdict-wentup"),
            (varied + ["--demo-verdict=Duolingo"], "verdict-abroad"),
            (varied + ["--demo-subscription-edit=Adobe Creative Cloud"], "edit-undated"),
            (varied + ["--demo-price-history=Spotify"], "pricehistory-changed"),
            (varied + ["--demo-cancel=Peloton"], "cancel-other"),
            (varied + ["--demo-pause-plan"], "pauseplan-setup"),
            (varied + ["--demo-pause-plan", "--demo-plan-active"], "pauseplan-running"),
            (varied + ["--demo-receipt=plain"], "receipt-one"),
            (varied + ["--demo-wrapped=list"], "year-varied"),
            (["--empty-demo-data", "--demo-receipt=plain"], "receipt-empty"),
            (["--empty-demo-data", "--demo-wrapped=list"], "year-empty"),
            (["--empty-demo-data", "--demo-settings=export"], "export-empty"),
            (["--demo-age-gate=underage"], "age-underage"),
            (["--demo-age-gate=locked"], "age-locked"),
        ]
        for screen in screens {
            let app = launch(screen.flags)
            capture(app, screen.name)
            scrollCapture(app, screen.name, times: 1)
        }

        // States behind a tap.
        state("home-year", varied + ["--demo-tab=0"]) { app in self.tap(app, "spendPeriodToggle") }
        state("home-dates", varied + ["--demo-tab=0"]) { app in self.tap(app, "undatedRow") }
        state("home-decide", varied + ["--demo-tab=0"]) { app in self.tap(app, "decideRow") }
        state("list-nomatch", varied + ["--demo-tab=1"]) { app in self.type(app, "subscriptionSearchField", "zzzz") }
        state("list-swipe", varied + ["--demo-tab=1"]) { app in
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Netflix'")).firstMatch.swipeLeft()
        }
        state("list-remove", varied + ["--demo-tab=1"]) { app in
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Netflix'")).firstMatch.swipeLeft()
            self.tap(app, "swipeRemove")
        }
        state("profile-signout", ["--fresh-demo-data", "--demo-tab=3"]) { app in self.tap(app, "signOutButton") }
        state("help-open", ["--demo-settings=help"]) { app in self.tap(app, "faq-0") }
        state("currency-nomatch", ["--demo-settings=currency"]) { app in self.type(app, "currencySearch", "zzzz") }
        state("privacy-delete", ["--demo-settings=privacy"]) { app in self.tap(app, "deleteAccountButton") }
        state("browser-nomatch", ["--demo-browser"]) { app in self.type(app, "catalogSearchField", "zzzzzz") }
        state("browser-category", ["--demo-browser"]) { app in
            let pills = app.buttons.matching(identifier: "categoryPill")
            if pills.count > 2 { pills.element(boundBy: 2).tap() }
        }
        state("plan-trial", ["--demo-tier"]) { app in self.tap(app, "tierTrialToggle") }
        state("custom-limit", varied + ["--demo-custom-add"]) { app in
            self.type(app, "serviceNameTextField", "Gym")
            self.type(app, "amountTextField", "30")
            self.tap(app, "addSubscriptionButton")
        }
        state("edit-noname", ["--demo-subscription-edit"]) { app in
            let name = app.descendants(matching: .any)["editNameField"].firstMatch
            if name.waitForExistence(timeout: 3) {
                name.tap()
                name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
            }
            self.tap(app, "editSaveButton")   // the form says what is missing when asked to save
        }
        state("edit-discard", ["--demo-subscription-edit"]) { app in
            self.type(app, "editAmountField", "9")
            self.tap(app, "editCancelButton")
        }
        state("manage-remove", ["--demo-subscription"]) { app in self.tap(app, "removeSubscriptionButton") }
        state("manage-usage", ["--demo-subscription"]) { app in self.tap(app, "usageRow") }
        state("manage-hours", ["--demo-subscription"]) { app in
            self.tap(app, "usageRow")
            self.tap(app, "enterUsageButton")
        }
        state("verdict-kept", varied + ["--demo-verdict=Apple One"]) { app in self.tap(app, "verdictKeepButton") }
        state("cancel-done", ["--demo-cancel"]) { app in self.tap(app, "iCancelledItButton") }
        state("receipt-share", ["--demo-receipt"]) { app in self.tap(app, "receiptShare") }
        state("pauseplan-end", varied + ["--demo-pause-plan", "--demo-plan-active"]) { app in self.tap(app, "endPausePlanButton") }
        state("inbox-add", ["--demo-gmail-results"]) { app in self.tap(app, "addInboxButton") }
        state("signup-rules", ["--demo-auth=signup"]) { app in self.type(app, "passwordTextField", "abc") }
    }

    /// Launches with `flags`, does `open`, and captures what is then on screen.
    private func state(_ name: String, _ flags: [String], open: (XCUIApplication) -> Void) {
        let app = launch(flags)
        open(app)
        sleep(2)
        capture(app, name)
    }

    private func launch(_ flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"] + flags + variantArguments
        app.launch()
        sleep(3)
        return app
    }

    /// Taps the element with this identifier, scrolling to it if it is below the fold.
    private func tap(_ app: XCUIApplication, _ identifier: String) {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        guard element.waitForExistence(timeout: 4) else { return }
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        if element.isHittable { element.tap() }
    }

    private func type(_ app: XCUIApplication, _ identifier: String, _ text: String) {
        let field = app.descendants(matching: .any)[identifier].firstMatch
        guard field.waitForExistence(timeout: 4) else { return }
        for _ in 0..<5 where !field.isHittable { app.swipeUp() }
        guard field.isHittable else { return }
        field.tap()
        field.typeText(text)
    }

    // MARK: - Helpers

    private func launchDemo(tab: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        // The demo list on every launch: without it the tabs show whatever the test before left behind.
        app.launchArguments = ["--uitesting", "--demo-mode", "--fresh-demo-data"] + (tab.map { ["--demo-tab=\($0)"] } ?? []) + variantArguments
        app.launch()
        sleep(4)
        return app
    }

    @discardableResult
    private func tapFirst(_ app: XCUIApplication, _ labels: [String]) -> Bool {
        for label in labels {
            let button = app.buttons[label].firstMatch
            if button.exists && button.isHittable {
                button.tap()
                return true
            }
        }
        return false
    }

    private func scrollCapture(_ app: XCUIApplication, _ name: String, times: Int) {
        for index in 1...times {
            app.swipeUp()
            sleep(1)
            capture(app, "\(name)-scroll\(index)")
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        step += 1
        let base = String(format: "%@-%02d-%@", name.components(separatedBy: "-").first ?? name, step, name)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: outputDir.appendingPathComponent(base + ".png"))
        try? app.debugDescription.write(to: outputDir.appendingPathComponent(base + ".txt"), atomically: true, encoding: .utf8)
        if auditing { audit(app, base) }
    }

    /// Runs the system accessibility audit on what is showing and records each issue instead of failing,
    /// so one run lists everything there is to fix.
    ///
    /// Two kinds of finding are written to their own files instead of `audit.txt`, each with the reason:
    /// - `audit_behind_bars.txt`: an element that, at this scroll position, sits behind the tab bar or the
    ///   status bar's strip. The audit measures the row through the bar and calls it low contrast or
    ///   clipped; scrolled clear of the bar, the same row passes. (Found by looking up the frame of
    ///   every contrast finding on the four tabs: all of them were under a bar.)
    /// - `audit_system_bar.txt`: titles of navigation-bar buttons. iOS does not grow those with the text
    ///   size; it offers the Large Content Viewer for them instead. Also iPad's tab-bar titles and the
    ///   system keyboard with its suggestions.
    private func audit(_ app: XCUIApplication, _ screen: String) {
        var counted: [String] = [], behindBars: [String] = [], systemBar: [String] = []
        let tabBar = app.tabBars.firstMatch
        let tabBarTop = tabBar.exists ? tabBar.frame.minY - 12 : CGFloat.infinity
        let statusBarBottom = app.windows.firstMatch.exists ? max(54, app.windows.firstMatch.frame.minY + 54) : 54
        let barButtons = Set(app.navigationBars.buttons.allElementsBoundByIndex.map { $0.identifier.isEmpty ? $0.label : $0.identifier })
        // The system keyboard and the bar of suggestions above it are not the app's to describe.
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 60 : CGFloat.infinity
        do {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { $0.identifier.isEmpty ? $0.label : $0.identifier } ?? ""
                let frame = issue.element?.frame ?? .zero
                // The detail carries what the audit says it measured.
                let detail = issue.detailedDescription.replacingOccurrences(of: "\n", with: " ")
                let place = "\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
                let line = "\(screen) | \(issue.auditType.name) | \(issue.compactDescription) | \(element.prefix(80)) | \(place) | \(detail.prefix(200))"
                // The app draws its text with SwiftUI; a bare UILabel is the system's own (on iPad, the
                // four titles in the tab bar at the top), which iOS sizes itself.
                if issue.auditType == .dynamicType, barButtons.contains(element) || detail.contains("this UILabel") {
                    systemBar.append(line)
                } else if frame != .zero, frame.minY >= keyboardTop {
                    systemBar.append(line)
                } else if frame != .zero, frame.maxY > tabBarTop || frame.minY < statusBarBottom {
                    behindBars.append(line)
                } else {
                    counted.append(line)
                }
                return true
            }
        } catch {
            counted.append("\(screen) | audit could not run | \(error.localizedDescription)")
        }
        // Not the system's audit, the tour's own: a scroll view is only as wide as what it holds, so
        // one with little in it shrinks, sits in the middle and leaves its screen unpainted beside it
        // (the empty Insights tab did, in Arabic, at the largest text and on iPad).
        // Checked at phone width, and only for a scroll view that reaches the top of the screen: a
        // sheet or a menu starts lower and is rightly narrower than the window, here and on iPad.
        let window = app.windows.firstMatch.frame.width
        if window < 500 {
            for scroll in app.scrollViews.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex
            where scroll.exists && scroll.frame.minY < 10 && scroll.frame.height > 200 && scroll.frame.width < window - 1 {
                counted.append("\(screen) | layout | Scroll view narrower than its screen |  | \(Int(scroll.frame.minX)),\(Int(scroll.frame.minY)) \(Int(scroll.frame.width))x\(Int(scroll.frame.height)) | \(Int(scroll.frame.width)) points wide in a \(Int(window))-point window")
            }
        }
        append(counted, to: "audit.txt")
        append(behindBars, to: "audit_behind_bars.txt")
        append(systemBar, to: "audit_system_bar.txt")
    }

    private func append(_ lines: [String], to file: String) {
        guard !lines.isEmpty else { return }
        let url = outputDir.appendingPathComponent(file)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

private extension XCUIAccessibilityAuditType {
    /// The kind of issue, in a word, for the audit file.
    var name: String {
        switch self {
        case .contrast: return "contrast"
        case .elementDetection: return "element not detected"
        case .hitRegion: return "hit region"
        case .sufficientElementDescription: return "description"
        case .dynamicType: return "dynamic type"
        case .textClipped: return "text clipped"
        case .trait: return "trait"
        default: return "other(\(rawValue))"
        }
    }
}
