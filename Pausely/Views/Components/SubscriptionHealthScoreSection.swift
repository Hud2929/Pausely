import SwiftUI

@MainActor
struct SubscriptionHealthScoreSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var insightsEngine = RealInsightsEngine.shared
    @State private var appear = false
    @State private var animatedScore: Double = 0

    private var healthScore: Int {
        insightsEngine.healthScore
    }

    private var scoreLabel: String {
        switch healthScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Needs Work"
        default: return "Get Started"
        }
    }

    private var scoreColor: Color {
        switch healthScore {
        case 80...100: return .semanticSuccess
        case 60..<80: return Color.luxuryTeal
        case 40..<60: return .semanticWarning
        case 20..<40: return Color(hex: "F97316")
        default: return .semanticDestructive
        }
    }

    private var scoreDescription: String {
        switch healthScore {
        case 80...100:
            return "Your subscriptions are well-organized, affordable, and delivering value."
        case 60..<80:
            return "Solid foundation. A few tweaks to cost or tracking could improve your score."
        case 40..<60:
            return "Some areas need attention. Review untracked subscriptions or high costs."
        case 20..<39:
            return "Several issues detected. Add billing dates, track usage, and review duplicates."
        default:
            return "Start by adding subscriptions and setting billing dates to build your health score."
        }
    }

    private var activeSubs: [Subscription] {
        store.subscriptions.filter { $0.status == .active }
    }

    private var dataCompleteness: String {
        guard !activeSubs.isEmpty else { return "0%" }
        let withBilling = activeSubs.filter { $0.nextBillingDate != nil }.count
        let withUsage = activeSubs.filter { screenTimeManager.getCurrentMonthUsage(for: $0.name) > 0 }.count
        let avg = Double(withBilling + withUsage) / Double(activeSubs.count * 2)
        return "\(Int(avg * 100))%"
    }

    private var avgMonthlyCost: String {
        guard !activeSubs.isEmpty else { return "$0" }
        let total = activeSubs.reduce(Decimal(0)) { $0 + $1.monthlyCost }
        let avg = total / Decimal(activeSubs.count)
        return CurrencyManager.shared.format(avg)
    }

    private var duplicateCount: Int {
        let grouped = Dictionary(grouping: activeSubs) { $0.name.lowercased() }
        return grouped.values.filter { $0.count > 1 }.reduce(0) { $0 + $1.count - 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Health")
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.primary)

                    Text("Overall score based on organization, cost, and value")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 20) {
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
                        animatedScore = Double(healthScore)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(scoreLabel)
                        .font(AppTypography.headlineSmall)
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

            // Breakdown — reflects the 5 components of the unified score
            BreakdownRow(icon: "checkmark.circle", label: "Data completeness", value: dataCompleteness)
            BreakdownRow(icon: "dollarsign.circle", label: "Avg monthly cost", value: avgMonthlyCost)
            BreakdownRow(icon: "chart.bar", label: "Active subscriptions", value: "\(activeSubs.count)")
            if duplicateCount > 0 {
                BreakdownRow(icon: "doc.on.doc", label: "Duplicate services", value: "\(duplicateCount)")
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
            Task {
                await insightsEngine.analyze(subscriptions: store.subscriptions)
                withAnimation(.easeOut(duration: 1.0)) {
                    animatedScore = Double(healthScore)
                }
            }
        }
        .onChange(of: store.subscriptions.count) {
            Task {
                await insightsEngine.analyze(subscriptions: store.subscriptions)
                withAnimation(.easeOut(duration: 1.0)) {
                    animatedScore = Double(healthScore)
                }
            }
        }
    }
}

struct BreakdownRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(label)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.primary)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        ScrollView {
            SubscriptionHealthScoreSection()
                .padding(.top, 40)
        }
    }
}
