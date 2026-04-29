import SwiftUI

@MainActor
struct SubscriptionHealthScoreSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var appear = false
    @State private var animatedScore: Double = 0

    private var healthScore: Int {
        let subs = store.subscriptions
        guard !subs.isEmpty else { return 0 }

        var score = 0

        // 40 points: billing dates known
        let withBillingDate = subs.filter { $0.nextBillingDate != nil }.count
        let billingScore = Int((Double(withBillingDate) / Double(subs.count)) * 40)
        score += billingScore

        // 30 points: usage tracked
        let withUsage = subs.filter { screenTimeManager.getCurrentMonthUsage(for: $0.name) > 0 }.count
        let usageScore = Int((Double(withUsage) / Double(subs.count)) * 30)
        score += usageScore

        // 15 points: no paused subscriptions with expired dates
        let activePaused = store.pausedSubscriptions.filter {
            guard let until = $0.pausedUntil else { return false }
            return until > Date()
        }.count
        let pauseScore = activePaused > 0 ? 15 : 0
        score += pauseScore

        // 15 points: mix of categories (diversified tracking)
        let uniqueCategories = Set(subs.map { $0.category }).count
        let categoryScore = min(15, uniqueCategories * 3)
        score += categoryScore

        return min(100, score)
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
            return "You're on top of your subscriptions. Great job tracking everything!"
        case 60..<80:
            return "Mostly tracked. Add missing billing dates or usage to improve."
        case 40..<60:
            return "Some gaps in your tracking. Tap a subscription to fill in details."
        case 20..<40:
            return "Several subscriptions need attention. Add billing dates and usage."
        default:
            return "Start by adding your subscriptions and setting billing dates."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Health")
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.primary)

                    Text("How well you're managing your subscriptions")
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

            // Breakdown
            BreakdownRow(icon: "calendar", label: "Billing dates set", count: store.subscriptions.filter { $0.nextBillingDate != nil }.count, total: store.subscriptions.count)
            BreakdownRow(icon: "clock", label: "Usage tracked", count: store.subscriptions.filter { screenTimeManager.getCurrentMonthUsage(for: $0.name) > 0 }.count, total: store.subscriptions.count)
            BreakdownRow(icon: "pause.circle", label: "Active pause reminders", count: store.pausedSubscriptions.count, total: store.subscriptions.count)
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
    }
}

struct BreakdownRow: View {
    let icon: String
    let label: String
    let count: Int
    let total: Int

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

            Text("\(count)/\(total)")
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
