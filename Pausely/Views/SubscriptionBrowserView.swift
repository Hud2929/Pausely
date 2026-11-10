//
//  SubscriptionBrowserView.swift
//  Pausely
//
//  The catalog: search, pick a service, then say what you pay for it.
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
    @State private var showingPaywall = false

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
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Text("Close")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(minHeight: Layout.tapTarget)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                    Button { showingCustomAdd = true } label: {
                        Text("Custom")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 34)
                            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                            .frame(minHeight: Layout.tapTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("customAddButton")
                }

                Text("Add Subscriptions")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                searchBar
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)

            categoryPills.padding(.top, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if catalogService.catalog.isEmpty {
                        Text("Loading…")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .padding(.vertical, 16)
                    } else if filteredEntries.isEmpty {
                        noResultsView
                    } else {
                        if showFeatured {
                            sectionTitle(L10n.string("Popular"))
                            ForEach(popularEntries) { entry in row(entry) }
                            sectionTitle(L10n.string("\(catalogService.catalog.count) services"))
                        }
                        ForEach(filteredEntries) { entry in row(entry) }
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.ink.ignoresSafeArea())
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
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .task {
            await catalogService.loadCatalog()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.inkTextMuted)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// A service: its logo, its name, what kind of thing it is. No price here: the plan sheet
    /// asks what the person really pays.
    private func row(_ entry: CatalogEntry) -> some View {
        let added = isAlreadyAdded(entry)
        return VStack(spacing: 0) {
            Button { open(entry) } label: {
                HStack(spacing: 12) {
                    ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        Text(entry.category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                    }
                    Spacer(minLength: 8)
                    if added {
                        Label(L10n.string("Added"), systemImage: "checkmark")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.inkTextMuted)
                    } else {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            Hairline()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkTextFaint)
                .accessibilityHidden(true)
            TextField(L10n.string("Search \(catalogService.catalog.count) services"), text: $searchText)
                .font(.body)
                .foregroundStyle(Color.inkText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .tint(Color.inkText)
                .accessibilityIdentifier("catalogSearchField")
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.inkTextFaint)
                }
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
    }

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(L10n.string("All"), isOn: selectedCategory == nil) { selectedCategory = nil }
                ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                    pill(category.displayName, isOn: selectedCategory == category) { selectedCategory = category }
                }
            }
            .padding(.horizontal, Layout.margin)
        }
    }

    private func pill(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? Color.paperInk : Color.inkText)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isOn ? Color.paper : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(isOn ? 0 : 0.18), lineWidth: 1))
                .frame(minHeight: Layout.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var noResultsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No results for \"\(searchText)\"")
                .font(.question(.title3))
                .foregroundStyle(Color.inkText)
            Text("Try a different name, or add it as a custom subscription.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button { showingCustomAdd = true } label: { Text("Add Custom") }
                .buttonStyle(.ink)
                .padding(.top, 8)
        }
        .padding(.top, 24)
    }

    private func isAlreadyAdded(_ entry: CatalogEntry) -> Bool {
        store.subscriptions.contains { $0.bundleIdentifier == entry.bundleId }
    }

    /// On the free plan's limit, the upgrade screen says so before any plan is picked.
    private func open(_ entry: CatalogEntry) {
        if PaymentManager.shared.hasReachedSubscriptionLimit(currentCount: store.subscriptions.count) {
            showingPaywall = true
        } else {
            selectedEntry = entry
            showingTierSheet = true
        }
    }

    private func addSubscription(entry: CatalogEntry, tier: PricingTier, billingFrequency: BillingFrequency,
                                  isOverridden: Bool, userPrice: Decimal?, nextBillingDate: Date, trialEndDate: Date?) {
        // The same price the tier sheet showed, in the currency it showed it in.
        let tierPricing = entry.pricing(for: tier, payingIn: currencyManager.selectedCurrency)
            ?? entry.defaultIndividualPricing
        let storedCurrency = tierPricing?.currencyCode ?? "USD"

        let price: Double
        if isOverridden, let override = userPrice {
            price = Double(truncating: override as NSDecimalNumber)
        } else if billingFrequency == .yearly, let annual = tierPricing?.annualPriceUSD, annual > 0 {
            price = annual
        } else {
            price = tierPricing?.monthlyPriceUSD ?? 0
        }

        let subscription = Subscription(
            name: entry.name,
            bundleIdentifier: entry.bundleId,
            category: entry.category.rawValue,
            amount: MoneyFormat.decimal(price),
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
            do {
                _ = try await store.addSubscription(subscription)
            } catch {
                // Only a refusal throws (the free plan's limit): never show it as added.
                try? await Task.sleep(nanoseconds: 400_000_000)   // let the plan sheet close first
                showingPaywall = true
                return
            }
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
