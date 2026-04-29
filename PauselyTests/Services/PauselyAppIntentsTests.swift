import Foundation
import XCTest
@testable import Pausely

@MainActor
final class PauselyAppIntentsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure store is in known state
        SubscriptionStore.shared.subscriptions = []
    }

    override func tearDown() {
        SubscriptionStore.shared.subscriptions = []
        super.tearDown()
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

    // MARK: - GetBestValueSubscriptionIntent

    func testGetBestValueSubscriptionIntent_noActive() async throws {
        let intent = GetBestValueSubscriptionIntent()
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "You don't have any active subscriptions.")
    }

    func testGetBestValueSubscriptionIntent_findsCheapest() async throws {
        SubscriptionStore.shared.subscriptions = [
            TestFactories.makeSubscription(name: "Expensive", amount: 50, status: .active),
            TestFactories.makeSubscription(name: "Cheap", amount: 5, status: .active)
        ]
        let intent = GetBestValueSubscriptionIntent()
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("Cheap"))
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

    // MARK: - PauseSubscriptionIntent

    func testPauseSubscriptionIntent_success() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", status: .active)
        SubscriptionStore.shared.subscriptions = [sub]

        let intent = PauseSubscriptionIntent()
        intent.name = "Netflix"
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("pause reminder"))
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.first?.status, .active)
        XCTAssertNotNil(SubscriptionStore.shared.subscriptions.first?.pausedUntil)
    }

    func testPauseSubscriptionIntent_notFound() async throws {
        let intent = PauseSubscriptionIntent()
        intent.name = "Missing"
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("No subscription found"))
    }

    // MARK: - ResumeSubscriptionIntent

    func testResumeSubscriptionIntent_success() async throws {
        var sub = TestFactories.makeSubscription(name: "Netflix", status: .active)
        sub.pausedUntil = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        SubscriptionStore.shared.subscriptions = [sub]

        let intent = ResumeSubscriptionIntent()
        intent.name = "Netflix"
        let result = try await intent.perform()
        XCTAssertTrue((result.value ?? "").contains("Cleared pause reminder"))
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.first?.status, .active)
        XCTAssertNil(SubscriptionStore.shared.subscriptions.first?.pausedUntil)
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
}
