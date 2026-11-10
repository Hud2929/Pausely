import XCTest

extension XCUIApplication {
    /// A tab in the system tab bar, by its old identifier. The system bar doesn't carry custom
    /// identifiers, and its labels are translated, so tabs are found by position.
    func tab(_ id: String) -> XCUIElement {
        let index = ["tabHome", "tabSubscriptions", "tabAnalysis", "tabProfile"].firstIndex(of: id) ?? 0
        return tabBars.buttons.element(boundBy: index)
    }
}
