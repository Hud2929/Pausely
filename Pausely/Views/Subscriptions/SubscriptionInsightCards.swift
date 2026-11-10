import SwiftUI

/// The cancel window: how far through the billing period this is, the next charge, and the day
/// to cancel by. A plain section, not a card.
struct CancelTimingCard: View {
    let subscription: Subscription

    private var cycleDays: Int {
        CancelTimingCalculator.cycleDays(for: subscription.billingFrequency)
    }

    private var lastBillingDate: Date? {
        guard let next = subscription.calculatedNextBillingDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: -cycleDays, to: next)
    }

    private var daysRemaining: Int {
        guard let next = subscription.calculatedNextBillingDate else { return 0 }
        return max(0, Calendar.current.calendarDays(from: Date(), to: next))
    }

    private var progress: Double {
        CancelTimingCalculator.progress(lastBillingDate: lastBillingDate, cycleDays: cycleDays)
    }

    private var nextChargeText: String? {
        guard let next = subscription.calculatedNextBillingDate else { return nil }
        let day = next.formatted(.dateTime.month(.abbreviated).day())
        return L10n.string("Next charge: \(MoneyFormat.string(subscription.amount, subscription.currency)) on \(day)")
    }

    private var adviceText: String {
        guard let next = subscription.calculatedNextBillingDate else {
            return L10n.string("Add a payment date to see when to cancel.")
        }
        let day = next.formatted(.dateTime.month(.abbreviated).day())
        return L10n.string("Cancel any day before \(day) to avoid it. Most services let you keep using it until then.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cancel Timing")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                Spacer(minLength: 8)
                Text(daysRemaining == 1 ? L10n.string("1 day left") : L10n.string("\(daysRemaining) days left"))
                    .font(.subheadline)
                    .foregroundStyle(daysRemaining <= 1 ? Color.due : Color.inkTextMuted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 4)
                    Capsule()
                        .fill(daysRemaining <= 1 ? Color.due : Color.inkText)
                        .frame(width: max(4, geo.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)

            if let nextChargeText {
                Text(nextChargeText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(adviceText)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// What this subscription adds up to over one, five and ten years, in the display currency.
struct LifetimeCostCard: View {
    let subscription: Subscription
    @ObservedObject private var cm = CurrencyManager.shared

    private var monthly: Decimal {
        cm.convertToSelected(subscription.monthlyCost, from: subscription.currency)
    }

    private let projections: [(label: LocalizedStringKey, years: Int)] = [
        ("1 year", 1), ("5 years", 5), ("10 years", 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lifetime Cost")
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .padding(.bottom, 4)
            ForEach(projections.indices, id: \.self) { index in
                if index > 0 { Hairline() }
                HStack(alignment: .firstTextBaseline) {
                    Text(projections[index].label)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                    Spacer(minLength: 12)
                    Text(cm.format(LifetimeCostCalculator.projectedCost(monthly: monthly, years: projections[index].years)))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(Color.inkText)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
