import SwiftUI

struct SubscriptionManagementView: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var actionManager = SubscriptionActionManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showingCancelConfirmation = false
    @State private var showingPauseConfirmation = false
    @State private var showingPaywall = false
    @State private var selectedAlternative: AlternativeService?
    @State private var showingAlternativeDetail = false
    @State private var showingSmartPauseDetail = false
    @State private var showingUsageInput = false
    @State private var manualUsageMinutes: String = ""
    @State private var showingScreenTimeInfo = false
    @State private var showingUsageHistory = false
    @State private var showingSharing = false
    @State private var showingPriceHistory = false
    @State private var showingAnnualSavings = false
    @State private var nextBillingDate: Date = Date()

    var service: SubscriptionService? {
        actionManager.getService(for: subscription.name)
    }
    
    var alternatives: [AlternativeService] {
        SubscriptionActionManager.shared.findAlternatives(for: subscription)
    }
    
    var currentUsageMinutes: Int {
        screenTimeManager.getCurrentMonthUsage(for: subscription.name)
    }
    
    var costPerHour: Decimal? {
        screenTimeManager.calculateCostPerHour(monthlyCost: subscription.monthlyCost, subscriptionName: subscription.name)
    }
    
    var smartSuggestion: PauseSuggestion? {
        screenTimeManager.shouldSuggestPause(for: subscription, thresholdMinutes: 60)
    }
    
    var usageStats: AppUsageStats? {
        screenTimeManager.getUsageStats(for: subscription.name)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with subscription info
                headerSection

                // Billing Date
                billingDateSection

                // Smart Pause Suggestion (REVOLUTIONARY FEATURE)
                if let suggestion = smartSuggestion, subscription.isActive {
                    smartPauseSection(suggestion: suggestion)
                }
                
                // Cost Per Use (killer feature)
                CostPerUseDetailSection(subscription: subscription)

                // Usage Tracking Section - IMPROVED
                usageTrackingSection

                // Quick Actions
                actionsSection
                
                // Alternatives
                if !alternatives.isEmpty {
                    alternativesSection
                }
                
                // Support Info
                supportSection
            }
            .padding()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: 0)
        }
        .sheet(item: $selectedAlternative) { alternative in
            AlternativeDetailView(alternative: alternative, current: subscription)
        }
        .sheet(isPresented: $showingSmartPauseDetail) {
            if let suggestion = smartSuggestion {
                SmartPauseDetailSheet(suggestion: suggestion, onPause: {
                    showingPauseConfirmation = true
                })
            }
        }
        .sheet(isPresented: $showingUsageInput) {
            UsageInputSheet(subscriptionName: subscription.name, currentMinutes: currentUsageMinutes) { minutes in
                screenTimeManager.setMonthlyUsage(minutes: minutes, for: subscription.name)
            }
        }
        .sheet(isPresented: $showingUsageHistory) {
            UsageHistorySheet(subscriptionName: subscription.name)
        }
        .sheet(isPresented: $showingSharing) {
            SubscriptionSharingView(subscription: subscription)
        }
        .sheet(isPresented: $showingPriceHistory) {
            PriceHistoryView(subscription: subscription)
        }
        .sheet(isPresented: $showingAnnualSavings) {
            AnnualSavingsCalculatorView(subscription: subscription)
        }
        .alert("Cancel Subscription", isPresented: $showingCancelConfirmation) {
            Button("Open Cancel Page", role: .destructive) {
                HapticStyle.heavy.trigger()
                openCancelURL()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll open the cancellation page for \(subscription.name). Would you like to proceed?")
        }
        .alert("Pause Subscription", isPresented: $showingPauseConfirmation) {
            Button("Open Pause Page") {
                HapticStyle.medium.trigger()
                openPauseURL()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll open the pause settings for \(subscription.name).")
        }
        .onAppear {
            nextBillingDate = subscription.nextBillingDate ?? Date()
            // Sync screen time data when view appears
            Task {
                await screenTimeManager.syncUsageData()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.3), iconColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Text(String(subscription.name.prefix(1)))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
            }
            
            Text(subscription.name)
                .font(.title.weight(.bold))
                .foregroundColor(.primary)

            Text(subscription.displayAmountInUserCurrency + "/" + subscription.billingFrequency.rawValue)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Usage badge - shows current month's usage
            if currentUsageMinutes > 0 {
                HStack {
                    Image(systemName: usageStats?.source.icon ?? "clock")
                    Text("This month: \(screenTimeManager.formatMinutes(currentUsageMinutes))")
                    EstimateBadge(isEstimated: screenTimeManager.isEstimated(for: subscription.name))
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(usageColor.opacity(0.2))
                .foregroundStyle(usageColor)
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Usage this month: \(screenTimeManager.formatMinutes(currentUsageMinutes))")
            }
            
            // Cost per hour badge (if usage data available)
            if let cph = costPerHour {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Cost per hour: \(formatCostPerHour(cph))")
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(costPerHourColor(cph).opacity(0.2))
                .foregroundStyle(costPerHourColor(cph))
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Cost per hour: \(formatCostPerHour(cph))")
            }
            
            // Difficulty badge
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Cancellation Difficulty: \(actionManager.getCancellationDifficulty(for: subscription).rawValue)")
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(difficultyColor.opacity(0.2))
            .foregroundColor(difficultyColor)
            .cornerRadius(8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cancellation difficulty: \(actionManager.getCancellationDifficulty(for: subscription).rawValue)")
        }
        .padding()
        .glassCard(color: iconColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), \(subscription.displayAmountInUserCurrency) per \(subscription.billingFrequency.rawValue)")
        .accessibilityHint("Double-tap to view details")
    }

    private var billingDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Color.accentMint)
                Text("Next Billing Date")
                    .font(.headline.weight(.semibold))
                Spacer()
                if subscription.nextBillingDate == nil {
                    Text("Not set")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            DatePicker(
                "Next Billing Date",
                selection: $nextBillingDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .onChange(of: nextBillingDate) { _, newDate in
                Task {
                    await saveBillingDate(newDate)
                }
            }

            if subscription.nextBillingDate == nil {
                Text("Set your billing date to get renewal reminders and track upcoming payments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func saveBillingDate(_ date: Date) async {
        var updated = subscription
        updated.nextBillingDate = date
        updated.updatedAt = Date()
        do {
            try await SubscriptionStore.shared.updateSubscription(updated)
        } catch {
            print("Failed to save billing date: \(error)")
        }
    }

    // MARK: - Smart Pause Section (REVOLUTIONARY FEATURE)
    private func smartPauseSection(suggestion: PauseSuggestion) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 Smart Suggestion")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.yellow)
                    
                    Text("Consider Pausing This Subscription")
                        .font(.body.weight(.bold))
                }
                
                Spacer()
                
                Button(action: { showingSmartPauseDetail = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.luxuryPurple)
                }
                .accessibilityLabel("Smart pause info")
            }
            
            SmartPauseBanner(
                suggestion: suggestion,
                onTap: { showingSmartPauseDetail = true },
                onDismiss: { /* Dismiss this suggestion for now */ }
            )
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Usage Tracking Section (IMPROVED)
    private var usageTrackingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("📱 Usage Tracking")
                    .font(.body.weight(.bold))

                Spacer()

                // Data source indicator
                if let source = usageStats?.source {
                    HStack(spacing: 4) {
                        Image(systemName: source.icon)
                            .font(.caption)
                        Text(source.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.secondary)
                    .cornerRadius(8)
                }

                // Link to full insights
                NavigationLink {
                    RevolutionaryScreenTimeDashboard(subscriptions: [subscription])
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .accessibilityLabel("View usage insights")

                Button(action: { showingUsageInput = true }) {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundColor(.luxuryPurple)
                }
                .accessibilityLabel("Edit usage")
            }

            // Disclaimer about estimated data
            ScreenTimeDisclaimer()

            // Main usage display
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("This Month's Usage")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            EstimateBadge(isEstimated: screenTimeManager.isEstimated(for: subscription.name))
                        }

                        if currentUsageMinutes > 0 {
                            Text(screenTimeManager.formatMinutes(currentUsageMinutes))
                                .font(.title.weight(.bold))
                        } else {
                            Text("No data yet")
                                .font(.title2.weight(.medium))
                                .foregroundColor(.secondary)
                        }

                        if let stats = usageStats, let lastUpdated = stats.lastUpdated {
                            Text("Updated \(lastUpdated, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Usage indicator ring
                    ZStack {
                        Circle()
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: min(CGFloat(currentUsageMinutes) / 600, 1.0))
                            .stroke(usageColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: currentUsageMinutes)

                        VStack(spacing: 0) {
                            Text("\(min(currentUsageMinutes * 100 / 600, 100))%")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.primary)
                            Text("of 10h")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Cost per hour section
                if let cph = costPerHour {
                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cost Per Hour")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(formatCostPerHour(cph))
                                .font(.title2.weight(.bold))
                                .foregroundColor(costPerHourColor(cph))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(efficiencyRating(cph))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(costPerHourColor(cph))

                            Text(efficiencyDescription(cph))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Usage bar chart
                    usageBarChart
                }

                // Manual entry buttons
                HStack(spacing: 8) {
                    QuickAddButton(minutes: 30, subscriptionName: subscription.name)
                    QuickAddButton(minutes: 60, subscriptionName: subscription.name)
                    QuickAddButton(minutes: 120, subscriptionName: subscription.name)

                    Spacer()
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(16)

            // Enable screen time tracking button
            if !screenTimeManager.isTrackingEnabled {
                enableTrackingButton
            } else if screenTimeManager.authorizationStatus == .authorized {
                // Show info about manual mode
                manualModeInfo
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(20)
    }
    
    private var usageBarChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Usage")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ForEach(0..<7) { day in
                    let minutes = usageStats?.dailyBreakdown?[day].minutes ?? 0
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(minutes > 0 ? usageColor : Color.gray.opacity(0.2))
                            .frame(height: max(CGFloat(minutes) / 120 * 40, 4))
                        
                        Text("\(day)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 50)
        }
    }
    
    private var enableTrackingButton: some View {
        Button(action: {
            Task {
                try? await screenTimeManager.requestAuthorization()
            }
        }) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                Text("Enable Automatic Screen Time Tracking")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient.premium
            )
            .cornerRadius(12)
        }
    }
    
    private var manualModeInfo: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Manual Tracking Mode")
                    .font(.subheadline.weight(.semibold))
                Text("Tap + buttons to add usage time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showingScreenTimeInfo = true }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Screen time info")
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Cancel Button - Premium feature (REVOLUTIONARY ONE-TAP)
            if paymentManager.isPremium {
                RevolutionaryCancelButton(subscription: subscription)
            } else {
                ActionButton(
                    title: "Cancel Subscription",
                    subtitle: "One-tap cancel (Pro)",
                    icon: "xmark.circle.fill",
                    color: .red,
                    isPremium: true,
                    action: { showingPaywall = true }
                )
            }
            
            // Pause/Resume Button - Only for Pro users (REVOLUTIONARY ONE-TAP)
            if paymentManager.canPauseSubscriptions && actionManager.canPause(subscription) {
                if subscription.isPaused {
                    RevolutionaryResumeButton(subscription: subscription)
                } else {
                    RevolutionaryPauseButton(subscription: subscription)
                }
            }
            
            // Find Alternatives - Premium feature
            if !alternatives.isEmpty {
                ActionButton(
                    title: "Find Cheaper Alternative",
                    subtitle: "\(alternatives.count) options found",
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: .green,
                    isPremium: true,
                    action: {
                        if paymentManager.isPremium {
                            // Scroll to alternatives
                        } else {
                            showingPaywall = true
                        }
                    }
                )
            }
            
            // View Usage History
            ActionButton(
                title: "View Usage History",
                subtitle: "See past months",
                icon: "chart.bar.fill",
                color: .blue,
                isPremium: false,
                action: {
                    showingUsageHistory = true
                }
            )
            
            // Edit - Available to all users
            ActionButton(
                title: "Edit Details",
                subtitle: "Update amount or billing",
                icon: "pencil.circle.fill",
                color: .blue,
                isPremium: false,
                action: {
                    // Open edit view
                }
            )

            // Cost Sharing - split with friends/family
            ActionButton(
                title: "Split Cost",
                subtitle: "Share with friends or family",
                icon: "person.2.fill",
                color: .purple,
                isPremium: false,
                action: {
                    showingSharing = true
                }
            )

            // Price History - track price changes
            ActionButton(
                title: "Price History",
                subtitle: "Track price changes over time",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange,
                isPremium: false,
                action: {
                    showingPriceHistory = true
                }
            )

            // Annual Savings Calculator
            if subscription.billingFrequency == .monthly {
                ActionButton(
                    title: "Annual Savings",
                    subtitle: "See savings with yearly billing",
                    icon: "calendar.badge.checkmark",
                    color: .green,
                    isPremium: false,
                    action: {
                        showingAnnualSavings = true
                    }
                )
            }
        }
    }
    
    private var alternativesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Cheaper Alternatives")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !paymentManager.isPremium {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.yellow)
                }
            }
            
            if paymentManager.isPremium {
                LazyVStack(spacing: 12) {
                    ForEach(alternatives.prefix(3)) { alternative in
                        AlternativeCard(
                            alternative: alternative,
                            savings: actionManager.calculateSavings(
                                current: subscription,
                                alternative: alternative
                            )
                        )
                        .onTapGesture {
                            selectedAlternative = alternative
                        }
                    }
                }
            } else {
                // Blurred preview for non-premium
                ZStack {
                    AlternativePreviewBlurred(alternatives: alternatives)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        
                        Text("Upgrade to Premium to see alternatives")
                            .font(.headline)
                        
                        Button("Upgrade Now") {
                            showingPaywall = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                    }
                }
                .frame(height: 200)
            }
        }
    }
    
    private var supportSection: some View {
        VStack(spacing: 16) {
            Text("Need Help?")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let contacts = actionManager.getSupportContacts(for: subscription)
            let phoneContact = contacts.first { $0.type == .phone }
            let chatContact = contacts.first { $0.type == .chat || $0.type == .email }
            
            if let phone = phoneContact {
                SupportButton(
                    title: "Call Support",
                    subtitle: phone.value,
                    icon: "phone.fill",
                    color: .green
                )
            }
            
            if let chat = chatContact {
                SupportButton(
                    title: "Contact Support",
                    subtitle: chat.label,
                    icon: "globe",
                    color: .blue
                )
            }
        }
    }
    
    private var iconColor: Color {
        switch subscription.category?.lowercased() {
        case "entertainment": return .red
        case "music": return .pink
        case "storage": return .blue
        case "productivity": return .green
        default: return .purple
        }
    }
    
    private var difficultyColor: Color {
        switch actionManager.getCancellationDifficulty(for: subscription) {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .veryHard: return .red
        }
    }
    
    private var usageColor: Color {
        if currentUsageMinutes < 30 { return .red }
        if currentUsageMinutes < 60 { return .orange }
        if currentUsageMinutes < 180 { return .yellow }
        return .green
    }
    
    private func openCancelURL() {
        if let url = actionManager.generateCancelURL(for: subscription) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPauseURL() {
        if let url = actionManager.generatePauseURL(for: subscription) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Helper Methods for Cost Per Hour
    private func formatCostPerHour(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = subscription.currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
    
    private func costPerHourColor(_ value: Decimal) -> Color {
        let doubleValue = Double(truncating: value as NSNumber)
        if doubleValue > 20 { return .red }
        if doubleValue > 10 { return .orange }
        if doubleValue > 5 { return .yellow }
        return .green
    }
    
    private func efficiencyRating(_ value: Decimal) -> String {
        let doubleValue = Double(truncating: value as NSNumber)
        if doubleValue > 20 { return "Poor Value" }
        if doubleValue > 10 { return "Fair Value" }
        if doubleValue > 5 { return "Good Value" }
        return "Great Value!"
    }
    
    private func efficiencyDescription(_ value: Decimal) -> String {
        let doubleValue = Double(truncating: value as NSNumber)
        if doubleValue > 20 { return "Very expensive per hour" }
        if doubleValue > 10 { return "Consider if worth it" }
        if doubleValue > 5 { return "Reasonable value" }
        return "Excellent value!"
    }
}

// MARK: - Quick Add Button Component
struct QuickAddButton: View {
    let minutes: Int
    let subscriptionName: String
    @State private var manager = ScreenTimeManager.shared
    
    var label: String {
        if minutes >= 60 {
            return "+\(minutes / 60)h"
        } else {
            return "+\(minutes)m"
        }
    }
    
    var body: some View {
        Button(action: { 
            manager.updateUsage(minutes: minutes, for: subscriptionName)
            HapticStyle.light.trigger()
        }) {
            Label(label, systemImage: "plus.circle")
                .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .tint(.luxuryPurple)
    }
}

// MARK: - Usage History Sheet
struct UsageHistorySheet: View {
    let subscriptionName: String
    @Environment(\.dismiss) private var dismiss
    @State private var manager = ScreenTimeManager.shared
    @State private var history: [AppUsageStats] = []
    
    var body: some View {
        let _ = { history = manager.getUsageHistory(for: subscriptionName) }()
        NavigationView {
            List {
                if history.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            
                            Text("No Usage History Yet")
                                .font(.headline)
                            
                            Text("Usage data will appear here as you track your time with \(subscriptionName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section(header: Text("Past 6 Months")) {
                        ForEach(history, id: \.id) { stats in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stats.formattedDate)
                                        .font(.headline)

                                    HStack(spacing: 4) {
                                        Image(systemName: stats.source.icon)
                                            .font(.caption)
                                        Text(stats.source.description)
                                            .font(.caption)
                                        EstimateBadge(isEstimated: stats.source == .screenTime)
                                    }
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(stats.formattedUsage)
                                    .font(.title3.bold())
                                    .foregroundColor(stats.totalMinutes < 60 ? .red : .primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section(footer: Text("Note: Screen Time data is estimated from session counts. Manual entries are exact values you provided.")) {
                        HStack {
                            Text("Total Tracked Time")
                            Spacer()
                            Text(manager.formatMinutes(history.reduce(0) { $0 + $1.totalMinutes }))
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .navigationTitle("Usage History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Smart Pause Detail Sheet
struct SmartPauseDetailSheet: View {
    let suggestion: PauseSuggestion
    let onPause: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            SmartPauseAlertView(
                suggestion: suggestion,
                onPause: {
                    dismiss()
                    onPause()
                },
                onDismiss: { dismiss() },
                onAdjustThreshold: { dismiss() }
            )
            .navigationTitle("Smart Pause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Usage Input Sheet
struct UsageInputSheet: View {
    let subscriptionName: String
    let currentMinutes: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hours: String = ""
    @State private var minutes: String = ""
    
    init(subscriptionName: String, currentMinutes: Int, onSave: @escaping (Int) -> Void) {
        self.subscriptionName = subscriptionName
        self.currentMinutes = currentMinutes
        self.onSave = onSave
        _hours = State(initialValue: String(currentMinutes / 60))
        _minutes = State(initialValue: String(currentMinutes % 60))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter Usage for \(subscriptionName)")) {
                    HStack {
                        TextField("Hours", text: $hours)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                            .frame(width: 80)

                        Text("hours")
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    HStack {
                        TextField("Minutes", text: $minutes)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                            .frame(width: 80)

                        Text("minutes")
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                
                Section(footer: Text("This helps Pausely calculate your cost per hour and suggest when to pause subscriptions to save money.")) {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            Text("Save Usage")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(hours.isEmpty && minutes.isEmpty)
                    .accessibilityHint(hours.isEmpty && minutes.isEmpty ? "Please enter hours or minutes" : "")
                }
                
                Section(header: Text("Quick Set")) {
                    Button("Haven't used it this month (0 minutes)") {
                        hours = "0"
                        minutes = "0"
                        save()
                    }
                    .foregroundColor(.red)
                    
                    Button("Light usage (30 minutes)") {
                        hours = "0"
                        minutes = "30"
                    }
                    
                    Button("Moderate usage (5 hours)") {
                        hours = "5"
                        minutes = "0"
                    }
                    
                    Button("Heavy usage (20 hours)") {
                        hours = "20"
                        minutes = "0"
                    }
                }
            }
            .navigationTitle("Update Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func save() {
        let h = Int(hours) ?? 0
        let m = Int(minutes) ?? 0
        let totalMinutes = h * 60 + m
        onSave(totalMinutes)
        dismiss()
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isPremium: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if isPremium {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
}

struct AlternativeCard: View {
    let alternative: AlternativeService
    let savings: Double
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alternative.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(alternative.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Label(String(format: "%.1f", alternative.rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    
                    Text("\(alternative.monthlyPrice, format: .currency(code: "USD"))/mo")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if savings > 0 {
                    Text("Save \(savings, format: .currency(code: "USD"))")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct AlternativePreviewBlurred: View {
    let alternatives: [AlternativeService]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(alternatives.prefix(2)) { alt in
                HStack {
                    Text(alt.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .blur(radius: 8)
            }
        }
    }
}

struct SupportButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var action: () -> Void = {}
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
}

struct AlternativeDetailView: View {
    let alternative: AlternativeService
    let current: Subscription
    @Environment(\.dismiss) private var dismiss
    
    var savings: Double {
        SubscriptionActionManager.shared.calculateSavings(current: current, alternative: alternative)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text(alternative.name)
                            .font(.title.bold())
                            .foregroundColor(.primary)
                        
                        Text(alternative.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", alternative.rating))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Pricing comparison
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(current.displayAmountInUserCurrency + "/mo")
                                    .font(.title3)
                                    .strikethrough()
                                    .foregroundStyle(.red)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.green)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text(alternative.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(alternative.monthlyPrice, format: .currency(code: "USD"))/mo")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        if savings > 0 {
                            Text("You save \(savings, format: .currency(code: "USD")) per year!")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .padding()
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        ForEach(alternative.features, id: \.self) { feature in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(feature)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Pros
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pros")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                        
                        ForEach(alternative.pros, id: \.self) { pro in
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                Text(pro)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Cons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cons")
                            .font(.title3.bold())
                            .foregroundStyle(.orange)
                        
                        ForEach(alternative.cons, id: \.self) { con in
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.orange)
                                Text(con)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // CTA
                    if let url = URL(string: alternative.websiteURL) {
                        Link(destination: url) {
                            HStack {
                                Text("Switch to \(alternative.name)")
                                    .font(.headline)
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(Color(.label))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.luxuryGold, .luxuryPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("Alternative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
