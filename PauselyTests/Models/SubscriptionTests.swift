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
        XCTAssertEqual(sub.annualCost, 120, "A monthly plan charges 12 times a year")
    }

    func testAnnualCost_yearly() {
        let sub = TestFactories.makeSubscription(amount: 100, billingFrequency: .yearly)
        XCTAssertEqual(sub.annualCost, 100)
    }

    func testAnnualCost_weekly() {
        let sub = TestFactories.makeSubscription(amount: 10, billingFrequency: .weekly)
        XCTAssertEqual(sub.annualCost, 520)
    }

    func testAnnualCost_biweekly() {
        let sub = TestFactories.makeSubscription(amount: 20, billingFrequency: .biweekly)
        XCTAssertEqual(sub.annualCost, 520)
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

    /// What is being paid for: on, or a trial that will turn into a charge.
    func testWhatIsCharging() {
        let list = [
            TestFactories.makeSubscription(name: "On", status: .active),
            TestFactories.makeSubscription(name: "Trial", status: .trial),
            TestFactories.makeSubscription(name: "Cancelled", status: .cancelled)
        ]
        XCTAssertEqual(list.charging.map(\.name), ["On", "Trial"])
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
        // Only a subscription that no longer renews keeps a date in the past; active ones roll forward
        // (see RenewalEngineTests).
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let sub = TestFactories.makeSubscription(status: .cancelled, nextBillingDate: past)
        let days = sub.daysUntilRenewal
        XCTAssertNotNil(days)
        // Allow -3 to -4 due to time-of-day boundary
        XCTAssertTrue(days == -3 || days == -4, "Expected ~-3 days, got \(days ?? 0)")
    }

    // MARK: - Renewal Status


    // MARK: - Equatable

    /// Two subscriptions are equal when everything about them is. With "same id means equal", a test
    /// comparing lists could not tell a wrong price or date from a right one, and nothing that watches
    /// for a change would see an edit.
    func testAnEditedSubscriptionIsNotEqualToWhatItWas() {
        let original = TestFactories.makeSubscription(id: UUID(), name: "Netflix", amount: 15.49)
        XCTAssertEqual(original, original)

        var repriced = original
        repriced.amount = 17.99
        XCTAssertNotEqual(repriced, original)

        var renamed = original
        renamed.name = "Netflix Premium"
        XCTAssertNotEqual(renamed, original)

        var redated = original
        redated.nextBillingDate = Calendar.billing.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 12))
        XCTAssertNotEqual(redated, original)
    }

    func testEquatable_differentId() {
        let a = TestFactories.makeSubscription(id: UUID(), name: "A")
        let b = TestFactories.makeSubscription(id: UUID(), name: "A")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Conversion


    // MARK: - Mutations


    // MARK: - ROI / Waste Score


    // MARK: - Effective Price


    // MARK: - ROI / Waste Score Edge Cases


    // MARK: - Date Math for Billing

    func testNextBillingDateMonthly() {
        let start = TestDates.date(year: 2024, month: 1, day: 15)
        let next = TestDates.addMonths(1, to: start)
        let sub = TestFactories.makeSubscription(
            billingFrequency: .monthly,
            nextBillingDate: next,
            createdAt: start
        )
        // The anchor (Feb 15, 2024) is in the past, so the subscription renews on the 15th of an upcoming month.
        let upcoming = sub.calculatedNextBillingDate!
        XCTAssertEqual(Calendar.current.component(.day, from: upcoming), 15)
        XCTAssertTrue((0...31).contains(sub.daysUntilRenewal ?? -1))
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
        XCTAssertEqual(sub.annualCost, 520)
    }
}
