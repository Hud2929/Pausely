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

    private var daysUsed: Int {
        CancelTimingCalculator.daysUsed(from: lastBillingDate ?? Date())
    }

    private var daysRemaining: Int {
        guard let next = subscription.calculatedNextBillingDate else { return 0 }
        return max(0, Calendar.current.calendarDays(from: Date(), to: next))
    }

    private var progress: Double {
        CancelTimingCalculator.progress(lastBillingDate: lastBillingDate, cycleDays: cycleDays)
    }

    private var valueUsed: Decimal {
        currencyManager.convertToSelected(
            CancelTimingCalculator.valueUsed(monthlyCost: subscription.monthlyCost, progress: progress),
            from: subscription.currency
        )
    }

    private var valueRemaining: Decimal {
        currencyManager.convertToSelected(
            CancelTimingCalculator.valueRemaining(monthlyCost: subscription.monthlyCost, progress: progress),
            from: subscription.currency
        )
    }

    private var timingAdvice: (text: String, color: Color) {
        let advice = CancelTimingCalculator.cancelAdvice(
            daysUsed: daysUsed,
            daysRemaining: daysRemaining,
            cycleDays: cycleDays
        )
        let color: Color = {
            switch advice.level {
            case .good: return .green
            case .fair: return .yellow
            case .poor: return .orange
            }
        }()
        return (advice.text, color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack {
                Label("Cancel Timing", systemImage: "clock.badge.checkmark.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(progress * 100))% used")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(timingAdvice.color)
                        .frame(width: max(0, geo.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)

            // Value row
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(currencyManager.format(valueUsed))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("consumed")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(currencyManager.format(valueRemaining))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(timingAdvice.color)
                    Text("remaining")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }

            // Advice pill
            HStack(spacing: 7) {
                Circle()
                    .fill(timingAdvice.color)
                    .frame(width: 7, height: 7)
                Text(timingAdvice.text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                ForEach(projections.indices, id: \.self) { i in
                    let p = projections[i]
                    let cost = LifetimeCostCalculator.projectedCost(monthly: monthly, years: p.years)
                    VStack(spacing: 4) {
                        Text(p.label)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                        Text(cm.format(cost))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(i == 0 ? .white : i == 1 ? .orange : .red)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    if i < projections.count - 1 {
                        Divider().background(Color.white.opacity(0.08)).frame(height: 30)
                    }
                }
            }

            // Retirement bomb
            let retirementCost = LifetimeCostCalculator.retirementCost(monthly: monthly)
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text("Keep until retirement: ")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary) +
                Text(cm.format(retirementCost))
                    .font(.system(.caption2, design: .rounded).weight(.black))
                    .foregroundStyle(.red)
            }
            .padding(8)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(18)
        .surfaceCard(cornerRadius: 20, elevated: true)
    }
}
