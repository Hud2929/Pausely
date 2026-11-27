import SwiftUI

/// The day to cancel by, in one sentence. The screen's header already says when it renews, how many
/// days away that is and what it costs; this used to say all three again above the one thing that
/// is its own.
struct CancelTimingCard: View {
    let subscription: Subscription

    var body: some View {
        if let charge = RenewalDecisions.upcomingCharge(for: subscription, now: Date()) {
            let days = Calendar.billing.calendarDays(from: Date(), to: charge.date)
            let isApple = CancelHelp.find(for: subscription).kind == .appleSubscription
            let line: String = {
                if days <= 0 {
                    return charge.isTrialEnd
                        ? L10n.string("Your free trial ends today — cancel right away if you don't want to be charged.")
                        : L10n.string("Today is the renewal day — cancel right away if it hasn't charged yet.")
                }
                if isApple {
                    return L10n.string("Apple needs at least 24 hours' notice before \(DayText.date(charge.date, locale: L10n.locale)) so it won't charge.")
                }
                return L10n.string("Cancel before \(DayText.date(charge.date, locale: L10n.locale)) and you won't be charged.")
            }()
            VStack(alignment: .leading, spacing: 6) {
                Text("When to cancel")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: line)
                    .font(.body)
                    .foregroundStyle(days <= 0 ? Color.due : Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// What this subscription adds up to over one, five and ten years, in the display currency.
struct LifetimeCostCard: View {
    let subscription: Subscription
    @ObservedObject private var cm = CurrencyManager.shared

    /// In the display currency; in its own when there is no rate to convert it with.
    private var monthly: (amount: Decimal, currency: String) {
        if let converted = cm.convertToSelected(subscription.monthlyCost, from: subscription.currency) {
            return (converted, cm.selectedCurrency)
        }
        return (subscription.monthlyCost, subscription.currency)
    }

    private let projections: [(label: LocalizedStringKey, years: Int)] = [
        ("1 year", 1), ("5 years", 5), ("10 years", 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Cost over time")
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .accessibilityAddTraits(.isHeader)
            // A forecast says what it assumes: the price as it is today, for the whole time.
            Text("At today's price.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .padding(.top, 2)
                .padding(.bottom, 4)
            ForEach(projections.indices, id: \.self) { index in
                if index > 0 { Hairline() }
                SideBySide {
                    Text(projections[index].label)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                } trailing: {
                    Text(verbatim: MoneyFormat.total(LifetimeCostCalculator.projectedCost(monthly: monthly.amount, years: projections[index].years),
                                                     monthly.currency, converted: monthly.currency != subscription.currency))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(Color.inkText)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
