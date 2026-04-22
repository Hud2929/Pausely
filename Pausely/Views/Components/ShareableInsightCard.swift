import SwiftUI

// MARK: - Shareable Insight Card
/// A beautiful, screenshot-ready card for sharing subscription insights on social media.
/// Designed for Instagram Stories with a 9:16 aspect ratio feel.
struct ShareableInsightCard: View {
    let totalMonthlySpend: Decimal
    let bestValueSubscription: CostPerUseResult?
    let worstValueSubscription: CostPerUseResult?
    let moneySavedByPausing: Decimal
    let efficiencyScore: Double?

    @Environment(\.colorScheme) private var colorScheme
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            // Top gradient header
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)

            // Main stats
            statsSection
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            // Best / Worst value
            if bestValueSubscription != nil || worstValueSubscription != nil {
                valueHighlightsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            // Money saved
            if moneySavedByPausing > 0 {
                savingsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            // Efficiency score
            if let score = efficiencyScore {
                efficiencySection(score: score)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }

            // Branding footer
            footerSection
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(
            ZStack {
                // Deep gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e"),
                        Color(hex: "0f0f1a")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative glows
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.luxuryPurple.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.8)
                        .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.1)
                        .blur(radius: 50)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.luxuryPink.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.4
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.6)
                        .blur(radius: 40)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.luxuryGold.opacity(0.4),
                            Color.luxuryPurple.opacity(0.2),
                            Color.luxuryPink.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1 : 0.95)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appear = true
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            // App logo / icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.luxuryPurple, Color.luxuryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 20, x: 0, y: 10)

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("My Subscription Insights")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Tracked with Pausely")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.luxuryGold)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 16) {
            // Total monthly spend (hero number)
            VStack(spacing: 4) {
                Text("Total Monthly Spend")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)

                Text(totalMonthlySpend.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.luxuryGold, Color.luxuryPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.luxuryGold.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Value Highlights
    private var valueHighlightsSection: some View {
        VStack(spacing: 12) {
            if let best = bestValueSubscription {
                ShareableHighlightRow(
                    icon: "trophy.fill",
                    iconColor: .semanticSuccess,
                    title: "Best Value",
                    subtitle: best.subscription.name,
                    detail: "\(best.displayCostPerHour)/hr • Score: \(best.displayValueScore)"
                )
            }

            if let worst = worstValueSubscription {
                ShareableHighlightRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .semanticWarning,
                    title: "Needs Attention",
                    subtitle: worst.subscription.name,
                    detail: "\(worst.displayCostPerHour)/hr • Score: \(worst.displayValueScore)"
                )
            }
        }
    }

    // MARK: - Savings Section
    private var savingsSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.semanticSuccess.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "banknote.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.semanticSuccess)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Money Saved by Pausing")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Text(moneySavedByPausing.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.semanticSuccess)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.semanticSuccess.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.semanticSuccess.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Efficiency Section
    private func efficiencySection(score: Double) -> some View {
        VStack(spacing: 12) {
            Text("Subscription Efficiency")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 120, height: 120)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.luxuryPurple, Color.luxuryPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("/ 100")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Text(efficiencyLabel(score: score))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(efficiencyColor(score: score))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 12))
                .foregroundStyle(Color.luxuryGold)

            Text("pausely.app")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.luxuryGold)

            Spacer()

            Text("Track smarter. Spend less.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Helpers

    private func efficiencyLabel(score: Double) -> String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Fair"
        case 20..<40:  return "Needs Work"
        default:       return "Critical"
        }
    }

    private func efficiencyColor(score: Double) -> Color {
        switch score {
        case 80...100: return .semanticSuccess
        case 60..<80:  return Color.luxuryTeal
        case 40..<60:  return .semanticWarning
        case 20..<40:  return Color(hex: "F97316")
        default:       return .semanticDestructive
        }
    }
}

// MARK: - Shareable Highlight Row
struct ShareableHighlightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Text(subtitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(iconColor)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(iconColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Share Sheet Wrapper
struct ShareableInsightSheet: View {
    @Environment(\.dismiss) private var dismiss

    let totalMonthlySpend: Decimal
    let bestValueSubscription: CostPerUseResult?
    let worstValueSubscription: CostPerUseResult?
    let moneySavedByPausing: Decimal
    let efficiencyScore: Double?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ShareableInsightCard(
                        totalMonthlySpend: totalMonthlySpend,
                        bestValueSubscription: bestValueSubscription,
                        worstValueSubscription: worstValueSubscription,
                        moneySavedByPausing: moneySavedByPausing,
                        efficiencyScore: efficiencyScore
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Share button
                    Button(action: shareCard) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Insights")
                        }
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.luxuryPurple, Color.luxuryPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .background(Color.deepBlack.ignoresSafeArea())
            .navigationTitle("Share Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func shareCard() {
        // In a real implementation, you would render the card to an image
        // using UIGraphicsImageRenderer and present a UIActivityViewController
        HapticStyle.success.trigger()
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ShareableInsightCard(
            totalMonthlySpend: Decimal(127.50),
            bestValueSubscription: CostPerUseResult(
                subscription: Subscription(name: "Netflix", price: 15.99, category: "Entertainment"),
                monthlyHoursUsed: 25,
                costPerHour: Decimal(0.64),
                costPerSession: nil,
                valueScore: 85,
                valueTier: .great,
                sessions: 12
            ),
            worstValueSubscription: CostPerUseResult(
                subscription: Subscription(name: "Adobe CC", price: 54.99, category: "Productivity"),
                monthlyHoursUsed: 2,
                costPerHour: Decimal(27.50),
                costPerSession: nil,
                valueScore: 15,
                valueTier: .poor,
                sessions: 3
            ),
            moneySavedByPausing: Decimal(32.00),
            efficiencyScore: 62
        )
        .padding()
    }
}
