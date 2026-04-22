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
        .glassCard(color: cardAccentColor)
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
            // Subscription icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [cardAccentColor.opacity(0.4), cardAccentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Text(String(result.subscription.name.prefix(1)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.subscription.name)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Value tier badge
                    ValueTierBadge(tier: result.valueTier)

                    if result.isWasted {
                        Text("Wasted")
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.15))
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
                .font(AppTypography.labelLarge)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                if let cph = result.costPerHour {
                    Text(CostPerUseCalculator.formatCostPerHour(cph, currencyCode: result.subscription.currency))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(result.valueTier.swiftUIColor)
                } else {
                    Text("—")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let score = result.valueScore {
                    Text("/ \(CostPerUseCalculator.formatValueScore(score))")
                        .font(AppTypography.headlineSmall)
                        .foregroundStyle(.secondary)
                }
            }

            // Contextual subtitle
            Text(subtitleText)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.secondary)
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
                .font(AppTypography.labelMedium)
                .foregroundStyle(Color.luxuryTeal)

            Text("You use \(result.subscription.name)")
                .font(AppTypography.bodySmall)
                .foregroundStyle(.secondary)

            + Text(" \(String(format: "%.1f", ratio))x ")
                .font(AppTypography.bodySmall)
                .foregroundStyle(Color.luxuryTeal)
                .fontWeight(.semibold)

            + Text("more than \(name)")
                .font(AppTypography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.luxuryTeal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Insight Row
    private var insightRow: some View {
        HStack(spacing: 8) {
            Image(systemName: insightIcon)
                .font(AppTypography.labelMedium)
                .foregroundStyle(insightColor)

            Text(insightText)
                .font(AppTypography.bodySmall)
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
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = result.subscription.currency
            formatter.maximumFractionDigits = 2
            let wasted = formatter.string(from: result.subscription.monthlyCost as NSDecimalNumber) ?? "\(result.subscription.monthlyCost)"
            return "You're paying \(wasted) for 0 hours of use this month"
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
        case .great:   return .semanticSuccess
        case .fair:    return .semanticWarning
        case .poor:    return .semanticDestructive
        case .unknown: return .luxuryPurple
        }
    }
}

// MARK: - Value Tier Badge
struct ValueTierBadge: View {
    let tier: ValueTier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(tier.label)
                .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Compact Cost Per Use Row (for lists)
struct CostPerUseRow: View {
    let result: CostPerUseResult

    var body: some View {
        HStack(spacing: 14) {
            // Value indicator dot
            Circle()
                .fill(result.valueTier.swiftUIColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.subscription.name)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(result.displayHoursUsed + " used")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text(result.displayCostPerHour + "/hr")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(result.valueTier.swiftUIColor)
                }
            }

            Spacer()

            // Value score circle
            if let score = result.valueScore {
                ZStack {
                    Circle()
                        .stroke(result.valueTier.swiftUIColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 38, height: 38)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(result.valueTier.swiftUIColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(-90))

                    Text(CostPerUseCalculator.formatValueScore(score))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassBackground(cornerRadius: 16, strokeColor: result.valueTier.swiftUIColor.opacity(0.15), strokeWidth: 1)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AnimatedGradientBackground()

        ScrollView {
            VStack(spacing: 20) {
                let sub = Subscription(
                    name: "Netflix",
                    amount: Decimal(15.99),
                    billingFrequency: .monthly
                )
                let result = CostPerUseResult(
                    subscription: sub,
                    monthlyHoursUsed: 25,
                    costPerHour: Decimal(0.64),
                    costPerSession: nil,
                    valueScore: 85,
                    valueTier: .great,
                    sessions: 12
                )
                CostPerUseCard(result: result)

                let sub2 = Subscription(
                    name: "Spotify",
                    amount: Decimal(10.99),
                    billingFrequency: .monthly
                )
                let result2 = CostPerUseResult(
                    subscription: sub2,
                    monthlyHoursUsed: 0.5,
                    costPerHour: Decimal(21.98),
                    costPerSession: nil,
                    valueScore: 25,
                    valueTier: .poor,
                    sessions: 2
                )
                CostPerUseCard(result: result2, showComparison: true, comparisonRatio: 2.5, comparisonName: "Netflix")

                CostPerUseRow(result: result)
                CostPerUseRow(result: result2)
            }
            .padding()
        }
    }
}
