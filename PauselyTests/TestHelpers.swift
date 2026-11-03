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
        userPriceUSD: Decimal? = nil,
        isPriceOverridden: Bool = false,
        canPause: Bool = true,
        pausedUntil: Date? = nil
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
            pausedUntil: pausedUntil,
            createdAt: createdAt,
            updatedAt: createdAt,
            userPriceUSD: userPriceUSD,
            isPriceOverridden: isPriceOverridden
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

/// Lets a test use the shared subscription store without touching the live database or leaving anything
/// behind on the simulator: cloud writes are off (changes are queued exactly as when offline), and the
/// list, its cache and totals, the sync queue, the event history, the widget data, Spotlight, reminders
/// and the review-prompt milestone are put back by `restore()`.
@MainActor
final class StoreSandbox {
    private static let defaultsKeys = ["debug_premium_override", "debug_free_pro", "review_receipt_milestone_last"]
    private let subscriptions: [Subscription]
    private let totals: (monthly: Decimal, annual: Decimal, lifetime: Decimal)
    private let cache: Data
    private let cacheDate: Date
    private let queue: [SyncOperation]
    private let queueData: Data
    private let events: [LifecycleEvent]
    private let currency: String
    private let defaults: [String: Any]

    init() {
        let store = SubscriptionStore.shared
        subscriptions = store.subscriptions
        totals = (store.totalMonthlySpend, store.totalAnnualSpend, store.totalLifetimeSpend)
        cache = AppSettings.shared.cachedSubscriptions
        cacheDate = AppSettings.shared.subscriptionsCacheDate
        queue = SyncQueue.shared.pendingOperations
        queueData = AppSettings.shared.syncQueueOperations
        events = LifecycleEventLog.shared.events
        currency = CurrencyManager.shared.selectedCurrency
        defaults = Dictionary(uniqueKeysWithValues: Self.defaultsKeys.compactMap { key in
            UserDefaults.standard.object(forKey: key).map { (key, $0) }
        })
        SubscriptionStore.cloudWritesEnabled = false
        store.subscriptions = []
        (store.totalMonthlySpend, store.totalAnnualSpend, store.totalLifetimeSpend) = (0, 0, 0)
    }

    func restore() async {
        let store = SubscriptionStore.shared
        store.subscriptions = subscriptions
        (store.totalMonthlySpend, store.totalAnnualSpend, store.totalLifetimeSpend) = totals
        AppSettings.shared.cachedSubscriptions = cache
        AppSettings.shared.subscriptionsCacheDate = cacheDate
        SyncQueue.shared.pendingOperations = queue
        AppSettings.shared.syncQueueOperations = queueData
        LifecycleEventLog.shared.restore(events)
        CurrencyManager.shared.selectedCurrency = currency
        for key in Self.defaultsKeys { UserDefaults.standard.set(defaults[key], forKey: key) }
        WidgetDataStore.shared.publish(subscriptions: subscriptions)
        await SpotlightManager.shared.index(subscriptions: subscriptions).value
        await ReminderScheduler.shared.reschedule(subscriptions)
        SubscriptionStore.cloudWritesEnabled = true
    }
}
