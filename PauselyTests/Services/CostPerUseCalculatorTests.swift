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
        let score = CostPerUseCalculator.valueScore(monthlyCost: Decimal(1), monthlyHoursUsed: 1000)
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

    func testValueTierLabel_great() {
        XCTAssertEqual(CostPerUseCalculator.valueTierLabel(.great), "Great Value")
    }

    func testValueTierLabel_fair() {
        XCTAssertEqual(CostPerUseCalculator.valueTierLabel(.fair), "Fair Value")
    }

    func testValueTierLabel_poor() {
        XCTAssertEqual(CostPerUseCalculator.valueTierLabel(.poor), "Poor Value")
    }

    func testValueTierLabel_unknown() {
        XCTAssertEqual(CostPerUseCalculator.valueTierLabel(.unknown), "No Data")
    }

    // MARK: - efficiencyScore

    func testEfficiencyScore_basic() {
        let subs = [
            TestFactories.makeSubscription(name: "A", amount: 10, billingFrequency: .monthly, status: .active),
            TestFactories.makeSubscription(name: "B", amount: 20, billingFrequency: .monthly, status: .active)
        ]
        let score = CostPerUseCalculator.efficiencyScore(for: subs) { name in
            name == "A" ? 10 : 5
        }
        XCTAssertNotNil(score)
    }

    func testEfficiencyScore_ignoresInactive() {
        let subs = [
            TestFactories.makeSubscription(name: "A", amount: 10, status: .active),
            TestFactories.makeSubscription(name: "B", amount: 20, status: .paused)
        ]
        let score = CostPerUseCalculator.efficiencyScore(for: subs) { _ in 10 }
        XCTAssertNotNil(score)
    }

    func testEfficiencyScore_noDataReturnsNil() {
        let subs = [TestFactories.makeSubscription(name: "A", amount: 10, status: .active)]
        let score = CostPerUseCalculator.efficiencyScore(for: subs) { _ in nil }
        XCTAssertNil(score)
    }

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

    func testWorstValue_limit() {
        let subs = (1...5).map {
            TestFactories.makeSubscription(name: "Sub \($0)", amount: Decimal($0), status: .active)
        }
        let worst = CostPerUseCalculator.worstValue(subscriptions: subs, usageProvider: { _ in 10 }, limit: 2)
        XCTAssertEqual(worst.count, 2)
    }

    // MARK: - usageRatio

    func testUsageRatio_basic() {
        let ratio = CostPerUseCalculator.usageRatio(
            subscription1Name: "A",
            subscription2Name: "B"
        ) { name in
            name == "A" ? 10 : 5
        }
        XCTAssertEqual(ratio, 2.0)
    }

    func testUsageRatio_zeroHoursReturnsNil() {
        let ratio = CostPerUseCalculator.usageRatio(
            subscription1Name: "A",
            subscription2Name: "B"
        ) { name in
            name == "A" ? 10 : 0
        }
        XCTAssertNil(ratio)
    }

    // MARK: - costPerUseChange

    func testCostPerUseChange_increase() {
        let change = CostPerUseCalculator.costPerUseChange(
            currentCostPerHour: Decimal(15),
            previousCostPerHour: Decimal(10)
        )
        XCTAssertEqual(change, 50.0)
    }

    func testCostPerUseChange_decrease() {
        let change = CostPerUseCalculator.costPerUseChange(
            currentCostPerHour: Decimal(5),
            previousCostPerHour: Decimal(10)
        )
        XCTAssertEqual(change, -50.0)
    }

    func testCostPerUseChange_zeroPrevious() {
        let change = CostPerUseCalculator.costPerUseChange(
            currentCostPerHour: Decimal(10),
            previousCostPerHour: Decimal(0)
        )
        XCTAssertEqual(change, 0)
    }

    // MARK: - Alert Triggers

    func testShouldAlertPause_lowUsage() {
        let sub = TestFactories.makeSubscription(amount: 10, status: .active)
        XCTAssertTrue(CostPerUseCalculator.shouldAlertPause(subscription: sub, monthlyHoursUsed: 1))
    }

    func testShouldAlertPause_highUsage() {
        let sub = TestFactories.makeSubscription(amount: 10, status: .active)
        XCTAssertFalse(CostPerUseCalculator.shouldAlertPause(subscription: sub, monthlyHoursUsed: 10))
    }

    func testShouldAlertPause_inactive() {
        let sub = TestFactories.makeSubscription(amount: 10, status: .paused)
        XCTAssertFalse(CostPerUseCalculator.shouldAlertPause(subscription: sub, monthlyHoursUsed: 0))
    }

    func testShouldAlertCostIncrease() {
        XCTAssertTrue(CostPerUseCalculator.shouldAlertCostIncrease(
            currentCostPerHour: Decimal(15),
            previousCostPerHour: Decimal(10)
        ))
    }

    func testShouldAlertCostIncrease_belowThreshold() {
        XCTAssertFalse(CostPerUseCalculator.shouldAlertCostIncrease(
            currentCostPerHour: Decimal(11),
            previousCostPerHour: Decimal(10)
        ))
    }

    func testShouldAlertZeroUsage() {
        let sub = TestFactories.makeSubscription(amount: 10, status: .active)
        XCTAssertTrue(CostPerUseCalculator.shouldAlertZeroUsage(subscription: sub, monthlyHoursUsed: 0))
    }

    func testShouldAlertZeroUsage_freeSubscription() {
        let sub = TestFactories.makeSubscription(amount: 0, status: .active)
        XCTAssertFalse(CostPerUseCalculator.shouldAlertZeroUsage(subscription: sub, monthlyHoursUsed: 0))
    }

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
