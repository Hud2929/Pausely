import Foundation
import XCTest
@testable import Pausely

@MainActor
final class PauselyAppIntentsTests: XCTestCase {

    private var sandbox: StoreSandbox!

    override func setUp() async throws {
        sandbox = StoreSandbox()   // an empty list, offline, put back afterwards
    }

    override func tearDown() async throws {
        await sandbox.restore()
        sandbox = nil
    }

    // MARK: - GetMonthlySpendIntent

    func testGetMonthlySpendIntent_noSubscriptions() async throws {
        let intent = GetMonthlySpendIntent()
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("0.00") || (result.value ?? "").contains("$0"))
    }

    func testGetMonthlySpendIntent_withSubscriptions() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", amount: 15.99, status: .active)
        SubscriptionStore.shared.subscriptions = [sub]
        SubscriptionStore.shared.totalMonthlySpend = sub.monthlyCost

        let intent = GetMonthlySpendIntent()
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("15.99"))
    }

    // MARK: - GetSubscriptionCountIntent

    func testGetSubscriptionCountIntent_empty() async throws {
        let intent = GetSubscriptionCountIntent()
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "You're tracking 0 subscriptions, 0 active.")
    }

    func testGetSubscriptionCountIntent_mixed() async throws {
        SubscriptionStore.shared.subscriptions = [
            TestFactories.makeSubscription(name: "A", status: .active),
            TestFactories.makeSubscription(name: "B", status: .paused)
        ]
        let intent = GetSubscriptionCountIntent()
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "You're tracking 2 subscriptions, 1 active.")
    }

    // MARK: - GetUpcomingRenewalsIntent

    func testGetUpcomingRenewalsIntent_none() async throws {
        let intent = GetUpcomingRenewalsIntent()
        intent.daysAhead = 7
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("No subscriptions renewing"))
    }

    func testGetUpcomingRenewalsIntent_oneUpcoming() async throws {
        let future = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        SubscriptionStore.shared.subscriptions = [
            TestFactories.makeSubscription(name: "Hulu", amount: 12.99, status: .active, nextBillingDate: future)
        ]
        let intent = GetUpcomingRenewalsIntent()
        intent.daysAhead = 7
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("Hulu"))
        // Allow 2-3 days due to time-of-day boundary
        XCTAssertTrue((result.value ?? "").contains("in 2 days") || (result.value ?? "").contains("in 3 days"))
    }

    // MARK: - GetSubscriptionDetailIntent

    func testGetSubscriptionDetailIntent_found() async throws {
        SubscriptionStore.shared.subscriptions = [
            TestFactories.makeSubscription(name: "Spotify", amount: 9.99, status: .active)
        ]
        let intent = GetSubscriptionDetailIntent()
        intent.name = "Spotify"
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("Spotify"))
        XCTAssertTrue((result.value ?? "").contains("Active"))
    }

    func testGetSubscriptionDetailIntent_notFound() async throws {
        let intent = GetSubscriptionDetailIntent()
        intent.name = "NonExistent"
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("No subscription found"))
    }

    // MARK: - DeleteSubscriptionIntent

    func testDeleteSubscriptionIntent_success() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", status: .active)
        SubscriptionStore.shared.subscriptions = [sub]

        let intent = DeleteSubscriptionIntent()
        intent.name = "Netflix"
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "Deleted Netflix.")
        XCTAssertTrue(SubscriptionStore.shared.subscriptions.isEmpty)
    }

    /// "Delete Apple" used to remove whichever subscription with "apple" in its name came first.
    func testDeletingNeedsANameThatMeansExactlyOneSubscription() async throws {
        SubscriptionStore.shared.subscriptions = [
            TestFactories.makeSubscription(name: "Apple One"),
            TestFactories.makeSubscription(name: "Apple Music"),
            TestFactories.makeSubscription(name: "Max")
        ]
        let intent = DeleteSubscriptionIntent()
        intent.name = "apple"
        var result = try await intent.perform()
        XCTAssertEqual(result.value, "2 subscriptions match 'apple': Apple One, Apple Music. Say the full name.")
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.count, 3, "nothing was removed")

        intent.name = "apple music"
        result = try await intent.perform()
        XCTAssertEqual(result.value, "Deleted Apple Music.")
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.map(\.name), ["Apple One", "Max"])
    }

    func testAnExactNameWinsOverNamesThatContainIt() {
        let list = [TestFactories.makeSubscription(name: "HBO Max"), TestFactories.makeSubscription(name: "Max")]
        guard case .one(let found) = NamedSubscription.find(" max ", in: list) else { return XCTFail("exact name not found") }
        XCTAssertEqual(found.name, "Max")
        guard case .one(let only) = NamedSubscription.find("hbo", in: list) else { return XCTFail("the only match was not used") }
        XCTAssertEqual(only.name, "HBO Max")
        guard case .none = NamedSubscription.find("netflix", in: list) else { return XCTFail() }
        guard case .none = NamedSubscription.find("  ", in: list) else { return XCTFail("an empty name matches nothing") }
    }

    // MARK: - What the Shortcuts say

    /// Anything that was not active used to be reported as "Paused", and a cancelled subscription
    /// as renewing "in -3 days".
    func testDetailReportsTheRealStatusAndNoRenewalForWhatWillNotCharge() async throws {
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        SubscriptionStore.shared.subscriptions = [
            TestFactories.makeSubscription(name: "Hulu", amount: 10, status: .cancelled, nextBillingDate: past),
            TestFactories.makeSubscription(name: "Crave", amount: 10, status: .trial, nextBillingDate: nil)
        ]
        let intent = GetSubscriptionDetailIntent()
        intent.name = "Hulu"
        var result = try await intent.perform()
        XCTAssertEqual(result.value, "Hulu: \(MoneyFormat.string(Decimal(10), "USD"))/month, Cancelled.")
        intent.name = "Crave"
        result = try await intent.perform()
        XCTAssertEqual(result.value, "Crave: \(MoneyFormat.string(Decimal(10), "USD"))/month, Trial. No renewal date.")
    }

    /// The person gave a name and a price, not a date, so none is saved as theirs.
    func testAddingByShortcutDoesNotInventARenewalDate() async throws {
        UserDefaults.standard.set(true, forKey: "debug_premium_override")
        let intent = AddSubscriptionIntent()
        intent.name = "Gym"
        intent.monthlyCost = 30
        _ = try await intent.perform()
        let added = try XCTUnwrap(SubscriptionStore.shared.subscriptions.first)
        XCTAssertEqual(added.name, "Gym")
        XCTAssertNil(added.nextBillingDate)
    }
}
