import Foundation

/// The Subscriptions list, grouped by when each one next asks for money. State is shown by the
/// group a row is in, so rows don't need coloured badges.
enum SubscriptionGroups {
    enum Group: Int, CaseIterable, Identifiable {
        case decide, thisWeek, thisMonth, later, undated, cancelled
        var id: Int { rawValue }
    }

    struct Section: Identifiable, Equatable {
        let group: Group
        let subscriptions: [Subscription]
        var id: Int { group.rawValue }
    }

    /// Which group a subscription belongs to today.
    static func group(for sub: Subscription, pending: Set<UUID>, now: Date, calendar: Calendar = .billing) -> Group {
        if sub.status == .cancelled { return .cancelled }
        if pending.contains(sub.id) { return .decide }
        guard let charge = RenewalDecisions.upcomingCharge(for: sub, now: now, calendar: calendar) else { return .undated }
        let days = calendar.calendarDays(from: now, to: charge.date)
        if days <= 7 { return .thisWeek }
        if days <= 30 { return .thisMonth }
        return .later
    }

    /// Sections in display order, empty ones left out. Inside a section the soonest charge comes
    /// first; groups without a date are ordered by cost, most expensive first.
    static func sections(_ subscriptions: [Subscription], pending: Set<UUID>, now: Date,
                         calendar: Calendar = .billing,
                         currency: String = CurrencyManager.shared.selectedCurrency,
                         rates: CurrencyRates = CurrencyManager.shared.rates) -> [Section] {
        var buckets: [Group: [Subscription]] = [:]
        for sub in subscriptions {
            buckets[group(for: sub, pending: pending, now: now, calendar: calendar), default: []].append(sub)
        }
        func chargeDay(_ sub: Subscription) -> Date {
            RenewalDecisions.upcomingCharge(for: sub, now: now, calendar: calendar)?.date ?? .distantFuture
        }
        return Group.allCases.compactMap { group in
            guard let items = buckets[group], !items.isEmpty else { return nil }
            let sorted: [Subscription]
            switch group {
            case .decide, .thisWeek, .thisMonth, .later:
                sorted = items.sorted { (chargeDay($0), $0.name) < (chargeDay($1), $1.name) }
            case .undated, .cancelled:
                // Ranked in one currency: ¥1,500 is not more than US$50. One with no rate goes last.
                func cost(_ sub: Subscription) -> Decimal { sub.monthlyCost(in: currency, rates: rates) ?? -1 }
                sorted = items.sorted { (cost($1), $0.name) < (cost($0), $1.name) }
            }
            return Section(group: group, subscriptions: sorted)
        }
    }
}
