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

    private enum ActiveSheet: Identifiable {
        case tier(CatalogEntry)
        case custom
        case inbox
        case screenshotImport
        case paywall(CatalogEntry?, reopenTier: Bool)

        var id: String {
            switch self {
            case .tier(let entry): return "tier-\(entry.id)"
            case .custom: return "custom"
            case .inbox: return "inbox"
            case .screenshotImport: return "screenshotImport"
            case .paywall(let entry, let reopen): return "paywall-\(entry?.id ?? "none")-\(reopen)"
            }
        }
    }

    @State private var searchText = ""
    @State private var selectedCategory: SubscriptionCategory?
    @State private var activeSheet: ActiveSheet?
    @State private var pendingSheet: ActiveSheet?
    @Environment(\.dynamicTypeSize) private var typeSize

    // Popular service names shown in the featured row (shown before any filter)
    private let popularNames: [String] = [
        "Netflix", "Spotify", "Apple TV+", "Disney+", "YouTube Premium",
        "Hulu", "Amazon Prime", "Apple Music", "Notion", "Duolingo",
        "ChatGPT Plus", "Calm", "Microsoft 365", "Slack", "GitHub Copilot"
    ]

    // MARK: - Computed

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredEntries: [CatalogEntry] {
        var entries = catalogService.catalog
        if let cat = selectedCategory {
            entries = entries.filter { $0.category == cat }
        }
        let query = trimmedSearch
        if !query.isEmpty {
            let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
            entries = entries.filter {
                $0.name.range(of: query, options: options, locale: L10n.locale) != nil
                    || $0.category.localizedName.range(of: query, options: options, locale: L10n.locale) != nil
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
        trimmedSearch.isEmpty && selectedCategory == nil
    }

    /// On-device screenshot import offered in every build (including App Store releases).
    private var screenshotImportRow: some View {
        VStack(spacing: 0) {
            Button(action: { activeSheet = .screenshotImport }) {
                HStack(spacing: 12) {
                    if !typeSize.isAccessibilitySize {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.body)
                            .foregroundStyle(Color.inkText)
                            .frame(width: 36, height: 36)
                            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from screenshots")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        Text("Read Apple Subscriptions or bank lists on this iPhone")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    RowChevron()
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("browserScreenshotImport")
            Hairline()
        }
    }

    /// The quicker way to fill the list, offered before the catalog.
    private var findInEmailRow: some View {
        VStack(spacing: 0) {
            Button(action: { activeSheet = .inbox }) {
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
                    RowChevron()
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
        Button { activeSheet = .custom } label: {
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

    /// The way out, the title, the search field and the categories.
    private var top: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    LeaveButton("Close") { dismiss() }
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
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed above the list at ordinary text sizes. At the accessibility sizes it scrolls away
            // with the list: fixed, it filled the screen above the keyboard and no result could be seen.
            if !typeSize.isAccessibilitySize {
                top
                    // In the page's column on iPad, as the list below is.
                    .frame(maxWidth: ReadableWidth.maxWidth)
                    .frame(maxWidth: .infinity)
            }

            SearchableScroll {
                if typeSize.isAccessibilitySize { top }
                LazyVStack(alignment: .leading, spacing: 0) {
                    if filteredEntries.isEmpty {
                        noResultsView
                    } else {
                        if showFeatured {
                            screenshotImportRow
                            if FeatureFlags.inboxImportEnabled { findInEmailRow }
                            sectionTitle(L10n.string("Popular"))
                            ForEach(popularEntries, id: \.popularRowID) { entry in row(entry) }
                            sectionTitle(L10n.string("All services"))
                        }
                        ForEach(filteredEntries) { entry in row(entry) }
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            // The phone's reading width on iPad, its margins still scrolling the list.
            .readableScroll()
        }
        .inkScreen()
        // A page on iPad: the door to everything that can be added showed four and a half rows in a 578 by
        // 636 box on a 13-inch screen (the rating of 2026-11-22).
        .presentationSizing(.page)
        .navigationBarHidden(true)
        .sheet(item: $activeSheet, onDismiss: {
            if let next = pendingSheet {
                pendingSheet = nil
                activeSheet = next
            }
        }) { sheet in
            switch sheet {
            case .tier(let entry):
                CatalogAddSheet(entry: entry) { frequency, amount, billingDate, trialDate, extras in
                    addSubscription(entry: entry, billingFrequency: frequency, amount: amount,
                                    nextBillingDate: billingDate, trialEndDate: trialDate, extras: extras)
                }
            case .custom:
                AddSubscriptionView()
            case .inbox:
                // "Done" after adding closes the catalog too: its outcome says the new ones are on Home.
                InboxImportView(onFinished: { dismiss() })
            case .screenshotImport:
                ScreenshotImportView(onFinished: { dismiss() })
            case .paywall(let entry, let reopenTier):
                StoreKitUpgradeView(context: PaywallContext(
                    trigger: .unlimitedSubscriptions,
                    serviceName: entry?.name
                )) {
                    if reopenTier, let entry {
                        pendingSheet = .tier(entry)
                    }
                }
            }
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
        SearchField(text: $searchText, identifier: "catalogSearchField")
    }

    /// The categories that hold at least one service, in their usual order. A category with none
    /// is not offered: chosen, it showed "No results for """ under an empty search field.
    nonisolated static func offeredCategories(in catalog: [CatalogEntry]) -> [SubscriptionCategory] {
        let present = Set(catalog.map(\.category))
        return SubscriptionCategory.allCases.filter(present.contains)
    }

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(L10n.string("All"), id: "all", isOn: selectedCategory == nil) { selectedCategory = nil }
                ForEach(Self.offeredCategories(in: catalogService.catalog), id: \.self) { category in
                    pill(category.localizedName, id: category.rawValue, isOn: selectedCategory == category) { selectedCategory = category }
                }
            }
            .padding(.horizontal, Layout.margin)
        }
    }

    private func pill(_ title: String, id: String, isOn: Bool, action: @escaping () -> Void) -> some View {
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
        .accessibilityIdentifier("categoryPill_\(id)")
    }

    private var noResultsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The same words as the list's own search when nothing matches.
            Text(L10n.string("Nothing matches \"\(trimmedSearch)\"."))
                .font(.question(.title3))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Try a different name, or add your own.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            if selectedCategory != nil {
                Button {
                    Feel.selection()
                    selectedCategory = nil
                } label: {
                    Text("Search all categories")
                }
                .buttonStyle(.ink(.quiet))
                .padding(.top, 4)
            }
            Button { activeSheet = .custom } label: { Text("Add your own") }
                .buttonStyle(.ink)
                .padding(.top, 8)
        }
        .padding(.top, 24)
    }

    private func isAlreadyAdded(_ entry: CatalogEntry) -> Bool {
        store.subscriptions.charging.contains { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }
    }

    /// On the free plan's limit, remember the service tapped and open Pro; on unlock, open its plan sheet directly.
    private func open(_ entry: CatalogEntry) {
        if !PaymentManager.shared.hasRoom(in: store.subscriptions) {
            activeSheet = .paywall(entry, reopenTier: true)
        } else {
            activeSheet = .tier(entry)
        }
    }

    private func addSubscription(entry: CatalogEntry, billingFrequency: BillingFrequency, amount: Decimal,
                                 nextBillingDate: Date?, trialEndDate: Date?, extras: CatalogAddSheet.Extras) {
        let subscription = Subscription(
            name: entry.name,
            category: entry.category.rawValue,
            amount: amount,
            currency: extras.currency,
            billingFrequency: billingFrequency,
            nextBillingDate: nextBillingDate,
            notifyBeforeDays: extras.reminderDays,
            trialEndsAt: trialEndDate,
            status: trialEndDate != nil ? .trial : .active,
            notes: extras.notes,
            paymentMethod: extras.paymentMethod
        )

        Task {
            do {
                _ = try await store.addSubscription(subscription)
            } catch SubscriptionStore.SubscriptionLimitError.freeTierLimitReached {
                // Free plan limit reached: keep it for when there's room, and hand off cleanly to Pro
                // without reopening the tier sheet (which would duplicate the waiting entry after unlock).
                let line = TallyLine(name: entry.name, category: entry.category.rawValue, amount: amount,
                                     currency: extras.currency, isConfirmed: true, frequency: billingFrequency,
                                     anchor: nextBillingDate, trialEndsAt: trialEndDate, paymentMethod: extras.paymentMethod,
                                     notes: extras.notes, notifyBeforeDays: extras.reminderDays)
                await TallyImporter.add([line], into: store)
                if activeSheet != nil {
                    pendingSheet = .paywall(entry, reopenTier: false)
                } else {
                    activeSheet = .paywall(entry, reopenTier: false)
                }
            } catch {
                PauselyLogger.error("Catalog add failed: \(String(describing: type(of: error)))", category: "subscriptions")
            }
        }
    }
}
