import XCTest
@testable import Pausely

/// The forecast on the Analysis tab. A subscription with no usage logged is unknown, not unused:
/// it must never be counted as a cut.
final class SpendingForecastTests: XCTestCase {

    func testUnloggedSubscriptionsStayInBothTotals() {
        // Only Netflix has usage logged. The other two must not vanish from the forecast.
        let totals = RealInsightsEngine.forecastTotals(
            [(monthly: 15.99, minutesLogged: 140), (monthly: 44, minutesLogged: nil), (monthly: 20, minutesLogged: nil)],
            pointedSavings: 0)
        XCTAssertEqual(totals.optimized, Decimal(string: "79.99"))
        XCTAssertEqual(totals.aggressive, Decimal(string: "79.99"))
    }

    func testLoggedZeroIsCutAndLightUseOnlyInTheLowerFigure() {
        let totals = RealInsightsEngine.forecastTotals(
            [(monthly: 10, minutesLogged: 0), (monthly: 20, minutesLogged: 10), (monthly: 30, minutesLogged: 45), (monthly: 5, minutesLogged: nil)],
            pointedSavings: 0)
        XCTAssertEqual(totals.optimized, 55)   // 20 + 30 + 5
        XCTAssertEqual(totals.aggressive, 35)  // 30 + 5
    }

    func testWithoutUsageOnlyPointedSavingsAreCut() {
        let totals = RealInsightsEngine.forecastTotals(
            [(monthly: 10, minutesLogged: nil), (monthly: 20, minutesLogged: nil)], pointedSavings: 4)
        XCTAssertEqual(totals.optimized, 26)
        XCTAssertEqual(totals.aggressive, 26)
    }

    func testPointedSavingsNeverGoBelowZero() {
        let totals = RealInsightsEngine.forecastTotals([(monthly: 10, minutesLogged: nil)], pointedSavings: 50)
        XCTAssertEqual(totals.optimized, 0)
    }
}
