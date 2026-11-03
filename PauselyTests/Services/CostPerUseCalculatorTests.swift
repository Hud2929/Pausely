import Foundation
import XCTest
@testable import Pausely

final class CostPerUseCalculatorTests: XCTestCase {

    // MARK: - costPerHour

    func testCostPerHour_basic() {
        let result = CostPerUseCalculator.costPerHour(monthlyCost: Decimal(10), monthlyHoursUsed: 5)
        XCTAssertEqual(result, Decimal(2))
    }

    func testCostPerHour_zeroHoursReturnsNil() {
        let result = CostPerUseCalculator.costPerHour(monthlyCost: Decimal(10), monthlyHoursUsed: 0)
        XCTAssertNil(result)
    }

    func testCostPerHour_negativeHoursReturnsNil() {
        let result = CostPerUseCalculator.costPerHour(monthlyCost: Decimal(10), monthlyHoursUsed: -1)
        XCTAssertNil(result)
    }

    // MARK: - costPerSession

    func testCostPerSession_basic() {
        let result = CostPerUseCalculator.costPerSession(monthlyCost: Decimal(30), monthlySessions: 10)
        XCTAssertEqual(result, Decimal(3))
    }

    func testCostPerSession_zeroSessionsReturnsNil() {
        let result = CostPerUseCalculator.costPerSession(monthlyCost: Decimal(30), monthlySessions: 0)
        XCTAssertNil(result)
    }

    // MARK: - valueScore

    func testValueScore_highUsage() {
        let score = CostPerUseCalculator.valueScore(monthlyCost: Decimal(10), monthlyHoursUsed: 10)
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 50)
    }

    func testValueScore_zeroHoursReturnsNil() {
        let score = CostPerUseCalculator.valueScore(monthlyCost: Decimal(10), monthlyHoursUsed: 0)
        XCTAssertNil(score)
    }

    func testValueScore_cappedAt100() {
        let score = CostPerUseCalculator.valueScore(monthlyCost: Decimal(0), monthlyHoursUsed: 1000)
        XCTAssertEqual(score, 100)
    }

    func testValueScore_minimumZero() {
        let score = CostPerUseCalculator.valueScore(monthlyCost: Decimal(1000), monthlyHoursUsed: 1)
        XCTAssertEqual(score, 0)
    }

    // MARK: - valueTier

    func testValueTier_great() {
        let tier = CostPerUseCalculator.valueTier(costPerHour: Decimal(0.01))
        XCTAssertEqual(tier, .great)
    }

    func testValueTier_fair() {
        let tier = CostPerUseCalculator.valueTier(costPerHour: Decimal(0.05))
        XCTAssertEqual(tier, .fair)
    }

    func testValueTier_poor() {
        let tier = CostPerUseCalculator.valueTier(costPerHour: Decimal(1.0))
        XCTAssertEqual(tier, .poor)
    }

    // MARK: - valueTierLabel


    // MARK: - efficiencyScore


    // MARK: - rankedByValue

    func testRankedByValue_sortsDescending() {
        let subs = [
            TestFactories.makeSubscription(name: "Cheap", amount: 5, status: .active),
            TestFactories.makeSubscription(name: "Expensive", amount: 50, status: .active)
        ]
        let ranked = CostPerUseCalculator.rankedByValue(subscriptions: subs) { name in
            name == "Cheap" ? 10 : 1
        }
        XCTAssertEqual(ranked.first?.subscription.name, "Cheap")
    }

    func testRankedByValue_unknownAtBottom() {
        let subs = [
            TestFactories.makeSubscription(name: "A", amount: 10, status: .active),
            TestFactories.makeSubscription(name: "B", amount: 10, status: .active)
        ]
        let ranked = CostPerUseCalculator.rankedByValue(subscriptions: subs) { name in
            name == "A" ? 10 : nil
        }
        XCTAssertEqual(ranked.last?.subscription.name, "B")
    }

    // MARK: - bestValue / worstValue

    func testBestValue_limit() {
        let subs = (1...5).map {
            TestFactories.makeSubscription(name: "Sub \($0)", amount: Decimal($0), status: .active)
        }
        let best = CostPerUseCalculator.bestValue(subscriptions: subs, usageProvider: { _ in 10 }, limit: 2)
        XCTAssertEqual(best.count, 2)
    }


    // MARK: - usageRatio




    // MARK: - Alert Triggers


    // MARK: - Formatting

    func testFormatCostPerHour() {
        let formatted = CostPerUseCalculator.formatCostPerHour(Decimal(2.5), currencyCode: "USD")
        XCTAssertTrue(formatted.contains("$") || formatted.contains("2.5"))
    }

    func testFormatHours_zero() {
        XCTAssertEqual(CostPerUseCalculator.formatHours(0), "0h")
    }

    func testFormatHours_lessThanOne() {
        XCTAssertEqual(CostPerUseCalculator.formatHours(0.5), "30m")
    }

    func testFormatHours_wholeNumber() {
        XCTAssertEqual(CostPerUseCalculator.formatHours(5), "5h")
    }

    func testFormatHours_decimal() {
        XCTAssertEqual(CostPerUseCalculator.formatHours(5.5), "5.5h")
    }

    func testFormatValueScore() {
        XCTAssertEqual(CostPerUseCalculator.formatValueScore(87.5), "88")
    }
}
