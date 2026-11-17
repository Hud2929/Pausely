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
    /// to left), `de`, `es`, `fr`, `ja` (the other languages, each in its own country's formats) or
    /// `big` (the largest text size) or `xxxl` (the largest size at which rows are still side by side).
    private var variantArguments: [String] {
        switch ProcessInfo.processInfo.environment["PAUSELY_TOUR_VARIANT"] ?? "" {
        case "ar": return ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
        case "de": return ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        case "es": return ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        case "fr": return ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        case "ja": return ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        case "big": return ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        // The largest of the ordinary sizes: rows are still side by side here, with a third more
        // text in them than at the default, so this is where a row runs out of width first.
        case "xxxl": return ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        default: return []
        }
    }

    /// The first launch, walked the way a new person walks it. Every step has to arrive: a walk
    /// that carried on without one filed the first question under the tally's name, twice, and
    /// nobody was told.
    func testFirstLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"] + variantArguments
        app.launch()
        let myGuess = app.buttons["getStartedButton"]
        XCTAssertTrue(myGuess.waitForExistence(timeout: 30), "The first question did not appear")
        sleep(2)
        capture(app, "firstrun-guess")

        // The question is whole: it ends above the slider that answers it. At the largest text
        // size the number and the slider were drawn across its fourth line.
        let question = app.staticTexts["firstRunQuestion"]
        let slider = app.sliders["guessSlider"]
        XCTAssertTrue(question.exists && slider.exists)
        XCTAssertLessThanOrEqual(question.frame.maxY, slider.frame.minY, "The slider is drawn over the question")

        if !myGuess.isHittable {
            bringIntoView(app, myGuess)
            sleep(1)
            capture(app, "firstrun-guess-scroll1")
        }
        XCTAssertTrue(myGuess.isHittable, "\"That's my guess\" cannot be reached")
        myGuess.tap()
        XCTAssertTrue(app.buttons["noneOfTheseButton"].waitForExistence(timeout: 20), "\"That's my guess\" did not lead to the tally")
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
        let showTotal = app.buttons["showTotalButton"]
        XCTAssertTrue(showTotal.waitForExistence(timeout: 10), "None of the four services could be tapped")
        sleep(1)
        capture(app, "firstrun-tally")

        // With something on the slip there is still a service on screen to tap. At the largest
        // text size the slip met the heading and there was none.
        let services = app.scrollViews.firstMatch.buttons.allElementsBoundByIndex.filter { $0.identifier != "firstRunBack" }
        XCTAssertTrue(services.contains { $0.isHittable }, "The slip leaves no service on screen")

        showTotal.tap()
        let keep = app.buttons["keepListButton"]
        XCTAssertTrue(keep.waitForExistence(timeout: 20), "\"Show me the total\" did not lead to the total")
        sleep(3)
        capture(app, "firstrun-reveal")
        if !keep.isHittable {
            // More than one screen down at the largest text size.
            bringIntoView(app, keep)
            sleep(1)
            capture(app, "firstrun-reveal-scroll1")
        }
        XCTAssertTrue(keep.isHittable, "\"Keep my list\" cannot be reached")
        keep.tap()
        // The age check on a device that has not answered it, the account form on one that has.
        // On iPad the two used to open at once and neither stayed: the walk was back on the total.
        let ageCheck = app.buttons["ageGateContinueButton"]
        let form = app.buttons["createAccountButton"]
        XCTAssertTrue(ageCheck.waitForExistence(timeout: 20) || form.waitForExistence(timeout: 5),
                      "\"Keep my list\" led to neither the age check nor the account form")
        sleep(2)
        capture(app, "firstrun-account")
    }

    func testMainTabs() throws {
        let app = launchDemo()
        capture(app, "dashboard")
        scrollCapture(app, "dashboard", times: tabScrolls)

        for (index, name) in ["subscriptions", "insights", "profile"].enumerated() {
            let app = launchDemo(tab: index + 1)
            capture(app, name)
            scrollCapture(app, name, times: tabScrolls)
        }
    }

    /// How far down a tab is followed. At the largest text size a page is two to three times as
    /// long: four screens stopped above the last section of Insights ("What went up").
    private var tabScrolls: Int {
        ProcessInfo.processInfo.environment["PAUSELY_TOUR_VARIANT"] == "big" ? 10 : 4
    }

    func testSubscriptionScreens() throws {
        let app = launchDemo(tab: 1)
        let firstRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Netflix' OR label CONTAINS[c] 'Spotify'")).firstMatch
        if firstRow.waitForExistence(timeout: 5) {
            firstRow.tap()
            sleep(2)
            capture(app, "subscription-detail")
            scrollCapture(app, "subscription-detail", times: 3)
            // By identifier. By its English name the button was found in English only, and in every
            // other language this walk ended here without a capture or a word (seen 2026-11-16).
            tap(app, "cancelSubscriptionButton")
            sleep(2)
            capture(app, "subscription-cancel")
            scrollCapture(app, "subscription-cancel", times: 2)
        } else {
            missed("subscription-detail: no row to open on the list")
        }
    }

    func testAddFlow() throws {
        let app = launchDemo()
        // By identifier, for the same reason as the walk above.
        tap(app, "homeAddButton")
        let search = app.descendants(matching: .any)["catalogSearchField"].firstMatch
        // This is the first test of a run, begun while the machine is still busy with the build,
        // and a tap then is sometimes lost: once more, if the button is still there to tap.
        if !search.waitForExistence(timeout: 8), app.buttons["homeAddButton"].firstMatch.isHittable { tap(app, "homeAddButton") }
        // Captured either way, so what did open can be seen; the line in the misses file says
        // when it was not the catalog.
        if !search.waitForExistence(timeout: 8) { missed("add: the catalog did not open from Home") }
        sleep(1)
        capture(app, "add")
        scrollCapture(app, "add", times: 2)
    }

    func testSingleScreens() throws {
        let screens: [(flags: [String], name: String)] = [
            (["--demo-verdict"], "verdict"), (["--demo-kept"], "kept"), (["--demo-cancelled"], "cancelled"),
            (["--demo-cancel"], "cancel"), (["--demo-receipt"], "receipt"),
            // On the varied list, which has several streaming services. On the first list there is one,
            // so both of these were captures of "Add two or more streaming services" (seen 2026-11-16).
            (["--varied-demo-data", "--demo-pause-plan"], "pauseplan"),
            (["--varied-demo-data", "--demo-pause-plan", "--demo-plan-active"], "pauseplan-active"),
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
            app.launchArguments = ["--uitesting", "--demo-mode"] + withList(screen.flags) + variantArguments
            app.launch()
            sleep(3)
            capture(app, screen.name)
            // The results of a mailbox are followed to their end: "Cancelled" is the last section,
            // and on the iPhone one scroll stopped two sections short of it (so a row drawn too
            // dim to read was seen only on iPad).
            scrollCapture(app, screen.name, times: screen.name == "inbox-results" ? 4 : 1)
        }
    }

    /// States no launch argument opens by itself: rows that depend on what is in the list, dialogs, a
    /// search with no match, the sheets behind a row. Each is opened here and captured like a screen.
    /// Nothing here reaches the network: sign-in, codes and purchases are left to their own tests.
    func testStates() throws {
        let varied = ["--varied-demo-data"]
        let large = ["--large-demo-data", "--demo-currency=IDR"]

        // What a list with one of everything shows on the tabs.
        for (tab, name) in [(0, "home-varied"), (1, "list-varied"), (2, "insights-varied")] where wanted(name) {
            let app = launch(varied + ["--demo-tab=\(tab)"])
            capture(app, name)
            scrollCapture(app, name, times: tabScrolls)
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
            (varied + ["--demo-verdict=Netflix"], "verdict-usage"),
            (varied + ["--demo-verdict=Adobe Creative Cloud"], "verdict-undated"),
            (varied + ["--demo-verdict=Hulu"], "verdict-cancelled"),
            (["--fresh-demo-data", "--demo-savings", "--demo-verdict=Pausely Pro"], "verdict-own"),
            (["--empty-demo-data", "--demo-verdict"], "verdict-gone"),
            (varied + ["--demo-cancel=Apple One"], "cancel-apple"),
            (["--demo-first-run=reveal", "--demo-guess=105"], "reveal-good"),
            (["--demo-first-run=reveal", "--demo-guess=400"], "reveal-less"),
            (["--demo-dates"], "dates-several"),
            (varied + ["--demo-tab=0", "--demo-plan-active"], "home-plan"),
            (varied + ["--demo-tab=2", "--demo-plan-active"], "insights-plan"),
            (varied + ["--demo-subscription=Netflix", "--demo-plan-active"], "manage-plan"),
            (varied + ["--demo-tab=3", "--demo-pro"], "profile-pro"),
            (varied + ["--demo-tab=3", "--demo-pro=trial"], "profile-pro-trial"),
            (varied + ["--demo-tab=3", "--demo-pro=ending"], "profile-pro-ending"),
            (varied + ["--demo-tab=3", "--demo-pro=problem"], "profile-pro-problem"),
            (varied + ["--demo-pause-plan", "--demo-pro"], "pauseplan-pro"),
            (["--fresh-demo-data", "--demo-tab=0", "--demo-waiting"], "home-waiting"),
            (["--quiet-demo-data", "--demo-tab=0"], "home-quiet"),
            (["--demo-splash"], "splash"),
            // A year of these is a nine-digit number of rupiah: does every amount still fit?
            (large + ["--demo-tab=0"], "home-large"),
            (large + ["--demo-tab=1"], "list-large"),
            (large + ["--demo-tab=2"], "insights-large"),
            (large + ["--demo-subscription=Coworking space"], "manage-large"),
            (large + ["--demo-subscription-edit=Adobe Creative Cloud"], "edit-large"),
            (large + ["--demo-verdict=Coworking space"], "verdict-large"),
            (large + ["--demo-wrapped=list"], "year-large"),
            (large + ["--demo-cancel=Coworking space"], "cancel-large"),
            (["--demo-paywall", "--demo-store-offline"], "paywall-offline"),
            (["--demo-paywall", "--demo-no-trial"], "paywall-notrial"),
            (["--demo-auth=signup", "--demo-form-problem"], "signup-problem"),
            (["--demo-auth=signin", "--demo-form-problem"], "signin-problem"),
            (["--demo-auth=verify", "--demo-form-problem"], "emailcode-problem"),
            (["--demo-auth=reset", "--demo-form-problem"], "resetpassword-problem"),
            (["--demo-auth=reset", "--demo-reset-code"], "resetpassword-code"),
            (["--demo-auth=newpassword", "--demo-form-problem"], "newpassword-problem"),
            (["--fresh-demo-data", "--demo-tab=0", "--demo-reminders=ask"], "home-reminders-ask"),
            (["--fresh-demo-data", "--demo-tab=0", "--demo-reminders=denied"], "home-reminders-denied"),
            (["--demo-settings=notifications", "--demo-reminders=ask"], "notifications-ask"),
            (["--demo-settings=notifications", "--demo-reminders=denied"], "notifications-denied"),
            (["--demo-settings=notifications", "--demo-reminders=on"], "notifications-on"),
            (["--demo-settings=notifications", "--demo-reminders=hidden"], "notifications-hidden"),
            (["--demo-settings=notifications", "--demo-reminders=late"], "notifications-late"),
            (["--empty-demo-data", "--demo-tab=0", "--demo-loading"], "home-loading"),
            (["--empty-demo-data", "--demo-tab=1", "--demo-loading"], "list-loading"),
            (["--empty-demo-data", "--demo-tab=2", "--demo-loading"], "insights-loading"),
            (["--empty-demo-data", "--demo-tab=0", "--demo-load-failed"], "home-notloaded"),
            (["--empty-demo-data", "--demo-tab=1", "--demo-load-failed"], "list-notloaded"),
            (["--empty-demo-data", "--demo-tab=2", "--demo-load-failed"], "insights-notloaded"),
            (["--quiet-demo-data", "--demo-pause-plan"], "pauseplan-few"),
            (varied + ["--demo-subscription=Apple One"], "manage-decide"),
            (["--demo-auth", "--demo-link-problem"], "welcome-linkproblem"),
            (["--fresh-demo-data", "--demo-tab=0", "--demo-notice"], "home-notice"),
            (["--fresh-demo-data", "--demo-tab=0", "--demo-banner"], "home-demobanner"),
        ]
        for screen in screens where wanted(screen.name) {
            let app = launch(screen.flags)
            capture(app, screen.name)
            scrollCapture(app, screen.name, times: 1)
        }

        // States behind a tap.
        state("home-year", varied + ["--demo-tab=0"]) { app in self.tap(app, "spendPeriodToggle") }
        state("home-large-year", large + ["--demo-tab=0"]) { app in self.tap(app, "spendPeriodToggle") }
        state("home-dates", varied + ["--demo-tab=0"]) { app in self.tap(app, "undatedRow") }
        // The calendar the system opens for a date: is the chosen day readable in the app's tint?
        state("dates-calendar", ["--demo-dates"]) { app in
            self.tap(app, "addDate-Netflix")
            self.tap(app, "datePicker-Netflix")
        }
        state("home-decide", varied + ["--demo-tab=0"]) { app in self.tap(app, "decideRow") }
        state("list-nomatch", varied + ["--demo-tab=1"]) { app in self.type(app, "subscriptionSearchField", "zzzz") }
        // The list's first row: a list builds its rows as they come near, so one further down does
        // not exist yet at the largest text size.
        state("list-swipe", varied + ["--demo-tab=1"]) { app in self.swipeRow(app, named: "iCloud+") }
        state("list-remove", varied + ["--demo-tab=1"]) { app in
            if self.swipeRow(app, named: "iCloud+") { self.tap(app, "swipeRemove") }
        }
        state("profile-signout", ["--fresh-demo-data", "--demo-tab=3"]) { app in self.tap(app, "signOutButton") }
        state("help-open", ["--demo-settings=help"]) { app in self.tap(app, "faq-0") }
        state("currency-nomatch", ["--demo-settings=currency"]) { app in self.type(app, "currencySearch", "zzzz") }
        state("privacy-delete", ["--demo-settings=privacy"]) { app in self.tap(app, "deleteAccountButton") }
        state("browser-nomatch", ["--demo-browser"]) { app in self.type(app, "catalogSearchField", "zzzzzz") }
        state("browser-category", ["--demo-browser"]) { app in
            // The second pill: the first is "All", and at the largest size the third is off the screen.
            let pill = app.buttons.matching(identifier: "categoryPill").element(boundBy: 1)
            if pill.waitForExistence(timeout: 4), pill.isHittable { pill.tap() }
        }
        state("plan-trial", ["--demo-tier"]) { app in
            self.tap(app, "tierTrialToggle")
            // The capture is of a trial only if the switch went on (it did not: see `tap`).
            if app.switches["tierTrialToggle"].firstMatch.value as? String != "1" { self.missed("tierTrialToggle: the switch did not turn on") }
        }
        state("paywall-monthly", ["--demo-paywall"]) { app in self.tap(app, "planMonthly") }
        state("custom-limit", varied + ["--demo-custom-add"]) { app in
            self.type(app, "serviceNameTextField", "Gym")
            self.type(app, "amountTextField", "30")
            self.tap(app, "addSubscriptionButton")
        }
        state("edit-noname", ["--demo-subscription-edit"]) { app in
            let name = app.descendants(matching: .any)["editNameField"].firstMatch
            if name.waitForExistence(timeout: 3), name.isHittable {
                // At the end of the name, wherever it wraps: a tap in the middle of the field left
                // the cursor in front of the name and deleted nothing.
                name.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.9)).tap()
                if app.keyboards.firstMatch.waitForExistence(timeout: 3) {
                    name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
                }
            }
            self.tap(app, "editSaveButton")   // the form says what is missing when asked to save
        }
        state("edit-discard", ["--demo-subscription-edit"]) { app in
            self.type(app, "editAmountField", "9")
            self.tap(app, "editCancelButton")
        }
        state("manage-remove", ["--demo-subscription"]) { app in self.tap(app, "removeSubscriptionButton") }
        // The rows under the facts, which the screen's own capture stops above at large text.
        state("manage-tools", ["--demo-subscription"]) { app in self.show(app, "pausePlanRow") }
        state("manage-usage", ["--demo-subscription"]) { app in self.tap(app, "usageRow") }
        state("manage-hours", ["--demo-subscription"]) { app in
            self.tap(app, "usageRow")
            self.tap(app, "enterUsageButton")
        }
        state("verdict-kept", varied + ["--demo-verdict=Apple One"]) { app in self.tap(app, "verdictKeepButton") }
        state("verdict-adddate", varied + ["--demo-verdict=Adobe Creative Cloud"]) { app in self.tap(app, "verdictAddDateButton") }
        state("cancel-done", ["--demo-cancel"]) { app in self.tap(app, "iCancelledItButton") }
        state("receipt-share", ["--demo-receipt"]) { app in self.tap(app, "receiptShare") }
        state("pauseplan-end", varied + ["--demo-pause-plan", "--demo-plan-active"]) { app in self.tap(app, "endPausePlanButton") }
        // The page with inboxes connected and nothing found (no made-up search ends there).
        state("inbox-connected", ["--demo-inbox=connected"]) { _ in }
        state("inbox-nothing", ["--demo-inbox=nothing"]) { _ in }
        state("inbox-failed", ["--demo-inbox=failed"]) { _ in }
        state("inbox-add", ["--demo-inbox=nothing"]) { app in self.tap(app, "addInboxButton") }
        // The mailbox page as it usually is: the app password has just been copied, so there is
        // something to paste. With nothing on the clipboard the system greys its paste button
        // out, and that was all the tour had ever captured of it.
        if wanted("inbox-connect-paste") {
            UIPasteboard.general.string = "abcd-efgh-ijkl-mnop"
            state("inbox-connect-paste", ["--demo-imap-connect"]) { _ in }
            UIPasteboard.general.items = []
        }
        state("signup-rules", ["--demo-auth=signup"]) { app in self.type(app, "passwordTextField", "abc") }
        state("newpassword-rules", ["--demo-auth=newpassword"]) { app in self.type(app, "newPasswordField", "abc") }
        state("firstrun-tally-empty", ["--demo-first-run"]) { app in self.tap(app, "getStartedButton") }
        state("reveal-price", ["--demo-first-run=reveal"]) { app in self.tap(app, "revealLine") }
        state("inbox-why", ["--demo-gmail-results"]) { app in self.tap(app, "foundRowWhy") }
    }

    /// Launches with `flags`, does `open`, and captures what is then on screen.
    private func state(_ name: String, _ flags: [String], open: (XCUIApplication) -> Void) {
        guard wanted(name) else { return }
        let app = launch(flags)
        open(app)
        sleep(2)
        capture(app, name)
    }

    /// `PAUSELY_TOUR_ONLY=name1,name2` keeps a run to those screens or states.
    private func wanted(_ name: String) -> Bool {
        let only = Set((ProcessInfo.processInfo.environment["PAUSELY_TOUR_ONLY"] ?? "").split(separator: ",").map(String.init))
        return only.isEmpty || only.contains(name)
    }

    /// Every launch starts from a list it names; one that names none gets the demo list as it is
    /// first seen. Without this a screen opened on whatever the launch before it had left behind
    /// (a quiet Home showed another list's cancellation on its Savings Receipt).
    private func withList(_ flags: [String]) -> [String] {
        let lists = ["--fresh-demo-data", "--varied-demo-data", "--empty-demo-data", "--quiet-demo-data", "--large-demo-data"]
        return flags.contains(where: lists.contains) ? flags : flags + ["--fresh-demo-data"]
    }

    private func launch(_ flags: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"] + withList(flags) + variantArguments
        app.launch()
        sleep(3)
        return app
    }

    /// Scrolls until the element is on the screen, clear of its edges. `isHittable` is true for a
    /// field that sits just below the bottom edge at the largest text size, where a tap then lands
    /// on nothing and the keyboard never comes.
    private func bringIntoView(_ app: XCUIApplication, _ element: XCUIElement) {
        let screen = app.windows.firstMatch.frame
        // What sits in a bar stays where it is: dragging the page cannot move it, and on a sheet a
        // drag downwards is the gesture that closes it. (In Arabic the tour pulled the edit sheet
        // down again and again for a "Save" that was already in reach, until an event timed out
        // and the pass ended, 2026-11-16.)
        if element.isHittable, element.frame.maxY < screen.minY + 120 { return }
        // Far off in long drags, near in short ones so it is not carried past. Eight short drags
        // were two screens: at the largest text size "Sign out", "Delete account" and "Remove"
        // are further down than that, and their dialogs were captured as the page above them.
        for _ in 0..<40 {
            let frame = element.frame
            let below = frame.maxY > screen.maxY - 70
            let above = frame.minY < screen.minY + 70
            if element.isHittable && !below && !above { return }
            let far = frame.minY > screen.maxY + screen.height / 2 || frame.maxY < screen.minY - screen.height / 2
            let reach: CGFloat = far ? 0.25 : 0.125
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.5 - reach : 0.5 + reach))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.5 + reach : 0.5 - reach))
            from.press(forDuration: 0.05, thenDragTo: to)
            sleep(1)
        }
    }

    /// A step the walk could not take is written down: the capture that follows is then of the
    /// screen before it, under the name of the state that was meant.
    private func missed(_ what: String) {
        let file = outputDir.appendingPathComponent("tour_misses.txt")
        let line = "\(what)\n"
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    /// Scrolls to the element with this identifier and leaves it on screen.
    private func show(_ app: XCUIApplication, _ identifier: String) {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        guard element.waitForExistence(timeout: 6) else { return missed("\(identifier): not on the page") }
        bringIntoView(app, element)
    }

    /// Taps the element with this identifier, scrolling to it if it is below the fold.
    private func tap(_ app: XCUIApplication, _ identifier: String) {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        // A row far down a long page is not built until the page is scrolled towards it.
        if !element.waitForExistence(timeout: 4) {
            for _ in 0..<40 where !element.exists {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
                sleep(1)
            }
        }
        guard element.exists else { return missed("\(identifier): not on the page") }
        // The button itself where there is one: in Arabic a bar's "Save" came back as what holds it.
        let button = app.buttons[identifier].firstMatch
        var target = button.exists ? button : element
        bringIntoView(app, target)
        // A switch's element is its whole row, and a tap in the middle of the row lands on its
        // words, which do nothing: the control is the switch inside it ("plan-trial" was a
        // capture of the switch still off).
        if target.elementType == .switch, target.switches.firstMatch.exists { target = target.switches.firstMatch }
        if target.isHittable { target.tap() } else { missed("\(identifier): could not be brought into reach") }
    }

    /// Swipes the list's row for this subscription, scrolling to it first: at the largest text size
    /// it is below the fold, and swiping a row that is not there ended the whole pass.
    @discardableResult
    private func swipeRow(_ app: XCUIApplication, named name: String) -> Bool {
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        guard row.waitForExistence(timeout: 4) else { return false }
        bringIntoView(app, row)
        guard row.isHittable else { return false }
        // The row's own actions are at its far end: the left in English, the right in Arabic
        // (a swipe to the left there opened "Details", and the remove dialog was never captured).
        if ProcessInfo.processInfo.environment["PAUSELY_TOUR_VARIANT"] == "ar" { row.swipeRight() } else { row.swipeLeft() }
        return true
    }

    private func type(_ app: XCUIApplication, _ identifier: String, _ text: String) {
        let field = app.descendants(matching: .any)[identifier].firstMatch
        guard field.waitForExistence(timeout: 4) else { return }
        bringIntoView(app, field)
        guard field.isHittable else { return }
        field.tap()
        // A field for a new password brings up the system's "Use Strong Password?" sheet in place of
        // the keyboard, and it covers the form ("signup-rules" was a capture of that sheet). Closed,
        // the field keeps the keyboard.
        if identifier.lowercased().contains("password"), app.buttons["GenerateStrongPasswordButton"].waitForExistence(timeout: 3) {
            app.buttons["xmark"].firstMatch.tap()
            sleep(1)
        }
        // Typing into a field that did not take the keyboard stops the whole run ("no keyboard focus").
        // At the largest text size the first tap can land before the screen has settled, so it is
        // made again at the field's centre, and nothing is typed when the keyboard still stays away.
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            guard app.keyboards.firstMatch.waitForExistence(timeout: 3) else { return }
        }
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
    private func scrollCapture(_ app: XCUIApplication, _ name: String, times: Int) {
        for index in 1...times {
            app.swipeUp()
            // Until the scroll has come to rest: the audit measured rows where they had been a
            // moment earlier and called their contrast failed.
            sleep(2)
            // A screen that fits has nothing further down: a second capture of it would be the same
            // picture and the same audit again (on iPad that was most of them, and most of the time).
            guard Self.withoutAddresses(app.debugDescription) != lastTree else { return }
            capture(app, "\(name)-scroll\(index)")
        }
    }

    /// What was on screen at the last capture: every element and where it is.
    private var lastTree = ""

    /// The element tree without the addresses of its snapshot objects, which differ every time.
    private static func withoutAddresses(_ tree: String) -> String {
        tree.replacingOccurrences(of: "0x[0-9a-f]+", with: "", options: .regularExpression)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        step += 1
        let base = String(format: "%@-%02d-%@", name.components(separatedBy: "-").first ?? name, step, name)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: outputDir.appendingPathComponent(base + ".png"))
        let tree = app.debugDescription
        lastTree = Self.withoutAddresses(tree)
        try? tree.write(to: outputDir.appendingPathComponent(base + ".txt"), atomically: true, encoding: .utf8)
        if auditing { audit(app, base) }
    }

    /// Runs the system accessibility audit on what is showing and records each issue instead of failing,
    /// so one run lists everything there is to fix.
    ///
    /// Three kinds of finding are written to their own files instead of `audit.txt`, each with the reason:
    /// - `audit_behind_bars.txt`: an element that, at this scroll position, sits behind the tab bar, the
    ///   status bar's strip or a navigation bar. The audit measures the row through the bar and calls it
    ///   low contrast or clipped; scrolled clear of the bar, the same row passes. (Found by looking up
    ///   the frame of every contrast finding on the four tabs: all of them were under a bar.) Also a
    ///   navigation bar's own button, measured while the page is scrolled under it.
    /// - `audit_system_bar.txt`: titles of navigation-bar buttons. iOS does not grow those with the text
    ///   size; it offers the Large Content Viewer for them instead. Also iPad's tab-bar titles and the
    ///   system keyboard with its suggestions.
    /// - `audit_decided.txt`: an amount field, reported as text that cannot grow at every size. It can
    ///   not: a field holds one line, so an amount as wide as the screen is drawn smaller instead of
    ///   being cut off (`AmountFit`, held by `ScreenRulesTests`).
    ///
    /// An element is placed by where it sat when the capture was taken. The audit changes the text
    /// size while it works and the page comes to rest somewhere else, so the frame it hands back is
    /// not where the element was measured (a title under the bar came back 46 points lower).
    private func audit(_ app: XCUIApplication, _ screen: String) {
        var counted: [String] = [], behindBars: [String] = [], systemBar: [String] = [], noElement: [String] = [], decided: [String] = []
        let tabBar = app.tabBars.firstMatch
        // Twelve points either side of a bar are counted with it: that is how far its edge fades the page.
        let tabBarTop = tabBar.exists ? tabBar.frame.minY - 12 : CGFloat.infinity
        let statusBarBottom = app.windows.firstMatch.exists ? max(54, app.windows.firstMatch.frame.minY + 54) : 54
        let navigationBar = app.navigationBars.firstMatch
        let topBarBottom = navigationBar.exists ? max(statusBarBottom, navigationBar.frame.maxY) : statusBarBottom
        let barButtons = Set(app.navigationBars.buttons.allElementsBoundByIndex.map { $0.identifier.isEmpty ? $0.label : $0.identifier })
        // The system keyboard and the bar of suggestions above it are not the app's to describe.
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 60 : CGFloat.infinity
        var places = Places()
        if let snapshot = try? app.snapshot() { places.read(snapshot, inBar: false) }
        let pageIsUnderTheBar = places.content.contains { $0.minY < topBarBottom - 1 && $0.maxY > statusBarBottom && $0.height < 200 }
        let amountFields: Set = ["editAmountField", "amountTextField", "tierAmountField"]
        do {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { $0.identifier.isEmpty ? $0.label : $0.identifier } ?? ""
                let reported = issue.element?.frame ?? .zero
                let frame = places.whenCaptured(element, reported: reported)
                // The detail carries what the audit says it measured.
                let detail = issue.detailedDescription.replacingOccurrences(of: "\n", with: " ")
                let place = "\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
                // An issue with no place and no name cannot be looked up on the capture, so the line
                // says what the audit did hand over: no element at all, or one that is not on screen.
                var unplaced = ""
                if frame == .zero, element.isEmpty {
                    unplaced = issue.element.map { " | element: type \($0.elementType.rawValue), \($0.exists ? "exists" : "not in the tree")" } ?? " | no element given"
                }
                let line = "\(screen) | \(issue.auditType.name) | \(issue.compactDescription) | \(element.prefix(80)) | \(place) | \(detail.prefix(200))\(unplaced)"
                let isTheBarsOwn = barButtons.contains(element) || places.inBars.contains(element)
                // The app draws its text with SwiftUI; a bare UILabel is the system's own (on iPad, the
                // four titles in the tab bar at the top), which iOS sizes itself.
                if issue.element == nil {
                    // The audit hands over no element for these (it does on the launch mark, a
                    // screen with no text at all), so there is nothing to look up or change. They
                    // are kept in a file of their own and counted there.
                    noElement.append(line)
                } else if issue.auditType == .dynamicType, barButtons.contains(element) || detail.contains("this UILabel") {
                    systemBar.append(line)
                } else if issue.auditType == .dynamicType, amountFields.contains(element) {
                    decided.append(line)
                } else if frame != .zero, frame.minY >= keyboardTop {
                    systemBar.append(line)
                } else if isTheBarsOwn {
                    if issue.auditType == .contrast, pageIsUnderTheBar { behindBars.append(line) } else { counted.append(line) }
                } else if frame != .zero, frame.maxY > tabBarTop || frame.minY < topBarBottom + 12 {
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
        append(noElement, to: "audit_no_element.txt")
        append(decided, to: "audit_decided.txt")
    }

    /// Where the named things on screen were when a capture was taken.
    private struct Places {
        /// Every frame a name was seen at (a list has many rows that say "Entertainment").
        var byName: [String: [CGRect]] = [:]
        /// The names of what a navigation bar holds: its title and its buttons.
        var inBars: Set<String> = []
        /// The frames of everything named that is not part of a navigation bar.
        var content: [CGRect] = []

        mutating func read(_ snapshot: XCUIElementSnapshot, inBar: Bool) {
            let inBar = inBar || snapshot.elementType == .navigationBar
            let name = snapshot.identifier.isEmpty ? snapshot.label : snapshot.identifier
            if !name.isEmpty, snapshot.elementType != .navigationBar {
                byName[name, default: []].append(snapshot.frame)
                if inBar { inBars.insert(name) } else if snapshot.elementType == .staticText { content.append(snapshot.frame) }
            }
            for child in snapshot.children { read(child, inBar: inBar) }
        }

        /// The frame the element had in the capture: the one of that name with the size the audit
        /// reports, when there is exactly one; otherwise what the audit reports.
        func whenCaptured(_ name: String, reported: CGRect) -> CGRect {
            guard reported != .zero, let seen = byName[name] else { return reported }
            let same = seen.filter { abs($0.width - reported.width) < 1.5 && abs($0.height - reported.height) < 1.5 && abs($0.minX - reported.minX) < 1.5 }
            let distinct = same.reduce(into: [CGRect]()) { list, frame in
                if !list.contains(where: { abs($0.minY - frame.minY) < 1.5 }) { list.append(frame) }
            }
            return distinct.count == 1 ? distinct[0] : reported
        }
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
