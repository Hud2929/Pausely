import XCTest
@testable import Pausely

/// The subscription list the whole app reads from. Changes land on the device first (offline-first);
/// totals, filters and history follow; whatever the cloud didn't get is queued for sync. Runs offline in
/// a `StoreSandbox`, so the live database is never touched and nothing is left behind.
@MainActor
final class SubscriptionStoreTests: XCTestCase {

    private let store = SubscriptionStore.shared
    private var sandbox: StoreSandbox!

    override func setUp() async throws {
        sandbox = StoreSandbox()
        CurrencyManager.shared.selectedCurrency = "USD"
        UserDefaults.standard.set(true, forKey: "debug_premium_override")   // the free limit has its own test
    }

    override func tearDown() async throws {
        await sandbox.restore()
        sandbox = nil
    }

    private func days(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: Date())! }
    private func add(_ sub: Subscription) async { _ = try? await store.addSubscription(sub) }
    private var queued: [SyncOperationType] { SyncQueue.shared.pendingOperations.map(\.type) }

    // MARK: Adding

    func testAddingPutsItFirstAndUpdatesTheTotals() async {
        await add(TestFactories.makeSubscription(name: "Monthly", amount: 10, billingFrequency: .monthly))
        await add(TestFactories.makeSubscription(name: "Yearly", amount: 120, billingFrequency: .yearly))
        XCTAssertEqual(store.subscriptions.map(\.name), ["Yearly", "Monthly"])
        XCTAssertEqual(store.totalMonthlySpend, 20)
        XCTAssertEqual(store.totalAnnualSpend, 240)
    }

    /// Offline isn't a failure: the change is kept, queued for sync, and a notice says so. Callers that
    /// treated the old error as "not saved" showed false errors and invited duplicate adds.
    func testAddingOfflineKeepsItQueuesItAndSaysSo() async throws {
        let sub = TestFactories.makeSubscription(name: "Offline")
        store.lastErrorMessage = nil
        let synced = try await store.addSubscription(sub)
        XCTAssertFalse(synced)
        XCTAssertEqual(store.lastErrorMessage, L10n.string("Saved on this iPhone. It will sync when you're back online."))
        XCTAssertEqual(store.subscriptions.map(\.id), [sub.id], "the subscription stays on the device")
        XCTAssertEqual(SyncQueue.shared.pendingOperations.last?.subscriptionId, sub.id)
        XCTAssertEqual(queued.last, .create)
        XCTAssertEqual(LifecycleEventLog.shared.events(for: sub.id).map(\.kind), [.added])
    }

    // MARK: Changing

    func testEditingTheAmountUpdatesTotalsAndRecordsThePriceChange() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", amount: 10)
        await add(sub)
        var edited = try XCTUnwrap(store.subscriptions.first)
        edited.amount = 12
        try await store.updateSubscription(edited)
        XCTAssertEqual(store.totalMonthlySpend, 12)
        let change = try XCTUnwrap(LifecycleEventLog.shared.events(for: sub.id).last)
        XCTAssertEqual(change.kind, .priceChanged)
        XCTAssertEqual(change.previousAmount, 10)
        XCTAssertEqual(change.amount, 12)
        XCTAssertEqual(queued.suffix(1), [.update])
    }

    func testCancellingStopsCountingItAndReactivatingCountsItAgain() async throws {
        let sub = TestFactories.makeSubscription(name: "Hulu", amount: 10)
        await add(sub)
        try await store.updateSubscriptionStatus(id: sub.id, status: .cancelled)
        XCTAssertEqual(store.totalMonthlySpend, 0)
        try await store.updateSubscriptionStatus(id: sub.id, status: .active)
        XCTAssertEqual(store.totalMonthlySpend, 10)
        XCTAssertEqual(LifecycleEventLog.shared.events(for: sub.id).map(\.kind), [.added, .cancelled, .reactivated])
        XCTAssertEqual(queued.suffix(2), [.updateStatus, .updateStatus])
    }

    func testPauseAndResume() async throws {
        let sub = TestFactories.makeSubscription(name: "Spotify")
        await add(sub)
        let until = Calendar.current.noon(of: days(30))
        try await store.pauseSubscription(id: sub.id, until: until)
        XCTAssertEqual(store.subscriptions.first?.pausedUntil, until)
        XCTAssertEqual(store.pausedSubscriptions.map(\.id), [sub.id])
        XCTAssertTrue(store.activeSubscriptions.isEmpty)

        try await store.resumeSubscription(id: sub.id)
        XCTAssertNil(store.subscriptions.first?.pausedUntil)
        XCTAssertEqual(store.activeSubscriptions.map(\.id), [sub.id])
        XCTAssertEqual(queued.suffix(2), [.pause, .resume])
    }

    func testDeletingRemovesItItsTotalAndRecordsIt() async throws {
        let keep = TestFactories.makeSubscription(name: "Keep", amount: 5)
        let gone = TestFactories.makeSubscription(name: "Gone", amount: 7)
        await add(keep)
        await add(gone)
        XCTAssertEqual(store.totalMonthlySpend, 12)
        try await store.deleteSubscription(id: gone.id)
        XCTAssertEqual(store.subscriptions.map(\.id), [keep.id])
        XCTAssertEqual(store.totalMonthlySpend, 5)
        XCTAssertEqual(LifecycleEventLog.shared.events(for: gone.id).last?.kind, .deleted)
        XCTAssertEqual(queued.suffix(1), [.delete])
    }

    // MARK: Lists and totals

    func testTotalsCountOnlyActiveSubscriptions() async {
        await add(TestFactories.makeSubscription(name: "Active", amount: 10, status: .active))
        await add(TestFactories.makeSubscription(name: "Cancelled", amount: 20, status: .cancelled))
        await add(TestFactories.makeSubscription(name: "Paused", amount: 30, status: .paused))
        await add(TestFactories.makeSubscription(name: "Expired", amount: 40, status: .expired))
        XCTAssertEqual(store.totalMonthlySpend, 10)
        XCTAssertEqual(store.totalAnnualSpend, 120)
    }

    func testUpcomingRenewalsAreTheNext30DaysOfActiveOnesInDateOrder() {
        store.subscriptions = [
            TestFactories.makeSubscription(name: "In 10 days", nextBillingDate: days(10)),
            TestFactories.makeSubscription(name: "In 60 days", billingFrequency: .yearly, nextBillingDate: days(60)),
            TestFactories.makeSubscription(name: "In 3 days", nextBillingDate: days(3)),
            TestFactories.makeSubscription(name: "Cancelled", status: .cancelled, nextBillingDate: days(5)),
            TestFactories.makeSubscription(name: "Paused", nextBillingDate: days(2), pausedUntil: days(20))
        ]
        XCTAssertEqual(store.upcomingRenewals.map(\.name), ["In 3 days", "In 10 days"])
    }

    func testFilteredSubscriptionsKeepsOrderAndStopsAtTheLimit() {
        store.subscriptions = ["Netflix", "Spotify", "Hulu", "Max"].map { TestFactories.makeSubscription(name: $0) }
        XCTAssertEqual(store.filteredSubscriptions(matching: { _ in true }, limit: 2).map(\.name), ["Netflix", "Spotify"])
        XCTAssertEqual(store.filteredSubscriptions(matching: { $0.name.contains("u") }).map(\.name), ["Hulu"])
    }
}
