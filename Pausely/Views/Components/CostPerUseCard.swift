import SwiftUI

// MARK: - Cost Per Use Card
/// A beautiful glass-morphism card showing cost-per-use analytics for a single subscription.
struct CostPerUseCard: View {
    let result: CostPerUseResult
    var showComparison: Bool = false
    var comparisonRatio: Double? = nil
    var comparisonName: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Icon + Name + Badge
            headerRow

            // Main metric: Cost per hour (large, prominent)
            mainMetricSection

            // Details row: Monthly cost + Hours used
            detailsRow

            // Comparison (optional)
            if showComparison, let ratio = comparisonRatio, let name = comparisonName {
                comparisonRow(ratio: ratio, name: name)
            }

            // Bottom insight line
            insightRow
        }
        .padding(20)
        .padding(20)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appear = true
            }
        }
    }

    // MARK: - Header Row
    private var headerRow: some View {
        HStack(spacing: 14) {
            ServiceLogoView(name: result.subscription.name, category: result.subscription.category, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.subscription.name)
                    .font(Font.headline)
                    .foregroundStyle(Color.inkText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Value tier badge
                    ValueTierBadge(tier: result.valueTier)

                    if result.isWasted {
                        Text("Wasted")
                            .font(Font.caption2.weight(.medium))
                            .foregroundStyle(Color.due)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.due.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Main Metric Section
    private var mainMetricSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cost Per Hour")
                .font(Font.footnote.weight(.medium))
                .foregroundStyle(Color.inkTextMuted)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                if let cph = result.costPerHour {
                    Text(CostPerUseCalculator.formatCostPerHour(cph, currencyCode: result.subscription.currency))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(result.valueTier.swiftUIColor)
                } else {
                    Text("—")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.inkTextMuted)
                }

                if let score = result.valueScore {
                    Text("/ \(CostPerUseCalculator.formatValueScore(score))")
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkTextMuted)
                }
            }

            // Contextual subtitle
            Text(subtitleText)
                .font(Font.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Details Row
    private var detailsRow: some View {
        HStack(spacing: 16) {
            DetailPill(
                icon: "dollarsign.circle.fill",
                label: "Monthly",
                value: result.subscription.displayAmount
            )

            DetailPill(
                icon: "clock.fill",
                label: "This Month",
                value: result.displayHoursUsed
            )

            if let score = result.valueScore {
                DetailPill(
                    icon: "chart.bar.fill",
                    label: "Score",
                    value: CostPerUseCalculator.formatValueScore(score)
                )
            }
        }
    }

    // MARK: - Comparison Row
    private func comparisonRow(ratio: Double, name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(Font.caption.weight(.medium))
                .foregroundStyle(Color.inkText)

            Text("You use \(result.subscription.name)")
                .font(Font.subheadline)
                .foregroundStyle(Color.inkTextMuted)

            + Text(" \(String(format: "%.1f", ratio))x ")
                .font(Font.subheadline)
                .foregroundStyle(Color.inkText)
                .fontWeight(.semibold)

            + Text("more than \(name)")
                .font(Font.subheadline)
                .foregroundStyle(Color.inkTextMuted)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Insight Row
    private var insightRow: some View {
        HStack(spacing: 8) {
            Image(systemName: insightIcon)
                .font(Font.caption.weight(.medium))
                .foregroundStyle(insightColor)

            Text(insightText)
                .font(Font.subheadline)
                .foregroundStyle(insightColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(10)
        .background(insightColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Computed Properties

    private var subtitleText: String {
        if result.isWasted {
            let wasted = MoneyFormat.string(result.subscription.monthlyCost, result.subscription.currency)
            return "You're paying \(wasted) — no usage data available"
        }
        guard let cph = result.costPerHour else {
            return "Add usage data to see your cost per hour"
        }
        let formatted = CostPerUseCalculator.formatCostPerHour(cph, currencyCode: result.subscription.currency)
        return "You're paying \(formatted) per hour of use"
    }

    private var insightText: String {
        if result.isWasted {
            return "Consider pausing to save money this month"
        }
        switch result.valueTier {
        case .great:
            return "Excellent value — you use this regularly"
        case .fair:
            return "Moderate value — track for another month"
        case .poor:
            return "Low value — consider if it's worth keeping"
        case .unknown:
            return "No usage data — tap to add manually"
        }
    }

    private var insightIcon: String {
        if result.isWasted { return "exclamationmark.triangle.fill" }
        switch result.valueTier {
        case .great:   return "checkmark.seal.fill"
        case .fair:    return "exclamationmark.triangle.fill"
        case .poor:    return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var insightColor: Color {
        if result.isWasted { return .red }
        return result.valueTier.swiftUIColor
    }

    private var cardAccentColor: Color {
        if result.isWasted { return .red }
        switch result.valueTier {
        case .great:   return .kept
        case .fair:    return .decide
        case .poor:    return .due
        case .unknown: return Color.inkText
        }
    }
}

// MARK: - Value Tier Badge
struct ValueTierBadge: View {
    let tier: ValueTier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.icon)
                .font(.caption2.weight(.semibold))
            Text(tier.label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tier.swiftUIColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tier.swiftUIColor.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Detail Pill
struct DetailPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(Color.inkTextMuted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.inkRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}


