import SwiftUI

// MARK: - Analysis View (merged Genius + Insights)
//
// Static analytics (health score, categories, forecast) auto-run on open.
// AI recommendations (waste alerts, actionable insights) require "Run Analysis" tap.
// Free users see the static section; AI section prompts paywall.

@MainActor
struct AnalysisView: View {
    @ObservedObject private var insightsEngine = RealInsightsEngine.shared
    @ObservedObject private var geniusEngine = RealGeniusEngine.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared

    @State private var aiState: AIRunState = .idle
    @State private var showingPaywall = false
    @State private var appeared = false

    private enum AIRunState {
        case idle
        case analyzing
        case results(GeniusReport)
        case noOpportunities
        case error(String)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                header
                    .padding(.top, 20)

                if store.subscriptions.isEmpty {
                    emptyState
                } else {
                    // --- Static analytics (always auto-computed) ---
                    staticSection
                        .opacity(appeared ? 1 : 0)

                    // --- AI recommendation section ---
                    aiDivider

                    aiSection
                        .opacity(appeared ? 1 : 0)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.obsidianBlack.ignoresSafeArea())
        .task(id: store.subscriptions.count) {
            await insightsEngine.analyze(subscriptions: store.subscriptions)
            // Auto-run genius for Pro users once when subscriptions are available
            if paymentManager.isPremium, !store.subscriptions.isEmpty, case .idle = aiState {
                await runAIAnalysis()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.05)) { appeared = true }
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Analysis")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            if let date = insightsEngine.lastAnalysisDate {
                Text("Updated \(date.formatted(.relative(presentation: .named)))")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            } else if insightsEngine.isAnalyzing {
                Text("Analyzing…")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            } else {
                Text("Subscription health and optimization")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Static Section

    private var staticSection: some View {
        VStack(spacing: 16) {
            if insightsEngine.isAnalyzing {
                SkeletonCard(height: 120, cornerRadius: 20)
                SkeletonCard(height: 100, cornerRadius: 20)
                SkeletonCard(height: 80, cornerRadius: 20)
            } else {
                // B4: Savings opportunity badge — shown when waste is detected
                let totalSavings = insightsEngine.wasteAlerts.reduce(Decimal(0)) { $0 + $1.potentialSavings }
                if totalSavings > 0 {
                    SavingsOpportunityBadge(
                        monthlyAmount: totalSavings,
                        alertCount: insightsEngine.wasteAlerts.count
                    )
                }

                if let forecast = insightsEngine.spendingForecast, forecast.annualCurrent > 0 {
                    AnnualSpendRealityCard(annualSpend: forecast.annualCurrent)
                }

                HealthScoreCard(score: insightsEngine.healthScore)

                if !insightsEngine.categoryBreakdown.isEmpty {
                    CategoryBreakdownCard(categories: insightsEngine.categoryBreakdown)
                }

                if let forecast = insightsEngine.spendingForecast {
                    SpendingForecastCard(forecast: forecast)
                }

                // Waste alerts — most actionable auto-computed output
                if !insightsEngine.wasteAlerts.isEmpty {
                    WasteAlertsSection(alerts: insightsEngine.wasteAlerts)
                }
            }
        }
    }

    // MARK: - Section Divider

    private var aiDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            Text("AI RECOMMENDATIONS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
                .tracking(1.5)
                .fixedSize()

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - AI Section

    private var aiSection: some View {
        VStack(spacing: 16) {
            // Run button
            Button {
                if paymentManager.isPremium {
                    Task { await runAIAnalysis() }
                } else {
                    HapticStyle.medium.trigger()
                    showingPaywall = true
                }
            } label: {
                HStack(spacing: 10) {
                    if case .analyzing = aiState {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: paymentManager.isPremium ? "wand.and.stars" : "crown.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(aiButtonLabel)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(paymentManager.isPremium ? Color.accentMint : Color.orange)
                        .shadow(color: (paymentManager.isPremium ? Color.accentMint : Color.orange).opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled({ if case .analyzing = aiState { return true } else { return false } }())

            // AI results
            switch aiState {
            case .idle:
                aiIdleState

            case .analyzing:
                VStack(spacing: 16) {
                    SkeletonCard(height: 90, cornerRadius: 16)
                    SkeletonCard(height: 90, cornerRadius: 16)
                    SkeletonCard(height: 90, cornerRadius: 16)
                }

            case .results(let report):
                aiResultsSection(report: report)

            case .noOpportunities:
                noOpportunitiesState

            case .error(let msg):
                aiErrorState(message: msg)
            }
        }
    }

    private var aiButtonLabel: String {
        if case .analyzing = aiState { return "Analyzing…" }
        return paymentManager.isPremium ? "Run Deep Analysis" : "Unlock Pro to Analyze"
    }

    // MARK: - AI Idle State

    private var aiIdleState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.10))
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentMint)
            }

            VStack(spacing: 6) {
                Text("Ready to Analyze")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text("Discover savings opportunities and optimization tips for your subscriptions.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: 20)
    }

    // MARK: - AI Results

    private func aiResultsSection(report: GeniusReport) -> some View {
        VStack(spacing: 12) {
            // Summary pills
            HStack(spacing: 12) {
                analysisPill(
                    icon: "lightbulb.fill",
                    value: "\(report.actionableCount)",
                    label: "Opportunities",
                    color: .yellow
                )
                analysisPill(
                    icon: "dollarsign.circle.fill",
                    value: CurrencyManager.shared.format(report.totalPotentialSavings),
                    label: "Potential/mo",
                    color: Color.accentMint
                )
            }

            // Insights
            if !report.insights.isEmpty {
                ForEach(Array(report.insights.prefix(8).enumerated()), id: \.element.id) { index, insight in
                    GeniusInsightCard(insight: insight)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: appeared)
                }
            }
        }
    }

    private func analysisPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .surfaceCard(cornerRadius: 16)
    }

    // MARK: - No Opportunities

    private var noOpportunitiesState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentMint)
            }
            VStack(spacing: 6) {
                Text("Fully Optimized")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("Your subscriptions are well-optimized. Enable Screen Time tracking for deeper usage-based recommendations.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: 20)
    }

    // MARK: - Error State

    private func aiErrorState(message: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.red)
            }
            VStack(spacing: 6) {
                Text("Analysis Failed")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.10))
                    .frame(width: 72, height: 72)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentMint)
            }
            VStack(spacing: 8) {
                Text("Nothing to Analyze Yet")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text("Add your subscriptions and come back to see a full health report and savings opportunities.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: 24)
        .padding(.top, 24)
    }

    // MARK: - Run AI Analysis

    private func runAIAnalysis() async {
        aiState = .analyzing
        HapticStyle.medium.trigger()

        let subs = store.subscriptions
        guard !subs.isEmpty else {
            aiState = .noOpportunities
            return
        }

        do {
            let report = try await geniusEngine.analyze(subscriptions: subs)
            try await Task.sleep(for: .milliseconds(400))
            if report.insights.isEmpty {
                aiState = .noOpportunities
            } else {
                HapticStyle.success.trigger()
                aiState = .results(report)
            }
        } catch {
            aiState = .error(error.localizedDescription)
        }
    }
}

// MARK: - Annual Spend Reality Card

private struct AnnualSpendRealityCard: View {
    let annualSpend: Decimal

    private var annualDouble: Double {
        NSDecimalNumber(decimal: annualSpend).doubleValue
    }

    private struct Comparison {
        let icon: String
        let count: String
        let label: String
    }

    private var comparisons: [Comparison] {
        // Convert USD reference prices to user's currency for accurate comparisons
        let cm = CurrencyManager.shared
        let latteUSD = Decimal(6.50)
        let flightUSD = Decimal(350)
        let hotelUSD = Decimal(180)
        let latteLocal = NSDecimalNumber(decimal: cm.convertToSelected(latteUSD, from: "USD")).doubleValue
        let flightLocal = NSDecimalNumber(decimal: cm.convertToSelected(flightUSD, from: "USD")).doubleValue
        let hotelLocal = NSDecimalNumber(decimal: cm.convertToSelected(hotelUSD, from: "USD")).doubleValue
        let lattes = latteLocal > 0 ? Int(annualDouble / latteLocal) : 0
        let flights = flightLocal > 0 ? Int(annualDouble / flightLocal) : 0
        let hotelNights = hotelLocal > 0 ? Int(annualDouble / hotelLocal) : 0
        return [
            Comparison(icon: "cup.and.saucer.fill",  count: "\(lattes)",       label: "lattes"),
            Comparison(icon: "airplane",              count: "\(flights)",      label: "round trips"),
            Comparison(icon: "moon.stars.fill",       count: "\(hotelNights)", label: "hotel nights"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This year you'll spend")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.obsidianTextSecondary)
                    Text(CurrencyManager.shared.format(annualSpend))
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(Color.accentMint)
                    Text("on subscriptions")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                Spacer()
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentMint.opacity(0.3))
            }

            Divider()
                .background(Color.white.opacity(0.06))

            HStack(spacing: 0) {
                ForEach(comparisons.indices, id: \.self) { i in
                    let c = comparisons[i]
                    VStack(spacing: 4) {
                        Image(systemName: c.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.obsidianTextSecondary)
                        Text(c.count)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text(c.label)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    if i < comparisons.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20)
    }
}

#Preview {
    AnalysisView()
}
