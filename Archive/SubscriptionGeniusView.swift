//
//  SubscriptionGeniusView.swift
//  Pausely
//
//  REVOLUTIONARY AI DASHBOARD - Subscription Intelligence
//

import SwiftUI

// MARK: - Revolutionary Genius Dashboard

struct SubscriptionGeniusDashboard: View {
    @StateObject private var genius = SubscriptionGeniusAI.shared
    @StateObject private var paymentManager = PaymentManager.shared
    let subscriptions: [Subscription]

    @State private var currentReport: RevolutionaryReport?
    @State private var showingPaywall = false
    @State private var selectedCategory: InsightCategory?

    var body: some View {
        ZStack {
            // Revolutionary dark background with gradient
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header
                    heroSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Revolutionary Features Grid
                    if !paymentManager.isPremium {
                        revolutionaryFeaturesPreview
                            .padding(.top, 24)
                    }

                    // Run Analysis Button
                    analysisButton
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Results
                    if let report = currentReport, report.hasOpportunities {
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: subscriptions.count)
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
                        .scaleEffect(genius.isAnalyzing ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: genius.isAnalyzing)
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
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .frame(height: 120)

            VStack(spacing: 8) {
                Text("Subscription Genius")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("AI-powered subscription intelligence")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            // Total Savings Counter
            VStack(spacing: 4) {
                Text("TOTAL SAVINGS FOUND")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text("$\(NSDecimalNumber(decimal: genius.totalSavingsFound).doubleValue, specifier: "%.2f")")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
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

    // MARK: - Revolutionary Features Preview

    private var revolutionaryFeaturesPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("REVOLUTIONARY FEATURES")
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                RevolutionaryFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .red,
                    title: "Trajectory Engine",
                    description: "Predicts waste before it happens",
                    badge: "NEW"
                )

                RevolutionaryFeatureRow(
                    icon: "arrow.up.circle.fill",
                    iconColor: .orange,
                    title: "Price Radar",
                    description: "Alerts before price increases hit",
                    badge: "NEW"
                )

                RevolutionaryFeatureRow(
                    icon: "clock.badge.exclamationmark",
                    iconColor: .purple,
                    title: "Trial Army",
                    description: "Tracks all trials before auto-convert",
                    badge: "NEW"
                )

                RevolutionaryFeatureRow(
                    icon: "hand.raised.fill",
                    iconColor: .pink,
                    title: "Cancellation Concierge",
                    description: "Guides you through actual cancellation",
                    badge: "NEW"
                )
            }
            .padding(.horizontal, 20)
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
                if genius.isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: paymentManager.isPremium ? "wand.and.stars" : "crown.fill")
                        .font(.title2)
                }

                Text(paymentManager.isPremium ? "Run Revolutionary Analysis" : "Upgrade to Pro")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: paymentManager.isPremium ?
                        [.purple, .pink] :
                        [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: (paymentManager.isPremium ? Color.purple : Color.orange).opacity(0.4), radius: 15, y: 8)
        }
    }

    // MARK: - Results Section

    private func resultsSection(report: RevolutionaryReport) -> some View {
        VStack(spacing: 24) {
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryPill(title: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(InsightCategory.allCases, id: \.self) { category in
                        CategoryPill(title: category.rawValue, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Savings Summary Card
            SavingsSummaryCard(report: report)
                .padding(.horizontal, 20)

            // Insights List
            LazyVStack(spacing: 12) {
                ForEach(filteredInsights(report: report)) { insight in
                    RevolutionaryInsightCard(insight: insight)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 24)
    }

    private func filteredInsights(report: RevolutionaryReport) -> [RevolutionaryInsight] {
        if let category = selectedCategory {
            return report.insights.filter { $0.type.category == category }
        }
        return report.insights
    }

    // MARK: - Actions

    private func runAnalysis() async {
        let report = await genius.runRevolutionaryAnalysis(subscriptions: subscriptions)
        currentReport = report
    }
}

// MARK: - Revolutionary Feature Row

struct RevolutionaryFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor)
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(iconColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.purple : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Savings Summary Card

struct SavingsSummaryCard: View {
    let report: RevolutionaryReport

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL OPPORTUNITIES")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    Text(formatCurrency(report.totalPotentialSavings))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }

                Spacer()

                // Mini breakdown
                VStack(alignment: .trailing, spacing: 4) {
                    MiniStat(value: "\(report.savingsInsights.count)", label: "Savings", color: .green)
                    MiniStat(value: "\(report.trialInsights.count)", label: "Trials", color: .red)
                    MiniStat(value: "\(report.familyOpportunities.count)", label: "Family", color: .purple)
                }
            }

            // Quick alerts
            if !report.priceAlerts.isEmpty {
                AlertBanner(
                    icon: "arrow.up.circle.fill",
                    color: .orange,
                    text: "\(report.priceAlerts.count) price increase\(report.priceAlerts.count == 1 ? "" : "s") detected"
                )
            }

            if !report.expiringTrials.isEmpty {
                AlertBanner(
                    icon: "clock.badge.exclamationmark",
                    color: .red,
                    text: "\(report.expiringTrials.count) trial\(report.expiringTrials.count == 1 ? "" : "s") expiring soon"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

struct MiniStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.gray)
        }
    }
}

struct AlertBanner: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(12)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Revolutionary Insight Card

struct RevolutionaryInsightCard: View {
    let insight: RevolutionaryInsight

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(insight.type.color.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: insight.type.icon)
                        .font(.title2)
                        .foregroundStyle(insight.type.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(insight.type.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(insight.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(insight.type.color.opacity(0.2))
                        .clipShape(Capsule())
                }

                Spacer()

                // Confidence
                GeniusConfidenceBadge(confidence: insight.confidence)
            }

            // Description
            Text(insight.description)
                .font(.system(size: 14))
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Savings Value
            if insight.potentialSavings > 0 {
                HStack {
                    Text("Potential savings:")
                        .font(.system(size: 13))
                        .foregroundStyle(.gray)

                    Text(formatCurrency(insight.potentialSavings))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.green)

                    Spacer()

                    // Action Button
                    InsightActionButton(insight: insight)
                }
            } else {
                // For non-savings insights, just show action
                HStack {
                    Spacer()
                    InsightActionButton(insight: insight)
                }
            }

            // Additional metadata if available
            if let metadata = insight.metadata {
                MetadataSection(metadata: metadata, type: insight.type)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(insight.type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Confidence Badge

struct GeniusConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(confidence * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(confidenceColor)

            Text("confident")
                .font(.system(size: 9))
                .foregroundStyle(.gray)
        }
        .padding(8)
        .background(confidenceColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var confidenceColor: Color {
        if confidence >= 0.85 { return .green }
        if confidence >= 0.70 { return .yellow }
        return .orange
    }
}

// MARK: - Insight Action Button

struct InsightActionButton: View {
    let insight: RevolutionaryInsight
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        Button(action: performAction) {
            HStack(spacing: 6) {
                Image(systemName: insight.action.icon)
                    .font(.system(size: 12))

                Text(insight.action.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(insight.type.color)
            .clipShape(Capsule())
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func performAction() {
        // Handle different action types
        switch insight.action.type {
        case .cancel:
            // Open cancellation flow using real URL from catalog
            if let subscription = insight.subscription {
                let cancellationURL = getCancellationURL(for: subscription)
                if let url = cancellationURL {
                    UIApplication.shared.open(url)
                } else {
                    // No known cancellation URL - user must cancel via service website
                    alertTitle = "Cancel \(subscription.name)"
                    alertMessage = "To cancel \(subscription.name), please visit their website or contact their support directly. We don't have a direct cancellation link for this service."
                    showingAlert = true
                }
            }
        case .pause:
            alertTitle = "Pause Subscription"
            alertMessage = "Most subscriptions cannot be paused directly through the app. You'll need to manage pauses through the subscription service's website directly."
            showingAlert = true
        case .trackUsage:
            alertTitle = "Usage Tracking"
            alertMessage = "Usage tracking is available through Screen Time. Go to your device Settings > Screen Time to enable app usage tracking."
            showingAlert = true
        case .exploreBundle:
            alertTitle = "Bundle Options"
            alertMessage = "We don't have bundle recommendations for this service yet. Check the provider's website for available bundles."
            showingAlert = true
        case .exploreAlternative:
            alertTitle = "Alternative Services"
            alertMessage = "We don't have alternative recommendations for this service yet. Research similar services on your own."
            showingAlert = true
        case .upgrade:
            alertTitle = "Upgrade Plan"
            alertMessage = "To upgrade your plan, please visit the subscription service's website or app directly."
            showingAlert = true
        case .downgrade:
            alertTitle = "Downgrade Plan"
            alertMessage = "To downgrade your plan, please visit the subscription service's website or app directly."
            showingAlert = true
        case .switchToAnnual:
            alertTitle = "Switch to Annual"
            alertMessage = "To switch to annual billing, please visit the subscription service's website or app directly."
            showingAlert = true
        case .claimRefund:
            alertTitle = "Claim Refund"
            alertMessage = "To request a refund, please contact the subscription service's support directly. Apple refunds can be requested through the App Store."
            showingAlert = true
        case .setupReminder:
            alertTitle = "Set Reminder"
            alertMessage = "Use the iOS Reminders app or ask Siri to set a reminder for this subscription's renewal date."
            showingAlert = true
        case .findRetention:
            alertTitle = "Retention Offers"
            alertMessage = "To find retention offers, try starting the cancellation flow on the provider's website — they often offer discounts to keep you."
            showingAlert = true
        case .openFamilyPlan:
            alertTitle = "Family Plans"
            alertMessage = "Check the provider's website for family or multi-user plans that could reduce your per-person cost."
            showingAlert = true
        default:
            break
        }
    }

    /// Looks up the real cancellation URL from the subscription catalog
    private func getCancellationURL(for subscription: Subscription) -> URL? {
        // First try to find by bundle identifier
        if let bundleId = subscription.bundleIdentifier,
           let info = SubscriptionCatalogService.shared.entry(for: bundleId),
           let urlString = info.cancellationURL {
            return URL(string: urlString)
        }
        // Then try to find by name
        if let bundleId = SubscriptionCatalogService.shared.findBundleId(for: subscription.name),
           let info = SubscriptionCatalogService.shared.entry(for: bundleId),
           let urlString = info.cancellationURL {
            return URL(string: urlString)
        }
        // Not found - will need to cancel via service website
        return nil
    }
}

// MARK: - Metadata Section

struct MetadataSection: View {
    let metadata: [String: Any]
    let type: RevolutionaryInsightType

    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.gray.opacity(0.3))

            // Show relevant metadata based on insight type
            switch type {
            case .trajectoryWarning:
                if let trajectory = metadata["trajectory"] as? String {
                    HStack {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .foregroundStyle(.red)
                        Text("Usage declining: \(trajectory)")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                }

            case .priceIncreaseAlert:
                if let date = metadata["effectiveDate"] as? Date {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.orange)
                        Text("Effective: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                }

            case .trialExpiring:
                if let date = metadata["trialEndDate"] as? Date {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.red)
                        Text("Trial ends: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                }

            case .familySharingOpportunity:
                if let familyCost = metadata["familyPlanCost"] as? Decimal {
                    HStack {
                        Image(systemName: "person.3")
                            .foregroundStyle(.purple)
                        Text("Family plan: \(formatCurrency(familyCost))/mo")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                        Spacer()
                    }
                }

            default:
                EmptyView()
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SubscriptionGeniusDashboard(subscriptions: [])
    }
    .preferredColorScheme(.dark)
}
