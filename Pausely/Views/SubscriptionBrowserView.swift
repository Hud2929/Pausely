//
//  SubscriptionBrowserView.swift
//  Pausely
//
//  Ultra-premium subscription browser with glass morphism and animations
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

    var body: some View {
        ZStack {
            // Premium animated gradient background
            PremiumBackground()

            VStack(spacing: 0) {
                // Premium glass search bar
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Premium category pills
                categoryPills
                    .padding(.top, 16)

                // Count with premium styling
                HStack {
                    Text("\(filteredEntries.count) services")
                        .font(STFont.labelMedium)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Premium grid with animations
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        if selectedCategory == .other || filteredEntries.isEmpty {
                            CustomSubscriptionCard {
                                showingCustomAdd = true
                            }
                        }

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
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Add Subscriptions")
                    .font(STFont.headlineMedium)
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    STAnimation.impactLight()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $showingTierSheet) {
            if let entry = selectedEntry {
                TierSelectionSheet(entry: entry) { tier, billingFreq, isOverridden, userPrice, billingDate in
                    addSubscription(entry: entry, tier: tier, billingFrequency: billingFreq, isOverridden: isOverridden, userPrice: userPrice, nextBillingDate: billingDate)
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

    // MARK: - Premium Glass Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.callout.weight(.medium))

            TextField("Search services...", text: $searchText)
                .font(.body.weight(.medium))
                .foregroundColor(.white)
                .autocapitalization(.none)
                .keyboardType(.default)
                .submitLabel(.search)
                .tint(.luxuryPurple)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Premium Category Pills
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PremiumCategoryPill(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    accentColor: .luxuryPurple
                ) {
                    withAnimation(STAnimation.snappy) { selectedCategory = nil }
                }

                ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                    PremiumCategoryPill(
                        title: cat.rawValue,
                        isSelected: selectedCategory == cat,
                        accentColor: categoryAccent(for: cat)
                    ) {
                        withAnimation(STAnimation.snappy) {
                            selectedCategory = cat
                            searchText = ""
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func categoryAccent(for category: SubscriptionCategory) -> Color {
        switch category {
        case .entertainment: return .purple
        case .music: return .pink
        case .productivity: return .blue
        case .healthFitness: return .green
        case .cloudStorage: return .cyan
        case .education: return .orange
        case .utilities: return .gray
        case .finance: return .mint
        case .food: return .yellow
        case .shopping: return .red
        case .sports: return .indigo
        case .social: return .teal
        case .news: return .brown
        case .phone: return .blue.opacity(0.7)
        case .insurance: return .green.opacity(0.7)
        case .gym: return .orange.opacity(0.8)
        case .automotive: return .red.opacity(0.7)
        case .home: return .purple.opacity(0.7)
        case .pet: return .brown.opacity(0.8)
        case .personalCare: return .pink.opacity(0.7)
        case .aiTools: return .purple
        case .gaming: return .indigo
        case .developerTools: return .blue.opacity(0.8)
        case .creator: return .orange.opacity(0.9)
        case .travel: return .cyan.opacity(0.8)
        case .dating: return .red.opacity(0.8)
        case .kids: return .yellow.opacity(0.8)
        case .security: return .green.opacity(0.9)
        case .other: return .secondary
        }
    }

    // MARK: - Helpers
    private func isAlreadyAdded(_ entry: CatalogEntry) -> Bool {
        store.subscriptions.contains { $0.bundleIdentifier == entry.bundleId }
    }

    private func addSubscription(entry: CatalogEntry, tier: PricingTier, billingFrequency: BillingFrequency, isOverridden: Bool, userPrice: Decimal?, nextBillingDate: Date) {
        let tierPricing = entry.pricing(for: tier)

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
            billingFrequency: billingFrequency,
            nextBillingDate: nextBillingDate,
            status: .active,
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

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if justAdded == entry.bundleId {
                        justAdded = nil
                    }
                }
            }
        }
    }
}

// MARK: - Premium Category Pill
struct PremiumCategoryPill: View {
    let title: String
    let isSelected: Bool
    var accentColor: Color = .luxuryPurple
    let action: () -> Void

    var body: some View {
        Button(action: {
            STAnimation.impactLight()
            action()
        }) {
            Text(title)
                .font(.footnote.weight(isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected ?
                            AnyShapeStyle(LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )) :
                            AnyShapeStyle(Color.white.opacity(0.08))
                        )
                }
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Catalog Entry Card
struct CatalogEntryCard: View {
    let entry: CatalogEntry
    let isAdded: Bool
    let justAdded: String?
    let currencyManager: CurrencyManager
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var showCheckmark = false

    private var defaultPricing: TierPricing? {
        entry.defaultIndividualPricing ?? entry.supportedTiers.first
    }

    private var iconColor: Color {
        switch entry.category {
        case .entertainment: return .purple
        case .music: return .pink
        case .productivity: return .blue
        case .healthFitness: return .green
        case .cloudStorage: return .cyan
        case .education: return .orange
        case .utilities: return .gray
        case .finance: return .mint
        case .food: return .yellow
        case .shopping: return .red
        case .sports: return .indigo
        case .social: return .teal
        case .news: return .brown
        case .phone: return .blue.opacity(0.7)
        case .insurance: return .green.opacity(0.7)
        case .gym: return .orange.opacity(0.8)
        case .automotive: return .red.opacity(0.7)
        case .home: return .purple.opacity(0.7)
        case .pet: return .brown.opacity(0.8)
        case .personalCare: return .pink.opacity(0.7)
        case .aiTools: return .purple
        case .gaming: return .indigo
        case .developerTools: return .blue.opacity(0.8)
        case .creator: return .orange.opacity(0.9)
        case .travel: return .cyan.opacity(0.8)
        case .dating: return .red.opacity(0.8)
        case .kids: return .yellow.opacity(0.8)
        case .security: return .green.opacity(0.9)
        case .other: return .secondary
        }
    }

    // MARK: - Card Content
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            nameAndCategory
            priceSection
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
        .scaleEffect(isPressed ? 0.97 : 1.0)
    }

    private var headerRow: some View {
        HStack {
            iconWithGlow
            Spacer()
            checkmarkView
        }
    }

    private var iconWithGlow: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [iconColor.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)

            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(iconColor.opacity(0.35), lineWidth: 1)
                )
                .frame(width: 48, height: 48)

            Image(systemName: entry.iconName)
                .font(.headline.weight(.bold))
                .foregroundColor(iconColor)
        }
    }

    @ViewBuilder
    private var checkmarkView: some View {
        if isAdded {
            Group {
                if showCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.luxuryPurple, .luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .luxuryPurple.opacity(0.6), radius: 10)
                } else {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.luxuryPurple))
                }
            }
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
    }

    private var nameAndCategory: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.name)
                .font(.callout.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(entry.category.rawValue)
                .font(.caption2.weight(.medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pricing = defaultPricing {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD))")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("/mo")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                if let annual = pricing.annualPriceUSD, annual > 0 {
                    Text("or \(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(annual))/yr")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            tierBadges
        }
    }

    private var tierBadges: some View {
        Group {
            if entry.availableTiers.count > 1 {
                HStack(spacing: 5) {
                    ForEach(Array(entry.availableTiers.prefix(3).enumerated()), id: \.element) { _, tier in
                        Text(tier.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .allowsTightening(false)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                            )
                    }
                    if entry.availableTiers.count > 3 {
                        Text("+\(entry.availableTiers.count - 3)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(isAdded ? 0.25 : 0.12),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    var body: some View {
        Button(action: {
            if !isAdded {
                STAnimation.impactMedium()
                withAnimation(STAnimation.spring) {
                    showCheckmark = true
                }
                onTap()
            }
        }) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isAdded)
        .accessibilityHint(isAdded ? "This subscription has already been added" : "")
        .onAppear {
            if justAdded == entry.bundleId {
                showCheckmark = true
            }
        }
        .onChange(of: justAdded) { oldVal, newVal in
            if newVal == nil && oldVal == entry.bundleId {
                withAnimation(PremiumAnimations.smooth) {
                    showCheckmark = false
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(PremiumAnimations.fast) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(STAnimation.snappy) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Custom Subscription Card
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
                        .fill(
                            LinearGradient(
                                colors: [Color.luxuryTeal.opacity(0.3), Color.luxuryPurple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.luxuryTeal)
                }

                VStack(spacing: 4) {
                    Text("Custom")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Add your own")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.luxuryTeal.opacity(0.4), lineWidth: 1.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.luxuryTeal.opacity(0.5), Color.luxuryPurple.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}

#Preview {
    NavigationStack {
        SubscriptionBrowserView()
    }
}
