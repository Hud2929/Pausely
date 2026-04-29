import SwiftUI

// MARK: - AI Financial Subscription Advisor
/// Revolutionary feature that acts as a personal financial advisor for subscriptions
/// Analyzes spending patterns, suggests optimizations, and provides actionable insights
@MainActor
struct FinancialAdvisorView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var appear = false
    @State private var selectedInsight: AdvisorInsight?
    @State private var showingActionSheet = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Computed insights based on user's subscriptions
    private var insights: [AdvisorInsight] {
        generateInsights()
    }
    
    private var healthScore: Int {
        calculateHealthScore()
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Health Score Card
                healthScoreCard

                // Disclaimer about usage data
                ScreenTimeDisclaimer()

                // Monthly Savings Potential
                savingsPotentialCard
                
                // AI Insights
                insightsSection
                
                // Action Items
                actionItemsSection
                
                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .sheet(item: $selectedInsight) { insight in
            InsightDetailSheet(insight: insight) { action in
                handleInsightAction(action, for: insight)
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.luxuryTeal.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    ))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(.largeTitle, design: .rounded).weight(.light))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.luxuryTeal, .white],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            
            VStack(spacing: 6) {
                Text("AI Financial Advisor")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                
                Text("Personalized subscription intelligence")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Health Score Card
    private var healthScoreCard: some View {
        VStack(spacing: 16) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(colorForScore(healthScore).opacity(0.2), lineWidth: 20)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: CGFloat(healthScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [colorForScore(healthScore), colorForScore(healthScore).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1), value: healthScore)
                
                VStack(spacing: 0) {
                    Text("\(healthScore)")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text(scoreLabel)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(colorForScore(healthScore))
                }
            }
            
            // Score breakdown
            HStack(spacing: 20) {
                ScoreMetric(icon: "dollarsign.circle", value: "\(insights.filter { $0.type == .savings }.count)", label: "Savings Found")
                ScoreMetric(icon: "exclamationmark.triangle", value: "\(insights.filter { $0.type == .warning }.count)", label: "Warnings")
                ScoreMetric(icon: "checkmark.circle", value: "\(insights.filter { $0.type == .optimization }.count)", label: "Optimizations")
            }
        }
        .padding()
        .glassCard(color: Color.luxuryTeal)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Savings Potential Card
    private var savingsPotentialCard: some View {
        let potentialSavings = insights.reduce(0) { $0 + $1.potentialSavings }
        
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Savings Potential")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(currencyManager.format(potentialSavings))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.luxuryGold)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.luxuryGold)
            }
            
            if potentialSavings > 0 {
                Text("You could save \(currencyManager.format(potentialSavings * 12)) per year!")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.luxuryTeal)
            }
        }
        .padding()
        .glass(intensity: 0.1, tint: Color.luxuryGold)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Insights")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if insights.isEmpty {
                    Text("All caught up!")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.luxuryTeal)
                } else {
                    Text("\(insights.count) recommendations")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            
            if insights.isEmpty {
                EmptyInsightsView()
            } else {
                VStack(spacing: 10) {
                    ForEach(insights.prefix(5)) { insight in
                        InsightCard(insight: insight) {
                            selectedInsight = insight
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Action Items Section
    private var actionItemsSection: some View {
        let actions = insights.filter { $0.isActionable }
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            if actions.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.luxuryTeal)

                    Text("No pending actions")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding()
                .glass(intensity: 0.06, tint: .white)
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(actions.prefix(3)) { action in
                        ActionItemCard(insight: action) {
                            selectedInsight = action
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func generateInsights() -> [AdvisorInsight] {
        var newInsights: [AdvisorInsight] = []
        let subscriptions = store.subscriptions
        let activeSubs = store.activeSubscriptions
        
        // 1. Duplicate Detection
        let duplicates = findDuplicates(in: subscriptions)
        for dup in duplicates {
            newInsights.append(AdvisorInsight(
                id: "dup-\(dup.id)",
                title: "Duplicate Subscription Detected",
                description: "You're paying for \(dup.name) multiple times. Consider consolidating.",
                type: .warning,
                potentialSavings: dup.monthlyCost,
                subscriptionId: dup.id,
                actionTitle: "Review Duplicates",
                isActionable: true
            ))
        }
        
        // 2. Unused Subscriptions (based on Screen Time)
        for sub in activeSubs {
            let usage = screenTimeManager.getCurrentMonthUsage(for: sub.name)
            if usage < 30 { // Less than 30 minutes per month
                newInsights.append(AdvisorInsight(
                    id: "unused-\(sub.id)",
                    title: "Low Usage Alert: \(sub.name)",
                    description: "You've only used \(sub.name) for \(usage) minutes this month. Consider pausing or canceling.",
                    type: .savings,
                    potentialSavings: sub.monthlyCost,
                    subscriptionId: sub.id,
                    actionTitle: sub.canPause ? "Pause Subscription" : "Cancel Subscription",
                    isActionable: true
                ))
            }
        }
        
        // 3. Annual vs Monthly Savings
        for sub in activeSubs where sub.billingFrequency == .monthly {
            let monthlyAmount = sub.monthlyCost
            let annualSavings = monthlyAmount * 3 // Approx 27% savings
            
            newInsights.append(AdvisorInsight(
                id: "annual-\(sub.id)",
                title: "Switch \(sub.name) to Annual",
                description: "Save ~27% by switching to annual billing. You'll save \(currencyManager.format(annualSavings)) per year.",
                type: .optimization,
                potentialSavings: annualSavings,
                subscriptionId: sub.id,
                actionTitle: "View Annual Plan",
                isActionable: true
            ))
        }
        
        // 4. Price Increase Alerts
        for sub in activeSubs where sub.amount > 15 {
            newInsights.append(AdvisorInsight(
                id: "price-\(sub.id)",
                title: "High-Cost Subscription",
                description: "\(sub.name) costs \(currencyManager.format(sub.amount))/month. Consider if the value justifies the cost.",
                type: .warning,
                potentialSavings: 0,
                subscriptionId: sub.id,
                actionTitle: "Find Alternatives",
                isActionable: true
            ))
        }
        
        // 5. Category Overspending
        let categoryTotals = calculateCategorySpending(subscriptions: activeSubs)
        for (category, total) in categoryTotals where total > 50 {
            newInsights.append(AdvisorInsight(
                id: "cat-\(category)",
                title: "High \(category) Spending",
                description: "You're spending \(currencyManager.format(total)) per month on \(category.lowercased()) subscriptions.",
                type: .warning,
                potentialSavings: 0,
                subscriptionId: nil,
                actionTitle: "Review Category",
                isActionable: false
            ))
        }
        
        // 6. Bundle Opportunities
        let streamingSubs = activeSubs.filter { 
            $0.name.lowercased().contains("netflix") ||
            $0.name.lowercased().contains("hulu") ||
            $0.name.lowercased().contains("disney") ||
            $0.name.lowercased().contains("hbo")
        }
        
        if streamingSubs.count >= 2 {
            let total = streamingSubs.reduce(Decimal(0)) { $0 + $1.monthlyCost }
            let savings = total / 3
            newInsights.append(AdvisorInsight(
                id: "bundle-streaming",
                title: "Streaming Bundle Opportunity",
                description: "You have \(streamingSubs.count) streaming services. Consider Disney+/Hulu/ESPN+ bundle to save money.",
                type: .optimization,
                potentialSavings: savings,
                subscriptionId: nil,
                actionTitle: "View Bundle Options",
                isActionable: true
            ))
        }
        
        return newInsights.sorted { $0.potentialSavings > $1.potentialSavings }
    }
    
    private func handleInsightAction(_ action: String, for insight: AdvisorInsight) {
        switch action {
        case "Pause Subscription":
            alertTitle = "Pause Subscription"
            alertMessage = "Most subscriptions cannot be paused directly through the app. You'll need to cancel or pause through the subscription service's website directly. Would you like to find the cancellation URL?"
            showingAlert = true
        case "Cancel Subscription":
            if let subId = insight.subscriptionId,
               let sub = store.subscriptions.first(where: { $0.id == subId }) {
                if let cancelURL = TrialProtectionStore.shared.getCancelURL(for: sub.name) {
                    UIApplication.shared.open(cancelURL)
                } else {
                    alertTitle = "Cancel \(sub.name)"
                    alertMessage = "To cancel \(sub.name), please visit their website or contact their support directly. We don't have a direct cancellation link for this service."
                    showingAlert = true
                }
            }
        case "View Annual Plan":
            if let subId = insight.subscriptionId,
               let sub = store.subscriptions.first(where: { $0.id == subId }) {
                alertTitle = "Switch to Annual"
                alertMessage = "To switch \(sub.name) to annual billing, please visit \(sub.name)'s website or account settings. Look for a 'Billing' or 'Subscription' option to change your plan."
                showingAlert = true
            }
        case "Find Alternatives":
            alertTitle = "Find Alternatives"
            alertMessage = "We don't have alternative recommendations for this service yet. Research similar services on your own."
            showingAlert = true
        case "Review Category":
            alertTitle = "Review Category"
            alertMessage = "Check your Dashboard for a breakdown of spending by category."
            showingAlert = true
        case "Review Duplicates":
            alertTitle = "Review Duplicates"
            alertMessage = "Please review your subscriptions list and consider consolidating duplicate services to save money."
            showingAlert = true
        default:
            alertTitle = "Not Available"
            alertMessage = "This feature is not available right now."
            showingAlert = true
        }
    }
    
    private func findDuplicates(in subscriptions: [Subscription]) -> [Subscription] {
        let grouped = Dictionary(grouping: subscriptions) { $0.name.lowercased() }
        return grouped.values.filter { $0.count > 1 }.flatMap { $0 }
    }
    
    private func calculateCategorySpending(subscriptions: [Subscription]) -> [String: Decimal] {
        var totals: [String: Decimal] = [:]
        for sub in subscriptions {
            let category = sub.category ?? "Other"
            totals[category, default: 0] += sub.monthlyCost
        }
        return totals
    }
    
    private func calculateHealthScore() -> Int {
        let subscriptions = store.subscriptions
        guard !subscriptions.isEmpty else { return 0 }
        
        var score = 100
        
        // Deductions
        let duplicateDeduction = findDuplicates(in: subscriptions).count * 15
        score -= duplicateDeduction
        
        let unusedCount = insights.filter { $0.type == .savings && $0.title.contains("Low Usage") }.count
        score -= unusedCount * 10
        
        let highCostCount = insights.filter { $0.type == .warning && $0.title.contains("High-Cost") }.count
        score -= highCostCount * 5
        
        return max(0, min(100, score))
    }
    
    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private var scoreLabel: String {
        switch healthScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Poor"
        default: return "Critical"
        }
    }
}

// MARK: - Models
struct AdvisorInsight: Identifiable {
    let id: String
    let title: String
    let description: String
    let type: InsightType
    let potentialSavings: Decimal
    let subscriptionId: UUID?
    let actionTitle: String
    let isActionable: Bool
}

enum InsightType {
    case savings, warning, optimization
    
    var icon: String {
        switch self {
        case .savings: return "dollarsign.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .optimization: return "arrow.up.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .savings: return .green
        case .warning: return .orange
        case .optimization: return .blue
        }
    }
}

// MARK: - Supporting Views
struct ScoreMetric: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.footnote)
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.bold))
            }
            .foregroundStyle(.white)
            
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

struct InsightCard: View {
    let insight: AdvisorInsight
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(insight.type.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: insight.type.icon)
                        .font(.title3)
                        .foregroundStyle(insight.type.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(insight.description)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if insight.potentialSavings > 0 {
                        Text("Save \(CurrencyManager.shared.format(insight.potentialSavings))/month")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.luxuryGold)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
            .glass(intensity: 0.08, tint: .white)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = pressing }
        }, perform: {})
    }
}

struct ActionItemCard: View {
    let insight: AdvisorInsight
    let onGo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.type.icon)
                .font(.title3)
                .foregroundStyle(insight.type.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.actionTitle)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                if insight.potentialSavings > 0 {
                    Text("Save \(CurrencyManager.shared.format(insight.potentialSavings))/month")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.luxuryGold)
                }
            }

            Spacer()

            Button(action: onGo) {
                Text("Go")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.luxuryTeal)
                    )
            }
        }
        .padding()
        .glass(intensity: 0.1, tint: Color.luxuryTeal)
    }
}

struct InsightDetailSheet: View {
    let insight: AdvisorInsight
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(insight.type.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: insight.type.icon)
                            .font(.title)
                            .foregroundStyle(insight.type.color)
                    }
                    .padding(.top, 20)
                    
                    // Title
                    Text(insight.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    Text(insight.description)
                        .font(.system(.callout, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Savings
                    if insight.potentialSavings > 0 {
                        VStack(spacing: 8) {
                            Text("Potential Monthly Savings")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text(CurrencyManager.shared.format(insight.potentialSavings))
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.luxuryGold)
                        }
                        .padding()
                        .glassCard(color: Color.luxuryGold)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Action Button
                    if insight.isActionable {
                        Button(action: {
                            dismiss()
                            onAction(insight.actionTitle)
                        }) {
                            Text(insight.actionTitle)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.luxuryTeal)
                                )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.luxuryTeal)

            Text("All caught up!")
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            Text("Your subscriptions are well-optimized. Great job!")
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    FinancialAdvisorView()
}
