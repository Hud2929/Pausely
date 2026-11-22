import Foundation

/// What is worth telling someone about the subscriptions their receipts prove: a price that rose, a
/// trial about to end, a yearly renewal coming up, a plan that looks ended, a charge after cancelling,
/// an announced price change, an introductory price about to end, a payment that failed.
/// The engine proves the subscriptions (`SubscriptionIntelligenceEngine`); this says what follows.
enum SubscriptionInsights {

    /// One merchant's receipts, under the merchant's key.
    typealias Groups = [String: (merchant: ResolvedMerchant, signals: [ReceiptSignal])]

    /// Every insight for what was detected, in no order: the caller ranks them.
    static func all(for detected: [ProvenSubscription], groups: Groups, now: Date, calendar: Calendar) -> [IntelligenceInsight] {
        var insights: [IntelligenceInsight] = []
        for sub in detected { insights.append(contentsOf: about(sub, now: now, calendar: calendar)) }
        insights.append(contentsOf: priceChangeNotices(groups: groups, detected: detected))
        let introEnds = introductoryPriceEnds(groups: groups, detected: detected)
        insights.append(contentsOf: introEnds)
        insights.append(contentsOf: failedPayments(groups: groups, detected: detected, now: now))
        // One note per charge. When an introductory price ends at the renewal, "renews in 34 days: expect
        // $152.54" (the old price) stood beside "goes up to $269.99 on Dec 26" about the same charge.
        let introducing = Set(introEnds.compactMap(\.subscriptionId))
        return insights.filter { !($0.kind == .renewalSoon && introducing.contains($0.subscriptionId ?? "")) }
    }

    private static func about(_ sub: ProvenSubscription, now: Date, calendar: Calendar) -> [IntelligenceInsight] {
        guard sub.tier >= .likely else { return [] }
        var out: [IntelligenceInsight] = []

        if sub.status == .priceIncreased, let old = sub.previousAmount {
            let impact = (sub.amount - old) * ProvenSubscription.periodsPerYear(sub.frequency)
            if ProvenSubscription.isPlanChange(from: old, to: sub.amount), let on = sub.lastChargeDate {
                // A jump this size is a new plan or a charge nobody asked for; the app can't tell which.
                out.append(IntelligenceInsight(
                    id: "price|\(sub.id)", kind: .priceIncrease,
                    title: L10n.string("\(sub.name) now costs more"),
                    detail: L10n.string("\(format(sub.amount, sub.currency)) on \(shortDate(on)), up from \(format(old, sub.currency)). If you didn't change plans, check this charge."),
                    subscriptionId: sub.id, annualImpact: impact))
            } else {
                out.append(IntelligenceInsight(
                    id: "price|\(sub.id)", kind: .priceIncrease,
                    title: L10n.string("\(sub.name) costs more than before"),
                    detail: L10n.string("From \(format(old, sub.currency)) to \(format(sub.amount, sub.currency)). That's \(format(impact, sub.currency)) more per year."),
                    subscriptionId: sub.id, annualImpact: impact))
            }
        }
        if let odd = sub.unusualCharge, sub.status != .cancelled {
            out.append(IntelligenceInsight(
                id: "unusual|\(sub.id)", kind: .priceIncrease,
                title: L10n.string("\(sub.name) charged more than usual"),
                detail: L10n.string("\(format(odd.amount, odd.currency)) on \(shortDate(odd.date)), more than the usual \(format(sub.amount, sub.currency)). A new plan or an extra charge: check it."),
                subscriptionId: sub.id, annualImpact: nil))
        }
        if sub.status == .trial, let ends = sub.trialEndsOn {
            out.append(IntelligenceInsight(
                id: "trial|\(sub.id)", kind: .trialEnding, title: L10n.string("\(sub.name) trial ends around \(shortDate(ends))"),
                // The day is worked out from the email's date, never read: the email has the exact one.
                detail: L10n.string("Check the exact day in the email, and cancel before it to avoid being charged."), subscriptionId: sub.id,
                annualImpact: sub.amount > 0 ? sub.annualCost : nil))
        }
        if sub.status == .active || sub.status == .priceIncreased, let next = sub.nextBillingDate {
            // Calendar days: from mid-morning, 24-hour spans called Dec 26 "in 37 days" on Nov 18.
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: next)).day ?? 999
            let window = sub.frequency == .yearly || sub.frequency == .semiannual ? 45 : 0
            if window > 0, days >= 0, days <= window {
                out.append(IntelligenceInsight(
                    id: "renew|\(sub.id)", kind: .renewalSoon, title: L10n.string("\(sub.name) renews \(whenPhrase(days))"),
                    detail: L10n.string("Expect a charge of \(format(sub.amount, sub.currency)) around \(shortDate(next))."),
                    subscriptionId: sub.id, annualImpact: sub.annualCost))
            }
        }
        if sub.status == .likelyEnded {
            out.append(IntelligenceInsight(
                id: "ended|\(sub.id)", kind: .likelyEnded, title: L10n.string("\(sub.name) looks like it ended"),
                detail: sub.lastChargeDate.map { L10n.string("No charge since \(shortDate($0)). Confirm it's really cancelled.") }
                    ?? L10n.string("No recent charge. Confirm it's really cancelled."),
                subscriptionId: sub.id, annualImpact: nil))
        }
        if sub.chargedAfterCancel {
            out.append(IntelligenceInsight(
                // A charge after a cancellation email may be a new sign-up; the app can't tell.
                id: "afterCancel|\(sub.id)", kind: .chargedAfterCancel, title: L10n.string("\(sub.name) charged again after a cancellation email"),
                detail: L10n.string("A cancellation email came, then a later charge of \(format(sub.amount, sub.currency)). If you didn't sign up again, ask for it back."),
                subscriptionId: sub.id, annualImpact: sub.annualCost))
        }
        return out
    }

    private static func priceChangeNotices(groups: Groups,
                                    detected: [ProvenSubscription]) -> [IntelligenceInsight] {
        var out: [IntelligenceInsight] = []
        for sub in detected where sub.tier >= .likely {
            guard let group = groups[sub.merchantKey], group.signals.contains(where: { $0.kind == .priceChange }) else { continue }
            if sub.status == .priceIncreased { continue } // already covered by an exact price insight
            out.append(IntelligenceInsight(
                id: "notice|\(sub.id)", kind: .priceChangeNotice, title: L10n.string("\(sub.name) announced a price change"),
                detail: L10n.string("They emailed about new pricing. Check what you'll pay next billing."), subscriptionId: sub.id, annualImpact: nil))
        }
        return out
    }

    /// "$134.99 for the first year, then $269.99/year": the jump at the next renewal.
    private static func introductoryPriceEnds(groups: Groups,
                                       detected: [ProvenSubscription]) -> [IntelligenceInsight] {
        var out: [IntelligenceInsight] = []
        for sub in detected where sub.tier >= .likely && (sub.status == .active || sub.status == .priceIncreased) {
            guard let group = groups[sub.merchantKey], let lastCharge = sub.lastChargeDate,
                  let signal = group.signals.last(where: {
                      ($0.kind == .charge || $0.kind == .renewalNotice) && $0.nextAmount != nil
                          && abs($0.date.timeIntervalSince(lastCharge)) < 3 * 86_400
                  }),
                  let next = signal.nextAmount else { continue }
            // The email's own two prices when it states both; the amount charged (tax included) otherwise.
            let intro = signal.introAmount ?? sub.amount
            guard next > intro else { continue }
            let impact = (next - intro) * ProvenSubscription.periodsPerYear(sub.frequency)
            let newPrice = format(next, sub.currency)
            // The amount charged is the price with tax; with both on the receipt, the coming charge is
            // the new price with the same tax, said as an estimate. Money in one sentence is all one way.
            var withTax: Decimal?
            if let stated = signal.introAmount, stated > 0, sub.amount > stated {
                var estimate = next * sub.amount / stated
                var rounded = Decimal()
                NSDecimalRound(&rounded, &estimate, 2, .plain)
                withTax = rounded
            }
            let title = sub.nextBillingDate.map { L10n.string("\(sub.name) goes up to \(newPrice) around \(shortDate($0))") }
                ?? L10n.string("\(sub.name) goes up to \(newPrice) at the next renewal")
            out.append(IntelligenceInsight(
                id: "intro|\(sub.id)", kind: .priceChangeNotice,
                title: title,
                detail: withTax.map { L10n.string("You're on an introductory price of \(format(intro, sub.currency)). It renews at \(newPrice) (about \(format($0, sub.currency)) with tax) unless you cancel or switch plans first.") }
                    ?? L10n.string("You're on an introductory price of \(format(intro, sub.currency)). It renews at \(newPrice) unless you cancel or switch plans first."),
                subscriptionId: sub.id, annualImpact: impact))
        }
        return out
    }

    /// A declined card with no successful charge since: the plan may be paused or cancelled by the merchant.
    private static func failedPayments(groups: Groups,
                                detected: [ProvenSubscription], now: Date) -> [IntelligenceInsight] {
        var out: [IntelligenceInsight] = []
        for sub in detected where sub.tier >= .likely && sub.status != .cancelled {
            guard let group = groups[sub.merchantKey],
                  let failure = group.signals.last(where: { $0.kind == .paymentFailed }),
                  now.timeIntervalSince(failure.date) < 45 * 86_400 else { continue }
            if let lastCharge = sub.lastChargeDate, lastCharge >= failure.date { continue }
            out.append(IntelligenceInsight(
                id: "failed|\(sub.id)", kind: .paymentFailed, title: L10n.string("Payment to \(sub.name) failed"),
                detail: L10n.string("A payment failed on \(shortDate(failure.date)). Update your payment details if you want to keep \(sub.name), or let it lapse if you don't."),
                subscriptionId: sub.id, annualImpact: nil))
        }
        return out
    }

    /// "today", "tomorrow", "in 3 days": the time phrase in insight titles.
    private static func whenPhrase(_ days: Int) -> String {
        L10n.relativeDay(max(days, 0))
    }

    private static func format(_ amount: Decimal, _ currency: String) -> String {
        MoneyFormat.string(amount, currency)
    }

    private static func shortDate(_ date: Date) -> String {
        ReceiptWording.shortDate(date)
    }
}
