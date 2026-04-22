import SwiftUI

// MARK: - Revolutionary Subscriptions View
// A unique timeline-based layout showing subscriptions as cards flowing through time

struct PremiumSubscriptionsView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var selectedFilter: FilterType = .all
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showingBrowser = false
    @State private var showingAutoDetect = false
    @State private var selectedSubscription: Subscription?
    @State private var cardOffset: CGFloat = 0
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case paused = "Paused"
        case upcoming = "Upcoming"
    }
    
    var filteredSubscriptions: [Subscription] {
        var result = store.subscriptions
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        switch selectedFilter {
        case .all:
            return result
        case .active:
            return result.filter { !$0.isPaused }
        case .paused:
            return result.filter { $0.isPaused }
        case .upcoming:
            return result.filter { ($0.daysUntilRenewal ?? 999) <= 7 }
        }
    }
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Header
                subscriptionsHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Apple Subscription Scanner Button
                appleScannerButton
                    .padding(.top, 16)

                // Search & Filter
                searchAndFilterSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Subscription Cards
                if filteredSubscriptions.isEmpty {
                    EmptySubscriptionsArtisticView {
                        showingBrowser = true
                    }
                    .padding(.top, 40)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(filteredSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                ArtisticSubscriptionCard(
                                    subscription: subscription,
                                    index: index,
                                    onTap: { selectedSubscription = subscription }
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ArtisticAddSubscriptionView()
        }
        .sheet(item: $selectedSubscription) { subscription in
            SubscriptionDetailView(subscription: subscription)
        }
        .sheet(isPresented: $showingBrowser) {
            SubscriptionBrowserView()
        }
        .sheet(isPresented: $showingAutoDetect) {
            AutoDetectView()
        }
    }
    
    private var subscriptionsHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(filteredSubscriptions.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(BrandColors.primary)

                Text("Subscriptions")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Browse Button
            Button(action: { showingBrowser = true }) {
                ZStack {
                    Circle()
                        .fill(Color.luxuryPurple.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.luxuryPurple)
                }
            }

            // Add Button - opens premium catalog browser
            Button(action: { showingBrowser = true }) {
                ZStack {
                    Circle()
                        .fill(BrandColors.primary)
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Apple Subscription Scanner Button
    private var appleScannerButton: some View {
        HStack(spacing: 0) {
            Button(action: { showingAutoDetect = true }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.luxuryPurple.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: "apple.logo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.luxuryPurple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Subscriptions")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Scan from App Store")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.luxuryPurple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17))
                    .foregroundColor(TextColors.tertiary)
                
                TextField("Search subscriptions...", text: $searchText)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .keyboardType(.default)
                    .submitLabel(.search)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(BackgroundColors.tertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        SubscriptionFilterPill(
                            title: filter.rawValue,
                            count: countForFilter(filter),
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func countForFilter(_ filter: FilterType) -> Int {
        switch filter {
        case .all:
            return store.subscriptions.count
        case .active:
            return store.subscriptions.filter { !$0.isPaused }.count
        case .paused:
            return store.subscriptions.filter { $0.isPaused }.count
        case .upcoming:
            return store.subscriptions.filter { ($0.daysUntilRenewal ?? 999) <= 7 }.count
        }
    }
}

// MARK: - Filter Pill
struct SubscriptionFilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? .white.opacity(0.2) : BackgroundColors.tertiary)
                    )
            }
            .foregroundColor(isSelected ? .white : TextColors.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? BrandColors.primary : BackgroundColors.secondary)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Artistic Subscription Card
struct ArtisticSubscriptionCard: View {
    let subscription: Subscription
    let index: Int
    let onTap: () -> Void
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var isPressed = false
    @State private var appear = false
    
    var cardColor: Color {
        let colors: [Color] = [
            BrandColors.primary,
            BrandColors.secondary,
            BrandColors.accent,
            SemanticColors.success,
            SemanticColors.info,
            SemanticColors.warning
        ]
        return colors[index % colors.count]
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left color bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(cardColor)
                    .frame(width: 4)
                    .padding(.vertical, 20)
                
                // Content
                HStack(spacing: 16) {
                    // Icon with gradient background
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [cardColor.opacity(0.3), cardColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Text(String(subscription.name.prefix(1)))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(subscription.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            // Billing frequency badge
                            Text(subscription.billingFrequency.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(BackgroundColors.tertiary)
                                )
                                .foregroundColor(TextColors.secondary)
                            
                            if subscription.isPaused {
                                Text("Paused")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(SemanticColors.warning.opacity(0.2))
                                    )
                                    .foregroundColor(SemanticColors.warning)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Price
                    VStack(alignment: .trailing, spacing: 4) {
                        let converted = currencyManager.convertToSelected(
                            subscription.amount,
                            from: subscription.currency
                        )
                        Text(currencyManager.format(converted))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(cardColor)
                        
                        if let days = subscription.daysUntilRenewal {
                            Text(days == 0 ? "Today" : "\(days)d")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(days <= 3 ? SemanticColors.error : TextColors.tertiary)
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 20)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(BackgroundColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(cardColor.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: cardColor.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(Double(index) * 0.05)) {
                appear = true
            }
        }
    }
}

// MARK: - Empty Subscriptions Artistic View
struct EmptySubscriptionsArtisticView: View {
    let onAdd: () -> Void
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated illustration
            ZStack {
                // Orbit rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(BrandColors.primary.opacity(0.1 + Double(i) * 0.1), lineWidth: 1)
                        .frame(width: 150 + CGFloat(i * 40), height: 150 + CGFloat(i * 40))
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .animation(
                            .linear(duration: 10 + Double(i) * 5).repeatForever(autoreverses: false),
                            value: animate
                        )
                }
                
                // Center icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [BrandColors.primary, BrandColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: BrandColors.primary.opacity(0.4), radius: 30, x: 0, y: 15)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 280)
            
            VStack(spacing: 12) {
                Text("No subscriptions yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Add your first subscription to start tracking your spending")
                    .font(.system(size: 17))
                    .foregroundColor(TextColors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Subscription")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.brandGradient)
                )
                .shadow(color: BrandColors.primary.opacity(0.4), radius: 20, x: 0, y: 10)
            }
        }
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            animate = true
        }
    }
}

// MARK: - Subscription Detail View
struct SubscriptionDetailView: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showingCancelSheet = false
    @State private var cancellationURL: URL?
    
    var cardColor: Color {
        BrandColors.primary
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header Card
                        VStack(spacing: 20) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [cardColor.opacity(0.3), cardColor.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                
                                Text(String(subscription.name.prefix(1)))
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            // Name
                            Text(subscription.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            // Price
                            let converted = currencyManager.convertToSelected(
                                subscription.amount,
                                from: subscription.currency
                            )
                            Text(currencyManager.format(converted))
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(cardColor)
                            
                            Text("per \(subscription.billingFrequency.displayName.lowercased())")
                                .font(.system(size: 17))
                                .foregroundColor(TextColors.secondary)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(BackgroundColors.secondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(cardColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        // Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Details")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 1) {
                                SubscriptionDetailRow(icon: "calendar", title: "Next Billing", value: renewalDateText)
                                SubscriptionDetailRow(icon: "tag", title: "Category", value: subscription.category ?? "Other")
                                SubscriptionDetailRow(icon: "checkmark.circle", title: "Status", value: subscription.status.displayName)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Actions
                        VStack(spacing: 12) {
                            // Cancel Subscription Button
                            Button(action: { openCancellationPage() }) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Cancel Subscription")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.red.opacity(0.8))
                                )
                            }

                            Button(action: { showingEditSheet = true }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Edit Subscription")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(BackgroundColors.tertiary)
                                )
                            }

                            Button(action: {
                                HapticStyle.heavy.trigger()
                                showingDeleteConfirm = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(SemanticColors.error)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(SemanticColors.error.opacity(0.1))
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(TextColors.secondary)
                }
            }
            .alert("Delete Subscription?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // Delete logic
                    dismiss()
                }
            } message: {
                Text("This will permanently remove \(subscription.name) from your subscriptions.")
            }
            .sheet(isPresented: $showingCancelSheet) {
                if let url = cancellationURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private func openCancellationPage() {
        // Look up the cancellation URL from the catalog
        if let entry = SubscriptionCatalogService.shared.entry(for: subscription.bundleIdentifier ?? "") {
            if let urlString = entry.cancellationURL, let url = URL(string: urlString) {
                cancellationURL = url
                showingCancelSheet = true
                return
            }
        }

        // Fallback: search by subscription name in catalog
        if let entry = SubscriptionCatalogService.shared.catalog.first(where: {
            $0.name.lowercased() == subscription.name.lowercased() ||
            subscription.name.lowercased().contains($0.name.lowercased())
        }) {
            if let urlString = entry.cancellationURL, let url = URL(string: urlString) {
                cancellationURL = url
                showingCancelSheet = true
                return
            }
        }

        // No cancellation URL found - use App Store subscriptions page as fallback
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            cancellationURL = url
            showingCancelSheet = true
        }
    }

    var renewalDateText: String {
        guard let date = subscription.nextBillingDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row
struct SubscriptionDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(BrandColors.primary)
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(TextColors.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(16)
        .background(BackgroundColors.secondary)
    }
}

// MARK: - Add Subscription View
struct ArtisticAddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedFrequency: BillingFrequency = .monthly
    @State private var selectedCategory: NeuralSubscriptionCategory = .entertainment
    @State private var nextRenewalDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    
    @State private var currentStep = 0
    @State private var isSaving = false
    
    let steps = ["Name", "Amount", "Schedule"]
    
    var canProceed: Bool {
        switch currentStep {
        case 0: return !name.isEmpty
        case 1: return !amount.isEmpty && Double(amount) != nil
        default: return true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()
                
                VStack(spacing: 0) {
                    // Progress
                    StepProgressView(steps: steps, currentStep: currentStep)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Content
                    TabView(selection: $currentStep) {
                        // Step 1: Name
                        NameStepView(name: $name, selectedCategory: $selectedCategory)
                            .tag(0)
                        
                        // Step 2: Amount
                        AmountStepView(amount: $amount, selectedFrequency: $selectedFrequency)
                            .tag(1)
                        
                        // Step 3: Schedule
                        ScheduleStepView(nextRenewalDate: $nextRenewalDate)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Navigation Buttons
                    HStack(spacing: 16) {
                        if currentStep > 0 {
                            Button(action: { currentStep -= 1 }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(BackgroundColors.tertiary)
                                    )
                            }
                            .accessibilityLabel("Previous step")
                        }
                        
                        Button(action: {
                            if currentStep < steps.count - 1 {
                                currentStep += 1
                            } else {
                                saveSubscription()
                            }
                        }) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(currentStep == steps.count - 1 ? "Save" : "Continue")
                                        .font(.system(size: 17, weight: .semibold))
                                    
                                    if currentStep < steps.count - 1 {
                                        Image(systemName: "arrow.right")
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.brandGradient)
                            )
                        }
                        .disabled(!canProceed || isSaving)
                        .opacity(canProceed ? 1 : 0.6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(TextColors.secondary)
                }
            }
        }
    }
    
    private func saveSubscription() {
        isSaving = true
        
        Task {
            guard let amountValue = Decimal(string: amount) else {
                isSaving = false
                return
            }
            
            let subscription = Subscription(
                name: name,
                category: selectedCategory.rawValue,
                amount: amountValue,
                currency: "USD",
                billingFrequency: selectedFrequency,
                nextBillingDate: nextRenewalDate
            )
            
            do {
                _ = try await store.addSubscription(subscription)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Step Progress View
struct StepProgressView: View {
    let steps: [String]
    let currentStep: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? BrandColors.primary : BackgroundColors.tertiary)
                            .frame(width: 32, height: 32)
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(index == currentStep ? .white : TextColors.tertiary)
                        }
                    }
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? BrandColors.primary : BackgroundColors.tertiary)
                            .frame(height: 2)
                    }
                }
            }
        }
    }
}

// MARK: - Name Step
struct NameStepView: View {
    @Binding var name: String
    @Binding var selectedCategory: NeuralSubscriptionCategory
    
    let categories: [(NeuralSubscriptionCategory, String, String)] = [
        (.entertainment, "film.fill", "Entertainment"),
        (.lifestyle, "heart.fill", "Lifestyle"),
        (.essential, "checkmark.shield.fill", "Essential"),
        (.utility, "bolt.fill", "Utility"),
        (.luxury, "crown.fill", "Luxury")
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("What's the subscription?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Enter the name of the service you're subscribing to")
                        .font(.system(size: 17))
                        .foregroundColor(TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Name input
                PremiumTextField(placeholder: "e.g. Netflix, Spotify", text: $name)
                    .padding(.horizontal, 20)
                
                // Category selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Category")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        ForEach(categories, id: \.0) { category, icon, label in
                            SubscriptionCategoryButton(
                                icon: icon,
                                label: label,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Category Button
struct SubscriptionCategoryButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? BrandColors.primary : BackgroundColors.tertiary)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : TextColors.secondary)
                }
                
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : TextColors.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Amount Step
struct AmountStepView: View {
    @Binding var amount: String
    @Binding var selectedFrequency: BillingFrequency
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("How much does it cost?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Enter the amount you pay for this subscription")
                        .font(.system(size: 17))
                        .foregroundColor(TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Amount display
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(BrandColors.primary)
                    
                    Text(amount.isEmpty ? "0.00" : amount)
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)
                
                // Amount input
                PremiumTextField(
                    placeholder: "0.00",
                    text: $amount,
                    keyboardType: .decimalPad
                )
                .padding(.horizontal, 20)
                
                // Frequency selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Billing Frequency")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 10) {
                        ForEach(BillingFrequency.allCases, id: \.self) { frequency in
                            FrequencyButton(
                                title: frequency.displayName,
                                isSelected: selectedFrequency == frequency
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedFrequency = frequency
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Frequency Button
struct FrequencyButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : TextColors.secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(BrandColors.primary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? BrandColors.primary.opacity(0.15) : BackgroundColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? BrandColors.primary.opacity(0.5) : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Schedule Step
struct ScheduleStepView: View {
    @Binding var nextRenewalDate: Date
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("When does it renew?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Select the next billing date for this subscription")
                        .font(.system(size: 17))
                        .foregroundColor(TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Date picker card
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(BrandColors.primary)
                    
                    DatePicker(
                        "Next Renewal",
                        selection: $nextRenewalDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorMultiply(BrandColors.primary)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(BackgroundColors.secondary)
                    )
                }
                .padding(.horizontal, 20)
                
                // Quick options
                HStack(spacing: 12) {
                    QuickDateButton(title: "Today", days: 0) { nextRenewalDate = Date() }
                    QuickDateButton(title: "+7 Days", days: 7) { nextRenewalDate = Date().addingTimeInterval(7 * 24 * 60 * 60) }
                    QuickDateButton(title: "+30 Days", days: 30) { nextRenewalDate = Date().addingTimeInterval(30 * 24 * 60 * 60) }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Quick Date Button
struct QuickDateButton: View {
    let title: String
    let days: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(BackgroundColors.tertiary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PremiumSubscriptionsView()
}
