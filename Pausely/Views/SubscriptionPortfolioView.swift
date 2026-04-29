//
//  SubscriptionPortfolioView.swift
//  Pausely
//
//  Wealthsimple-inspired subscription portfolio with elegant dark design
//

import SwiftUI

struct SubscriptionPortfolioView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var selectedSubscription: Subscription?
    @State private var animateChart = false
    @State private var selectedCategory: ServiceCategory?

    // MARK: - Computed Properties

    private var activeSubscriptions: [Subscription] {
        store.subscriptions.filter { $0.status == .active }
    }

    private var groupedSubscriptions: [ServiceCategory: [Subscription]] {
        Dictionary(grouping: activeSubscriptions) { sub in
            ServiceCategory.allCases.first { cat in
                sub.category?.lowercased().contains(cat.rawValue.lowercased()) ?? false
            } ?? .other
        }
    }

    private var totalMonthlySpend: Double {
        activeSubscriptions.reduce(0.0) { total, sub in
            let monthlyAmount = currencyManager.convertToSelected(sub.amount, from: sub.currency)
            let doubleAmount = Double(truncating: monthlyAmount as NSDecimalNumber)
            return total + monthlyEquivalent(doubleAmount, frequency: sub.billingFrequency)
        }
    }

    private var annualSpend: Double {
        totalMonthlySpend * 12
    }

    private var sortedCategories: [ServiceCategory] {
        groupedSubscriptions.keys.sorted { cat1, cat2 in
            let total1 = categoryTotal(cat1)
            let total2 = categoryTotal(cat2)
            return total1 > total2
        }
    }

    private func categoryTotal(_ category: ServiceCategory) -> Double {
        guard let subs = groupedSubscriptions[category] else { return 0 }
        return subs.reduce(0.0) { total, sub in
            let monthlyAmount = currencyManager.convertToSelected(sub.amount, from: sub.currency)
            let doubleAmount = Double(truncating: monthlyAmount as NSDecimalNumber)
            return total + monthlyEquivalent(doubleAmount, frequency: sub.billingFrequency)
        }
    }

    private func categoryPercentage(_ category: ServiceCategory) -> Double {
        guard totalMonthlySpend > 0 else { return 0 }
        return categoryTotal(category) / totalMonthlySpend
    }

    private func monthlyEquivalent(_ amount: Double, frequency: BillingFrequency) -> Double {
        switch frequency {
        case .weekly: return amount * 4.33
        case .biweekly: return amount * 2.17
        case .monthly: return amount
        case .quarterly: return amount / 3
        case .semiannual: return amount / 6
        case .yearly: return amount / 12
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Hero Section with Circular Chart
                heroSection

                // Category Breakdown
                if !sortedCategories.isEmpty {
                    categoryBreakdownSection
                }

                // All Subscriptions by Category
                ForEach(sortedCategories, id: \.self) { category in
                    categorySection(category)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.obsidianBlack.ignoresSafeArea())
        .sheet(item: $selectedSubscription) { subscription in
            SubscriptionManagementView(subscription: subscription)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateChart = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Total Portfolio Value
            VStack(spacing: 4) {
                Text("Total Subscriptions")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.obsidianTextSecondary)

                Text("\(activeSubscriptions.count)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.obsidianText)
            }

            // Circular Spend Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.obsidianElevated, lineWidth: 16)
                    .frame(width: 200, height: 200)

                // Animated progress ring
                Circle()
                    .trim(from: 0, to: animateChart ? 1 : 0)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.accentMint,
                                Color.accentMint.opacity(0.6),
                                Color.luxuryPurple,
                                Color.luxuryPink,
                                Color.luxuryGold,
                                Color.accentMint
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency))
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color.obsidianTextSecondary)

                    Text(formatAmount(totalMonthlySpend))
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.obsidianText)

                    Text("per month")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }
            .padding(.vertical, 8)

            // Stats Row
            HStack(spacing: 16) {
                PortfolioStatPill(
                    title: "Monthly",
                    value: currencyManager.currencySymbol(for: currencyManager.selectedCurrency) + formatAmount(totalMonthlySpend),
                    color: Color.accentMint
                )

                PortfolioStatPill(
                    title: "Yearly",
                    value: currencyManager.currencySymbol(for: currencyManager.selectedCurrency) + formatAmount(annualSpend),
                    color: Color.luxuryGold
                )

                PortfolioStatPill(
                    title: "Categories",
                    value: "\(sortedCategories.count)",
                    color: Color.luxuryPurple
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakdown by Category")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.obsidianText)

            // Category bars
            VStack(spacing: 12) {
                ForEach(sortedCategories.prefix(6), id: \.self) { category in
                    CategoryBarRow(
                        category: category,
                        percentage: categoryPercentage(category),
                        amount: categoryTotal(category),
                        animate: animateChart
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Category Section

    private func categorySection(_ category: ServiceCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Header
            HStack {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: category.icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(category.color)
                }

                Text(category.rawValue)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.obsidianText)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency) + formatAmount(categoryTotal(category)))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.obsidianText)

                    Text("/month")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }

            // Subscriptions in category
            ForEach(groupedSubscriptions[category] ?? [], id: \.id) { subscription in
                PortfolioSubscriptionRow(subscription: subscription) {
                    selectedSubscription = subscription
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.1fK", amount / 1000)
        } else if amount == floor(amount) {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.2f", amount)
        }
    }
}

// MARK: - Supporting Views

struct PortfolioStatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.callout.weight(.bold))
                .foregroundStyle(color)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.obsidianTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CategoryBarRow: View {
    let category: ServiceCategory
    let percentage: Double
    let amount: Double
    let animate: Bool

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(category.color)

                    Text(category.rawValue)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.obsidianText)
                }

                Spacer()

                Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency) + String(format: "%.2f", amount))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.obsidianElevated)
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [category.color, category.color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animate ? geometry.size.width * CGFloat(percentage) : 0, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct PortfolioSubscriptionRow: View {
    let subscription: Subscription
    let onTap: () -> Void

    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var isPressed = false

    private var monthlyAmount: Double {
        let converted = currencyManager.convertToSelected(subscription.amount, from: subscription.currency)
        let doubleAmount = Double(truncating: converted as NSDecimalNumber)
        switch subscription.billingFrequency {
        case .weekly: return doubleAmount * 4.33
        case .biweekly: return doubleAmount * 2.17
        case .monthly: return doubleAmount
        case .quarterly: return doubleAmount / 3
        case .semiannual: return doubleAmount / 6
        case .yearly: return doubleAmount / 12
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Text(String(subscription.name.prefix(1)))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(categoryColor)
                }

                // Name and billing
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.obsidianText)
                        .lineLimit(1)

                    Text(subscription.billingFrequency.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }

                Spacer()

                // Amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currencyManager.format(currencyManager.convertToSelected(subscription.amount, from: subscription.currency)))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.obsidianText)

                    Text("/\(subscription.billingFrequency.shortDisplay)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PortfolioButtonStyle())
    }

    private var categoryColor: Color {
        guard let catStr = subscription.category else { return .gray }
        return ServiceCategory.allCases.first { cat in
            catStr.lowercased().contains(cat.rawValue.lowercased())
        }?.color ?? .gray
    }
}

struct PortfolioButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPortfolioView()
}
