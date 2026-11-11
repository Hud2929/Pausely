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

    func testCodableRoundTrip() throws {
        for status in SubscriptionStatus.allCases {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(SubscriptionStatus.self, from: encoded)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - Transitions


    func testTrialCanTransitionToActive() {
        var sub = TestFactories.makeSubscription(status: .trial)
        sub.status = .active
        XCTAssertEqual(sub.status, .active)
    }

}
