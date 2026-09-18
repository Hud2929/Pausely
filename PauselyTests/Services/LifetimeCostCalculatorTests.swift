import XCTest
@testable import Pausely

final class LifetimeCostCalculatorTests: XCTestCase {

    // MARK: - projectedCost

    func testProjectedCost_oneYear() {
        XCTAssertEqual(LifetimeCostCalculator.projectedCost(monthly: Decimal(10), years: 1), 120)
    }

    func testProjectedCost_fiveYears() {
        XCTAssertEqual(LifetimeCostCalculator.projectedCost(monthly: Decimal(10), years: 5), 600)
    }

    func testProjectedCost_tenYears() {
        XCTAssertEqual(LifetimeCostCalculator.projectedCost(monthly: Decimal(10), years: 10), 1200)
    }

    func testProjectedCost_zeroMonthly() {
        XCTAssertEqual(LifetimeCostCalculator.projectedCost(monthly: Decimal(0), years: 5), 0)
    }

    func testProjectedCost_decimalPrecision() {
        // 14.99 × 12 × 1 = 179.88 (exact Decimal arithmetic)
        let cost = LifetimeCostCalculator.projectedCost(monthly: Decimal(string: "14.99")!, years: 1)
        XCTAssertEqual(cost, Decimal(string: "179.88")!)
    }

    func testProjectedCost_largeValue() {
        // $999.99/mo × 12 × 10 years = $119,998.80
        let cost = LifetimeCostCalculator.projectedCost(monthly: Decimal(string: "999.99")!, years: 10)
        XCTAssertEqual(cost, Decimal(string: "119998.80")!)
    }

    func testProjectedCost_isLinear() {
        // projectedCost(10, 2) should be exactly 2× projectedCost(10, 1)
        let one = LifetimeCostCalculator.projectedCost(monthly: Decimal(10), years: 1)
        let two = LifetimeCostCalculator.projectedCost(monthly: Decimal(10), years: 2)
        XCTAssertEqual(two, one * 2)
    }

    // MARK: - retirementCost

    func testRetirementYears_is30() {
        XCTAssertEqual(LifetimeCostCalculator.retirementYears, 30)
    }

    func testRetirementCost_equals30YearProjection() {
        let monthly = Decimal(10)
        let retirement = LifetimeCostCalculator.retirementCost(monthly: monthly)
        let thirtyYears = LifetimeCostCalculator.projectedCost(monthly: monthly, years: 30)
        XCTAssertEqual(retirement, thirtyYears)
    }

    func testRetirementCost_specificValue() {
        // $15/mo × 12 × 30 = $5,400
        XCTAssertEqual(LifetimeCostCalculator.retirementCost(monthly: Decimal(15)), 5400)
    }

    func testRetirementCost_zero() {
        XCTAssertEqual(LifetimeCostCalculator.retirementCost(monthly: Decimal(0)), 0)
    }

    // MARK: - dailyCost

    func testDailyCost_monthly30() {
        // $30/mo ÷ 30 = $1.00/day
        XCTAssertEqual(LifetimeCostCalculator.dailyCost(monthly: Decimal(30)), Decimal(1))
    }

    func testDailyCost_monthly10() {
        // $10/mo ÷ 30 = 1/3 per day — test exact Decimal equality
        let daily = LifetimeCostCalculator.dailyCost(monthly: Decimal(10))
        XCTAssertEqual(daily, Decimal(10) / 30)
    }

    func testDailyCost_zero() {
        XCTAssertEqual(LifetimeCostCalculator.dailyCost(monthly: Decimal(0)), 0)
    }

    func testDailyCost_isConsistentWithMonthly() {
        // daily × 30 should round-trip back to monthly
        let monthly = Decimal(string: "9.99")!
        let daily = LifetimeCostCalculator.dailyCost(monthly: monthly)
        XCTAssertEqual(daily * 30, monthly)
    }
}
