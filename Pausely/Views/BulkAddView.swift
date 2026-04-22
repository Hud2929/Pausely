//
//  BulkAddView.swift
//  Pausely
//
//  Bulk Add subscriptions from the catalog
//

import SwiftUI

/// BulkAddView allows users to select multiple subscriptions from the catalog
/// and add them all at once
struct BulkAddView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var catalogService = SubscriptionCatalogService.shared
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared

    @State private var searchText = ""
    @State private var selectedCategory: SubscriptionCategory?
    @State private var selectedSubscriptions: Set<UUID> = []
    @State private var isAdding = false
    @State private var showingResults = false
    @State private var addedCount = 0
    @State private var failedCount = 0
    @State private var showingCSVImport = false
    @State private var csvText = ""

    private var filteredSubscriptions: [CatalogEntry] {
        var subs = catalogService.catalog

        if let category = selectedCategory {
            subs = subs.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            subs = subs.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query)
            }
        }

        return subs
    }

    private var groupedSubscriptions: [(category: SubscriptionCategory, subscriptions: [CatalogEntry])] {
        let grouped = Dictionary(grouping: filteredSubscriptions) { $0.category }
        return SubscriptionCategory.allCases
            .filter { grouped[$0] != nil }
            .map { ($0, grouped[$0]!) }
    }

    private var selectedCount: Int {
        selectedSubscriptions.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()

                if showingResults {
                    resultsView
                } else {
                    contentView
                }
            }
            .navigationTitle("Bulk Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showingResults {
                        Button(selectedCount > 0 ? "Add (\(selectedCount))" : "Add") {
                            Task { await addSelectedSubscriptions() }
                        }
                        .foregroundColor(selectedCount > 0 ? Color.luxuryGold : .white.opacity(0.5))
                        .disabled(selectedCount == 0 || isAdding)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search subscriptions")
            .sheet(isPresented: $showingCSVImport) {
                BulkAddCSVImportSheet(csvText: $csvText) { text in
                    Task { await importFromCSV(text) }
                }
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            // Category filter pills
            categoryFilterBar

            // Subscription list
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedSubscriptions, id: \.category) { category, subscriptions in
                        Section {
                            ForEach(subscriptions) { subscription in
                                SubscriptionCatalogRow(
                                    subscription: subscription,
                                    isSelected: selectedSubscriptions.contains(subscription.id),
                                    onToggle: { toggleSelection(subscription) }
                                )
                            }
                        } header: {
                            sectionHeader(for: category)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            // Bottom bar with CSV import option
            bottomBar
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BulkAddFilterPill(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                    BulkAddFilterPill(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.backgroundPrimary)
    }

    private func sectionHeader(for category: SubscriptionCategory) -> some View {
        HStack {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(Color.luxuryPurple)

            Text(category.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Text("\(filteredSubscriptions.filter { $0.category == category }.count)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.backgroundPrimary)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if selectedCount > 0 {
                HStack {
                    Text("\(selectedCount) subscription\(selectedCount == 1 ? "" : "s") selected")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Text("Tap to deselect all")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .onTapGesture {
                            selectedSubscriptions.removeAll()
                        }
                }
                .padding(.horizontal, 16)
            }

            Button(action: { showingCSVImport = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))

                    Text("Import from CSV")
                        .font(.system(size: 14, weight: .medium))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(16)
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color.backgroundPrimary)
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Added Successfully!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 8) {
                Text("\(addedCount) subscription\(addedCount == 1 ? "" : "s") added")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))

                if failedCount > 0 {
                    Text("\(failedCount) failed (may already exist)")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.luxuryGold)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func toggleSelection(_ subscription: CatalogEntry) {
        if selectedSubscriptions.contains(subscription.id) {
            selectedSubscriptions.remove(subscription.id)
        } else {
            selectedSubscriptions.insert(subscription.id)
        }
    }

    private func addSelectedSubscriptions() async {
        isAdding = true

        let selectedEntries = filteredSubscriptions.filter { selectedSubscriptions.contains($0.id) }
        let newSubscriptions = selectedEntries.map { entry in
            Subscription(
                name: entry.name,
                bundleIdentifier: entry.bundleId,
                description: entry.description,
                category: entry.category.rawValue,
                amount: Decimal(entry.defaultPrice),
                currency: "USD",
                billingFrequency: .monthly,
                nextBillingDate: calculateNextBillingDate(frequency: .monthly),
                status: .active,
                isDetected: false,
                canPause: entry.canPause
            )
        }

        let result = await subscriptionStore.batchAddSubscriptions(newSubscriptions)
        addedCount = result.added
        failedCount = result.failed

        isAdding = false
        showingResults = true
    }

    private func importFromCSV(_ csvData: String) async {
        isAdding = true
        showingCSVImport = false

        let lines = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var imported: [Subscription] = []
        for line in lines {
            let columns = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard columns.count >= 3 else { continue }
            guard !columns.isEmpty else { continue }

            let name = columns[0]
            guard !name.isEmpty, !name.lowercased().contains("name") else { continue }

            let amountString = columns[1].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: " ", with: "")
            guard let amount = Decimal(string: amountString) else { continue }

            let frequencyString = columns.count > 2 ? columns[2].lowercased() : "monthly"
            let frequency = parseBillingFrequency(frequencyString)

            let subscription = Subscription(
                name: name,
                category: "Other",
                amount: amount,
                currency: "USD",
                billingFrequency: frequency,
                nextBillingDate: calculateNextBillingDate(frequency: frequency),
                status: .active,
                isDetected: false,
                canPause: true
            )
            imported.append(subscription)
        }

        let result = await subscriptionStore.batchAddSubscriptions(imported)
        addedCount = result.added
        failedCount = result.failed

        isAdding = false
        showingResults = true
    }

    private func parseBillingFrequency(_ string: String) -> BillingFrequency {
        switch string.lowercased() {
        case "weekly", "week": return .weekly
        case "biweekly", "bi-weekly", "every 2 weeks": return .biweekly
        case "monthly", "month": return .monthly
        case "quarterly", "quarter", "every 3 months": return .quarterly
        case "semiannual", "semi-annual", "every 6 months": return .semiannual
        case "yearly", "annual", "year": return .yearly
        default: return .monthly
        }
    }

    private func calculateNextBillingDate(frequency: BillingFrequency) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: Date()) ?? Date()
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        case .semiannual:
            return calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        }
    }
}

// MARK: - Subscription Catalog Row
struct SubscriptionCatalogRow: View {
    let subscription: CatalogEntry
    let isSelected: Bool
    let onToggle: () -> Void

    private var defaultPrice: Double {
        subscription.defaultIndividualPricing?.monthlyPriceUSD ?? 0
    }

    private var frequency: BillingFrequency {
        .monthly // Default to monthly if not specified
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.luxuryGold : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.luxuryGold)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.luxuryPurple.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: subscription.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(Color.luxuryPurple)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subscription.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", defaultPrice))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(frequency.shortDisplay)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.luxuryGold.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bulk Add Filter Pill
struct BulkAddFilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.luxuryGold : Color.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Filter by \(title)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

// MARK: - Bulk Add CSV Import Sheet
struct BulkAddCSVImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var csvText: String
    let onImport: (String) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Paste your CSV data")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Format: name, cost, frequency (e.g., Netflix, 15.99, monthly)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)

                    TextEditor(text: $csvText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .frame(maxHeight: 300)

                    Spacer()

                    Button(action: {
                        onImport(csvText)
                    }) {
                        Text("Import \(csvText.isEmpty ? 0 : csvText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) Items")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(csvText.isEmpty ? Color.gray : Color.luxuryTeal)
                            .cornerRadius(16)
                    }
                    .disabled(csvText.isEmpty)
                }
                .padding(20)
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}
