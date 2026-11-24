import Foundation

/// What a subscription has cost over time, read from the event log: the price it was added at and
/// every change the person recorded since. The one source for the price line on a Renewal Verdict,
/// "What went up" on Insights and the price history screen.
enum PriceHistory {

    struct Point: Equatable, Identifiable {
        let id: String
        /// Nil for a price from before Pausely kept dates for it.
        let date: Date?
        let amount: Decimal
        let currency: String
        let frequency: BillingFrequency
    }

    /// A real change in what one charge costs.
    struct Change: Equatable {
        let from: Decimal
        let to: Decimal
        let currency: String
        let since: Date

        var isIncrease: Bool { to > from }
    }

    /// Every price on record, oldest first.
    static func points(for subscriptionId: UUID, events: [LifecycleEvent]) -> [Point] {
        let recorded = events
            .filter { $0.subscriptionId == subscriptionId && ($0.kind == .added || $0.kind == .priceChanged) }
            .sorted { $0.date < $1.date }
        var points: [Point] = []
        for event in recorded {
            // A history that starts with a change (it was added before events were kept): the price
            // before it is known, the day it was set is not.
            if points.isEmpty, event.kind == .priceChanged, let before = event.previousAmount {
                points.append(Point(id: event.id.uuidString + "-before", date: nil, amount: before,
                                    currency: event.currency, frequency: event.frequency))
            }
            points.append(Point(id: event.id.uuidString, date: event.date, amount: event.amount,
                                currency: event.currency, frequency: event.frequency))
        }
        return points
    }

    /// The latest recorded change, when it is a change in price that the person actually paid through.
    ///
    /// Not a change: a different currency or billing period (10 dollars a month to 100 a year is not
    /// "up"), a price that has since been changed again or back, and a correction made before the
    /// earlier price had stood for one billing period. A price that was never charged was a guess
    /// (often the catalog's typical price) or a slip of the finger, and fixing it is not the service
    /// raising its price.
    static func latestChange(for subscription: Subscription, events: [LifecycleEvent],
                             calendar: Calendar = .billing) -> Change? {
        let all = points(for: subscription.id, events: events)
        guard all.count >= 2, let now = all.last, let changedOn = now.date else { return nil }
        let before = all[all.count - 2]
        let currency = MoneyFormat.normalizedCode(now.currency)
        guard now.amount == subscription.effectiveAmount, currency == MoneyFormat.normalizedCode(subscription.currency),
              currency == MoneyFormat.normalizedCode(before.currency), before.frequency == now.frequency,
              before.amount != now.amount else { return nil }
        if let setOn = before.date {
            let firstCharge = RenewalSchedule.occurrence(1, anchorDay: calendar.startOfDay(for: setOn),
                                                         frequency: before.frequency, calendar: calendar)
            guard calendar.startOfDay(for: changedOn) >= firstCharge else { return nil }
        }
        return Change(from: before.amount, to: now.amount, currency: now.currency, since: changedOn)
    }
}
