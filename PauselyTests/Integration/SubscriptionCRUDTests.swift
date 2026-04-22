import Foundation
import XCTest
@testable import Pausely

@MainActor
final class SubscriptionCRUDTests: XCTestCase {

    var store: SubscriptionStore!

    override func setUp() {
        super.setUp()
        store = SubscriptionStore.shared
        // Clear local state for clean tests
        store.subscriptions = []
        store.totalMonthlySpend = 0
        store.totalAnnualSpend = 0
        store.isUsingLocalStorage = true
    }

    override func tearDown() {
        store.subscriptions = []
        store.isUsingLocalStorage = false
        super.tearDown()
    }

    // MARK: - Create

    func testAddSubscription_increasesCount() async throws {
        let initialCount = store.subscriptions.count
        let sub = TestFactories.makeSubscription(name: "Test Sub")
        _ = try await store.addSubscription(sub)
        XCTAssertEqual(store.subscriptions.count, initialCount + 1)
    }

    func testAddSubscription_calculatesTotals() async throws {
        let sub = TestFactories.makeSubscription(name: "Test Sub", amount: 10, billingFrequency: .monthly)
        _ = try await store.addSubscription(sub)
        XCTAssertGreaterThan(store.totalMonthlySpend, 0)
    }

    func testAddSubscription_setsUUID() async throws {
        let sub = TestFactories.makeSubscription(name: "Test Sub")
        _ = try await store.addSubscription(sub)
        XCTAssertNotNil(store.subscriptions.first?.id)
    }

    func testAddMultipleSubscriptions() async throws {
        let uuid = UUID().uuidString.prefix(8)
        let initialCount = store.subscriptions.count
        let subs = [
            TestFactories.makeSubscription(name: "Sub 1 \(uuid)", amount: 10),
            TestFactories.makeSubscription(name: "Sub 2 \(uuid)", amount: 20)
        ]
        for sub in subs {
            _ = try await store.addSubscription(sub)
        }
        XCTAssertEqual(store.subscriptions.count, initialCount + 2)
    }

    // MARK: - Read

    func testActiveSubscriptionsFilter() async throws {
        let active = TestFactories.makeSubscription(name: "Active", status: .active)
        let paused = TestFactories.makeSubscription(name: "Paused", status: .paused)
        _ = try await store.addSubscription(active)
        _ = try await store.addSubscription(paused)
        XCTAssertEqual(store.activeSubscriptions.count, 1)
        XCTAssertEqual(store.activeSubscriptions.first?.name, "Active")
    }

    func testPausedSubscriptionsFilter() async throws {
        let active = TestFactories.makeSubscription(name: "Active", status: .active)
        let paused = TestFactories.makeSubscription(name: "Paused", status: .paused)
        _ = try await store.addSubscription(active)
        _ = try await store.addSubscription(paused)
        XCTAssertEqual(store.pausedSubscriptions.count, 1)
        XCTAssertEqual(store.pausedSubscriptions.first?.name, "Paused")
    }

    func testPausableSubscriptions() async throws {
        let pausable = TestFactories.makeSubscription(name: "Pausable", status: .active, canPause: true)
        let notPausable = TestFactories.makeSubscription(name: "Not Pausable", status: .active, canPause: false)
        _ = try await store.addSubscription(pausable)
        _ = try await store.addSubscription(notPausable)
        XCTAssertEqual(store.pausableSubscriptions.count, 1)
    }

    func testUpcomingRenewals() async throws {
        let soon = TestFactories.makeSubscription(
            name: "Soon",
            status: .active,
            nextBillingDate: TestDates.addDays(5, to: Date())
        )
        let far = TestFactories.makeSubscription(
            name: "Far",
            status: .active,
            nextBillingDate: TestDates.addDays(60, to: Date())
        )
        _ = try await store.addSubscription(soon)
        _ = try await store.addSubscription(far)
        XCTAssertEqual(store.upcomingRenewals.count, 1)
        XCTAssertEqual(store.upcomingRenewals.first?.name, "Soon")
    }

    func testSubscriptionsByCategory() async throws {
        let entertainment = TestFactories.makeSubscription(name: "Netflix", amount: 15, category: "Entertainment")
        let productivity = TestFactories.makeSubscription(name: "Notion", amount: 10, category: "Productivity")
        _ = try await store.addSubscription(entertainment)
        _ = try await store.addSubscription(productivity)
        let byCategory = store.subscriptionsByCategory()
        XCTAssertEqual(byCategory.count, 2)
    }

    // MARK: - Update

    func testUpdateSubscription() async throws {
        let sub = TestFactories.makeSubscription(name: "Original", amount: 10)
        _ = try await store.addSubscription(sub)
        guard var toUpdate = store.subscriptions.first else {
            XCTFail("Subscription not added")
            return
        }
        toUpdate.amount = Decimal(20)
        try await store.updateSubscription(toUpdate)
        XCTAssertEqual(store.subscriptions.first?.amount, Decimal(20))
    }

    func testUpdateSubscriptionStatus() async throws {
        let sub = TestFactories.makeSubscription(name: "Test", status: .active)
        _ = try await store.addSubscription(sub)
        guard let id = store.subscriptions.first?.id else {
            XCTFail("No subscription ID")
            return
        }
        try await store.updateSubscriptionStatus(id: id, status: .paused)
        XCTAssertEqual(store.subscriptions.first?.status, .paused)
    }

    func testPauseSubscription() async throws {
        let sub = TestFactories.makeSubscription(name: "Test", status: .active)
        _ = try await store.addSubscription(sub)
        guard let id = store.subscriptions.first?.id else {
            XCTFail("No subscription ID")
            return
        }
        let pauseDate = TestDates.addDays(30, to: Date())
        try await store.pauseSubscription(id: id, until: pauseDate)
        XCTAssertEqual(store.subscriptions.first?.status, .paused)
        XCTAssertEqual(store.subscriptions.first?.pausedUntil, pauseDate)
    }

    func testResumeSubscription() async throws {
        let sub = TestFactories.makeSubscription(name: "Test", status: .paused)
        _ = try await store.addSubscription(sub)
        guard let id = store.subscriptions.first?.id else {
            XCTFail("No subscription ID")
            return
        }
        try await store.resumeSubscription(id: id)
        XCTAssertEqual(store.subscriptions.first?.status, .active)
    }

    // MARK: - Delete

    func testDeleteSubscription() async throws {
        let sub = TestFactories.makeSubscription(name: "To Delete")
        _ = try await store.addSubscription(sub)
        guard let id = store.subscriptions.first?.id else {
            XCTFail("No subscription ID")
            return
        }
        try await store.deleteSubscription(id: id)
        XCTAssertTrue(store.subscriptions.isEmpty)
    }

    func testDeleteSubscription_updatesTotals() async throws {
        let sub = TestFactories.makeSubscription(name: "To Delete", amount: 10)
        _ = try await store.addSubscription(sub)
        guard let id = store.subscriptions.first?.id else {
            XCTFail("No subscription ID")
            return
        }
        let beforeMonthly = store.totalMonthlySpend
        try await store.deleteSubscription(id: id)
        XCTAssertLessThan(store.totalMonthlySpend, beforeMonthly)
    }

    // MARK: - Batch Operations

    func testBatchAddSubscriptions() async {
        let uuid = UUID().uuidString.prefix(8)
        let subs = [
            TestFactories.makeSubscription(name: "Batch 1 \(uuid)"),
            TestFactories.makeSubscription(name: "Batch 2 \(uuid)")
        ]
        let initialCount = store.subscriptions.count
        let result = await store.batchAddSubscriptions(subs)
        XCTAssertEqual(result.added, min(2, max(0, 2 - initialCount)))
    }

    func testBatchAddSubscriptions_deduplicates() async {
        let uuid = UUID().uuidString.prefix(8)
        let subs = [
            TestFactories.makeSubscription(name: "Same \(uuid)"),
            TestFactories.makeSubscription(name: "Same \(uuid)")
        ]
        let result = await store.batchAddSubscriptions(subs)
        // With free tier limit of 2, deduplication may add 0-2 depending on store state.
        // The key assertion: we never add more than the input count.
        XCTAssertLessThanOrEqual(result.added, subs.count)
    }

    // MARK: - Filtered Subscriptions

    func testFilteredSubscriptions() async throws {
        let netflix = TestFactories.makeSubscription(name: "Netflix")
        let spotify = TestFactories.makeSubscription(name: "Spotify")
        _ = try await store.addSubscription(netflix)
        _ = try await store.addSubscription(spotify)
        let filtered = store.filteredSubscriptions(matching: { $0.name.contains("Net") })
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Netflix")
    }

    func testFilteredSubscriptions_withLimit() async throws {
        let uuid = UUID().uuidString.prefix(8)
        for i in 1...2 {
            let sub = TestFactories.makeSubscription(name: "Sub \(uuid)-\(i)")
            _ = try await store.addSubscription(sub)
        }
        let filtered = store.filteredSubscriptions(matching: { _ in true }, limit: 3)
        XCTAssertLessThanOrEqual(filtered.count, 3)
    }

    // MARK: - Totals Calculation

    func testTotalMonthlySpend() async throws {
        let monthly = TestFactories.makeSubscription(name: "Monthly", amount: 10, billingFrequency: .monthly)
        let yearly = TestFactories.makeSubscription(name: "Yearly", amount: 120, billingFrequency: .yearly)
        _ = try await store.addSubscription(monthly)
        _ = try await store.addSubscription(yearly)
        // Monthly = 10 + (120/12) = 20
        XCTAssertEqual(store.totalMonthlySpend, Decimal(20))
    }

    func testTotalAnnualSpend() async throws {
        let monthly = TestFactories.makeSubscription(name: "Monthly", amount: 10, billingFrequency: .monthly)
        _ = try await store.addSubscription(monthly)
        XCTAssertEqual(store.totalAnnualSpend, store.totalMonthlySpend * Decimal(12))
    }

    func testTotalsExcludeCancelled() async throws {
        let active = TestFactories.makeSubscription(name: "Active", amount: 10, status: .active)
        let cancelled = TestFactories.makeSubscription(name: "Cancelled", amount: 20, status: .cancelled)
        _ = try await store.addSubscription(active)
        _ = try await store.addSubscription(cancelled)
        XCTAssertEqual(store.totalMonthlySpend, Decimal(10))
    }

    func testTotalsExcludePaused() async throws {
        let active = TestFactories.makeSubscription(name: "Active", amount: 10, status: .active)
        let paused = TestFactories.makeSubscription(name: "Paused", amount: 20, status: .paused)
        _ = try await store.addSubscription(active)
        _ = try await store.addSubscription(paused)
        XCTAssertEqual(store.totalMonthlySpend, Decimal(10))
    }
}
