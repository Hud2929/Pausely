import SwiftUI

// MARK: - Cost Per Use Detail Section
/// Integrated into SubscriptionManagementView. Shows cost-per-use analytics,
/// usage trends, and comparisons for a single subscription.
struct CostPerUseDetailSection: View {
    let subscription: Subscription
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var appear = false

    private var usageMinutes: Int {
        screenTimeManager.getCurrentMonthUsage(for: subscription.name)
    }

    private var usageHours: Double {
        Double(usageMinutes) / 60.0
    }

    private var result: CostPerUseResult {
        let cph = CostPerUseCalculator.costPerHour(monthlyCost: subscription.monthlyCost, monthlyHoursUsed: usageHours)
        let score = CostPerUseCalculator.valueScore(monthlyCost: subscription.monthlyCost, monthlyHoursUsed: usageHours)
        let tier: ValueTier
        if let cph = cph {
            tier = CostPerUseCalculator.valueTier(costPerHour: cph)
        } else {
            tier = .unknown
        }
        return CostPerUseResult(
            subscription: subscription,
            monthlyHoursUsed: usageHours,
            costPerHour: cph,
            costPerSession: nil,
            valueScore: score,
            valueTier: tier,
            sessions: 0
        )
    }

    /// Mock 3-month trend data (in a real app, this would come from historical storage)
    private var trendData: [Double] {
        // Simulate: current month, last month, 2 months ago
        // In production, fetch from a historical usage store
        let current = usageHours
        let lastMonth = max(0, current * Double.random(in: 0.5...1.5))
        let twoMonthsAgo = max(0, current * Double.random(in: 0.3...1.8))
        return [twoMonthsAgo, lastMonth, current]
    }

    private var trendLabels: [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<3).map { offset in
            if let date = calendar.date(byAdding: .month, value: -(2 - offset), to: Date()) {
                return formatter.string(from: date)
            }
            return ""
        }
    }

    private var totalTrackedHours: Double {
        // In production, sum all historical usage
        usageHours * 3 // Approximation for demo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section title
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(Color.luxuryPurple)

                Text("Cost Per Use")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.primary)

                Spacer()
            }

            // Main cost-per-use card
            CostPerUseCard(result: result)

            // Usage trend (3-month bar chart)
            if usageMinutes > 0 {
                usageTrendSection
            }

            // Total tracked time
            if totalTrackedHours > 0 {
                totalTrackedSection
            }

            // Comparison to similar subscriptions
            similarSubscriptionsComparison
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appear = true
            }
        }
    }

    // MARK: - Usage Trend Section
    private var usageTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Usage Trend")
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                Spacer()

                Text("Last 3 Months")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
            }

            // Simple bar chart
            HStack(alignment: .bottom, spacing: 16) {
                let maxValue = max(trendData.max() ?? 1, 0.1)

                ForEach(0..<trendData.count, id: \.self) { index in
                    VStack(spacing: 6) {
                        // Value label
                        Text(CostPerUseCalculator.formatHours(trendData[index]))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        // Bar
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        barColor(for: trendData[index]).opacity(0.8),
                                        barColor(for: trendData[index]).opacity(0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 40, height: max(20, CGFloat(trendData[index] / maxValue) * 100))

                        // Month label
                        Text(trendLabels[index])
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .glassBackground(cornerRadius: 16, strokeColor: .white.opacity(0.1), strokeWidth: 0.5)
        }
    }

    // MARK: - Total Tracked Section
    private var totalTrackedSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.luxuryTeal.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.luxuryTeal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Since You Started Tracking")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.secondary)

                Text("\(CostPerUseCalculator.formatHours(totalTrackedHours)) of use")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(14)
        .glassBackground(cornerRadius: 16, strokeColor: Color.luxuryTeal.opacity(0.2), strokeWidth: 1)
    }

    // MARK: - Similar Subscriptions Comparison
    private var similarSubscriptionsComparison: some View {
        let store = SubscriptionStore.shared
        let similar = store.activeSubscriptions.filter {
            $0.id != subscription.id &&
            $0.category?.lowercased() == subscription.category?.lowercased()
        }

        guard !similar.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Category Comparison")
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    ForEach(similar.prefix(2)) { other in
                        let otherMinutes = screenTimeManager.getCurrentMonthUsage(for: other.name)
                        let otherHours = Double(otherMinutes) / 60.0

                        if usageHours > 0, otherHours > 0 {
                            let ratio = usageHours / otherHours

                            HStack(spacing: 10) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(AppTypography.labelMedium)
                                    .foregroundStyle(Color.luxuryTeal)

                                Text("You use \(subscription.name)")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(.secondary)

                                + Text(" \(String(format: "%.1f", ratio))x ")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(Color.luxuryTeal)
                                    .fontWeight(.semibold)

                                + Text("more than \(other.name)")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .padding(12)
                            .glassBackground(cornerRadius: 12, strokeColor: Color.luxuryTeal.opacity(0.15), strokeWidth: 0.5)
                        }
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private func barColor(for hours: Double) -> Color {
        if hours < 2 { return .red }
        if hours < 10 { return .orange }
        if hours < 30 { return .yellow }
        return .green
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AnimatedGradientBackground()
        ScrollView {
            CostPerUseDetailSection(
                subscription: Subscription(
                    name: "Netflix",
                    price: 15.99,
                    category: "Entertainment"
                )
            )
            .padding()
        }
    }
}
