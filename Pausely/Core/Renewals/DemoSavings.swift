#if DEBUG
import Foundation

/// DEBUG only: sample cancellations so the Savings Receipt can be seen without waiting months.
/// Used by the `--demo-savings` and `--demo-receipt` launch arguments.
enum DemoSavings {
    @MainActor
    static func seed(now: Date = Date()) {
        let log = LifecycleEventLog.shared
        guard !log.events.contains(where: { $0.kind == .cancelled }) else { return }
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
}
#endif
