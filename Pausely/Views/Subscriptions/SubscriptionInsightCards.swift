import SwiftUI

// MARK: - Cancel Timing Card

struct CancelTimingCard: View {
    let subscription: Subscription
    @ObservedObject private var currencyManager = CurrencyManager.shared

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

    /// Shown in the subscription's own currency, like every single price.
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
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack {
                Label("Cancel Timing", systemImage: "clock.badge.checkmark.fill")
                    .font(.system(.headline, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(daysRemaining == 1 ? L10n.string("1 day left") : L10n.string("\(daysRemaining) days left"))
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(daysRemaining <= 3 ? Color.orange : Color.accentMint)
                        .frame(width: max(0, geo.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)

            if let nextChargeText {
                Text(nextChargeText)
                    .font(.system(.subheadline, design: .default).weight(.semibold))
                    .foregroundStyle(.white)
            }

            Text(adviceText)
                .font(.system(.caption, design: .default))
                .foregroundStyle(Color.obsidianTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(18)
        .surfaceCard(cornerRadius: 20, elevated: true)
    }
}

// MARK: - Lifetime Cost Card

struct LifetimeCostCard: View {
    let subscription: Subscription
    @ObservedObject private var cm = CurrencyManager.shared

    private var monthly: Decimal {
        cm.convertToSelected(subscription.monthlyCost, from: subscription.currency)
    }

    private struct Projection {
        let label: String
        let years: Int
    }

    private let projections: [Projection] = [
        Projection(label: "1 year",  years: 1),
        Projection(label: "5 years", years: 5),
        Projection(label: "10 years", years: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lifetime Cost", systemImage: "infinity.circle.fill")
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                ForEach(projections.indices, id: \.self) { i in
                    let p = projections[i]
                    let cost = LifetimeCostCalculator.projectedCost(monthly: monthly, years: p.years)
                    VStack(spacing: 4) {
                        Text(p.label)
                            .font(.system(size: 10, design: .default))
                            .foregroundStyle(Color.obsidianTextTertiary)
                        Text(cm.format(cost))
                            .font(.system(.caption, design: .default).weight(.bold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    if i < projections.count - 1 {
                        Divider().background(Color.white.opacity(0.08)).frame(height: 30)
                    }
                }
            }
        }
        .padding(18)
        .surfaceCard(cornerRadius: 20, elevated: true)
    }
}
