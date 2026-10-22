import XCTest

/// The custom floating tab bar: every tab exists and switching works.
@MainActor
final class TabNavigationTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo-mode"]
        app.launch()
    }

    private func tab(_ id: String) -> XCUIElement { app.buttons[id].firstMatch }

    func testAllTabsExist() throws {
        for id in ["tabHome", "tabSubscriptions", "tabAnalysis", "tabProfile"] {
            XCTAssertTrue(tab(id).waitForExistence(timeout: 10), "\(id) should exist")
        }
    }

    func testNavigateBetweenTabs() throws {
        XCTAssertTrue(tab("tabHome").waitForExistence(timeout: 10))
        for id in ["tabSubscriptions", "tabAnalysis", "tabProfile", "tabHome"] {
            tab(id).tap()
            XCTAssertTrue(tab(id).isSelected, "\(id) should be selected after tapping it")
        }
    }
}
