import SwiftUI

// MARK: - Catalog Category Compare View
struct CatalogCategoryCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var catalogService = SubscriptionCatalogService.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedCategory: SubscriptionCategory = .aiTools
    @State private var selectedEntries: [CatalogEntry] = []
    @State private var showingDetail: CatalogEntry?

    var categoryEntries: [CatalogEntry] {
        catalogService.catalog
            .filter { $0.category == selectedCategory }
            .sorted { entry1, entry2 in
                let price1 = entry1.defaultIndividualPricing?.monthlyPriceUSD ?? Double.infinity
                let price2 = entry2.defaultIndividualPricing?.monthlyPriceUSD ?? Double.infinity
                return price1 < price2
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidianBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Category picker
                        categoryPicker
                            .padding(.horizontal, 20)

                        if categoryEntries.isEmpty {
                            emptyCategoryState
                        } else {
                            // Comparison table
                            if selectedEntries.count >= 2 {
                                comparisonTable
                                    .padding(.horizontal, 20)
                            }

                            // Entry cards
                            entriesList
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Compare Catalog")
            .navigationBarTitleDisplayMode(.inline
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                if selectedEntries.count >= 2 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            withAnimation {
                                selectedEntries.removeAll()
                            }
                        }
                        .foregroundStyle(Color.luxuryTeal)
                    }
                }
            }
            .sheet(item: $showingDetail) { entry in
                CatalogEntryDetailSheet(entry: entry)
            }
            .task {
                await catalogService.loadCatalog()
            }
        }
    }

    // MARK: - Category Picker
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SubscriptionCategory.allCases.filter { hasEntries(in: $0) }, id: \.self) { cat in
                    CategoryComparePill(
                        title: cat.displayName,
                        isSelected: selectedCategory == cat,
                        accentColor: categoryColor(for: cat)
                    ) {
                        withAnimation(.snappy) {
                            selectedCategory = cat
                            selectedEntries.removeAll()
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Comparison Table
    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Side-by-Side Comparison")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            // Header row
            HStack(spacing: 12) {
                Text("Feature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)

                ForEach(selectedEntries) { entry in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(categoryColor(for: entry.category).opacity(0.2))
                                .frame(width: 44, height: 44)

                            Text(String(entry.name.prefix(1)))
                                .font(.callout.weight(.bold))
                                .foregroundStyle(categoryColor(for: entry.category))
                        }

                        Text(entry.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Price row
            compareRow(label: "Monthly") {
                ForEach(selectedEntries) { entry in
                    if let pricing = entry.defaultIndividualPricing {
                        Text(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD, sourceCurrency: pricing.currencyCode) + "/mo")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    } else {
                        Text("—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Annual row
            compareRow(label: "Annual") {
                ForEach(selectedEntries) { entry in
                    if let pricing = entry.defaultIndividualPricing, pricing.annualPriceUSD ?? 0 > 0 {
                        Text(currencyManager.formatCatalogPrice(pricing.annualPriceUSD!, sourceCurrency: pricing.currencyCode) + "/yr")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    } else {
                        Text("—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Tiers row
            compareRow(label: "Plans") {
                ForEach(selectedEntries) { entry in
                    Text("\(entry.availableTiers.count) tiers")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Best value badge
            if let bestValue = selectedEntries.min(by: {
                ($0.defaultIndividualPricing?.monthlyPriceUSD ?? Double.infinity) <
                ($1.defaultIndividualPricing?.monthlyPriceUSD ?? Double.infinity)
            }) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)

                    Text("Best Value: \(bestValue.name)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func compareRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }

    // MARK: - Entries List
    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(categoryEntries.count) services in \(selectedCategory.displayName)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(categoryEntries) { entry in
                    CatalogCompareRow(
                        entry: entry,
                        isSelected: selectedEntries.contains(where: { $0.id == entry.id }),
                        accentColor: categoryColor(for: entry.category)
                    ) {
                        toggleSelection(entry)
                    } onDetail: {
                        showingDetail = entry
                    }
                }
            }
        }
    }

    private func toggleSelection(_ entry: CatalogEntry) {
        withAnimation(.snappy) {
            if let index = selectedEntries.firstIndex(where: { $0.id == entry.id }) {
                selectedEntries.remove(at: index)
            } else if selectedEntries.count < 3 {
                selectedEntries.append(entry)
            }
        }
    }

    // MARK: - Empty State
    private var emptyCategoryState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No services found")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("This category doesn't have any catalog entries yet.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers
    private func hasEntries(in category: SubscriptionCategory) -> Bool {
        catalogService.catalog.contains { $0.category == category }
    }

    private func categoryColor(for category: SubscriptionCategory) -> Color {
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
}

// MARK: - Catalog Compare Row
struct CatalogCompareRow: View {
    let entry: CatalogEntry
    let isSelected: Bool
    let accentColor: Color
    let onToggle: () -> Void
    let onDetail: () -> Void

    @ObservedObject private var currencyManager = CurrencyManager.shared

    private var defaultPricing: TierPricing? {
        entry.defaultIndividualPricing
    }

    var body: some View {
        HStack(spacing: 14) {
            // Selection circle
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? accentColor : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: entry.iconName)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(accentColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let pricing = defaultPricing {
                    Text(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD, sourceCurrency: pricing.currencyCode) + "/mo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Detail button
            Button(action: onDetail) {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? accentColor.opacity(0.1) : Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? accentColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Category Compare Pill
struct CategoryComparePill: View {
    let title: String
    let isSelected: Bool
    var accentColor: Color = .luxuryPurple
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
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

// MARK: - Catalog Entry Detail Sheet
struct CatalogEntryDetailSheet: View {
    let entry: CatalogEntry
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(categoryColor(for: entry.category).opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: entry.iconName)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(categoryColor(for: entry.category))
                        }

                        Text(entry.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text(entry.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)

                    // Pricing
                    if !entry.supportedTiers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pricing")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)

                            VStack(spacing: 8) {
                                ForEach(entry.supportedTiers.prefix(3)) { tierPricing in
                                    TierPricingRow(
                                        tier: tierPricing.tier,
                                        pricing: tierPricing,
                                        currencyManager: currencyManager
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Tiers
                    if entry.availableTiers.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Plans")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)

                            FlowLayout(spacing: 8) {
                                ForEach(entry.availableTiers) { tier in
                                    Text(tier.displayName)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func categoryColor(for category: SubscriptionCategory) -> Color {
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
}

// MARK: - Tier Pricing Row
struct TierPricingRow: View {
    let tier: PricingTier
    let pricing: TierPricing
    let currencyManager: CurrencyManager

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: tier.icon)
                        .font(.caption)
                        .foregroundStyle(Color.luxuryTeal)

                    Text(tier.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text("\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD, sourceCurrency: pricing.currencyCode))/mo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let annual = pricing.annualPriceUSD, annual > 0 {
                Text("\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(annual, sourceCurrency: pricing.currencyCode))/yr")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
