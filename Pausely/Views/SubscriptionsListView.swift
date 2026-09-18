import SwiftUI

@MainActor
struct SubscriptionsListView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showingAddSheet = false
    @State private var showingPaywall = false
    @State private var searchText = ""
    @State private var selectedSubscription: Subscription?
    @State private var selectedCategory: ServiceCategory?
    @State private var subscriptionToDelete: Subscription?
    
    /// Check if user can add more subscriptions
    var canAddSubscription: Bool {
        paymentManager.canAddSubscription(currentCount: store.subscriptions.count)
    }
    
    var filteredSubscriptions: [Subscription] {
        var subs = store.subscriptions
        
        if let category = selectedCategory {
            subs = subs.filter { $0.category?.lowercased() == category.rawValue.lowercased() }
        }
        
        if !searchText.isEmpty {
            subs = subs.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return subs
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SUBSCRIPTIONS")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                            .tracking(2)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(currencyManager.format(store.totalMonthlySpend))
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.accentMint)
                            Text("/mo")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundStyle(Color.obsidianTextSecondary)
                        }

                        let count = store.activeSubscriptions.count
                        Text("\(count) active")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .font(.system(size: 15))

                    TextField("Search subscriptions", text: $searchText)
                        .foregroundStyle(Color.obsidianText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.default)
                        .submitLabel(.search)
                        .accessibilityIdentifier("searchTextField")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .surfaceCard(cornerRadius: 14)
                .padding(.horizontal, 20)

                // Content or skeleton
                if store.isLoading && store.subscriptions.isEmpty {
                    skeletonSection
                } else {
                    // Category Filter
                    if selectedCategory != nil || !store.subscriptions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                AnimatedCategoryChip(
                                    title: "All",
                                    isSelected: selectedCategory == nil
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedCategory = nil
                                    }
                                }
                                .accessibilityLabel("Filter by All")
                                .accessibilityValue(selectedCategory == nil ? "Selected" : "Not selected")

                                ForEach(ServiceCategory.allCases, id: \.self) { category in
                                    let count = store.subscriptions.filter {
                                        $0.category?.lowercased() == category.rawValue.lowercased()
                                    }.count

                                    if count > 0 {
                                        AnimatedCategoryChip(
                                            title: "\(category.rawValue) (\(count))",
                                            isSelected: selectedCategory == category
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedCategory = category
                                            }
                                        }
                                        .accessibilityLabel("Filter by \(category.rawValue)")
                                        .accessibilityValue(selectedCategory == category ? "Selected" : "Not selected")
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Upgrade banner for free users approaching or at limit
                    if !paymentManager.isPremium && store.subscriptions.count >= PaymentManager.freeTierLimit - 1 {
                        UpgradeBannerView(
                            currentCount: store.subscriptions.count,
                            limit: PaymentManager.freeTierLimit,
                            onUpgrade: { showingPaywall = true }
                        )
                        .padding(.horizontal, 20)
                    }

                    // List
                    LazyVStack(spacing: 12) {
                        if filteredSubscriptions.isEmpty && !store.subscriptions.isEmpty {
                            EmptyFilterView(
                                searchText: searchText,
                                category: selectedCategory,
                                onClearFilters: {
                                    HapticStyle.light.trigger()
                                    searchText = ""
                                    selectedCategory = nil
                                }
                            )
                            .transition(.opacity.combined(with: .scale))
                            .onAppear {
                                HapticStyle.warning.trigger()
                            }
                        } else if store.subscriptions.isEmpty && !store.isLoading {
                            ArtisticEmptyState(
                                icon: "list.bullet.rectangle.fill",
                                title: "No subscriptions yet",
                                message: "Add your first subscription to start tracking your spending.",
                                action: {
                                    if canAddSubscription {
                                        showingAddSheet = true
                                    } else {
                                        showingPaywall = true
                                    }
                                },
                                actionTitle: "Add Subscription"
                            )
                        } else {
                            ForEach(Array(filteredSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                Button(action: {
                                    HapticStyle.medium.trigger()
                                    selectedSubscription = subscription
                                }) {
                                    EnhancedSubscriptionRow(subscription: subscription)
                                        .listRowEntrance(index: index)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        HapticStyle.medium.trigger()
                                        subscriptionToDelete = subscription
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
        }
        .refreshable {
            HapticStyle.medium.trigger()
            await store.fetchSubscriptions()
            HapticStyle.light.trigger()
        }
        .safeAreaInset(edge: .bottom) {
            // Fixed FAB — always accessible, never buried in scroll
            HStack {
                Spacer()
                Button(action: {
                    HapticStyle.medium.trigger()
                    if canAddSubscription {
                        showingAddSheet = true
                    } else {
                        showingPaywall = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: canAddSubscription ? "plus" : "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text(canAddSubscription ? "Add" : "Upgrade")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .background(
                        Capsule()
                            .fill(canAddSubscription ? Color.accentMint : Color.obsidianElevated)
                            .shadow(color: canAddSubscription ? Color.accentMint.opacity(0.35) : .clear, radius: 12, y: 4)
                    )
                }
                .accessibilityLabel(canAddSubscription ? "Add subscription" : "Upgrade to add more subscriptions")
                .accessibilityIdentifier("addSubscriptionButton")
                Spacer()
            }
            .padding(.bottom, 12)
            .background(Color.clear)
        }
        .sheet(isPresented: $showingAddSheet) {
            SubscriptionBrowserView()
        }
        .sheet(item: $selectedSubscription) { subscription in
            SubscriptionManagementView(subscription: subscription)
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .confirmationDialog(
            "Delete \"\(subscriptionToDelete?.name ?? "subscription")\"?",
            isPresented: Binding(get: { subscriptionToDelete != nil }, set: { if !$0 { subscriptionToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let sub = subscriptionToDelete else { return }
                HapticStyle.heavy.trigger()
                Task {
                    do {
                        try await store.deleteSubscription(id: sub.id)
                    } catch {
                        PauselyLogger.error("Error deleting subscription: \(error)", category: "Subscriptions")
                    }
                    subscriptionToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { subscriptionToDelete = nil }
        } message: {
            Text("This will permanently remove it from your list.")
        }
    }

    // MARK: - Skeleton Loading Section
    private var skeletonSection: some View {
        VStack(spacing: 20) {
            // Stat cards skeleton
            HStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    SkeletonCard(height: 90)
                }
            }
            .padding(.horizontal, 20)

            // Category chips skeleton
            HStack(spacing: 8) {
                ForEach(0..<4) { _ in
                    SkeletonCard(height: 36, cornerRadius: 16)
                        .frame(width: 80)
                }
            }
            .padding(.horizontal, 20)

            // Subscription row skeletons using SkeletonRow
            ForEach(0..<4) { _ in
                SkeletonRow()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 40)
        }
    }
}

struct EnhancedSubscriptionRow: View {
    let subscription: Subscription
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var pressed = false
    
    var usageMinutes: Int {
        screenTimeManager.getCurrentMonthUsage(for: subscription.name)
    }
    
    var costPerHour: Decimal? {
        screenTimeManager.calculateCostPerHour(monthlyCost: subscription.monthlyCost, subscriptionName: subscription.name)
    }
    
    var hasUsageData: Bool {
        usageMinutes > 0
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Service logo — real brand mark or colored initial fallback
            ServiceLogoView(name: subscription.name, category: subscription.category, size: 52)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(subscription.name)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    StatusBadge(status: subscription.status)
                    
                    if subscription.canPause {
                        Image(systemName: "pause.circle")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.orange)
                    }
                    
                    if subscription.currency != currencyManager.selectedCurrency {
                        Text(currencyManager.currencyFlag(for: subscription.currency))
                            .font(AppTypography.labelMedium)
                    }
                }
                
                // Usage indicator row (if data available)
                if hasUsageData {
                    HStack(spacing: 8) {
                        // Usage time
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(AppTypography.labelSmall)
                            Text(screenTimeManager.formatMinutes(usageMinutes))
                                .font(AppTypography.labelSmall)
                            EstimateBadge(isEstimated: screenTimeManager.isEstimated(for: subscription.name))
                        }
                        .foregroundStyle(usageColor)

                        if let cph = costPerHour {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.4))

                            // Cost per hour
                            HStack(spacing: 2) {
                                Image(systemName: "dollarsign.circle")
                                    .font(AppTypography.labelSmall)
                                Text(formatCostPerHour(cph))
                                    .font(AppTypography.labelSmall)
                            }
                            .foregroundStyle(costPerHourColor(cph))
                        }
                    }
                } else {
                    // Payment countdown: always show when next billing date is known
                    if subscription.daysUntilRenewal != nil {
                        let days = subscription.daysUntilRenewal!
                        let countdownInfo: (text: String, color: Color) = {
                            if days < 0 { return ("Payment overdue", .red) }
                            if days == 0 { return ("Paying today", .orange) }
                            if days == 1 { return ("Paying tomorrow", .yellow) }
                            return ("Paying in \(days) days", .white.opacity(0.5))
                        }()
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(AppTypography.labelSmall)
                            Text(countdownInfo.text)
                                .font(AppTypography.labelMedium)
                        }
                        .foregroundStyle(countdownInfo.color)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Converted amount in user's currency
                let convertedAmount = currencyManager.convertToSelected(
                    subscription.amount,
                    from: subscription.currency
                )
                Text(currencyManager.format(convertedAmount))
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(Color.accentMint)

                // Show original amount if different currency
                if subscription.currency != currencyManager.selectedCurrency {
                    Text(subscription.displayAmount)
                        .font(AppTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    Text("/\(subscription.billingFrequency.shortDisplay)")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // Swipe-to-delete handles removal — no inline button needed
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.obsidianTextTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .surfaceCard(cornerRadius: 18)
        .scaleEffect(pressed ? 0.98 : 1)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { pressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { pressed = false }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), \(subscription.displayAmount) per \(subscription.billingFrequency.shortDisplay), status \(subscription.status.displayName)")
        .accessibilityHint("Double-tap to view details")
    }
    
    var usageColor: Color {
        if usageMinutes < 30 { return .red }
        if usageMinutes < 60 { return .orange }
        if usageMinutes < 180 { return .yellow }
        return .green
    }
    
    private func formatCostPerHour(_ value: Decimal) -> String {
        CurrencyManager.shared.format(value) + "/hr"
    }
    
    private func costPerHourColor(_ value: Decimal) -> Color {
        let doubleValue = Double(truncating: value as NSNumber)
        if doubleValue > 20 { return .red }
        if doubleValue > 10 { return .orange }
        if doubleValue > 5 { return .yellow }
        return .green
    }
    
}

// See CategoryFilterChip.swift

// See EmptyFilterView.swift

// See StatusBadge.swift

// See UpgradeBannerView.swift

// See LuxuryAddSubscriptionView.swift

#Preview {
    SubscriptionsListView()
}

struct CurrencyPickerButton: View {
    @Binding var selectedCurrency: String
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                Text(selectedCurrency)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding()
            .glass(intensity: 0.1, tint: .white)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showPicker) {
            SimpleCurrencyPickerView(selectedCurrency: $selectedCurrency)
        }
    }
}
