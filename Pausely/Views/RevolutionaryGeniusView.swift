//
//  RevolutionaryGeniusView.swift
//  Pausely
//
//  REAL subscription intelligence powered by actual data
//

import SwiftUI

// MARK: - Analysis State

enum AnalysisState {
    case idle
    case analyzing
    case results(GeniusReport)
    case noInsights
    case error(String)
}

// MARK: - Revolutionary Genius View

struct RevolutionaryGeniusView: View {
    @ObservedObject private var engine = RealGeniusEngine.shared
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var analysisState: AnalysisState = .idle
    @State private var showingPaywall = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header
                    heroSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Run Analysis Button
                    analysisButton
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Results
                    switch analysisState {
                    case .idle:
                        idleState
                    case .analyzing:
                        analyzingState
                    case .results(let report):
                        if report.insights.isEmpty {
                            noInsightsState
                        } else {
                            resultsSection(report: report)
                        }
                    case .noInsights:
                        noInsightsState
                    case .error(let message):
                        errorState(message: message)
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Genius AI")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: subscriptionStore.subscriptions.count)
        }
        .task(id: subscriptionStore.subscriptions.count) {
            // Auto-run only once: when Pro user first opens Genius with subscriptions
            // and no prior analysis exists. The button remains the primary control.
            guard paymentManager.isPremium else { return }
            guard !subscriptionStore.subscriptions.isEmpty else { return }
            if case .idle = analysisState {
                await runAnalysis()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Animated brain icon
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.purple.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: 100 + CGFloat(i * 30), height: 100 + CGFloat(i * 30))
                        .scaleEffect(engine.isAnalyzing ? 1.1 : 1.0)
                        .animation(
                            UIAccessibility.isReduceMotionEnabled
                                ? .none
                                : .easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(i) * 0.3),
                            value: engine.isAnalyzing
                        )
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .frame(height: 120)

            VStack(spacing: 8) {
                Text("Subscription Genius")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Real intelligence from your actual data")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            // Total Savings Counter
            VStack(spacing: 4) {
                Text("TOTAL SAVINGS IDENTIFIED")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text(CurrencyManager.shared.format(engine.totalSavingsFound))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Analysis Button

    private var analysisButton: some View {
        Button {
            if paymentManager.isPremium {
                Task { await runAnalysis() }
            } else {
                showingPaywall = true
            }
        } label: {
            HStack(spacing: 12) {
                if case .analyzing = analysisState {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: paymentManager.isPremium ? "wand.and.stars" : "crown.fill")
                        .font(.title2)
                }

                Text(buttonLabel)
                    .font(.headline)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: paymentManager.isPremium ? [.purple, .pink] : [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .disabled(isAnalyzing)
        .accessibilityHint(isAnalyzing ? "Please wait, analysis in progress" : "")
    }

    private var isAnalyzing: Bool {
        if case .analyzing = analysisState { return true }
        return false
    }

    private var buttonLabel: String {
        if case .analyzing = analysisState {
            return "Analyzing..."
        }
        return paymentManager.isPremium ? "Run Real Analysis" : "Unlock Pro to Analyze"
    }

    // MARK: - Idle State

    private var idleState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.purple)
            }

            VStack(spacing: 6) {
                Text("Ready to Analyze")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text(subscriptionStore.subscriptions.isEmpty
                     ? "Add subscriptions first, then tap the button above to run your analysis."
                     : "Tap the button above to discover savings opportunities hidden in your subscriptions.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Analyzing State

    private var analyzingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                .scaleEffect(1.5)

            Text("Analyzing your subscriptions...")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - No Insights State

    private var noInsightsState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark.seal.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.purple)
            }

            VStack(spacing: 6) {
                Text("No Savings Found")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text("Your subscriptions look well-optimized. Add more subscriptions or enable Screen Time tracking for deeper insights.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.red)
            }

            VStack(spacing: 6) {
                Text("Analysis Failed")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Results Section

    private func resultsSection(report: GeniusReport) -> some View {
        VStack(spacing: 20) {
            // Summary
            HStack(spacing: 16) {
                GeniusSummaryCard(
                    title: "Opportunities",
                    value: "\(report.actionableCount)",
                    icon: "lightbulb.fill",
                    color: .yellow
                )

                GeniusSummaryCard(
                    title: "Potential Savings",
                    value: "\(CurrencyManager.shared.format(report.totalPotentialSavings))/mo",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)

            // Insights List
            VStack(alignment: .leading, spacing: 12) {
                Text("INSIGHTS")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)

                ForEach(Array(report.insights.prefix(10).enumerated()), id: \.element.id) { index, insight in
                    GeniusInsightCard(insight: insight)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: appeared)
                }
            }
        }
        .padding(.top, 24)
    }

    private func runAnalysis() async {
        analysisState = .analyzing

        let subs = subscriptionStore.subscriptions
        guard !subs.isEmpty else {
            analysisState = .noInsights
            return
        }

        do {
            let report = try await engine.analyze(subscriptions: subs)

            // Minimum loading duration so the user perceives the action
            try await Task.sleep(for: .milliseconds(500))

            if report.insights.isEmpty {
                analysisState = .noInsights
            } else {
                analysisState = .results(report)
            }
        } catch {
            analysisState = .error(error.localizedDescription)
        }
    }
}

// MARK: - Summary Card

struct GeniusSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Insight Card

struct GeniusInsightCard: View {
    let insight: GeniusInsight

    private var actionColor: Color {
        switch insight.action {
        case .cancel, .cancelTrial: return .red
        case .pause: return .orange
        case .switchToAnnual, .consolidate: return .blue
        case .exploreFamilyPlan: return .purple
        case .review: return .yellow
        case .none: return .gray
        }
    }

    private var actionText: String {
        switch insight.action {
        case .cancel: return "Cancel"
        case .cancelTrial: return "Cancel Trial"
        case .pause: return "Pause"
        case .switchToAnnual: return "Switch Annual"
        case .consolidate: return "Consolidate"
        case .exploreFamilyPlan: return "Family Plan"
        case .review: return "Review"
        case .none: return ""
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(insight.iconColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: insight.icon)
                    .font(.callout)
                    .foregroundColor(insight.iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    Spacer()

                    // Confidence badge
                    Text("\(insight.confidencePercent)% confidence")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)

                HStack {
                    if insight.potentialSavings > 0 {
                        Text("Save \(formatCurrency(insight.potentialSavings))/mo")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }

                    Spacer()

                    if insight.action != .none {
                        Text(actionText)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(actionColor)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(insight.urgency.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        CurrencyManager.shared.format(amount)
    }
}

#Preview {
    NavigationStack {
        RevolutionaryGeniusView()
    }
}
