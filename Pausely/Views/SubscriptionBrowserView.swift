//
//  SubscriptionBrowserView.swift
//  Pausely
//
//  Ultra-premium subscription browser with real brand logos and butter-smooth UX
//

import SwiftUI

struct SubscriptionBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var catalogService = SubscriptionCatalogService.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var searchText = ""
    @State private var selectedCategory: SubscriptionCategory?
    @State private var addedIds: Set<String> = []
    @State private var justAdded: String?
    @State private var selectedEntry: CatalogEntry?
    @State private var showingTierSheet = false
    @State private var showingCustomAdd = false
    @State private var contentAppeared = false

    // Popular service names shown in the featured row (shown before any filter)
    private let popularNames: [String] = [
        "Netflix", "Spotify", "Apple TV+", "Disney+", "YouTube Premium",
        "Hulu", "Amazon Prime", "Apple Music", "Notion", "Duolingo",
        "ChatGPT Plus", "Calm", "Microsoft 365", "Slack", "GitHub Copilot"
    ]

    // MARK: - Computed

    var filteredEntries: [CatalogEntry] {
        var entries = catalogService.catalog
        if let cat = selectedCategory {
            entries = entries.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            entries = entries.filter {
                $0.name.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }
        return entries
    }

    private var popularEntries: [CatalogEntry] {
        popularNames.compactMap { name in
            catalogService.catalog.first { $0.name.lowercased() == name.lowercased() }
        }
    }

    // Show featured row only when browsing all (no search, no category filter)
    private var showFeatured: Bool {
        searchText.isEmpty && selectedCategory == nil
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button {
                        STAnimation.impactLight()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.callout.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .frame(minWidth: 44, minHeight: 44)

                    Spacer()

                    Text("Add Subscriptions")
                        .font(STFont.headlineMedium)
                        .foregroundColor(.white)

                    Spacer()

                    // Custom add button (always accessible)
                    Button {
                        STAnimation.impactLight()
                        showingCustomAdd = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption.weight(.semibold))
                            Text("Custom")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.accentMint)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Color.accentMint.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.accentMint.opacity(0.25), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Search bar
                searchBar
                    .padding(.horizontal, 20)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 8)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.02), value: contentAppeared)

                // Category pills
                categoryPills
                    .padding(.top, 14)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(0.04), value: contentAppeared)

                // Result count
                HStack {
                    if catalogService.catalog.isEmpty {
                        Text("Loading…")
                            .font(STFont.labelMedium)
                            .foregroundColor(.white.opacity(0.3))
                    } else {
                        Text(showFeatured ? "\(catalogService.catalog.count) services" : "\(filteredEntries.count) results")
                            .font(STFont.labelMedium)
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 4)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Featured popular row — only when not searching/filtering
                        if showFeatured && !popularEntries.isEmpty {
                            featuredSection
                                .padding(.bottom, 20)
                                .opacity(contentAppeared ? 1 : 0)
                                .offset(y: contentAppeared ? 0 : 12)
                                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.05), value: contentAppeared)
                        }

                        if searchText.isEmpty {
                            // 2-column grid for browsing
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(filteredEntries) { entry in
                                    CatalogEntryCard(
                                        entry: entry,
                                        isAdded: isAlreadyAdded(entry),
                                        justAdded: justAdded,
                                        currencyManager: currencyManager
                                    ) {
                                        selectedEntry = entry
                                        showingTierSheet = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 16)
                            .animation(.spring(response: 0.52, dampingFraction: 0.82).delay(0.10), value: contentAppeared)
                        } else {
                            // Single-column list for search results — much easier to scan
                            LazyVStack(spacing: 10) {
                                ForEach(filteredEntries) { entry in
                                    SearchResultRow(
                                        entry: entry,
                                        isAdded: isAlreadyAdded(entry),
                                        currencyManager: currencyManager
                                    ) {
                                        selectedEntry = entry
                                        showingTierSheet = true
                                    }
                                }
                                if filteredEntries.isEmpty {
                                    noResultsView
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .onAppear {
                    withAnimation { contentAppeared = true }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingTierSheet) {
            if let entry = selectedEntry {
                TierSelectionSheet(entry: entry) { tier, billingFreq, isOverridden, userPrice, billingDate, trialDate in
                    addSubscription(entry: entry, tier: tier, billingFrequency: billingFreq,
                                    isOverridden: isOverridden, userPrice: userPrice,
                                    nextBillingDate: billingDate, trialEndDate: trialDate)
                }
            }
        }
        .sheet(isPresented: $showingCustomAdd) {
            LuxuryAddSubscriptionView()
        }
        .task {
            await catalogService.loadCatalog()
        }
    }

    // MARK: - Featured Popular Section
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Popular", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentMint)
                    .padding(.leading, 20)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(popularEntries) { entry in
                        PopularServiceChip(
                            entry: entry,
                            isAdded: isAlreadyAdded(entry)
                        ) {
                            selectedEntry = entry
                            showingTierSheet = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.45))
                .font(.callout.weight(.medium))

            TextField("Search 1,000+ services…", text: $searchText)
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .autocapitalization(.none)
                .keyboardType(.default)
                .submitLabel(.search)
                .tint(.accentMint)

            if !searchText.isEmpty {
                Button { withAnimation(STAnimation.snappy) { searchText = "" } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.35))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .animation(STAnimation.snappy, value: searchText.isEmpty)
    }

    // MARK: - Category Pills
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PremiumCategoryPill(title: "All", isSelected: selectedCategory == nil, accentColor: .accentMint) {
                    withAnimation(STAnimation.snappy) { selectedCategory = nil; searchText = "" }
                }
                ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                    PremiumCategoryPill(title: cat.displayName, isSelected: selectedCategory == cat,
                                        accentColor: categoryAccent(for: cat)) {
                        withAnimation(STAnimation.snappy) { selectedCategory = cat; searchText = "" }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - No Results
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.2))
            VStack(spacing: 6) {
                Text("No results for \"\(searchText)\"")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Try a different name, or add it as a custom subscription.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
            Button {
                STAnimation.impactLight()
                showingCustomAdd = true
            } label: {
                Text("Add Custom")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.accentMint.cornerRadius(12))
            }
        }
        .padding(.top, 48)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers
    private func isAlreadyAdded(_ entry: CatalogEntry) -> Bool {
        store.subscriptions.contains { $0.bundleIdentifier == entry.bundleId }
    }

    private func categoryAccent(for category: SubscriptionCategory) -> Color {
        switch category {
        case .entertainment: return .purple
        case .music:         return .pink
        case .productivity:  return .blue
        case .healthFitness: return .green
        case .cloudStorage:  return .cyan
        case .education:     return .orange
        case .utilities:     return .gray
        case .finance:       return .mint
        case .food:          return .yellow
        case .shopping:      return .red
        case .sports:        return .indigo
        case .social:        return .teal
        case .news:          return .brown
        case .phone:         return .blue.opacity(0.7)
        case .insurance:     return .green.opacity(0.7)
        case .gym:           return .orange.opacity(0.8)
        case .automotive:    return .red.opacity(0.7)
        case .home:          return .purple.opacity(0.7)
        case .pet:           return .brown.opacity(0.8)
        case .personalCare:  return .pink.opacity(0.7)
        case .aiTools:       return .purple
        case .gaming:        return .indigo
        case .developerTools:return .blue.opacity(0.8)
        case .creator:       return .orange.opacity(0.9)
        case .travel:        return .cyan.opacity(0.8)
        case .dating:        return .red.opacity(0.8)
        case .kids:          return .yellow.opacity(0.8)
        case .security:      return .green.opacity(0.9)
        case .other:         return .secondary
        }
    }

    private func addSubscription(entry: CatalogEntry, tier: PricingTier, billingFrequency: BillingFrequency,
                                  isOverridden: Bool, userPrice: Decimal?, nextBillingDate: Date, trialEndDate: Date?) {
        // Resolve region from user's selected currency so stored price matches displayed price
        let userRegion: Region = {
            switch currencyManager.selectedCurrency {
            case "CAD": return .ca
            case "GBP": return .uk
            case "EUR": return .eu
            case "AUD": return .au
            default:    return .us
            }
        }()
        let tierPricing = entry.pricing(for: tier, in: userRegion)
        let storedCurrency = tierPricing?.currencyCode ?? currencyManager.selectedCurrency

        let price: Double
        if isOverridden, let override = userPrice {
            price = Double(truncating: override as NSDecimalNumber)
        } else if billingFrequency == .yearly, let annual = tierPricing?.annualPriceUSD, annual > 0 {
            price = annual
        } else {
            price = tierPricing?.monthlyPriceUSD ?? entry.defaultIndividualPricing?.monthlyPriceUSD ?? 0
        }

        let subscription = Subscription(
            name: entry.name,
            bundleIdentifier: entry.bundleId,
            category: entry.category.rawValue,
            amount: Decimal(price),
            currency: isOverridden ? currencyManager.selectedCurrency : storedCurrency,
            billingFrequency: billingFrequency,
            nextBillingDate: nextBillingDate,
            trialEndsAt: trialEndDate,
            status: trialEndDate != nil ? .trial : .active,
            isDetected: true,
            selectedTier: tier,
            userPriceUSD: userPrice,
            isPriceOverridden: isOverridden
        )

        Task {
            _ = try? await store.addSubscription(subscription)
            await MainActor.run {
                addedIds.insert(entry.bundleId)
                justAdded = entry.bundleId
                NotificationCenter.default.post(name: Notification.Name("subscriptionAdded"), object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if justAdded == entry.bundleId { justAdded = nil }
                }
            }
        }
    }
}

// MARK: - Popular Service Chip (featured horizontal row)
struct PopularServiceChip: View {
    let entry: CatalogEntry
    let isAdded: Bool
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !isAdded else { return }
            STAnimation.impactLight()
            onTap()
        }) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 52)
                    if isAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.accentMint)
                            .background(Circle().fill(Color.obsidianBlack).padding(1))
                    }
                }

                Text(entry.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isAdded ? Color.white.opacity(0.35) : Color.white.opacity(0.8))
                    .lineLimit(1)
                    .frame(width: 66)
            }
            .frame(width: 72)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isAdded ? 0.03 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isAdded ? Color.accentMint.opacity(0.3) : Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.93 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isAdded)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false } }
        )
    }
}

// MARK: - Search Result Row (single-column list mode)
struct SearchResultRow: View {
    let entry: CatalogEntry
    let isAdded: Bool
    let currencyManager: CurrencyManager
    let onTap: () -> Void
    @State private var isPressed = false

    private var defaultPricing: TierPricing? {
        entry.supportedTiers.first { $0.tier == .individual }
            ?? entry.defaultIndividualPricing
            ?? entry.supportedTiers.first
    }

    var body: some View {
        Button(action: {
            guard !isAdded else { return }
            STAnimation.impactMedium()
            onTap()
        }) {
            HStack(spacing: 14) {
                ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                    Text(entry.category.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if let pricing = defaultPricing {
                        let needsConversion = currencyManager.selectedCurrency != "USD"
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD, sourceCurrency: pricing.currencyCode))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Text("/mo")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.white.opacity(0.5))
                            if needsConversion {
                                Text("*")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(Color.obsidianTextTertiary)
                            }
                        }
                    }
                    if entry.availableTiers.count > 1 {
                        Text("\(entry.availableTiers.count) plans")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentMint)
                        .font(.title3)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isAdded ? Color.accentMint.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isAdded)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(PremiumAnimations.fast) { isPressed = true } }
                .onEnded   { _ in withAnimation(STAnimation.snappy)    { isPressed = false } }
        )
    }
}

// MARK: - Premium Category Pill
struct PremiumCategoryPill: View {
    let title: String
    let isSelected: Bool
    var accentColor: Color = .accentMint
    let action: () -> Void

    var body: some View {
        Button(action: {
            STAnimation.impactLight()
            action()
        }) {
            Text(title)
                .font(.footnote.weight(isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor.opacity(0.75)],
                                                            startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.08)))
                }
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.10), lineWidth: 1))
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Catalog Entry Card (2-col grid)
struct CatalogEntryCard: View {
    let entry: CatalogEntry
    let isAdded: Bool
    let justAdded: String?
    let currencyManager: CurrencyManager
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var showCheckmark = false

    private var defaultPricing: TierPricing? {
        entry.supportedTiers.first { $0.tier == .individual && $0.currencyCode == currencyManager.selectedCurrency }
            ?? entry.defaultIndividualPricing
            ?? entry.supportedTiers.first
    }

    var body: some View {
        Button(action: {
            guard !isAdded else { return }
            STAnimation.impactMedium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showCheckmark = true }
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: logo + added indicator
                HStack(alignment: .top) {
                    ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 46)
                    Spacer()
                    if isAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.accentMint)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Name + category
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(entry.category.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.45))
                }

                // Price + plan count
                VStack(alignment: .leading, spacing: 5) {
                    if let pricing = defaultPricing {
                        let needsConversion = currencyManager.selectedCurrency != "USD"
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD, sourceCurrency: pricing.currencyCode))
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                            Text("/mo")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.white.opacity(0.4))
                            if needsConversion {
                                Text("*")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(Color.obsidianTextTertiary)
                            }
                        }
                    }

                    // Clean plan count — never truncates
                    planCountBadge
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            .scaleEffect(isPressed ? 0.965 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isAdded)
        .onAppear {
            if justAdded == entry.bundleId { showCheckmark = true }
        }
        .onChange(of: justAdded) { oldVal, newVal in
            if newVal == nil && oldVal == entry.bundleId {
                withAnimation(PremiumAnimations.smooth) { showCheckmark = false }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(PremiumAnimations.fast) { isPressed = true } }
                .onEnded   { _ in withAnimation(STAnimation.snappy)    { isPressed = false } }
        )
    }

    @ViewBuilder
    private var planCountBadge: some View {
        let count = entry.availableTiers.count
        if count == 1 {
            Text(entry.availableTiers[0].displayName)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        } else if count > 1 {
            Text("\(count) plans")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(isAdded ? 0.2 : 0.10), .white.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Custom Subscription Card (no longer in grid — replaced by toolbar button)
struct CustomSubscriptionCard: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            STAnimation.impactLight()
            action()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color.accentMint.opacity(0.25), Color.accentMint.opacity(0.15)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 80)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentMint)
                }
                VStack(spacing: 4) {
                    Text("Custom").font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(.white)
                    Text("Add your own").font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.accentMint.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
}

#Preview {
    NavigationStack { SubscriptionBrowserView() }
}
