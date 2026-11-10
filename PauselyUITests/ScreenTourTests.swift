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
            for name in ["Netflix", "Spotify", "YouTube Premium", "iCloud+"] where app.buttons[name].exists {
                app.buttons[name].tap()
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
            (["--demo-settings=export"], "export"), (["--demo-whats-new"], "whatsnew"),
            (["--empty-demo-data", "--demo-tab=0"], "home-empty"), (["--empty-demo-data", "--demo-tab=1"], "list-empty"),
            (["--empty-demo-data", "--demo-tab=2"], "insights-empty"),
        ]
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "--demo-mode"] + screen.flags + variantArguments
            app.launch()
            sleep(3)
            capture(app, screen.name)
            scrollCapture(app, screen.name, times: 1)
        }
    }

    // MARK: - Helpers

    private func launchDemo(tab: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"] + (tab.map { ["--demo-tab=\($0)"] } ?? []) + variantArguments
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
    }
}
