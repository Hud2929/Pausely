import Foundation
import XCTest
@testable import Pausely

final class SubscriptionTests: XCTestCase {

    // MARK: - Monthly Cost

    func testMonthlyCost_monthly() {
        let sub = TestFactories.makeSubscription(amount: 10, billingFrequency: .monthly)
        XCTAssertEqual(sub.monthlyCost, 10)
    }

    func testMonthlyCost_yearly() {
        let sub = TestFactories.makeSubscription(amount: 120, billingFrequency: .yearly)
        XCTAssertEqual(sub.monthlyCost, 10)
    }

    func testMonthlyCost_weekly() {
        let sub = TestFactories.makeSubscription(amount: 10, billingFrequency: .weekly)
        let expected = Decimal(10) * Decimal(52) / 12
        XCTAssertEqual(sub.monthlyCost, expected)
    }

    func testMonthlyCost_biweekly() {
        let sub = TestFactories.makeSubscription(amount: 20, billingFrequency: .biweekly)
        let expected = Decimal(20) * Decimal(26) / 12
        XCTAssertEqual(sub.monthlyCost, expected)
    }

    func testMonthlyCost_quarterly() {
        let sub = TestFactories.makeSubscription(amount: 30, billingFrequency: .quarterly)
        XCTAssertEqual(sub.monthlyCost, 10)
    }

    func testMonthlyCost_semiannual() {
        let sub = TestFactories.makeSubscription(amount: 60, billingFrequency: .semiannual)
        XCTAssertEqual(sub.monthlyCost, 10)
    }

    // MARK: - Annual Cost

    func testAnnualCost_monthly() {
        let sub = TestFactories.makeSubscription(amount: 10, billingFrequency: .monthly)
        XCTAssertEqual(sub.annualCost, Decimal(10) * Decimal(12.03))
    }

    func testAnnualCost_yearly() {
        let sub = TestFactories.makeSubscription(amount: 100, billingFrequency: .yearly)
        XCTAssertEqual(sub.annualCost, 100)
    }

    func testAnnualCost_weekly() {
        let sub = TestFactories.makeSubscription(amount: 10, billingFrequency: .weekly)
        XCTAssertEqual(sub.annualCost, Decimal(10) * Decimal(52.14))
    }

    func testAnnualCost_biweekly() {
        let sub = TestFactories.makeSubscription(amount: 20, billingFrequency: .biweekly)
        XCTAssertEqual(sub.annualCost, Decimal(20) * Decimal(26.07))
    }

    func testAnnualCost_quarterly() {
        let sub = TestFactories.makeSubscription(amount: 30, billingFrequency: .quarterly)
        XCTAssertEqual(sub.annualCost, 120)
    }

    func testAnnualCost_semiannual() {
        let sub = TestFactories.makeSubscription(amount: 50, billingFrequency: .semiannual)
        XCTAssertEqual(sub.annualCost, 100)
    }

    // MARK: - Status

    func testIsActive() {
        let active = TestFactories.makeSubscription(status: .active)
        XCTAssertTrue(active.isActive)
        XCTAssertFalse(active.isPaused)
    }

    func testIsPaused() {
        var paused = TestFactories.makeSubscription(status: .active)
        paused.pausedUntil = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        XCTAssertTrue(paused.isPaused)
        XCTAssertTrue(paused.isActive)
    }

    // MARK: - Days Until Renewal

    func testDaysUntilRenewal_nilWhenNoDate() {
        let sub = TestFactories.makeSubscription(nextBillingDate: nil)
        XCTAssertNil(sub.daysUntilRenewal)
    }

    func testDaysUntilRenewal_futureDate() {
        let future = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let sub = TestFactories.makeSubscription(nextBillingDate: future)
        let days = sub.daysUntilRenewal
        XCTAssertNotNil(days)
        // Allow 6-7 due to time-of-day boundary
        XCTAssertTrue(days == 6 || days == 7, "Expected ~7 days, got \(days ?? 0)")
    }

    func testDaysUntilRenewal_pastDate() {
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let sub = TestFactories.makeSubscription(nextBillingDate: past)
        let days = sub.daysUntilRenewal
        XCTAssertNotNil(days)
        // Allow -3 to -4 due to time-of-day boundary
        XCTAssertTrue(days == -3 || days == -4, "Expected ~-3 days, got \(days ?? 0)")
    }

    // MARK: - Renewal Status

    func testRenewalStatus_unknown() {
        let sub = TestFactories.makeSubscription(nextBillingDate: nil)
        if case .unknown = sub.renewalStatus {
            // pass
        } else {
            XCTFail("Expected unknown")
        }
    }

    func testRenewalStatus_overdue() {
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let sub = TestFactories.makeSubscription(nextBillingDate: past)
        if case .overdue = sub.renewalStatus {
            // pass
        } else {
            XCTFail("Expected overdue")
        }
    }

    func testRenewalStatus_today() {
        let sub = TestFactories.makeSubscription(nextBillingDate: Date())
        if case .today = sub.renewalStatus {
            // pass
        } else {
            XCTFail("Expected today")
        }
    }

    func testRenewalStatus_soon() {
        let soon = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let sub = TestFactories.makeSubscription(nextBillingDate: soon)
        if case .soon = sub.renewalStatus {
            // pass
        } else {
            XCTFail("Expected soon")
        }
    }

    func testRenewalStatus_thisWeek() {
        let thisWeek = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let sub = TestFactories.makeSubscription(nextBillingDate: thisWeek)
        if case .thisWeek = sub.renewalStatus {
            // pass
        } else {
            XCTFail("Expected thisWeek")
        }
    }

    func testRenewalStatus_upcoming() {
        let upcoming = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let sub = TestFactories.makeSubscription(nextBillingDate: upcoming)
        if case .upcoming = sub.renewalStatus {
            // pass
        } else {
            XCTFail("Expected upcoming")
        }
    }

    // MARK: - Equatable

    func testEquatable_sameId() {
        let id = UUID()
        let a = TestFactories.makeSubscription(id: id, name: "A")
        let b = TestFactories.makeSubscription(id: id, name: "B")
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentId() {
        let a = TestFactories.makeSubscription(id: UUID(), name: "A")
        let b = TestFactories.makeSubscription(id: UUID(), name: "A")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Conversion

    func testConvertedTo() {
        let sub = TestFactories.makeSubscription(amount: 10, currency: "USD")
        let converted = sub.convertedTo(currency: "EUR", rate: Decimal(0.85))
        XCTAssertEqual(converted.amount, Decimal(8.5))
        XCTAssertEqual(converted.currency, "EUR")
    }

    // MARK: - Mutations

    func testMarkAsCancelled() {
        var sub = TestFactories.makeSubscription(status: .active)
        sub.markAsCancelled()
        XCTAssertEqual(sub.status, .cancelled)
    }

    func testMarkAsPaused() {
        var sub = TestFactories.makeSubscription(status: .active)
        let pauseDate = TestDates.addDays(30, to: Date())
        sub.markAsPaused(until: pauseDate)
        XCTAssertEqual(sub.status, .active)
        XCTAssertTrue(sub.isPaused)
        XCTAssertEqual(sub.pausedUntil, pauseDate)
    }

    func testResume() {
        var sub = TestFactories.makeSubscription(status: .active)
        sub.pausedUntil = TestDates.addDays(30, to: Date())
        sub.resume()
        XCTAssertEqual(sub.status, .active)
        XCTAssertFalse(sub.isPaused)
        XCTAssertNil(sub.pausedUntil)
    }

    // MARK: - ROI / Waste Score

    func testCalculateROI_withUsage() {
        var sub = TestFactories.makeSubscription(amount: 12, billingFrequency: .monthly)
        sub.calculateROI(usageMinutes: 120)
        XCTAssertNotNil(sub.costPerHour)
        XCTAssertNotNil(sub.roiScore)
        XCTAssertNotNil(sub.wasteScore)
    }

    func testCalculateROI_zeroUsage() {
        var sub = TestFactories.makeSubscription(amount: 10, billingFrequency: .monthly)
        sub.calculateROI(usageMinutes: 0)
        // monthlyHours = 0, so costPerHour should not be set
        XCTAssertNil(sub.costPerHour)
    }

    func testWasteLevel_unknown() {
        let sub = TestFactories.makeSubscription()
        XCTAssertEqual(sub.wasteLevel, .unknown)
    }

    func testWasteLevel_critical() {
        var sub = TestFactories.makeSubscription(amount: 10)
        sub.wasteScore = Decimal(0.1)
        XCTAssertEqual(sub.wasteLevel, .critical)
    }

    func testWasteLevel_none() {
        var sub = TestFactories.makeSubscription(amount: 10)
        sub.wasteScore = Decimal(0.9)
        XCTAssertEqual(sub.wasteLevel, .none)
    }

    func testWasteRecommendation() {
        var sub = TestFactories.makeSubscription(amount: 10)
        sub.wasteScore = Decimal(0.1)
        XCTAssertEqual(sub.wasteRecommendation, .cancelImmediately)

        sub.wasteScore = Decimal(0.9)
        XCTAssertEqual(sub.wasteRecommendation, .excellentValue)
    }

    // MARK: - Effective Price

    func testEffectivePrice_notOverridden() {
        let sub = TestFactories.makeSubscription(amount: 10, isPriceOverridden: false)
        XCTAssertEqual(sub.effectivePriceUSD, 10)
    }

    func testEffectivePrice_overridden() {
        let sub = TestFactories.makeSubscription(amount: 10, userPriceUSD: Decimal(5), isPriceOverridden: true)
        XCTAssertEqual(sub.effectivePriceUSD, 5)
    }

    func testEffectivePrice_overriddenNil() {
        let sub = TestFactories.makeSubscription(amount: 10, userPriceUSD: nil, isPriceOverridden: true)
        XCTAssertEqual(sub.effectivePriceUSD, 10)
    }

    // MARK: - Date Math for Billing

    func testNextBillingDateMonthly() {
        let start = TestDates.date(year: 2024, month: 1, day: 15)
        let next = TestDates.addMonths(1, to: start)
        let sub = TestFactories.makeSubscription(
            billingFrequency: .monthly,
            nextBillingDate: next,
            createdAt: start
        )
        XCTAssertEqual(sub.daysUntilRenewal, Calendar.current.dateComponents([.day], from: Date(), to: next).day)
    }

    func testNextBillingDateYearly() {
        let start = TestDates.date(year: 2024, month: 1, day: 1)
        let next = TestDates.addMonths(12, to: start)
        let sub = TestFactories.makeSubscription(
            billingFrequency: .yearly,
            nextBillingDate: next,
            createdAt: start
        )
        XCTAssertEqual(sub.billingFrequency, .yearly)
        XCTAssertNotNil(sub.daysUntilRenewal)
    }

    func testQuarterlyBillingCycles() {
        let start = TestDates.date(year: 2024, month: 1, day: 1)
        let next = TestDates.addMonths(3, to: start)
        let sub = TestFactories.makeSubscription(
            amount: 30,
            billingFrequency: .quarterly,
            nextBillingDate: next,
            createdAt: start
        )
        XCTAssertEqual(sub.monthlyCost, 10)
        XCTAssertEqual(sub.annualCost, 120)
    }

    func testWeeklyBillingCycles() {
        let sub = TestFactories.makeSubscription(amount: 10, billingFrequency: .weekly)
        // 52 weeks / 12 months = ~4.33 weeks per month
        let expectedMonthly = Decimal(10) * Decimal(52) / 12
        XCTAssertEqual(sub.monthlyCost, expectedMonthly)
        let expectedYearly = Decimal(10) * Decimal(52.14)
        XCTAssertEqual(sub.annualCost, expectedYearly)
    }
}
