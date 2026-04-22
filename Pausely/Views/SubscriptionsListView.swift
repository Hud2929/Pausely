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
                            showingAddOptions = true
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
                            value: "$\(Int(Double(truncating: store.totalMonthlySpend as NSNumber)))",
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
                        } else if store.subscriptions.isEmpty && !store.isLoading {
                            ArtisticEmptyState(
                                icon: "list.bullet.rectangle.fill",
                                title: "No subscriptions yet",
                                message: "Add your first subscription to start tracking your spending.",
                                action: {
                                    if canAddSubscription {
                                        showingAddOptions = true
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
            EnhancedAddSubscriptionView()
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
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 90)
                        .shimmer()
                }
            }
            .padding(.horizontal, 20)

            // Category chips skeleton
            HStack(spacing: 8) {
                ForEach(0..<4) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 80, height: 36)
                        .shimmer()
                }
            }
            .padding(.horizontal, 20)

            // Subscription row skeletons
            ForEach(0..<4) { _ in
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 56, height: 56)
                        .shimmer()

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 140, height: 18)
                            .shimmer()

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 90, height: 14)
                            .shimmer()
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 60, height: 22)
                        .shimmer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 40)
        }
    }
}

struct SubscriptionStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(AppTypography.headlineLarge)
                .foregroundStyle(color)

            Text(value)
                .font(AppTypography.displaySmall)
                .foregroundStyle(.white)

            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glass(intensity: 0.1, tint: color)
    }
}

struct EnhancedSubscriptionRow: View {
    let subscription: Subscription
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var pressed = false
    @State private var showingPausey = false
    
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
                    let renewalStatus = subscription.renewalStatus
                    if case .upcoming = renewalStatus {
                        Text("Renews in \(renewalStatus.description)")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.4))
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
            .padding(.leading, 8)
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

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Text(title)
                .font(AppTypography.labelMedium)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.luxuryPurple : Color.white.opacity(0.1))
                )
                .scaleEffect(pressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = false }
                }
        )
    }
}

struct EmptyFilterView: View {
    let searchText: String
    let category: ServiceCategory?
    let onClearFilters: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.displayLarge)
                .foregroundStyle(.white.opacity(0.3))
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Text("No subscriptions found")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            } else if let category = category {
                Text("No \(category.rawValue) subscriptions yet")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }

            Button(action: {
                HapticStyle.light.trigger()
                onClearFilters()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.bodyMedium)
                    Text("Clear Filters")
                        .font(AppTypography.headlineSmall)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .accessibilityLabel("Clear filters")
            .premiumPress(haptic: .light, scale: 0.97)
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .padding(.vertical, 40)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                appeared = true
                return
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }
}

struct StatusBadge: View {
    let status: SubscriptionStatus
    
    var body: some View {
        Text(status.displayName)
            .font(AppTypography.labelSmall)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.2))
            )
            .foregroundStyle(statusColor)
    }
    
    var statusColor: Color {
        switch status {
        case .active: return Color.luxuryTeal
        case .paused: return .orange
        case .cancelled: return .red
        case .trial: return .blue
        case .expired: return .gray
        }
    }
}

// MARK: - Upgrade Banner for Free Users
struct UpgradeBannerView: View {
    let currentCount: Int
    let limit: Int
    let onUpgrade: () -> Void
    
    var isAtLimit: Bool {
        currentCount >= limit
    }
    
    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isAtLimit ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isAtLimit ? "lock.fill" : "crown.fill")
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(isAtLimit ? .red : Color.luxuryGold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAtLimit ? "Subscription Limit Reached" : "Almost at Limit")
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(.white)
                    
                    Text(isAtLimit 
                         ? "You've used all \(limit) free subscriptions. Upgrade to Pro for unlimited."
                         : "You've used \(currentCount) of \(limit) free subscriptions. Upgrade for unlimited."
                    )
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(Color.luxuryGold)
            }
            .padding()
            .glass(intensity: isAtLimit ? 0.15 : 0.1, tint: isAtLimit ? .red : Color.luxuryGold)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isAtLimit ? Color.red.opacity(0.3) : Color.luxuryGold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LuxuryAddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: BillingFrequency = .monthly
    @ObservedObject private var store = SubscriptionStore.shared
    @FocusState private var focusedField: Field?
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum Field {
        case name, amount
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Subscription")
                            .font(AppTypography.displayMedium)
                            .foregroundStyle(.white)
                        
                        Text("Track a new recurring expense")
                            .font(AppTypography.bodyLarge)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Service Name")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                            
                            TextField("Netflix, Spotify...", text: $name)
                                .font(AppTypography.bodyLarge)
                                .foregroundStyle(.white)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .padding()
                                .glass(intensity: 0.2, tint: .white)
                        }
                        
                        // Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                            
                            HStack {
                                Text("$")
                                    .font(AppTypography.headlineLarge)
                                    .foregroundStyle(Color.luxuryGold)
                                
                                TextField("0.00", text: $amount)
                                    .font(AppTypography.displaySmall)
                                    .foregroundStyle(.white)
                                    .keyboardType(.decimalPad)
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .amount)
                            }
                            .padding()
                            .glass(intensity: 0.2, tint: .white)
                        }
                        
                        // Frequency
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Billing Frequency")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                            
                            Picker("Frequency", selection: $frequency) {
                                ForEach(BillingFrequency.allCases, id: \.self) { freq in
                                    Text(freq.displayName)
                                        .tag(freq)
                                        .foregroundStyle(.white)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            .glass(intensity: 0.2, tint: .white)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Buttons
                    VStack(spacing: 16) {
                        Button(action: saveSubscription) {
                            Text("Add Subscription")
                                .premiumButton(gradient: [Color.luxuryPurple, Color.luxuryPink])
                        }
                        .disabled(name.isEmpty || amount.isEmpty)
                        .accessibilityHint(name.isEmpty || amount.isEmpty ? "Please enter a service name and amount" : "")

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(AppTypography.bodyLarge)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    func saveSubscription() {
        guard let price = Double(amount), !name.isEmpty else {
            HapticStyle.warning.trigger()
            return
        }
        HapticStyle.success.trigger()
        let newSub = Subscription(name: name, price: price, category: "Other", billingFrequency: frequency)
        Task { 
            do {
                _ = try await store.addSubscription(newSub)
                await MainActor.run { dismiss() }
            } catch {
                #if DEBUG
                print("Error adding subscription: \(error)")
                #endif
                await MainActor.run {
                    errorMessage = formatErrorMessage(error)
                    showError = true
                }
            }
        }
    }
    
    /// Formats database errors into user-friendly messages
    private func formatErrorMessage(_ error: Error) -> String {
        // Check if it's our custom DatabaseError
        if let dbError = error as? SubscriptionStore.DatabaseError {
            return dbError.detailedMessage
        }
        
        let errorString = String(describing: error).lowercased()
        let localizedError = error.localizedDescription.lowercased()
        
        // Check for table not found error (multiple patterns)
        let tableNotFoundPatterns = [
            "could not find the table",
            "does not exist",
            "42p01",
            "relation",
            "schema cache"
        ]
        
        for pattern in tableNotFoundPatterns {
            if errorString.contains(pattern) || localizedError.contains(pattern) {
                return """
                Database Not Set Up

                To fix this:
                1. Go to Supabase Dashboard
                2. Open SQL Editor  
                3. Run FINAL_SUPABASE_SETUP.sql
                4. Return and try again

                Need help? Contact pausely@proton.me
                """
            }
        }
        
        // Check for authentication errors
        if errorString.contains("not authenticated") || 
           errorString.contains("jwt") ||
           localizedError.contains("unauthorized") {
            return "Please sign in to add subscriptions."
        }
        
        // Check for network errors
        if errorString.contains("network") || 
           errorString.contains("connection") || 
           errorString.contains("offline") ||
           errorString.contains("timeout") {
            return "Network error. Please check your internet connection and try again."
        }
        
        // Default: return the error description
        return error.localizedDescription
    }
    
    /// Checks if error is a "table not found" error
    private func isTableNotFoundError(_ error: Error) -> Bool {
        if let dbError = error as? SubscriptionStore.DatabaseError {
            return dbError.isTableNotFound
        }
        
        let errorString = String(describing: error).lowercased()
        let tableNotFoundPatterns = [
            "could not find the table",
            "does not exist",
            "42p01",
            "relation",
            "schema cache"
        ]
        
        for pattern in tableNotFoundPatterns {
            if errorString.contains(pattern) {
                return true
            }
        }
        return false
    }
}

#Preview {
    SubscriptionsListView()
}

struct SmartURLInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var urlParser = SmartURLParser.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    
    @State private var urlText = ""
    @State private var isParsing = false
    @State private var parsedResult: ParsedSubscription?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAddDetails = false
    @State private var showingPaywall = false
    
    // Subscription details (editable)
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedCurrency: String = "USD"
    @State private var frequency: BillingFrequency = .monthly
    @State private var category: ServiceCategory = .other
    @State private var nextBillingDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // URL Input Section
                        urlInputSection
                        
                        if let parsed = parsedResult {
                            // Parsed Result Card
                            ParsedResultCard(result: parsed)
                            
                            // Edit Details Section
                            if showAddDetails {
                                editDetailsSection
                            }
                            
                            // Action Buttons
                            actionButtons
                        }
                        
                        // Recent Parses
                        if !urlParser.recentParses.isEmpty && parsedResult == nil {
                            recentParsesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add from URL")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Connection Issue", isPresented: $showError) {
                if isTableNotFoundError(errorMessage) {
                    Button("Continue Offline", role: .none) {
                        store.enableLocalStorage()
                        // Retry the save
                        saveSubscription()
                    }
                    Button("Try Again", role: .none) {
                        // Just dismiss and let user try again
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingPaywall) {
                StoreKitUpgradeView(currentSubscriptionCount: 0)
            }
        }
    }
    
    /// Checks if error message indicates table not found
    private func isTableNotFoundError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("database") ||
               lowercased.contains("connection") ||
               lowercased.contains("could not find") ||
               lowercased.contains("does not exist") ||
               lowercased.contains("schema cache") ||
               lowercased.contains("offline")
    }
    
    private var urlInputSection: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(AppTypography.displayLarge)
                    .foregroundStyle(Color.luxuryGold)
                
                Text("Paste Subscription URL")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.white)
                
                Text("Paste a link to Netflix, Spotify, or any subscription service")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // URL Input
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.white.opacity(0.5))
                
                TextField("https://...", text: $urlText)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                
                if !urlText.isEmpty {
                    Button(action: { urlText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .accessibilityLabel("Clear URL")
                }

                Button(action: parseURL) {
                    if isParsing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.luxuryGold)
                    }
                }
                .accessibilityLabel("Parse URL")
                .disabled(urlText.isEmpty || isParsing)
                .accessibilityHint(urlText.isEmpty ? "Please enter a URL first" : isParsing ? "Please wait, parsing URL" : "")
            }
            .padding()
            .glass(intensity: 0.2, tint: .white)
            
            // Paste Button
            Button(action: pasteFromClipboard) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste from Clipboard")
                }
                .font(AppTypography.bodySmall)
                .foregroundStyle(Color.luxuryGold)
            }
            .accessibilityLabel("Paste URL from clipboard")
        }
    }
    
    private var editDetailsSection: some View {
        VStack(spacing: 20) {
            Text("Subscription Details")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Name
            EnhancedFormField(title: "Name") {
                TextField("Service name", text: $name)
                    .foregroundStyle(.white)
            }
            
            // Amount & Currency
            HStack(spacing: 12) {
                EnhancedFormField(title: "Amount") {
                    HStack {
                        Text(currencyManager.currencySymbol(for: selectedCurrency))
                            .foregroundStyle(Color.luxuryGold)
                        TextField("0.00", text: $amount)
                            .foregroundStyle(.white)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // Currency Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                    
                    CurrencyPickerButton(selectedCurrency: $selectedCurrency)
                }
            }
            
            // Billing Frequency
            VStack(alignment: .leading, spacing: 8) {
                Text("Billing Frequency")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                
                Picker("Frequency", selection: $frequency) {
                    ForEach(BillingFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName)
                            .tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                .colorMultiply(.white)
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(ServiceCategory.allCases, id: \.self) { cat in
                        CategoryChip(
                            category: cat,
                            isSelected: category == cat
                        ) {
                            withAnimation {
                                category = cat
                            }
                        }
                    }
                }
            }
            
            // Next Billing Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Billing Date")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                
                DatePicker("", selection: $nextBillingDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .colorMultiply(.white)
                    .padding()
                    .glass(intensity: 0.1, tint: .white)
            }
        }
        .padding()
        .glass(intensity: 0.1, tint: .white)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !showAddDetails {
                Button(action: { showAddDetails = true }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Details")
                    }
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.luxuryPurple.opacity(0.3))
                    .cornerRadius(12)
                }
            }
            
            Button(action: saveSubscription) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Add Subscription")
                }
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.luxuryPurple, Color.luxuryPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(name.isEmpty || amount.isEmpty)
            .accessibilityHint(name.isEmpty || amount.isEmpty ? "Please enter a service name and amount" : "")
            .opacity(name.isEmpty || amount.isEmpty ? 0.6 : 1)
        }
    }
    
    private var recentParsesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)
            
            ForEach(urlParser.recentParses.prefix(3)) { parse in
                RecentParseRow(parse: parse)
                    .onTapGesture {
                        withAnimation {
                            parsedResult = parse
                            populateFromParsed(parse)
                        }
                    }
            }
        }
    }
    
    // MARK: - Actions
    
    private func parseURL() {
        guard !urlText.isEmpty else { return }
        
        isParsing = true
        HapticStyle.medium.trigger()
        
        Task {
            if let result = await urlParser.parseURL(urlText) {
                await MainActor.run {
                    self.parsedResult = result
                    self.populateFromParsed(result)
                    self.isParsing = false
                    HapticStyle.success.trigger()
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Could not recognize this URL. Please check the link and try again."
                    self.showError = true
                    self.isParsing = false
                    HapticStyle.error.trigger()
                }
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.string {
            urlText = pasted
            parseURL()
        }
    }
    
    private func populateFromParsed(_ parsed: ParsedSubscription) {
        name = parsed.name
        amount = parsed.price != nil ? String(format: "%.2f", parsed.price!) : ""
        selectedCurrency = parsed.currency
        category = parsed.category
        
        // Try to find the service in our database for more details
        if SubscriptionActionManager.shared.getService(for: parsed.name) != nil {
            // Use service details
        }
    }
    
    private func saveSubscription() {
        guard let price = Double(amount), !name.isEmpty else {
            HapticStyle.warning.trigger()
            return
        }

        // Check limit before attempting to save (UI-level enforcement)
        guard paymentManager.canAddSubscription(currentCount: store.subscriptions.count) else {
            showingPaywall = true
            return
        }

        HapticStyle.success.trigger()
        
        let newSubscription = Subscription(
            name: name,
            description: parsedResult?.description,
            logoUrl: parsedResult?.logoURL?.absoluteString,
            category: category.rawValue,
            amount: Decimal(price),
            currency: selectedCurrency,
            billingFrequency: frequency,
            nextBillingDate: nextBillingDate,
            canPause: parsedResult?.directPauseURL != nil,
            pauseUrl: parsedResult?.directPauseURL?.absoluteString
        )
        
        Task {
            do {
                _ = try await store.addSubscription(newSubscription)
                await MainActor.run { dismiss() }
            } catch _ as SubscriptionStore.SubscriptionLimitError {
                // Show paywall when subscription limit is reached
                await MainActor.run {
                    showingPaywall = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = formatErrorMessage(error)
                    showError = true
                }
            }
        }
    }
    
    /// Formats database errors into user-friendly messages
    private func formatErrorMessage(_ error: Error) -> String {
        // Check if it's our custom DatabaseError
        if let dbError = error as? SubscriptionStore.DatabaseError {
            return dbError.detailedMessage
        }
        
        let errorString = String(describing: error).lowercased()
        let localizedError = error.localizedDescription.lowercased()
        
        // Check for table not found error (multiple patterns)
        let tableNotFoundPatterns = [
            "could not find the table",
            "does not exist",
            "42p01",
            "relation",
            "schema cache"
        ]
        
        for pattern in tableNotFoundPatterns {
            if errorString.contains(pattern) || localizedError.contains(pattern) {
                return """
                Database Not Set Up

                To fix this:
                1. Go to Supabase Dashboard
                2. Open SQL Editor  
                3. Run FINAL_SUPABASE_SETUP.sql
                4. Return and try again

                Need help? Contact pausely@proton.me
                """
            }
        }
        
        // Check for authentication errors
        if errorString.contains("not authenticated") || 
           errorString.contains("jwt") ||
           localizedError.contains("unauthorized") {
            return "Please sign in to add subscriptions."
        }
        
        // Check for network errors
        if errorString.contains("network") || 
           errorString.contains("connection") || 
           errorString.contains("offline") ||
           errorString.contains("timeout") {
            return "Network error. Please check your internet connection and try again."
        }
        
        // Default: return the error description
        return error.localizedDescription
    }
    
    /// Shows the database setup required alert
    private func showDatabaseSetupAlert() {
        errorMessage = """
        Database Not Set Up

        To fix this:
        1. Go to Supabase Dashboard
        2. Open SQL Editor  
        3. Run FINAL_SUPABASE_SETUP.sql
        4. Return and try again

        Need help? Contact pausely@proton.me
        """
        showError = true
    }
}

// MARK: - Supporting Views

struct ParsedResultCard: View {
    let result: ParsedSubscription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Logo placeholder
                ZStack {
                    Circle()
                        .fill(result.category.color.opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: result.category.icon)
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(result.category.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.white)
                    
                    Text(result.category.rawValue)
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(result.category.color)
                }
                
                Spacer()
                
                // Confidence badge
                ConfidenceBadge(level: result.confidenceLevel)
            }
            
            if let description = result.description {
                Text(description)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            if let price = result.price {
                HStack {
                    Text("Detected Price:")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text("\(result.currency) \(String(format: "%.2f", price))")
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(Color.luxuryGold)
                    
                    Text("/\(result.billingFrequency.rawValue)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            // Action URLs
            HStack(spacing: 12) {
                if result.directCancelURL != nil {
                    ActionChip(icon: "xmark.circle", text: "Cancel", color: .red)
                }
                if result.directPauseURL != nil {
                    ActionChip(icon: "pause.circle", text: "Pause", color: .orange)
                }
                if result.supportURL != nil {
                    ActionChip(icon: "questionmark.circle", text: "Support", color: .blue)
                }
            }
        }
        .padding()
        .glass(intensity: 0.15, tint: result.category.color)
    }
}

struct ConfidenceBadge: View {
    let level: ParsedSubscription.ConfidenceLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(level.rawValue)
                .font(AppTypography.labelMedium)
        }
        .foregroundStyle(level.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(level.color.opacity(0.15))
        )
    }
}

struct ActionChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppTypography.labelMedium)
            Text(text)
                .font(AppTypography.labelMedium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

struct CategoryChip: View {
    let category: ServiceCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(AppTypography.labelLarge)
                Text(category.rawValue)
                    .font(AppTypography.labelMedium)
            }
            .foregroundStyle(isSelected ? .white : category.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : category.color.opacity(0.15))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentParseRow: View {
    let parse: ParsedSubscription
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: parse.category.icon)
                .font(AppTypography.headlineLarge)
                .foregroundStyle(parse.category.color)
                .frame(width: 40, height: 40)
                .background(parse.category.color.opacity(0.15))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(parse.name)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.white)
                
                Text(parse.url.host ?? "")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }
}

struct EnhancedFormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
            
            content
                .padding()
                .glass(intensity: 0.1, tint: .white)
        }
    }
}

struct SimpleCurrencyPickerView: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var searchText = ""
    
    var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return currencyManager.currencies
        }
        return currencyManager.currencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredCurrencies) { currency in
                    Button(action: {
                        selectedCurrency = currency.code
                        currencyManager.setCurrency(currency.code)
                        dismiss()
                    }) {
                        HStack {
                            Text(currency.flag)
                                .font(.title3)
                            Text(currency.code)
                                .font(AppTypography.headlineMedium)
                            Text(currency.name)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedCurrency == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.luxuryGold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Currency")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
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

struct SmartURLInputView_Previews: PreviewProvider {
    static var previews: some View {
        SmartURLInputView()
    }
}

struct EnhancedAddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var catalogService = SubscriptionCatalogService.shared

    // Form fields
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedCurrency: String
    @State private var frequency: BillingFrequency = .monthly
    @State private var category: ServiceCategory = .other
    @State private var nextBillingDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingPaywall = false
    @State private var catalogSuggestions: [CatalogEntry] = []

    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool

    init() {
        _selectedCurrency = State(initialValue: CurrencyManager.shared.selectedCurrency)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()

                ScrollView {
                    VStack(spacing: 32) {
                        // Hero Section
                        heroSection

                        // Name Input
                        nameInputSection

                        // Amount Input
                        amountInputSection

                        // Billing Frequency
                        frequencySection

                        // Category
                        categorySection

                        // Next Billing Date
                        dateSection

                        // Save Button
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Oops", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingPaywall) {
                StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "plus.circle.fill")
                    .font(AppTypography.displayLarge)
                    .foregroundStyle(Color.luxuryPurple)
            }

            Text("Add a subscription to track")
                .font(AppTypography.bodyLarge)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }

    // MARK: - Name Input

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Service")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.7))

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(AppTypography.bodyLarge)
                        .foregroundStyle(Color.luxuryTeal)
                        .frame(width: 24)

                    TextField("Netflix, Spotify, Apple Music...", text: $name)
                        .font(AppTypography.bodyLarge)
                        .focused($isNameFocused)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(.white)
                        .submitLabel(.next)
                        .onSubmit {
                            isAmountFocused = true
                        }
                        .onChange(of: name) { oldValue, newValue in
                            if newValue.count >= 2 {
                                catalogSuggestions = catalogService.search(newValue, category: nil).prefix(5).map { $0 }
                            } else {
                                catalogSuggestions = []
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glass(intensity: 0.15, tint: .white)

                // Catalog suggestions
                if !catalogSuggestions.isEmpty && isNameFocused {
                    VStack(spacing: 0) {
                        ForEach(catalogSuggestions) { entry in
                            Button(action: {
                                name = entry.name
                                if let price = entry.supportedTiers.first?.monthlyPriceUSD {
                                    amount = String(format: "%.2f", price)
                                }
                                if let serviceCat = ServiceCategory(rawValue: entry.category.rawValue) {
                                    category = serviceCat
                                }
                                catalogSuggestions = []
                                isNameFocused = false
                                HapticStyle.light.trigger()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.iconName)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundStyle(Color.luxuryTeal)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundStyle(.white)

                                        if let price = entry.supportedTiers.first?.monthlyPriceUSD {
                                            Text("~$\(String(format: "%.2f", price))/mo")
                                                .font(AppTypography.labelMedium)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(AppTypography.labelSmall)
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(PlainButtonStyle())

                            if entry.id != catalogSuggestions.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.deepBlack.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.top, 4)
                    .zIndex(1)
                }
            }
        }
    }

    // MARK: - Amount Input

    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 0) {
                // Currency Button
                Menu {
                    ForEach(["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN"], id: \.self) { curr in
                        Button(curr) {
                            selectedCurrency = curr
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCurrency)
                            .font(AppTypography.headlineMedium)
                        Image(systemName: "chevron.down")
                            .font(AppTypography.labelMedium)
                    }
                    .foregroundStyle(Color.luxuryTeal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))

                // Amount Field
                TextField("0.00", text: $amount)
                    .font(AppTypography.displaySmall)
                    .keyboardType(.decimalPad)
                    .foregroundStyle(.white)
                    .focused($isAmountFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
            }
            .glass(intensity: 0.15, tint: .white)
        }
    }

    // MARK: - Frequency Section

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How often")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 0) {
                ForEach([BillingFrequency.weekly, .monthly, .yearly], id: \.self) { freq in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            frequency = freq
                        }
                    } label: {
                        Text(freq.shortDisplay)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(frequency == freq ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                if frequency == freq {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.luxuryPurple)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glass(intensity: 0.15, tint: .white)
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ServiceCategory.allCases, id: \.self) { cat in
                        categoryPill(category: cat, isSelected: category == cat) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                category = cat
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryPill(category: ServiceCategory, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(AppTypography.labelLarge)

                Text(category.rawValue)
                    .font(AppTypography.labelLarge)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(category.color)
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next billing")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "calendar")
                    .font(AppTypography.bodyLarge)
                    .foregroundStyle(Color.luxuryTeal)
                    .frame(width: 24)

                DatePicker("", selection: $nextBillingDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorMultiply(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glass(intensity: 0.15, tint: .white)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveSubscription()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Add Subscription")
                        .font(AppTypography.headlineMedium)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            canSave
                            ? LinearGradient(
                                colors: [Color.luxuryPurple, Color.luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0)],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1.5
                        )
                }
            }
            .shadow(color: canSave ? Color.luxuryPurple.opacity(0.4) : Color.clear, radius: 15, x: 0, y: 8)
        }
        .disabled(!canSave || isLoading)
        .accessibilityHint(!canSave ? "Please fill in all required fields correctly" : isLoading ? "Please wait, saving subscription" : "")
        .pressEffect(scale: 0.97)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil
    }

    // MARK: - Actions

    private func saveSubscription() {
        guard let price = Double(amount), !name.isEmpty else {
            HapticStyle.warning.trigger()
            return
        }

        guard paymentManager.canAddSubscription(currentCount: store.subscriptions.count) else {
            showingPaywall = true
            return
        }

        isLoading = true
        HapticStyle.success.trigger()

        let newSubscription = Subscription(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.rawValue,
            amount: Decimal(price),
            currency: selectedCurrency,
            billingFrequency: frequency,
            nextBillingDate: nextBillingDate
        )

        Task {
            do {
                _ = try await store.addSubscription(newSubscription)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch _ as SubscriptionStore.SubscriptionLimitError {
                await MainActor.run {
                    isLoading = false
                    showingPaywall = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct CategoryButton: View {
    let category: ServiceCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : category.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: category.icon)
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(isSelected ? .white : category.color)
                }
                
                Text(category.rawValue)
                    .font(AppTypography.labelSmall)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LuxuryAddSubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        LuxuryAddSubscriptionView()
    }
}
