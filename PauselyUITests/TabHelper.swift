import XCTest

extension XCUIApplication {
    /// A tab in the system tab bar, by its old identifier. The system bar doesn't carry custom
    /// identifiers, and its labels are translated, so tabs are found by position.
    func tab(_ id: String) -> XCUIElement {
        let index = ["tabHome", "tabSubscriptions", "tabAnalysis", "tabProfile"].firstIndex(of: id) ?? 0
        return tabBars.buttons.element(boundBy: index)
    }
}

extension XCUIElement {
    /// Taps, and taps once more if the tap brought nothing. On the simulator a touch made by a test
    /// is sometimes taken back before it counts: the button is drawn pressed, then released, and its
    /// action never runs. It was seen on Cancel at the top edge of a sheet and on the main button at
    /// the bottom of the first run, with the Mac busy; the same build passed two runs in three.
    /// A button that does nothing still fails: the second tap finds it as dead as the first.
    @discardableResult
    func tap(until arrived: @autoclosure () -> Bool, within timeout: TimeInterval = 5) -> Bool {
        func waits() -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if arrived() { return true }
                usleep(200_000)
            }
            return arrived()
        }
        tap()
        if waits() { return true }
        guard exists, isHittable else { return arrived() }
        XCTContext.runActivity(named: "The tap on \(identifier.isEmpty ? label : identifier) brought nothing: tapping once more") { _ in }
        tap()
        return waits()
    }
}
