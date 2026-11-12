import Foundation
import XCTest
@testable import Pausely

// MARK: - Mock Data Factories

enum TestFactories {

    static func makeSubscription(
        id: UUID = UUID(),
        name: String = "Netflix",
        amount: Decimal = 15.49,
        currency: String = "USD",
        billingFrequency: BillingFrequency = .monthly,
        status: SubscriptionStatus = .active,
        nextBillingDate: Date? = nil,
        monthlyUsageMinutes: Int = 120,
        category: String = "Entertainment",
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        canPause: Bool = true
    ) -> Subscription {
        Subscription(
            id: id,
            name: name,
            category: category,
            amount: amount,
            currency: currency,
            billingFrequency: billingFrequency,
            nextBillingDate: nextBillingDate,
            monthlyUsageMinutes: monthlyUsageMinutes,
            status: status,
            canPause: canPause,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }


}

// MARK: - Async Test Helpers

extension XCTestCase {


}

// MARK: - Date Helpers

enum TestDates {
    static var calendar: Calendar { Calendar.current }

    static func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func addMonths(_ months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }
}

// MARK: - Currency Test Helpers

enum CurrencyTestHelpers {
    static func withRates(_ rates: [String: Double], body: () -> Void) {
        let manager = CurrencyManager.shared
        let originalRates = manager.exchangeRates
        manager.exchangeRates = rates
        body()
        manager.exchangeRates = originalRates
    }
}

// MARK: - Subscription store sandbox

/// Stands in for the account's `subscriptions` table. Offline until a test says otherwise; it can
/// refuse, and it can let something happen on the phone while a change is on its way.
@MainActor
final class FakeSyncTransport: SyncTransport {
    var canSend = false
    /// What the account holds.
    private(set) var rows: [UUID: Subscription] = [:]
    /// Every request that left the phone, in order ("create Netflix", "update Netflix", "delete").
    private(set) var calls: [String] = []
    /// When set, every request fails with it and the account is not changed.
    var failure: Error?
    /// Runs once, after the next request has reached the account and before its answer is back.
    var whileSending: (() -> Void)?

    /// A row that is already on the account (put there by another device, or earlier).
    func hold(_ subscription: Subscription) { rows[subscription.id] = subscription }

    func create(_ subscription: Subscription) async throws {
        try await request("create \(subscription.name)") { rows[subscription.id] = subscription }
    }

    func update(_ subscription: Subscription) async throws {
        try await request("update \(subscription.name)") {
            if rows[subscription.id] != nil { rows[subscription.id] = subscription }
        }
    }

    func delete(id: UUID) async throws {
        try await request("delete") { rows[id] = nil }
    }

    private func request(_ call: String, _ apply: () -> Void) async throws {
        calls.append(call)
        if let failure { throw failure }
        apply()
        await Task.yield()
        if let hook = whileSending {
            whileSending = nil
            hook()
        }
    }
}

/// Lets a test use the shared subscription store without touching the live database or leaving anything
/// behind on the simulator. The store's way to the account is replaced by `transport`, a stand-in that is
/// offline until the test says otherwise, with a sync queue of its own that is never saved. The list, its
/// cache and totals, the event history, the widget data, Spotlight, reminders and the review-prompt
/// milestone are put back by `restore()`.
@MainActor
final class StoreSandbox {
    private static let defaultsKeys = ["debug_premium_override", "debug_free_pro", "review_receipt_milestone_last"]
    let transport = FakeSyncTransport()
    private let subscriptions: [Subscription]
    private let totals: (monthly: Decimal, annual: Decimal)
    private let cache: Data
    private let cacheDate: Date
    private let sync: SyncQueue
    private let events: [LifecycleEvent]
    private let currency: String
    private let defaults: [String: Any]

    init() {
        let store = SubscriptionStore.shared
        subscriptions = store.subscriptions
        totals = (store.totalMonthlySpend, store.totalAnnualSpend)
        cache = AppSettings.shared.cachedSubscriptions
        cacheDate = AppSettings.shared.subscriptionsCacheDate
        sync = store.sync
        events = LifecycleEventLog.shared.events
        currency = CurrencyManager.shared.selectedCurrency
        defaults = Dictionary(uniqueKeysWithValues: Self.defaultsKeys.compactMap { key in
            UserDefaults.standard.object(forKey: key).map { (key, $0) }
        })
        SubscriptionStore.cloudSyncEnabled = false
        store.sync = SyncQueue(transport: transport, load: { Data() }, store: { _ in })
        store.subscriptions = []
        (store.totalMonthlySpend, store.totalAnnualSpend) = (0, 0)
    }

    func restore() async {
        let store = SubscriptionStore.shared
        store.subscriptions = subscriptions
        (store.totalMonthlySpend, store.totalAnnualSpend) = totals
        AppSettings.shared.cachedSubscriptions = cache
        AppSettings.shared.subscriptionsCacheDate = cacheDate
        store.sync = sync
        LifecycleEventLog.shared.restore(events)
        CurrencyManager.shared.selectedCurrency = currency
        for key in Self.defaultsKeys { UserDefaults.standard.set(defaults[key], forKey: key) }
        WidgetDataStore.shared.publish(subscriptions: subscriptions)
        await SpotlightManager.shared.index(subscriptions: subscriptions).value
        await ReminderScheduler.shared.reschedule(subscriptions)
        SubscriptionStore.cloudSyncEnabled = true
    }
}
