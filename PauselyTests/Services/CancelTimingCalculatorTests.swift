import XCTest
@testable import Pausely

final class CancelTimingCalculatorTests: XCTestCase {

    // MARK: - cycleDays

    func testCycleDays_weekly()     { XCTAssertEqual(CancelTimingCalculator.cycleDays(for: .weekly),     7)   }
    func testCycleDays_biweekly()   { XCTAssertEqual(CancelTimingCalculator.cycleDays(for: .biweekly),   14)  }
    func testCycleDays_monthly()    { XCTAssertEqual(CancelTimingCalculator.cycleDays(for: .monthly),    30)  }
    func testCycleDays_quarterly()  { XCTAssertEqual(CancelTimingCalculator.cycleDays(for: .quarterly),  91)  }
    func testCycleDays_semiannual() { XCTAssertEqual(CancelTimingCalculator.cycleDays(for: .semiannual), 182) }
    func testCycleDays_yearly()     { XCTAssertEqual(CancelTimingCalculator.cycleDays(for: .yearly),     365) }

    // MARK: - daysUsed

    func testDaysUsed_sameDay() {
        let today = Date()
        XCTAssertEqual(CancelTimingCalculator.daysUsed(from: today, today: today), 0)
    }

    func testDaysUsed_tenDays() {
        let today = Date()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: today)!
        XCTAssertEqual(CancelTimingCalculator.daysUsed(from: tenDaysAgo, today: today), 10)
    }

    func testDaysUsed_neverNegative() {
        // Future billing date (shouldn't happen in practice) must not go negative
        let today = Date()
        let future = Calendar.current.date(byAdding: .day, value: 5, to: today)!
        XCTAssertEqual(CancelTimingCalculator.daysUsed(from: future, today: today), 0)
    }

    // MARK: - progress

    func testProgress_nilDate() {
        XCTAssertEqual(CancelTimingCalculator.progress(lastBillingDate: nil, cycleDays: 30), 0)
    }

    func testProgress_zeroCycleDays() {
        let last = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        XCTAssertEqual(CancelTimingCalculator.progress(lastBillingDate: last, cycleDays: 0), 0)
    }

    func testProgress_halfwayThrough() {
        let today = Date()
        let fifteenDaysAgo = Calendar.current.date(byAdding: .day, value: -15, to: today)!
        let p = CancelTimingCalculator.progress(lastBillingDate: fifteenDaysAgo, cycleDays: 30, today: today)
        XCTAssertEqual(p, 0.5, accuracy: 0.01)
    }

    func testProgress_clampedAt1_whenOverdue() {
        // 40 days into a 30-day cycle
        let today = Date()
        let fortyDaysAgo = Calendar.current.date(byAdding: .day, value: -40, to: today)!
        let p = CancelTimingCalculator.progress(lastBillingDate: fortyDaysAgo, cycleDays: 30, today: today)
        XCTAssertEqual(p, 1.0)
    }

    func testProgress_firstDay() {
        let today = Date()
        let p = CancelTimingCalculator.progress(lastBillingDate: today, cycleDays: 30, today: today)
        XCTAssertEqual(p, 0, accuracy: 0.001)
    }
}
