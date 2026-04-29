//
//  SubscriptionCompareView.swift
//  Pausely
//
//  Side-by-side subscription comparison for best value
//

import SwiftUI

// MARK: - Subscription Compare View
struct SubscriptionCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedSubscriptions: [Subscription] = []
    @State private var showingSubscriptionPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidianBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if selectedSubscriptions.isEmpty {
                            emptyState
                        } else {
                            // Comparison grid
                            comparisonSection

                            // Recommendations
                            recommendationSection
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedSubscriptions.count < 3 {
                        Button {
                            showingSubscriptionPicker = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(Color.luxuryTeal)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSubscriptionPicker) {
                SubscriptionPickerSheet(
                    subscriptions: store.subscriptions.filter { sub in
                        !selectedSubscriptions.contains(where: { $0.id == sub.id })
                    },
                    onSelect: { sub in
                        selectedSubscriptions.append(sub)
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.luxuryTeal.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.luxuryTeal)
            }

            VStack(spacing: 8) {
                Text("Compare Subscriptions")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Select subscriptions to compare side-by-side on cost, usage, and value.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingSubscriptionPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Subscription to Compare")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.luxuryTeal, Color.luxuryPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 80)
    }

    // MARK: - Comparison Section

    private var comparisonSection: some View {
        VStack(spacing: 16) {
            // Header row with subscription names
            HStack(spacing: 12) {
                Text("Metric")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(selectedSubscriptions) { sub in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(categoryColor(for: sub).opacity(0.2))
                                .frame(width: 44, height: 44)

                            Text(String(sub.name.prefix(1)))
                                .font(.system(.callout, design: .rounded).weight(.bold))
                                .foregroundStyle(categoryColor(for: sub))
                        }

                        Text(sub.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 20)

            // Comparison rows
            VStack(spacing: 0) {
                CompareMetricRow(
                    label: "Monthly Cost",
                    values: selectedSubscriptions.map { currencyManager.format($0.monthlyCost) }
                )

                CompareMetricRow(
                    label: "Annual Cost",
                    values: selectedSubscriptions.map { currencyManager.format($0.annualCost) }
                )

                CompareMetricRow(
                    label: "Status",
                    values: selectedSubscriptions.map { $0.status.displayName },
                    valueColors: selectedSubscriptions.map { $0.status.displayColor }
                )

                CompareMetricRow(
                    label: "Category",
                    values: selectedSubscriptions.map { $0.category?.capitalized ?? "Other" }
                )

                CompareMetricRow(
                    label: "Usage This Month",
                    values: selectedSubscriptions.map { usageText(for: $0) }
                )

                CompareMetricRow(
                    label: "Cost Per Hour",
                    values: selectedSubscriptions.map { costPerHourText(for: $0) },
                    highlightBest: true,
                    lowerIsBetter: true
                )

                // Tier comparison if catalog data available
                if selectedSubscriptions.first != nil {
                    CompareMetricRow(
                        label: "Current Tier",
                        values: selectedSubscriptions.map { $0.selectedTier.displayName }
                    )
                }
            }
            .padding(.horizontal, 20)

            // Alternative plans section
            ForEach(selectedSubscriptions) { sub in
                alternativePlansSection(for: sub)
            }
        }
    }

    // MARK: - Alternative Plans

    private func alternativePlansSection(for subscription: Subscription) -> some View {
        guard let entry = SubscriptionCatalogService.shared.catalog.first(where: {
            $0.name.localizedCaseInsensitiveContains(subscription.name) ||
            subscription.name.localizedCaseInsensitiveContains($0.name)
        }) else { return AnyView(EmptyView()) }

        let otherTiers = entry.availableTiers.filter { $0 != subscription.selectedTier }
        guard !otherTiers.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Other Plans for \(subscription.name)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(otherTiers) { tier in
                            if let pricing = entry.pricing(for: tier) {
                                AlternativePlanCard(
                                    tier: tier,
                                    pricing: pricing,
                                    currentTier: subscription.selectedTier == tier
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
        )
    }

    // MARK: - Recommendation Section

    private var recommendationSection: some View {
        guard selectedSubscriptions.count >= 2 else { return AnyView(EmptyView()) }

        let bestValue = selectedSubscriptions.min {
            (costPerHourValue(for: $0) ?? Double.infinity) <
            (costPerHourValue(for: $1) ?? Double.infinity)
        }

        let cheapest = selectedSubscriptions.min {
            NSDecimalNumber(decimal: $0.monthlyCost).doubleValue <
            NSDecimalNumber(decimal: $1.monthlyCost).doubleValue
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Recommendation")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    if let best = bestValue {
                        RecommendationCard(
                            icon: "trophy.fill",
                            iconColor: .yellow,
                            title: "Best Value: \(best.name)",
                            detail: "Lowest cost per hour of actual usage."
                        )
                    }

                    if let cheap = cheapest, cheap.id != bestValue?.id {
                        RecommendationCard(
                            icon: "dollarsign.circle.fill",
                            iconColor: .green,
                            title: "Cheapest: \(cheap.name)",
                            detail: "Lowest monthly cost at \(currencyManager.format(cheap.monthlyCost))/mo."
                        )
                    }

                    // Overlap warning
                    let categories = selectedSubscriptions.compactMap { $0.category }
                    let duplicates = Dictionary(grouping: categories) { $0 }.filter { $0.value.count > 1 }
                    ForEach(Array(duplicates.keys), id: \.self) { category in
                        RecommendationCard(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .orange,
                            title: "Category Overlap: \(category.capitalized)",
                            detail: "You have multiple subscriptions in the same category. Consider consolidating."
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
        )
    }

    // MARK: - Helpers

    private func categoryColor(for subscription: Subscription) -> Color {
        guard let categoryStr = subscription.category else { return .gray }
        switch categoryStr.lowercased() {
        case "entertainment": return .purple
        case "music": return .pink
        case "productivity": return .blue
        case "healthfitness", "health", "fitness": return .green
        case "cloudstorage", "cloud": return .cyan
        case "education": return .orange
        case "utilities": return .gray
        case "finance": return .mint
        case "food": return .yellow
        case "shopping": return .red
        case "sports": return .indigo
        case "social": return .teal
        case "news": return .brown
        default: return .gray
        }
    }

    private func usageText(for subscription: Subscription) -> String {
        let minutes = screenTimeManager.getCurrentMonthUsage(for: subscription.name)
        guard minutes > 0 else { return "No data" }
        if minutes < 60 { return "\(minutes)m" }
        return String(format: "%.1fh", Double(minutes) / 60.0)
    }

    private func costPerHourText(for subscription: Subscription) -> String {
        let minutes = screenTimeManager.getCurrentMonthUsage(for: subscription.name)
        guard minutes > 0 else { return "N/A" }
        let hours = Double(minutes) / 60.0
        let cost = NSDecimalNumber(decimal: subscription.monthlyCost).doubleValue / hours
        return currencyManager.format(Decimal(cost)) + "/hr"
    }

    private func costPerHourValue(for subscription: Subscription) -> Double? {
        let minutes = screenTimeManager.getCurrentMonthUsage(for: subscription.name)
        guard minutes > 0 else { return nil }
        let hours = Double(minutes) / 60.0
        return NSDecimalNumber(decimal: subscription.monthlyCost).doubleValue / hours
    }
}

// MARK: - Compare Metric Row

struct CompareMetricRow: View {
    let label: String
    let values: [String]
    var valueColors: [Color]?
    var highlightBest = false
    var lowerIsBetter = false

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let isBest = highlightBest && bestIndex == index
                Text(value)
                    .font(.subheadline.weight(isBest ? .bold : .medium))
                    .foregroundStyle(valueColor(at: index, isBest: isBest))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }

    private var bestIndex: Int? {
        guard highlightBest, lowerIsBetter else { return nil }
        // Find the index with the lowest numeric value
        let numericValues = values.compactMap { text -> Double? in
            let cleaned = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            return Double(cleaned)
        }
        guard numericValues.count == values.count else { return nil }
        guard let minVal = numericValues.min() else { return nil }
        return numericValues.firstIndex(of: minVal)
    }

    private func valueColor(at index: Int, isBest: Bool) -> Color {
        if isBest { return .green }
        return valueColors?[safe: index] ?? .white
    }
}

// MARK: - Alternative Plan Card

struct AlternativePlanCard: View {
    let tier: PricingTier
    let pricing: TierPricing
    let currentTier: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tier.icon)
                    .foregroundStyle(currentTier ? Color.luxuryTeal : .white)

                Text(tier.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                if currentTier {
                    Text("Current")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.luxuryTeal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.luxuryTeal.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            Text("\(CurrencyManager.shared.format(Decimal(pricing.monthlyPriceUSD)))/mo")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            if let annual = pricing.annualPriceUSD, annual > 0 {
                Text("\(CurrencyManager.shared.format(Decimal(annual)))/yr")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let perUser = pricing.monthlyPricePerUser {
                Text("\(CurrencyManager.shared.format(Decimal(perUser)))/person")
                    .font(.caption2)
                    .foregroundStyle(Color.luxuryTeal)
            }

            if pricing.isBestValue {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("Best Value")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.yellow)
            }
        }
        .padding(14)
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(currentTier ? Color.luxuryTeal.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(iconColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Subscription Picker Sheet

struct SubscriptionPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let subscriptions: [Subscription]
    let onSelect: (Subscription) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if subscriptions.isEmpty {
                        Text("No more subscriptions to add")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(subscriptions) { sub in
                            Button {
                                onSelect(sub)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentMint.opacity(0.15))
                                            .frame(width: 44, height: 44)

                                        Text(String(sub.name.prefix(1)))
                                            .font(.system(.callout, design: .rounded).weight(.bold))
                                            .foregroundStyle(Color.accentMint)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(sub.name)
                                            .font(.system(.body, design: .rounded).weight(.semibold))
                                            .foregroundStyle(.white)

                                        Text(CurrencyManager.shared.format(sub.monthlyCost) + "/month")
                                            .font(.system(.caption, design: .rounded).weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.accentMint)
                                }
                                .padding(14)
                                .background(Color.obsidianSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Select Subscription")
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
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - SubscriptionStatus Extensions

extension SubscriptionStatus {
    var displayColor: Color {
        switch self {
        case .active: return .green
        case .paused: return .orange
        case .cancelled: return .red
        case .trial: return .blue
        case .expired: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionCompareView()
}
