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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingCustomAdd = false
    @State private var showingPaywall = false
    @State private var showingInbox = false

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
                $0.name.lowercased().contains(query) || $0.category.localizedName.lowercased().contains(query)
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

    /// The quicker way to fill the list, offered before the catalog.
    private var findInEmailRow: some View {
        VStack(spacing: 0) {
            Button(action: { showingInbox = true }) {
                HStack(spacing: 12) {
                    // At accessibility text sizes the words take the row; the pictures step aside.
                    if !typeSize.isAccessibilitySize {
                        Image(systemName: "envelope")
                            .font(.body)
                            .foregroundStyle(Color.inkText)
                            .frame(width: 36, height: 36)
                            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find in Email")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        Text("Pausely reads your receipts on this iPhone")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkTextFaint)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("browserFindInEmail")
            Hairline()
        }
    }

    private var addYourOwnButton: some View {
        Button { showingCustomAdd = true } label: {
            Text("Add your own")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(minHeight: 34)
                .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                .tapArea()
        }
        .accessibilityIdentifier("customAddButton")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Text("Close")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkTextMuted)
                            .tapArea(.leading)
                    }
                    Spacer()
                    if !typeSize.isAccessibilitySize { addYourOwnButton }
                }

                Text("Add subscriptions")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                // Beside "Close" it was cut to "Add yo…" at the largest text sizes; under the title it
                // has the width for all three words.
                if typeSize.isAccessibilitySize { addYourOwnButton }

                searchBar
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)

            categoryPills.padding(.top, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if filteredEntries.isEmpty {
                        noResultsView
                    } else {
                        if showFeatured {
                            if FeatureFlags.inboxImportEnabled { findInEmailRow }
                            sectionTitle(L10n.string("Popular"))
                            ForEach(popularEntries) { entry in row(entry) }
                            sectionTitle(L10n.string("All services"))
                        }
                        ForEach(filteredEntries) { entry in row(entry) }
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .inkScreen()
        .navigationBarHidden(true)
        .sheet(isPresented: $showingTierSheet) {
            if let entry = selectedEntry {
                CatalogAddSheet(entry: entry) { frequency, amount, billingDate, trialDate in
                    addSubscription(entry: entry, billingFrequency: frequency, amount: amount,
                                    nextBillingDate: billingDate, trialEndDate: trialDate)
                }
            }
        }
        .sheet(isPresented: $showingCustomAdd) {
            AddSubscriptionView()
        }
        .sheet(isPresented: $showingInbox) { InboxImportView() }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView()
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
                // At accessibility text sizes the row is words only, one under the other: beside a
                // logo and a mark, names broke in the middle ("Spoti-fy") and "Added" letter by letter.
                HStack(spacing: 12) {
                    if !typeSize.isAccessibilitySize {
                        ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: entry.category.localizedName)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                        if added, typeSize.isAccessibilitySize { addedMark }
                    }
                    Spacer(minLength: 8)
                    if !typeSize.isAccessibilitySize {
                        if added {
                            addedMark
                        } else {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .accessibilityHidden(true)
                        }
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

    private var addedMark: some View {
        Label(L10n.string("Added"), systemImage: "checkmark")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.inkTextMuted)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkTextFaint)
                .accessibilityHidden(true)
            TextField(L10n.string("Search"), text: $searchText)
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
                    pill(category.localizedName, isOn: selectedCategory == category) { selectedCategory = category }
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
                .overlay(Capsule().stroke(isOn ? Color.clear : Color.outline, lineWidth: 1))
                .tapArea()
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
            Button { showingCustomAdd = true } label: { Text("Add your own") }
                .buttonStyle(.ink)
                .padding(.top, 8)
        }
        .padding(.top, 24)
    }

    private func isAlreadyAdded(_ entry: CatalogEntry) -> Bool {
        store.subscriptions.contains { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }
    }

    /// On the free plan's limit, the upgrade screen says so before any plan is picked.
    private func open(_ entry: CatalogEntry) {
        if !PaymentManager.shared.hasRoom(in: store.subscriptions) {
            showingPaywall = true
        } else {
            selectedEntry = entry
            showingTierSheet = true
        }
    }

    private func addSubscription(entry: CatalogEntry, billingFrequency: BillingFrequency, amount: Decimal,
                                 nextBillingDate: Date?, trialEndDate: Date?) {
        let subscription = Subscription(
            name: entry.name,
            category: entry.category.rawValue,
            amount: amount,
            currency: currencyManager.selectedCurrency,
            billingFrequency: billingFrequency,
            nextBillingDate: nextBillingDate,
            trialEndsAt: trialEndDate,
            status: trialEndDate != nil ? .trial : .active
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
                addedIds.insert(entry.name)
                justAdded = entry.name
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if justAdded == entry.name { justAdded = nil }
                }
            }
        }
    }
}
