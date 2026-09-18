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
            .tint(Color.accentMint)
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
    @State private var showingAddSubscription = false
    @State private var showingApplyReferral = false
    @State private var selectedTimeframe: DashboardTimeframe = .monthly
    @State private var heroScale: CGFloat = 1.0

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
                // Hero Header — big number dominates
                heroHeader

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
                    // 1. Next upcoming payment — most urgent item
                    NextPaymentCard(subscription: store.upcomingRenewals.first ?? store.activeSubscriptions.first)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // 2. Upcoming bills this week
                    BillsThisWeekCard(subscriptions: store.activeSubscriptions)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // 2b. Perception Gap — the $219 problem
                    PerceptionGapCard(monthlySpend: store.totalMonthlySpend)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // 2c. Waste Score Callout
                    WasteScoreCalloutCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // 3. Trials ending soon (conditional)
                    let expiringTrials = store.activeSubscriptions.filter { sub in
                        guard let trial = sub.trialEndsAt else { return false }
                        return trial > Date() && trial < Date().addingTimeInterval(7 * 86400)
                    }
                    if !expiringTrials.isEmpty {
                        TrialExpirationSection(subscriptions: expiringTrials)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    // 4. Biggest expenses
                    BiggestExpensesSection()

                    // 5. Paused subscriptions (conditional)
                    if !store.pausedSubscriptions.isEmpty {
                        PausedSubscriptionsSection(subscriptions: store.pausedSubscriptions)
                            .padding(.top, 16)
                    }

                    // 6. Lifetime spend
                    LifetimeSpendCard(
                        lifetimeSpend: store.totalLifetimeSpend,
                        currencyManager: currencyManager
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer(minLength: 100)
                }
            }
        }
        .refreshable {
            HapticStyle.medium.trigger()
            await store.fetchSubscriptions(force: true)
            HapticStyle.success.trigger()
        }
        .sheet(isPresented: $showingAddSubscription) {
            SubscriptionBrowserView()
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .sheet(isPresented: $showingApplyReferral) {
            ApplyReferralView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("subscriptionAdded"))) { _ in
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                heroScale = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    heroScale = 1.0
                }
            }
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

    // MARK: - Hero Header
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Timeframe label
                Text(selectedTimeframe == .weekly ? "WEEKLY SPEND" : selectedTimeframe == .yearly ? "YEARLY SPEND" : "MONTHLY SPEND")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .tracking(2)
                    .animation(.none, value: selectedTimeframe)

                Spacer()

                HStack(spacing: 8) {
                    CurrencySelectorButton()
                        .accessibilityIdentifier("currencySelectorButton")
                    NotificationButton()
                        .accessibilityIdentifier("notificationButton")
                }
            }

            Text(currencyManager.format(displayAmount))
                .font(.system(.largeTitle, design: .rounded).weight(.black))
                .foregroundStyle(Color.accentMint)
                .contentTransition(.numericText())
                .scaleEffect(heroScale)

            HStack(spacing: 12) {
                let count = store.activeSubscriptions.count
                Text("\(count) active")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.obsidianTextSecondary)

                // Timeframe picker — compact inline
                HStack(spacing: 0) {
                    ForEach(DashboardTimeframe.allCases, id: \.self) { tf in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { selectedTimeframe = tf }
                            HapticStyle.light.trigger()
                        } label: {
                            Text(tf.shortLabel)
                                .font(.system(size: 11, weight: selectedTimeframe == tf ? .bold : .medium, design: .rounded))
                                .foregroundStyle(selectedTimeframe == tf ? Color.obsidianSurface : Color.obsidianTextTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedTimeframe == tf ? Color.accentMint : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(Color.obsidianElevated)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : -8)
    }
}

// MARK: - Accessibility Helpers

extension DashboardInsightCard {
    func accessibilityLabelText() -> String {
        "\(title), \(subtitle), value \(value)"
    }
}

// MARK: - Compelling Dashboard Empty State
struct DashboardEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentMint.opacity(0.12))
                        .frame(width: 88, height: 88)

                    Circle()
                        .stroke(Color.accentMint.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 88, height: 88)

                    Image(systemName: "plus")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentMint)
                }

                // Text content — 8pt gap between headline and body
                Text("Track Your Subscriptions")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Text("Add services to see your monthly spend, renewal dates, and savings opportunities.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 8)

                // Full-width mint CTA — 24pt gap from body
                Button(action: {
                    HapticStyle.medium.trigger()
                    onAdd()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Add Subscription")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentMint)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 24)
                .accessibilityIdentifier("addSubscriptionButton")
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .surfaceCard(cornerRadius: 24)
        }
        .padding(.vertical, 16)
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
                                colors: [.accentMint.opacity(0.8), .accentMint.opacity(0.6)],
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
        let calendar = Calendar.current
        // Sum amounts for subscriptions that renew on this specific day
        let renewalTotal = store.subscriptions
            .filter { sub in
                guard sub.status == .active,
                      let billingDate = sub.nextBillingDate else { return false }
                return calendar.isDate(billingDate, inSameDayAs: date)
            }
            .reduce(Decimal(0)) { $0 + CurrencyManager.shared.convertToSelected($1.amount, from: $1.currency) }

        // If no renewals today, show a low baseline (monthly cost / 30 as a daily average)
        if renewalTotal == 0 {
            let dailyAverage = store.subscriptions
                .filter { $0.status == .active }
                .reduce(Decimal(0)) { $0 + CurrencyManager.shared.convertToSelected($1.monthlyCost, from: $1.currency) } / 30
            return dailyAverage * Decimal(0.3) // Show at 30% baseline so chart isn't flat
        }
        return renewalTotal
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
                    iconColor: Color.accentMint,
                    title: "Available Perks",
                    subtitle: perksCount > 0 ? "From your subscriptions" : "Analyze to discover perks",
                    value: perksCount > 0 ? "\(perksCount)" : "—",
                    valueColor: Color.accentMint
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
    @State private var showingSettings = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            showingSettings = true
        }) {
            Image(systemName: "bell.fill")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(Color.accentMint)
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
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Notification Settings")
        .sheet(isPresented: $showingSettings) {
            NotificationsSettingsView()
        }
    }
}

// MARK: - Offline Mode Banner

struct OfflineModeBanner: View {
    let onEnableCloud: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(Color.accentMint)

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
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentMint)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .glassBackground(cornerRadius: 16, strokeColor: Color.accentMint.opacity(0.3), strokeWidth: 1)
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
                        .fill(Color.accentMint.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: "gift.fill")
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(Color.accentMint)
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
                    .foregroundStyle(Color.accentMint)
            }
            .padding(16)
            .glassBackground(cornerRadius: 20, strokeColor: Color.accentMint.opacity(0.3), strokeWidth: 1)
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
