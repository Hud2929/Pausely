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

                NavigationView {
                    PremiumProfileView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
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
                // Hero Header
                heroHeader
                    .padding(.top, 16)

                // Offline Mode Banner
                if store.isUsingLocalStorage {
                    OfflineModeBanner {
                        Task {
                            store.disableLocalStorage()
                            await store.fetchSubscriptions(force: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                if store.isLoading && store.subscriptions.isEmpty {
                    dashboardSkeletonSection
                        .transition(.opacity)
                } else if store.subscriptions.isEmpty {
                    ArtisticEmptyState(
                        icon: "chart.pie.fill",
                        title: "Track your first subscription",
                        message: "Add a subscription to see your spending dashboard, upcoming renewals, and smart insights.",
                        action: { showingAddOptions = true },
                        actionTitle: "Add Subscription"
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                } else {
                    // Referral Promotion
                    if !paymentManager.isPremium || referralManager.referralData?.isEligibleForFreePro == false {
                        ReferralPromotionCard()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    // Total Spend Hero Card
                    HeroSpendCard(
                        amount: displayAmount,
                        timeframe: $selectedTimeframe,
                        subscriptionCount: store.subscriptions.count,
                        isLoading: store.isLoading && store.subscriptions.isEmpty
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Quick Actions
                    QuickActionsGrid(
                        onAddTap: { showingAddOptions = true },
                        onPaywallTap: { showingPaywall = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Smart Insights
                    SmartInsightsSection()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Upcoming Renewals
                    if !store.upcomingRenewals.isEmpty {
                        UpcomingRenewalsCarousel(subscriptions: store.upcomingRenewals)
                            .padding(.top, 24)
                    } else if !store.isLoading {
                        // Empty state for upcoming renewals
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
            await store.refresh()
            HapticStyle.light.trigger()
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
            EnhancedAddSubscriptionView()
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 180)
                .shimmer()
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Quick actions skeleton
            HStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 100)
                        .shimmer()
                }
            }
            .padding(.horizontal, 20)

            // Insights card skeleton
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 120)
                .shimmer()
                .padding(.horizontal, 20)

            // Carousel skeleton
            HStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 160, height: 100)
                        .shimmer()
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 100)
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.secondary)

                Text("Dashboard")
                    .font(AppTypography.displayLarge)
                    .foregroundStyle(.primary)
            }

            Spacer()

            HStack(spacing: 12) {
                // Currency selector
                CurrencySelectorButton()

                // Notifications
                NotificationButton()
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
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
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

    var potentialSavings: Decimal {
        // Calculate potential savings from low-usage subscriptions
        store.subscriptions
            .filter { sub in
                guard let usage = screenTimeManager.getCurrentMonthUsage(for: sub.name) as Int? else { return false }
                return usage < 60 && sub.monthlyCost > 5
            }
            .reduce(0) { $0 + $1.monthlyCost }
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
                DashboardInsightCard(
                    icon: "gift.fill",
                    iconColor: Color.luxuryGold,
                    title: "Available Perks",
                    subtitle: "From your subscriptions",
                    value: "3",
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
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
