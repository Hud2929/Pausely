import Foundation
import XCTest
@testable import Pausely

final class BillingFrequencyTests: XCTestCase {

    // MARK: - Display Names

    func testDisplayNames() {
        XCTAssertEqual(BillingFrequency.weekly.displayName, "Weekly")
        XCTAssertEqual(BillingFrequency.biweekly.displayName, "Every 2 Weeks")
        XCTAssertEqual(BillingFrequency.monthly.displayName, "Monthly")
        XCTAssertEqual(BillingFrequency.quarterly.displayName, "Every 3 Months")
        XCTAssertEqual(BillingFrequency.semiannual.displayName, "Every 6 Months")
        XCTAssertEqual(BillingFrequency.yearly.displayName, "Yearly")
    }

    func testShortDisplay() {
        XCTAssertEqual(BillingFrequency.weekly.shortDisplay, "/wk")
        XCTAssertEqual(BillingFrequency.biweekly.shortDisplay, "/2wk")
        XCTAssertEqual(BillingFrequency.monthly.shortDisplay, "/mo")
        XCTAssertEqual(BillingFrequency.quarterly.shortDisplay, "/3mo")
        XCTAssertEqual(BillingFrequency.semiannual.shortDisplay, "/6mo")
        XCTAssertEqual(BillingFrequency.yearly.shortDisplay, "/yr")
    }

    // MARK: - Multipliers

    func testMultiplierToMonthly() {
        XCTAssertEqual(BillingFrequency.weekly.multiplierToMonthly, Decimal(52) / 12)
        XCTAssertEqual(BillingFrequency.biweekly.multiplierToMonthly, Decimal(26) / 12)
        XCTAssertEqual(BillingFrequency.monthly.multiplierToMonthly, 1)
        XCTAssertEqual(BillingFrequency.quarterly.multiplierToMonthly, Decimal(1) / 3)
        XCTAssertEqual(BillingFrequency.semiannual.multiplierToMonthly, Decimal(1) / 6)
        XCTAssertEqual(BillingFrequency.yearly.multiplierToMonthly, Decimal(1) / 12)
    }

    func testMultiplierToYearly() {
        XCTAssertEqual(BillingFrequency.weekly.multiplierToYearly, 52)
        XCTAssertEqual(BillingFrequency.biweekly.multiplierToYearly, 26)
        XCTAssertEqual(BillingFrequency.monthly.multiplierToYearly, 12)
        XCTAssertEqual(BillingFrequency.quarterly.multiplierToYearly, 4)
        XCTAssertEqual(BillingFrequency.semiannual.multiplierToYearly, 2)
        XCTAssertEqual(BillingFrequency.yearly.multiplierToYearly, 1)
    }

    // MARK: - Identifiable

    func testIdMatchesRawValue() {
        for freq in BillingFrequency.allCases {
            XCTAssertEqual(freq.id, freq.rawValue)
        }
    }

    // MARK: - Codable Round-trip

    func testCodableRoundTrip() throws {
        for freq in BillingFrequency.allCases {
            let encoded = try JSONEncoder().encode(freq)
            let decoded = try JSONDecoder().decode(BillingFrequency.self, from: encoded)
            XCTAssertEqual(decoded, freq)
        }
    }

    // MARK: - CaseIterable

    func testAllCasesCount() {
        XCTAssertEqual(BillingFrequency.allCases.count, 6)
    }
}

// MARK: - SubscriptionStatus Tests

final class SubscriptionStatusTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(SubscriptionStatus.active.displayName, "Active")
        XCTAssertEqual(SubscriptionStatus.paused.displayName, "Paused")
        XCTAssertEqual(SubscriptionStatus.cancelled.displayName, "Cancelled")
        XCTAssertEqual(SubscriptionStatus.trial.displayName, "Trial")
        XCTAssertEqual(SubscriptionStatus.expired.displayName, "Expired")
    }

    func testIcons() {
        XCTAssertEqual(SubscriptionStatus.active.icon, "checkmark.circle.fill")
        XCTAssertEqual(SubscriptionStatus.paused.icon, "pause.circle.fill")
        XCTAssertEqual(SubscriptionStatus.cancelled.icon, "xmark.circle.fill")
        XCTAssertEqual(SubscriptionStatus.trial.icon, "clock.fill")
        XCTAssertEqual(SubscriptionStatus.expired.icon, "exclamationmark.circle.fill")
    }

    func testColors() {
        XCTAssertEqual(SubscriptionStatus.active.color, "green")
        XCTAssertEqual(SubscriptionStatus.paused.color, "orange")
        XCTAssertEqual(SubscriptionStatus.cancelled.color, "red")
        XCTAssertEqual(SubscriptionStatus.trial.color, "blue")
        XCTAssertEqual(SubscriptionStatus.expired.color, "gray")
    }

    func testCodableRoundTrip() throws {
        for status in SubscriptionStatus.allCases {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(SubscriptionStatus.self, from: encoded)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - Transitions

    func testActiveCanTransitionToPaused() {
        var sub = TestFactories.makeSubscription(status: .active)
        sub.markAsPaused(until: TestDates.addDays(30, to: Date()))
        XCTAssertEqual(sub.status, .paused)
    }

    func testPausedCanTransitionToActive() {
        var sub = TestFactories.makeSubscription(status: .paused)
        sub.pausedUntil = TestDates.addDays(30, to: Date())
        sub.resume()
        XCTAssertEqual(sub.status, .active)
        XCTAssertNil(sub.pausedUntil)
    }

    func testActiveCanTransitionToCancelled() {
        var sub = TestFactories.makeSubscription(status: .active)
        sub.markAsCancelled()
        XCTAssertEqual(sub.status, .cancelled)
    }

    func testTrialCanTransitionToActive() {
        var sub = TestFactories.makeSubscription(status: .trial)
        sub.status = .active
        XCTAssertEqual(sub.status, .active)
    }

    func testExpiredCannotBePaused() {
        var sub = TestFactories.makeSubscription(status: .expired)
        sub.markAsPaused(until: Date())
        XCTAssertEqual(sub.status, .paused)
    }
}
