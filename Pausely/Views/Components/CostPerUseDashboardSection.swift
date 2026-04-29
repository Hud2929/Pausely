import SwiftUI
import TipKit

// MARK: - Cost Per Use Dashboard Section
/// Integrated into the Dashboard view. Shows top/bottom value subscriptions and efficiency score.
struct CostPerUseDashboardSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showingShareSheet = false
    @State private var appear = false
    private let costPerUseTip = CostPerUseTip()

    /// Get usage hours for a subscription name
    private func usageHours(for name: String) -> Double? {
        let minutes = screenTimeManager.getCurrentMonthUsage(for: name)
        guard minutes > 0 else { return nil }
        return Double(minutes) / 60.0
    }

    private var rankedResults: [CostPerUseResult] {
        CostPerUseCalculator.rankedByValue(
            subscriptions: store.activeSubscriptions,
            usageProvider: usageHours
        )
    }

    private var bestValue: [CostPerUseResult] {
        Array(rankedResults.prefix(3).filter { $0.valueScore != nil })
    }

    private var worstValue: [CostPerUseResult] {
        let withScores = rankedResults.filter { $0.valueScore != nil }
        return Array(withScores.suffix(3).reversed())
    }

    private var efficiencyScore: Double? {
        CostPerUseCalculator.efficiencyScore(
            for: store.activeSubscriptions,
            usageProvider: usageHours
        )
    }

    private var moneySavedByPausing: Decimal {
        store.pausedSubscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    private var hasEnoughData: Bool {
        rankedResults.contains { $0.valueScore != nil }
    }

    private var hasEstimatedData: Bool {
        rankedResults.contains { screenTimeManager.isEstimated(for: $0.subscription.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Cost Per Use"))
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.primary)

                    Text(LocalizedStringKey("Where your money goes furthest"))
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(.secondary)

                    if hasEstimatedData {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 10))
                            Text("Hours marked with ~ are estimated from session counts. Tap a subscription to enter exact minutes.")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.top, 2)
                    }
                }
                // .popoverTip(costPerUseTip, arrowEdge: .top) // Disabled for testing

                Spacer()

                // Share button
                if hasEnoughData {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(AppTypography.headlineMedium)
                            .foregroundStyle(Color.luxuryGold)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.luxuryGold.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                    }
                    .accessibilityLabel("Share cost per use insights")
                }
            }

            if !hasEnoughData {
                // Empty state
                CostPerUseEmptyState()
            } else {
                // Efficiency score card
                if let score = efficiencyScore {
                    EfficiencyScoreCard(score: score)
                }

                // Best value
                if !bestValue.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(Color.semanticSuccess)
                            Text(LocalizedStringKey("Best Value"))
                                .font(AppTypography.headlineSmall)
                                .foregroundStyle(.primary)
                        }

                        VStack(spacing: 8) {
                            ForEach(bestValue.prefix(3)) { result in
                                CostPerUseCompactRow(result: result, isEstimated: screenTimeManager.isEstimated(for: result.subscription.name))
                            }
                        }
                    }
                }

                // Worst value (with suggestion)
                if !worstValue.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(AppTypography.labelMedium)
                                .foregroundStyle(Color.semanticWarning)
                            Text(LocalizedStringKey("Consider Pausing"))
                                .font(AppTypography.headlineSmall)
                                .foregroundStyle(.primary)
                        }

                        VStack(spacing: 8) {
                            ForEach(worstValue.prefix(3)) { result in
                                CostPerUseCompactRow(result: result, isEstimated: screenTimeManager.isEstimated(for: result.subscription.name))
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                appear = true
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareableInsightSheet(
                totalMonthlySpend: store.totalMonthlySpend,
                bestValueSubscription: bestValue.first,
                worstValueSubscription: worstValue.first,
                moneySavedByPausing: moneySavedByPausing,
                efficiencyScore: efficiencyScore
            )
        }
    }
}

// MARK: - Efficiency Score Card
struct EfficiencyScoreCard: View {
    let score: Double
    @State private var animatedScore: Double = 0

    var body: some View {
        HStack(spacing: 20) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: CGFloat(animatedScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [scoreColor.opacity(0.7), scoreColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(animatedScore))")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                    Text("/100")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    animatedScore = score
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Subscription Efficiency"))
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                Text(scoreLabel)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(scoreColor)
                    .fontWeight(.semibold)

                Text(scoreDescription)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .glassBackground(cornerRadius: 20, strokeColor: scoreColor.opacity(0.2), strokeWidth: 1)
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .semanticSuccess
        case 60..<80:  return Color.luxuryTeal
        case 40..<60:  return .semanticWarning
        case 20..<40:  return Color(hex: "F97316")
        default:       return .semanticDestructive
        }
    }

    private var scoreLabel: String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Fair"
        case 20..<40:  return "Needs Work"
        default:       return "Critical"
        }
    }

    private var scoreDescription: String {
        switch score {
        case 80...100:
            return "Your subscriptions are well-utilized. Great job!"
        case 60..<80:
            return "Most subscriptions are giving you good value."
        case 40..<60:
            return "Some subscriptions could use more attention."
        case 20..<40:
            return "Several subscriptions are underused. Consider pausing."
        default:
            return "Many subscriptions are going unused. Big savings opportunity!"
        }
    }
}

// MARK: - Compact Row (for dashboard list)
struct CostPerUseCompactRow: View {
    let result: CostPerUseResult
    let isEstimated: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Color dot
            Circle()
                .fill(result.valueTier.swiftUIColor)
                .frame(width: 8, height: 8)

            // Name
            Text(result.subscription.name)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Hours
            Text((isEstimated ? "~" : "") + result.displayHoursUsed)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.secondary)

            Text("•")
                .font(AppTypography.labelMedium)
                .foregroundStyle(.secondary.opacity(0.5))

            // Cost per hour
            Text(result.displayCostPerHour + "/hr")
                .font(AppTypography.labelMedium)
                .foregroundStyle(result.valueTier.swiftUIColor)
                .fontWeight(.semibold)
        }
        .padding(12)
        .glassBackground(
            cornerRadius: 12,
            strokeColor: result.valueTier.swiftUIColor.opacity(0.15),
            strokeWidth: 0.5
        )
    }
}

// MARK: - Empty State
struct CostPerUseEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "chart.bar.xaxis")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.luxuryPurple)
            }

            VStack(spacing: 6) {
                Text("No Usage Data Yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.primary)

                Text(LocalizedStringKey("Enable Screen Time tracking or manually add usage to see your cost-per-use insights."))
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            NavigationLink {
                ScreenTimeSetupView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark")
                    Text(LocalizedStringKey("Enable Tracking"))
                }
                .font(AppTypography.headlineSmall)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [Color.luxuryPurple, Color.luxuryPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: 20, strokeColor: Color.luxuryPurple.opacity(0.2), strokeWidth: 1)
    }
}

// MARK: - Smart Alerts Section
struct CostPerUseAlertsSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var dismissedAlerts: Set<UUID> = []

    private func usageHours(for name: String) -> Double? {
        let minutes = screenTimeManager.getCurrentMonthUsage(for: name)
        guard minutes > 0 else { return nil }
        return Double(minutes) / 60.0
    }

    private var alerts: [CostPerUseAlert] {
        var result: [CostPerUseAlert] = []

        for sub in store.activeSubscriptions {
            let hours = usageHours(for: sub.name) ?? 0

            // Low usage alert (only if we have some usage data)
            if hours > 0, CostPerUseCalculator.shouldAlertPause(subscription: sub, monthlyHoursUsed: hours, thresholdHours: 2) {
                result.append(CostPerUseAlert(
                    type: .unused,
                    subscription: sub,
                    message: "Low usage on \(sub.name)",
                    detail: "You've used it for only \(CostPerUseCalculator.formatHours(hours)) this month. Consider pausing?",
                    actionLabel: "Review"
                ))
            }
        }

        return result.filter { !dismissedAlerts.contains($0.id) }
    }

    var body: some View {
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(Color.semanticWarning)
                    Text(LocalizedStringKey("Smart Alerts"))
                        .font(AppTypography.headlineSmall)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    ForEach(alerts.prefix(3)) { alert in
                        SmartAlertCard(alert: alert) {
                            dismissedAlerts.insert(alert.id)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Smart Alert Card
struct SmartAlertCard: View {
    let alert: CostPerUseAlert
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(alertColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: alertIcon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(alertColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.message)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(alert.detail)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Dismiss alert")
        }
        .padding(14)
        .glassBackground(cornerRadius: 16, strokeColor: alertColor.opacity(0.2), strokeWidth: 1)
    }

    private var alertColor: Color {
        switch alert.type {
        case .unused:        return .orange
        case .costIncreased: return .red
        case .zeroWaste:     return .red
        case .poorValue:     return .semanticWarning
        }
    }

    private var alertIcon: String {
        switch alert.type {
        case .unused:        return "pause.circle.fill"
        case .costIncreased: return "arrow.up.circle.fill"
        case .zeroWaste:     return "exclamationmark.triangle.fill"
        case .poorValue:     return "dollarsign.circle.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AnimatedGradientBackground()
        ScrollView {
            CostPerUseDashboardSection()
                .padding(.top, 40)
        }
    }
}
