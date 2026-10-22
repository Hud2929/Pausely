import Foundation

/// DEBUG only: sample cancellations so the Savings Receipt can be seen without waiting months.
/// Used by the `--demo-savings` and `--demo-receipt` launch arguments.
enum DemoSavings {
    /// `--screenshots` (DEBUG): App Store captures without the one-time permission card. Always false in release.
    static var isScreenshotRun: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--screenshots")
        #else
        return false
        #endif
    }

    #if DEBUG
    @MainActor
    static func seed(now: Date = Date()) {
        let store = SubscriptionStore.shared
        // Pausely tracks itself, so the Pausely Promise has something to compare against.
        if !store.subscriptions.contains(where: \.isPausely) {
            store.subscriptions.append(Subscription(
                name: "Pausely Pro", bundleIdentifier: "com.pausely.app.Pausely", category: "Productivity",
                amount: ProPricing.annualUSD, currency: "USD", billingFrequency: .yearly,
                nextBillingDate: Calendar.current.date(byAdding: .month, value: 9, to: now)))
        }
        let log = LifecycleEventLog.shared
        guard !log.events.contains(where: { $0.kind == .cancelled }) else { return }
        // A Netflix price rise and some usage, so a Renewal Verdict shows its full set of facts.
        if let netflix = store.subscriptions.first(where: { $0.name == "Netflix" }) {
            log.record(.priceChanged, for: netflix, date: Calendar.current.date(byAdding: .month, value: -7, to: now) ?? now,
                       previousAmount: netflix.amount - 2)
            ScreenTimeManager.shared.setMonthlyUsage(minutes: 140, for: netflix.name)
        }
        let calendar = Calendar.current
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now) ?? now }

        let samples: [(name: String, amount: Decimal, anchorDaysAgo: Int, cancelledDaysAgo: Int)] = [
            ("Hulu", 18.99, 98, 100),
            ("Paramount+", 11.99, 40, 45),
            ("Headspace", 12.99, 12, 14)
        ]
        for sample in samples {
            let sub = Subscription(name: sample.name, category: "Entertainment", amount: sample.amount,
                                   currency: CurrencyManager.shared.selectedCurrency,
                                   billingFrequency: .monthly, nextBillingDate: calendar.noon(of: daysAgo(sample.anchorDaysAgo)))
            log.record(.cancelled, for: sub, date: daysAgo(sample.cancelledDaysAgo), renewalDate: sub.nextBillingDate)
        }
    }
    #endif
}
