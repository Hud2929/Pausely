import Foundation

/// The next 30 days of charges, for Home: one dot per charge on a line, and "what leaves by then".
/// Pure: takes `now` and a calendar. Renewal days come from `RenewalSchedule`, never recomputed here.
enum Horizon {
    static let days = 30

    struct Charge: Identifiable, Equatable {
        let subscriptionId: UUID
        let name: String
        let category: String?
        /// The charge day, at local noon.
        let date: Date
        /// 0 = today … 29.
        let dayOffset: Int
        /// The amount in the subscription's own currency.
        let amount: Decimal
        let currency: String
        let isTrialEnd: Bool

        var id: String { "\(subscriptionId.uuidString)|\(dayOffset)" }
    }

    /// Every charge from today through the next `days - 1` days, soonest first. A trial is charged
    /// when it ends; paused and cancelled subscriptions, and ones without a renewal date, have none.
    static func charges(for subscriptions: [Subscription], now: Date, calendar: Calendar = .current) -> [Charge] {
        let today = calendar.startOfDay(for: now)
        var result: [Charge] = []
        for sub in subscriptions where sub.renewsAutomatically {
            var dates: [(Date, Bool)] = []
            if sub.status == .trial, let end = sub.trialEndsAt, calendar.startOfDay(for: end) >= today {
                dates = [(calendar.noon(of: end), true)]
            } else if let anchor = sub.nextBillingDate {
                dates = RenewalSchedule
                    .upcomingRenewals(anchor: anchor, frequency: sub.billingFrequency, onOrAfter: now,
                                      count: days, calendar: calendar)
                    .map { ($0, false) }
            }
            for (date, isTrialEnd) in dates {
                let offset = calendar.calendarDays(from: today, to: date)
                guard offset >= 0 else { continue }
                guard offset < days else { break }
                result.append(Charge(subscriptionId: sub.id, name: sub.name, category: sub.category, date: date,
                                     dayOffset: offset, amount: sub.amount, currency: sub.currency, isTrialEnd: isTrialEnd))
            }
        }
        return result.sorted { ($0.dayOffset, $0.name) < ($1.dayOffset, $1.name) }
    }

    /// What leaves through day `dayOffset`, in `currency`. Charges that can't be converted are left
    /// out rather than added at the wrong value.
    static func total(of charges: [Charge], through dayOffset: Int, in currency: String, rates: CurrencyRates) -> Decimal {
        charges.filter { $0.dayOffset <= dayOffset }
            .compactMap { rates.convert($0.amount, from: $0.currency, to: currency) }
            .reduce(0, +)
    }

    /// Active subscriptions Pausely can't remind about yet, because it doesn't know when they renew.
    static func undated(_ subscriptions: [Subscription]) -> [Subscription] {
        subscriptions.filter { $0.status == .active && $0.nextBillingDate == nil }
    }
}
