import Foundation

/// What the hours a person typed say about their subscriptions this month: what an hour of each one
/// cost, and which ones they said they didn't use. Their own figures and plain arithmetic. No score,
/// no threshold, no advice: the judgment is theirs.
enum UsageFacts {
    struct Line: Identifiable, Equatable {
        let subscription: Subscription
        /// What they entered for this month.
        let minutes: Int
        /// A month of it in the display currency.
        let monthly: Decimal
        /// True when `monthly` was converted from another currency, so it is an estimate.
        let isConverted: Bool

        var id: UUID { subscription.id }

        /// What an hour of use cost this month. Nil when none was used.
        var costPerHour: Decimal? {
            minutes > 0 ? monthly / (Decimal(minutes) / 60) : nil
        }
    }

    /// The subscriptions that are charging and have hours entered this month. `used`: the dearest hour
    /// first. `unused` (zero entered): the dearest month first. One with nothing entered is in
    /// neither, and one whose price can't be converted is left out rather than ranked wrongly.
    static func lines(for subscriptions: [Subscription], minutesThisMonth: (Subscription) -> Int?,
                      currency: String, rates: CurrencyRates) -> (used: [Line], unused: [Line]) {
        let lines: [Line] = subscriptions.charging.compactMap { subscription in
            guard let minutes = minutesThisMonth(subscription),
                  let monthly = subscription.monthlyCost(in: currency, rates: rates) else { return nil }
            return Line(subscription: subscription, minutes: minutes, monthly: monthly,
                        isConverted: [subscription].isConverted(to: currency))
        }
        let used = lines.filter { $0.minutes > 0 }
            .sorted { (($0.costPerHour ?? 0), $1.subscription.name) > (($1.costPerHour ?? 0), $0.subscription.name) }
        let unused = lines.filter { $0.minutes == 0 }
            .sorted { ($0.monthly, $1.subscription.name) > ($1.monthly, $0.subscription.name) }
        return (used, unused)
    }
}
