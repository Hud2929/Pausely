import SwiftUI

@MainActor
struct SubscriptionsListView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showingAddSheet = false
    @State private var showingAddOptions = false
    @State private var showingSmartURLInput = false
    @State private var showingPaywall = false
    @State private var searchText = ""
    @State private var selectedSubscription: Subscription?
    @State private var selectedCategory: ServiceCategory?
    
    /// Check if user can add more subscriptions
    var canAddSubscription: Bool {
        paymentManager.canAddSubscription(currentCount: store.subscriptions.count)
    }
    
    /// Current subscription count display for free users (e.g., "3/3")
    var subscriptionCountDisplay: String {
        "\(store.subscriptions.count)/\(PaymentManager.freeTierLimit)"
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your")
                            .font(AppTypography.displaySmall)
                            .foregroundStyle(.white)
                        
                        Text("Subscriptions")
                            .font(AppTypography.displaySmall)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.luxuryGold, Color.luxuryPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    // Add button - shows paywall if limit reached
                    Button(action: {
                        HapticStyle.medium.trigger()
                        if canAddSubscription {
                            showingAddSheet = true
                        } else {
                            showingPaywall = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: canAddSubscription
                                            ? [Color.luxuryPurple, Color.luxuryPink]
                                            : [Color.gray, Color.gray.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)

                            Image(systemName: canAddSubscription ? "plus" : "lock.fill")
                                .font(AppTypography.headlineLarge)
                                .foregroundStyle(.white)
                        }
                        .shadow(color: canAddSubscription ? Color.luxuryPurple.opacity(0.5) : Color.clear, radius: 15)
                        .accessibilityLabel(canAddSubscription ? "Add subscription" : "Upgrade to add more subscriptions")
                    }
                    .accessibilityIdentifier("addSubscriptionButton")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))

                    TextField("Search subscriptions...", text: $searchText)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.default)
                        .submitLabel(.search)
                        .accessibilityIdentifier("searchTextField")
                }
                .padding()
                .glass(intensity: 0.15, tint: .white)
                .padding(.horizontal, 20)

                // Content or skeleton
                if store.isLoading && store.subscriptions.isEmpty {
                    skeletonSection
                } else {
                    // Stats cards
                    HStack(spacing: 12) {
                        // Show "X/3" for free users, just count for pro
                        SubscriptionStatCard(
                            value: paymentManager.isPremium ? "\(store.subscriptions.count)" : subscriptionCountDisplay,
                            label: paymentManager.isPremium ? "Active" : "Used",
                            icon: "checkmark.circle.fill",
                            color: canAddSubscription ? Color.luxuryTeal : .orange
                        )

                        // Only show pausable count for Pro users
                        SubscriptionStatCard(
                            value: paymentManager.canPauseSubscriptions
                                ? store.pausableSubscriptions.count.formatted()
                                : "—",
                            label: "Pausable",
                            icon: "pause.circle.fill",
                            color: paymentManager.canPauseSubscriptions ? .orange : .gray
                        )

                        SubscriptionStatCard(
                            value: currencyManager.format(store.totalMonthlySpend),
                            label: "/month",
                            icon: "dollarsign.circle.fill",
                            color: Color.luxuryGold
                        )
                    }
                    .padding(.horizontal, 20)

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

                    // Upgrade banner for free users at/near limit
                    if !paymentManager.isPremium && store.subscriptions.count >= 2 {
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
                                        HapticStyle.heavy.trigger()
                                        Task {
                                            do {
                                                try await store.deleteSubscription(id: subscription.id)
                                            } catch {
                                                PauselyLogger.error("Error deleting subscription: \(error)", category: "Subscriptions")
                                            }
                                        }
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
        .confirmationDialog("Add Subscription", isPresented: $showingAddOptions, titleVisibility: .visible) {
            Button("Add Manually") {
                showingAddSheet = true
            }
            
            Button("Paste from URL") {
                showingSmartURLInput = true
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("How would you like to add a subscription?")
        }
        .sheet(isPresented: $showingAddSheet) {
            SubscriptionBrowserView()
        }
        .sheet(isPresented: $showingSmartURLInput) {
            SmartURLInputView()
        }
        .sheet(item: $selectedSubscription) { subscription in
            SubscriptionManagementView(subscription: subscription)
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: 0)
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
    @State private var showingPausey = false
    @State private var showingDeleteConfirmation = false
    
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
        HStack(spacing: 16) {
            // Icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.4), categoryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                if let logoUrl = subscription.logoUrl,
                   URL(string: logoUrl) != nil {
                    // AsyncImage would go here for real logos
                    Text(String(subscription.name.prefix(1)))
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: categoryIcon)
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.white)
                }
            }
            
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
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.luxuryGold, Color.luxuryPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

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

            // Delete button
            Button(action: { showingDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Remove \(subscription.name)")
            .padding(.leading, 4)

            // Pausey button
            Button(action: { showingPausey = true }) {
                Image(systemName: "figure.butler")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(Color.luxuryPurple)
                    .frame(width: 36, height: 36)
                    .background(Color.luxuryPurple.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Ask Pausey about \(subscription.name)")
            .padding(.leading, 4)
        }
        .padding()
        .glass(intensity: 0.1, tint: .white)
        .scaleEffect(pressed ? 0.98 : 1)
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { pressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { pressed = false }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), \(subscription.displayAmount) per \(subscription.billingFrequency.shortDisplay), status \(subscription.status.displayName)")
        .accessibilityHint("Double-tap to view details")
        .sheet(isPresented: $showingPausey) {
            PauseyButlerView(subscription: subscription)
        }
        .alert("Remove Subscription?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                HapticStyle.heavy.trigger()
                Task {
                    do {
                        try await SubscriptionStore.shared.deleteSubscription(id: subscription.id)
                    } catch {
                        PauselyLogger.error("Error deleting subscription: \(error.localizedDescription)", category: "subscriptions")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to remove \(subscription.name) from your subscriptions?")
        }
    }
    
    var usageColor: Color {
        if usageMinutes < 30 { return .red }
        if usageMinutes < 60 { return .orange }
        if usageMinutes < 180 { return .yellow }
        return .green
    }
    
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
    
    var categoryColor: Color {
        if let category = subscription.category,
           let serviceCategory = ServiceCategory.allCases.first(where: { 
               $0.rawValue.lowercased() == category.lowercased() 
           }) {
            return serviceCategory.color
        }
        return .purple
    }
    
    var categoryIcon: String {
        if let category = subscription.category,
           let serviceCategory = ServiceCategory.allCases.first(where: { 
               $0.rawValue.lowercased() == category.lowercased() 
           }) {
            return serviceCategory.icon
        }
        return "star.fill"
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
