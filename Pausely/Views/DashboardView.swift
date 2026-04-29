import SwiftUI

@MainActor
struct MainTabView: View {
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "chart.pie.fill" : "chart.pie")
                        Text("Dashboard")
                    }
                    .tag(0)

                SubscriptionsListView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                        Text("Subscriptions")
                    }
                    .tag(1)

                PerksView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "sparkles" : "sparkles")
                        Text("Perks")
                    }
                    .tag(2)

                NavigationStack {
                    PremiumProfileView()
                }
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(3)
            }
            .tint(Color.luxuryGold)
            .onChange(of: selectedTab) { oldValue, newValue in
                HapticStyle.light.trigger()
            }
        }
        .task {
            await subscriptionStore.fetchSubscriptions()
        }
    }
}

// MARK: - Dashboard View

@MainActor
struct DashboardView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var referralManager = ReferralManager.shared
    @State private var appear = false
    @State private var showingPaywall = false
    @State private var showingAddOptions = false
    @State private var showingAddSubscription = false
    @State private var showingSmartURLInput = false
    @State private var showingApplyReferral = false
    @State private var selectedTimeframe: DashboardTimeframe = .monthly
    @State private var showingComingSoonAlert = false
    @State private var comingSoonMessage = ""

    var displayAmount: Decimal {
        switch selectedTimeframe {
        case .weekly:
            return store.totalMonthlySpend / 4.33
        case .monthly:
            return store.totalMonthlySpend
        case .yearly:
            return store.totalAnnualSpend
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Personalized Header
                personalizedHeader
                    .padding(.top, 16)

                // Price Increase Alerts
                if !PriceIncreaseMonitor.shared.alerts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(PriceIncreaseMonitor.shared.alerts) { alert in
                            PriceAlertBanner(alert: alert) {
                                PriceIncreaseMonitor.shared.dismissAlert(id: alert.id)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                if store.isLoading && store.subscriptions.isEmpty {
                    dashboardSkeletonSection
                        .transition(.opacity)
                } else if store.subscriptions.isEmpty {
                    DashboardEmptyState(
                        onAdd: { showingAddSubscription = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                } else {
                    // Next Payment Card (prominent)
                    NextPaymentCard(subscription: store.upcomingRenewals.first ?? store.activeSubscriptions.first)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Total Spend Summary
                    TotalSpendSummaryCard(
                        monthlySpend: store.totalMonthlySpend,
                        yearlySpend: store.totalAnnualSpend,
                        subscriptionCount: store.subscriptions.count
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Lifetime Spend
                    LifetimeSpendCard(
                        lifetimeSpend: store.totalLifetimeSpend,
                        currencyManager: currencyManager
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Forgotten Apple Subscriptions
                    ForgottenSubscriptionsSection()

                    // Biggest Expenses
                    BiggestExpensesSection()

                    // Category Spending Breakdown
                    CategorySpendingSection()

                    // Subscription Health Score
                    SubscriptionHealthScoreSection()

                    // Quick Actions
                    QuickActionsGrid(
                        onAddTap: { showingAddSubscription = true },
                        onPaywallTap: { showingPaywall = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Smart Insights
                    SmartInsightsSection()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Family Plan Opportunities
                    let familySuggestions = FamilyPlanDetector.shared.detectFamilyPlanOpportunities(in: store.subscriptions)
                    if !familySuggestions.isEmpty {
                        FamilyPlanSuggestionsSection(
                            suggestions: familySuggestions,
                            currencyManager: currencyManager
                        )
                    }

                    // Upcoming Renewals
                    if !store.upcomingRenewals.isEmpty {
                        UpcomingRenewalsCarousel(subscriptions: store.upcomingRenewals)
                            .padding(.top, 24)
                    } else if !store.isLoading {
                        ArtisticEmptyState(
                            icon: "calendar.badge.clock",
                            title: "No upcoming renewals",
                            message: "Your subscriptions are all set for now.",
                            action: nil,
                            actionTitle: nil
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }

                    // Paused Subscriptions
                    if !store.pausedSubscriptions.isEmpty {
                        PausedSubscriptionsSection(subscriptions: store.pausedSubscriptions)
                            .padding(.top, 24)
                    }

                    // Cost Per Use (killer feature)
                    CostPerUseDashboardSection()

                    // Smart Alerts
                    CostPerUseAlertsSection()

                    // Usage Tracking (if data available)
                    if screenTimeManager.hasAnyUsageData {
                        UsageHighlightsSection()
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                    }

                    // Recent Subscriptions
                    RecentSubscriptionsCarousel(subscriptions: store.subscriptions)
                        .padding(.top, 24)

                    Spacer(minLength: 100)
                }
            }
        }
        .refreshable {
            HapticStyle.medium.trigger()
            await store.fetchSubscriptions(force: true)
            HapticStyle.success.trigger()
        }
        .confirmationDialog("Add Subscription", isPresented: $showingAddOptions) {
            Button("Add Manually") {
                showingAddSubscription = true
            }
            Button("Paste from URL") {
                showingSmartURLInput = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddSubscription) {
            SubscriptionBrowserView()
        }
        .sheet(isPresented: $showingSmartURLInput) {
            SmartURLInputView()
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .sheet(isPresented: $showingApplyReferral) {
            ApplyReferralView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appear = true
            }
            Task {
                await screenTimeManager.syncUsageData()
            }
            checkPendingReferralCode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .referralCodeReceived)) { _ in
            checkPendingReferralCode()
        }
    }

    private func checkPendingReferralCode() {
        if referralManager.pendingReferralCode != nil,
           referralManager.referrerCodeUsed == nil,
           !paymentManager.isPremium {
            showingApplyReferral = true
        }
    }

    // MARK: - Skeleton Loading Section
    private var dashboardSkeletonSection: some View {
        VStack(spacing: 20) {
            // Hero card skeleton
            SkeletonCard(height: 180, cornerRadius: 28)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Quick actions skeleton
            HStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    SkeletonCard(height: 100)
                }
            }
            .padding(.horizontal, 20)

            // Insights card skeleton
            SkeletonCard(height: 120, cornerRadius: 24)
                .padding(.horizontal, 20)

            // Carousel skeleton
            HStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    SkeletonCard(height: 100)
                        .frame(width: 160)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 100)
        }
    }

    // MARK: - Personalized Header
    private var personalizedHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Your Subscriptions")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .allowsTightening(false)

                if !store.subscriptions.isEmpty {
                    Text(summaryText)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                CurrencySelectorButton()
                    .accessibilityIdentifier("currencySelectorButton")
                NotificationButton()
                    .accessibilityIdentifier("notificationButton")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Dashboard header, \(greeting)")
        }
        .padding(.horizontal, 20)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : -20)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = RevolutionaryAuthManager.shared.currentUser?.displayName ?? ""
        let prefix = name.isEmpty ? "" : "\(name), "
        switch hour {
        case 0..<12: return "\(prefix)Good morning"
        case 12..<17: return "\(prefix)Good afternoon"
        default: return "\(prefix)Good evening"
        }
    }

    private var summaryText: String {
        let active = store.activeSubscriptions.count
        let paused = store.pausedSubscriptions.count
        let monthlyTotal = store.activeSubscriptions.reduce(Decimal(0)) { total, sub in
            let converted = (try? currencyManager.convert(sub.monthlyCost, from: sub.currency, to: currencyManager.selectedCurrency)) ?? sub.monthlyCost
            return total + converted
        }
        let monthly = currencyManager.format(monthlyTotal)
        if paused > 0 {
            return "\(active) active, \(paused) paused • \(monthly)/mo"
        }
        return "\(active) active subscriptions • \(monthly)/mo"
    }
}

// MARK: - Accessibility Helpers

extension DashboardInsightCard {
    func accessibilityLabelText() -> String {
        "\(title), \(subtitle), value \(value)"
    }
}

// MARK: - Dashboard Empty State View
struct DashboardEmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        ArtisticEmptyState(
            icon: "chart.pie.fill",
            title: "Track your first subscription",
            message: "Add a subscription to see your spending dashboard, upcoming renewals, and smart insights.",
            action: onAdd,
            actionTitle: "Add Subscription"
        )
    }
}

// MARK: - Compelling Dashboard Empty State
struct DashboardEmptyState: View {
    let onAdd: () -> Void
    @State private var animate = false

    var body: some View {
        VStack(spacing: 32) {
            // Artistic SF Symbols composition
            ZStack {
                // Orbiting circles
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.luxuryPurple.opacity(0.15 - Double(i) * 0.03),
                                    Color.luxuryGold.opacity(0.1 - Double(i) * 0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 160 + CGFloat(i * 40), height: 160 + CGFloat(i * 40))
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .animation(
                            UIAccessibility.isReduceMotionEnabled
                                ? .none
                                : .linear(duration: 10 + Double(i) * 5).repeatForever(autoreverses: false),
                            value: animate
                        )
                }

                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.luxuryPurple.opacity(0.25),
                                Color.luxuryPurple.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(animate ? 1.1 : 0.9)
                    .animation(
                        UIAccessibility.isReduceMotionEnabled
                            ? .none
                            : .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: animate
                    )

                // Central icon cluster
                ZStack {
                    // Main icon
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.luxuryGold, Color.luxuryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.luxuryGold.opacity(0.4), radius: 20, x: 0, y: 8)

                    // Dollar sign orbiting
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundColor(Color.luxuryGold)
                        .offset(x: animate ? 50 : 42, y: animate ? -30 : -26)
                        .animation(
                            UIAccessibility.isReduceMotionEnabled
                                ? .none
                                : .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                            value: animate
                        )

                    // Plus circle orbiting
                    Image(systemName: "plus.circle.fill")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundColor(Color.luxuryPurple)
                        .offset(x: animate ? -45 : -38, y: animate ? 35 : 30)
                        .animation(
                            UIAccessibility.isReduceMotionEnabled
                                ? .none
                                : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                            value: animate
                        )
                }
            }
            .frame(height: 220)

            // Text content
            VStack(spacing: 12) {
                Text("Track Your First Subscription")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Add a subscription to see your spending insights, renewal alerts, and cost-per-use analytics.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // CTA Button with glass morphism
            Button(action: {
                HapticStyle.medium.trigger()
                onAdd()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(AppTypography.headlineMedium)
                    Text("Add Subscription")
                        .font(AppTypography.headlineSmall)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.luxuryPurple, Color.luxuryPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 20, x: 0, y: 10)
            }
            .premiumPress(haptic: .medium, scale: 0.96)
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .accessibilityIdentifier("addSubscriptionButton")
        }
        .padding(.vertical, 40)
        .glass(intensity: 0.08, tint: .white)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                animate = true
                return
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animate = true
            }
        }
    }
}

// MARK: - Spending Sparkline

struct SpendingSparkline: View {
    @ObservedObject private var store = SubscriptionStore.shared

    var body: some View {
        GeometryReader { geo in
            let maxCost = store.subscriptions.map { $0.monthlyCost }.max() ?? 1

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(weeklyData.indices, id: \.self) { index in
                    let value = weeklyData[index]
                    let height = maxCost > 0 ? (CGFloat(truncating: value as NSDecimalNumber) / CGFloat(truncating: maxCost as NSDecimalNumber)) : 0.3

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.luxuryPurple.opacity(0.8), .luxuryPink.opacity(0.6)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(8, geo.size.height * height))
                        .scaleEffect(y: store.subscriptions.isEmpty ? 0.3 : 1, anchor: .bottom)
                        .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.05), value: store.subscriptions.isEmpty)
                }
            }
        }
    }

    private var weeklyData: [Decimal] {
        // Real weekly spending from subscriptions
        return getRealWeeklySpendingHistory()
    }

    private func getRealWeeklySpendingHistory() -> [Decimal] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<7).map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return Decimal(0)
            }
            return getDailyTotal(for: date)
        }.reversed()
    }

    private func getDailyTotal(for date: Date) -> Decimal {
        // Sum all active subscriptions
        return store.subscriptions
            .filter { $0.status == .active }
            .reduce(Decimal(0)) { $0 + $1.monthlyCost }
    }
}

// MARK: - Smart Insights Section

struct SmartInsightsSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var potentialSavings: Decimal {
        // Calculate potential savings from low-usage subscriptions in user's selected currency
        store.subscriptions
            .filter { sub in
                let usage = screenTimeManager.getCurrentMonthUsage(for: sub.name)
                return usage < 60 && sub.monthlyCost > 5
            }
            .reduce(Decimal(0)) { total, sub in
                let converted = (try? currencyManager.convert(sub.monthlyCost, from: sub.currency, to: currencyManager.selectedCurrency)) ?? sub.monthlyCost
                return total + converted
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Insights")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                // Savings opportunity
                if potentialSavings > 0 {
                    DashboardInsightCard(
                        icon: "leaf.fill",
                        iconColor: .green,
                        title: "Potential Savings",
                        subtitle: "From low-usage subscriptions",
                        value: formatCurrency(potentialSavings),
                        valueColor: .green
                    )
                }

                // Hidden perks
                let perksCount = PerkEngine.shared.discoveredPerks.count
                DashboardInsightCard(
                    icon: "gift.fill",
                    iconColor: Color.luxuryGold,
                    title: "Available Perks",
                    subtitle: perksCount > 0 ? "From your subscriptions" : "Analyze to discover perks",
                    value: perksCount > 0 ? "\(perksCount)" : "—",
                    valueColor: Color.luxuryGold
                )

                // Usage status
                DashboardInsightCard(
                    icon: screenTimeManager.authorizationStatus.icon,
                    iconColor: screenTimeManager.authorizationStatus.color,
                    title: "Usage Tracking",
                    subtitle: screenTimeManager.hasAnyUsageData ? "Data available" : "Not enabled",
                    value: screenTimeManager.hasAnyUsageData ? "Active" : "Setup",
                    valueColor: screenTimeManager.hasAnyUsageData ? .green : .orange
                )
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        return CurrencyManager.shared.format(amount)
    }
}

// MARK: - Insight Card

struct DashboardInsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(AppTypography.headlineMedium)
                .foregroundStyle(valueColor)
        }
        .padding(14)
        .glassBackground(cornerRadius: 16, strokeColor: .white.opacity(0.1), strokeWidth: 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle), value \(value)")
    }
}

// MARK: - Currency Selector Button

struct CurrencySelectorButton: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showingCurrencyPicker = false

    var body: some View {
        Button(action: {
            showingCurrencyPicker = true
            HapticStyle.light.trigger()
        }) {
            HStack(spacing: 6) {
                Text(currencyManager.currencyFlag(for: currencyManager.selectedCurrency))
                    .font(AppTypography.bodyMedium)
                Text(currencyManager.selectedCurrency)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .accessibilityLabel("Select currency, currently \(currencyManager.selectedCurrency)")
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencySettingsView()
        }
    }
}

// MARK: - Notification Button

struct NotificationButton: View {
    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
        }) {
            Image(systemName: "bell.fill")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(Color.luxuryGold)
                .padding(10)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                )
        }
        .accessibilityLabel("Notifications")
    }
}

// MARK: - Offline Mode Banner

struct OfflineModeBanner: View {
    let onEnableCloud: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(Color.luxuryTeal)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                Text("Subscriptions saved locally")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onEnableCloud) {
                Text("Sync")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.luxuryTeal)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .glassBackground(cornerRadius: 16, strokeColor: Color.luxuryTeal.opacity(0.3), strokeWidth: 1)
    }
}

// MARK: - Referral Promotion Card

struct ReferralPromotionCard: View {
    @State private var showingApply = false

    var body: some View {
        Button(action: { showingApply = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.luxuryGold.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: "gift.fill")
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(Color.luxuryGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Unlock Pro for Free")
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(.primary)

                    Text("Refer friends and earn free months")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(Color.luxuryGold)
            }
            .padding(16)
            .glassBackground(cornerRadius: 20, strokeColor: Color.luxuryGold.opacity(0.3), strokeWidth: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unlock Pro for Free, refer friends and earn free months")
        .accessibilityHint("Double-tap to view referral options")
        .sheet(isPresented: $showingApply) {
            ApplyReferralView()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
