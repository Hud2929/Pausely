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
        XCTAssertGreaterThanOrEqual(CancelTimingCalculator.daysUsed(from: future, today: today), 0)
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

    // MARK: - valueUsed + valueRemaining

    func testValueUsed_halfProgress() {
        XCTAssertEqual(CancelTimingCalculator.valueUsed(monthlyCost: Decimal(10), progress: 0.5), Decimal(5))
    }

    func testValueRemaining_halfProgress() {
        XCTAssertEqual(CancelTimingCalculator.valueRemaining(monthlyCost: Decimal(10), progress: 0.5), Decimal(5))
    }

    func testValueUsedPlusRemainingEqualsMonthlyCost() {
        let monthly = Decimal(14)   // exact value to avoid floating-point accumulation
        let progress = 0.73
        let used = CancelTimingCalculator.valueUsed(monthlyCost: monthly, progress: progress)
        let remaining = CancelTimingCalculator.valueRemaining(monthlyCost: monthly, progress: progress)
        XCTAssertEqual(used + remaining, monthly)
    }

    func testValueUsed_zeroProgress() {
        XCTAssertEqual(CancelTimingCalculator.valueUsed(monthlyCost: Decimal(20), progress: 0), 0)
    }

    func testValueRemaining_fullProgress() {
        XCTAssertEqual(CancelTimingCalculator.valueRemaining(monthlyCost: Decimal(20), progress: 1.0), 0)
    }

    func testValueUsed_zeroCost() {
        XCTAssertEqual(CancelTimingCalculator.valueUsed(monthlyCost: Decimal(0), progress: 0.5), 0)
    }

    // MARK: - cancelAdvice

    func testCancelAdvice_good_at87Percent() {
        // 26 / 30 = 86.7% → good
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 26, daysRemaining: 4, cycleDays: 30)
        XCTAssertEqual(advice.level, .good)
        XCTAssertTrue(advice.text.contains("Great time"))
    }

    func testCancelAdvice_fair_at60Percent() {
        // 18 / 30 = 60% → fair
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 18, daysRemaining: 12, cycleDays: 30)
        XCTAssertEqual(advice.level, .fair)
        XCTAssertTrue(advice.text.contains("Decent timing"))
        XCTAssertTrue(advice.text.contains("12 days"))
    }

    func testCancelAdvice_fair_singularDay() {
        // 29 / 30 = 96.7% → actually good (>85%)
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 28, daysRemaining: 1, cycleDays: 30)
        XCTAssertEqual(advice.level, .good)
    }

    func testCancelAdvice_fair_exactlyOneDay() {
        // 17 / 30 = 56.7% → fair; 1 day remaining → singular "day"
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 17, daysRemaining: 1, cycleDays: 30)
        XCTAssertEqual(advice.level, .fair)
        XCTAssertTrue(advice.text.contains("1 day left"))
    }

    func testCancelAdvice_poor_at20Percent() {
        // 6 / 30 = 20% → poor
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 6, daysRemaining: 24, cycleDays: 30)
        XCTAssertEqual(advice.level, .poor)
        XCTAssertTrue(advice.text.contains("just got billed"))
    }

    func testCancelAdvice_poor_daysToWait_singular() {
        // cycleDays/2 = 15; daysUsed = 14; daysToWait = max(0, 15 - 14) = 1 → "1 more day"
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 14, daysRemaining: 16, cycleDays: 30)
        XCTAssertTrue(advice.text.contains("1 more day"))
    }

    func testCancelAdvice_exactlyAt85Percent() {
        // floor(0.85 * 30) = 25 days → 25/30 = 83.3% → fair (not yet good)
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 25, daysRemaining: 5, cycleDays: 30)
        XCTAssertEqual(advice.level, .fair)
    }

    func testCancelAdvice_zeroCycleDays_edgeCase() {
        // Progress = 0 when cycleDays = 0 → poor
        let advice = CancelTimingCalculator.cancelAdvice(daysUsed: 0, daysRemaining: 0, cycleDays: 0)
        XCTAssertEqual(advice.level, .poor)
    }
}
