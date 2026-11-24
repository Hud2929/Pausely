import Foundation

/// Facts from the event log that a Renewal Verdict shows. Pure, so they can be tested.
enum VerdictFacts {

    /// Why a verdict has no charge to decide on. A reminder that was delivered can still be tapped
    /// after its subscription lost its date or was cancelled; "Keep it" is about one charge, and a
    /// button that can do nothing is never shown without the way forward.
    enum NoCharge: Equatable {
        /// It renews, but Pausely was never told when: the verdict asks for the date instead.
        case noDate
        /// It was cancelled: the verdict shows the cancelled slip.
        case notRenewing
    }

    static func noCharge(for sub: Subscription, now: Date, calendar: Calendar = .billing) -> NoCharge? {
        guard RenewalDecisions.upcomingCharge(for: sub, now: now, calendar: calendar) == nil else { return nil }
        return sub.renewsAutomatically ? .noDate : .notRenewing
    }

    /// When the user last chose to keep it.
    static func lastKept(for subscriptionId: UUID, events: [LifecycleEvent]) -> Date? {
        events.filter { $0.subscriptionId == subscriptionId && $0.kind == .kept }.map(\.date).max()
    }

    /// What the renewals Pausely has seen come to: every renewal day that passed while this was listed
    /// as charging (and the first charge at the end of a free trial), at the price it had that day.
    /// Nil when none has passed yet, or when the price was in another currency for some of them (a sum
    /// across currencies would be a guess).
    static func renewedSoFar(for sub: Subscription, events: [LifecycleEvent]) -> (total: Decimal, since: Date)? {
        let charges = events.filter { $0.subscriptionId == sub.id && ($0.kind == .renewed || $0.kind == .trialEnded) }
        guard let first = charges.map(\.date).min(),
              let total = MoneyMath.exactTotal(charges, allIn: sub.currency, amount: \.amount, currencyOf: \.currency) else { return nil }
        return (total, first)
    }

    /// What the slip says about a year of it, under the price.
    enum YearLine: Equatable {
        /// "That's $131.88 a year": the sum the price doesn't show.
        case yearly(Decimal)
        /// The same, with what it comes to in the person's own currency.
        case yearlyAndConverted(Decimal, inDisplay: Decimal)
        /// A yearly price in another currency: only what it comes to here. "That's €59.99 a year"
        /// under "€59.99 /yr" said the price twice.
        case convertedOnly(inDisplay: Decimal)
    }

    /// Nil for a yearly price in the person's own currency: the price is already the year's.
    static func yearLine(for sub: Subscription, displayCurrency: String, rates: CurrencyRates) -> YearLine? {
        let isAbroad = MoneyFormat.normalizedCode(sub.currency) != MoneyFormat.normalizedCode(displayCurrency)
        let inDisplay = isAbroad ? rates.convert(sub.annualCost, from: sub.currency, to: displayCurrency) : nil
        if sub.billingFrequency == .yearly { return inDisplay.map { .convertedOnly(inDisplay: $0) } }
        return inDisplay.map { .yearlyAndConverted(sub.annualCost, inDisplay: $0) } ?? .yearly(sub.annualCost)
    }

    /// The renewal after `charge`, for "we'll ask again before …".
    static func renewal(after charge: Date, for sub: Subscription, calendar: Calendar = .billing) -> Date? {
        guard let anchor = sub.nextBillingDate,
              let dayAfter = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: charge)) else { return nil }
        return RenewalSchedule.nextRenewal(anchor: anchor, frequency: sub.billingFrequency, onOrAfter: dayAfter, calendar: calendar)
    }
}
