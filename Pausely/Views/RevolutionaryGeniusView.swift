//
//  RevolutionaryGeniusView.swift
//  Pausely
//
//  REAL subscription intelligence powered by actual data
//

import SwiftUI

// MARK: - Revolutionary Genius View

struct RevolutionaryGeniusView: View {
    @ObservedObject private var engine = RealGeniusEngine.shared
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var currentReport: GeniusReport?
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
                    if let report = currentReport, !report.insights.isEmpty {
                        resultsSection(report: report)
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
        .task {
            await runAnalysis()
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

                Text("$\(NSDecimalNumber(decimal: engine.totalSavingsFound).doubleValue, specifier: "%.2f")")
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
                if engine.isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: paymentManager.isPremium ? "wand.and.stars" : "crown.fill")
                        .font(.title2)
                }

                Text(engine.isAnalyzing ? "Analyzing..." : "Run Real Analysis")
                    .font(.headline)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .disabled(engine.isAnalyzing)
        .accessibilityHint(engine.isAnalyzing ? "Please wait, analysis in progress" : "")
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
                    value: "$\(NSDecimalNumber(decimal: report.totalPotentialSavings).intValue)/mo",
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
        let subs = subscriptionStore.subscriptions
        currentReport = await engine.analyze(subscriptions: subs)
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
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return String(format: "$%.2f", value)
    }
}

#Preview {
    NavigationStack {
        RevolutionaryGeniusView()
    }
}
