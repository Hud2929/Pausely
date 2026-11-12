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
        XCTAssertEqual(SubscriptionStatus.cancelled.displayName, "Cancelled")
        XCTAssertEqual(SubscriptionStatus.trial.displayName, "Free trial")
    }

    /// Earlier versions had "paused" and "expired". The pause paused nothing at the service, so a row
    /// left paused is still charging; an expired one had stopped. A status nobody knows counts as
    /// charging, and none of them may stop the saved list from loading.
    func testStatusesSavedByEarlierVersionsAreStillRead() throws {
        XCTAssertEqual(SubscriptionStatus(saved: "paused"), .active)
        XCTAssertEqual(SubscriptionStatus(saved: "expired"), .cancelled)
        XCTAssertEqual(SubscriptionStatus(saved: "something new"), .active)
        XCTAssertEqual(SubscriptionStatus(saved: "trial"), .trial)

        let saved = #"[{"id":"7B8D7A51-3D59-4C1E-9E39-0A6D4D7F1C11","name":"Hulu","amount":7.99,"currency":"USD","billingFrequency":"monthly","notifyBeforeDays":3,"status":"paused","createdAt":700000000,"canPause":true,"isDetected":false,"monthlyUsageMinutes":0,"updatedAt":700000000}]"#
        let list = try JSONDecoder().decode([Subscription].self, from: Data(saved.utf8))
        XCTAssertEqual(list.map(\.status), [.active])
        XCTAssertEqual(list.first?.renewsAutomatically, true)
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
