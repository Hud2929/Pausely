//
//  TierSelectionSheet.swift
//  Pausely
//
//  Ultra-premium tier + billing frequency picker
//

import SwiftUI

struct TierSelectionSheet: View {
    let entry: CatalogEntry
    let onSelect: (PricingTier, BillingFrequency, Bool, Decimal?) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedTier: PricingTier = .individual
    @State private var selectedBillingFrequency: BillingFrequency = .monthly
    @State private var isOverridingPrice = false
    @State private var priceOverrideText = ""

    // MARK: - Region mapping
    private var userRegion: Region {
        switch currencyManager.selectedCurrency {
        case "USD", "CAD": return .us
        case "GBP": return .uk
        case "EUR": return .eu
        case "AUD": return .au
        default: return .us
        }
    }

    private var availableTierPricings: [TierPricing] {
        let regionTiers = entry.supportedTiers.filter { $0.region == userRegion }
        if !regionTiers.isEmpty { return regionTiers }

        let globalTiers = entry.supportedTiers.filter { $0.region == .global }
        if !globalTiers.isEmpty { return globalTiers }

        return entry.supportedTiers
    }

    private var uniqueTiers: [PricingTier] {
        Array(Set(availableTierPricings.map { $0.tier })).sorted { $0.rawValue < $1.rawValue }
    }

    private var selectedTierPricing: TierPricing? {
        availableTierPricings.first { $0.tier == selectedTier }
    }

    private var showAnnualOption: Bool {
        selectedTierPricing?.annualPriceUSD != nil && (selectedTierPricing?.annualPriceUSD ?? 0) > 0
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
        case .other: return .secondary
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Premium header card with glow
                        headerCard
                            .padding(.horizontal, 20)

                        // Tier selection
                        tierSelectionSection
                            .padding(.horizontal, 20)

                        // Billing toggle (if applicable)
                        if showAnnualOption {
                            billingToggleSection
                                .padding(.horizontal, 20)
                        }

                        // Price summary card
                        priceSummaryCard
                            .padding(.horizontal, 20)

                        // Price override section
                        priceOverrideSection
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Choose Your Plan")
                        .font(STFont.headlineMedium)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        STAnimation.impactLight()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        STAnimation.success()
                        let price = parsePriceOverride()
                        onSelect(selectedTier, selectedBillingFrequency, isOverridingPrice, price)
                        dismiss()
                    } label: {
                        Text("Add")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.luxuryPurple, .luxuryPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
        }
    }

    // MARK: - Premium Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Icon with glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [iconColor.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                // Icon background with glass
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(iconColor.opacity(0.5), lineWidth: 1.5)
                        )

                    Image(systemName: entry.iconName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(iconColor)
                }
                .frame(width: 72, height: 72)
            }

            VStack(spacing: 6) {
                Text(entry.name)
                    .font(STFont.headlineLarge)
                    .foregroundColor(.white)

                Text(entry.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Tier Selection
    private var tierSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Your Plan")
                .font(STFont.labelLarge)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)

            VStack(spacing: 10) {
                ForEach(uniqueTiers, id: \.self) { tier in
                    PremiumTierRow(
                        tier: tier,
                        tierPricing: availableTierPricings.first { $0.tier == tier },
                        isSelected: selectedTier == tier,
                        currencyManager: currencyManager
                    ) {
                        STAnimation.impactMedium()
                        withAnimation(STAnimation.snappy) {
                            selectedTier = tier
                        }
                    }
                }
            }
        }
    }

    // MARK: - Billing Toggle
    private var billingToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Billing Cycle")
                .font(STFont.labelLarge)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)

            HStack(spacing: 0) {
                BillingToggleButton(
                    title: "Monthly",
                    isSelected: selectedBillingFrequency == .monthly
                ) {
                    STAnimation.impactLight()
                    withAnimation(STAnimation.snappy) {
                        selectedBillingFrequency = .monthly
                    }
                }

                BillingToggleButton(
                    title: "Annual",
                    isSelected: selectedBillingFrequency == .yearly
                ) {
                    STAnimation.impactLight()
                    withAnimation(STAnimation.snappy) {
                        selectedBillingFrequency = .yearly
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Price Summary
    private var priceSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Price")
                    .font(STFont.labelLarge)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                if isOverridingPrice, let override = parsePriceOverride() {
                    Text(currencyManager.format(override))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    Text(effectivePriceText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }

            if showAnnualOption && !isOverridingPrice {
                HStack {
                    Text("Annual total")
                        .font(STFont.labelMedium)
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(annualTotalText)
                        .font(STFont.labelMedium)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Savings badge if annual
            if showAnnualOption && selectedBillingFrequency == .yearly, let pricing = selectedTierPricing, let annual = pricing.annualPriceUSD {
                let monthlyEquivalent = annual / 12
                let savings = pricing.monthlyPriceUSD - monthlyEquivalent
                if savings > 0 {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("You save \(currencyManager.formatCatalogPrice(savings * 12))/yr")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.luxuryGold, .luxuryPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.luxuryGold.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.luxuryGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Price Override
    private var priceOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Price")
                .font(STFont.labelLarge)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)

            Toggle(isOn: $isOverridingPrice) {
                Text("I pay a different amount")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .tint(.luxuryPurple)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            if isOverridingPrice {
                HStack(spacing: 12) {
                    Text(currencyManager.selectedCurrency == "USD" ? "$" : currencyManager.currencySymbol(for: currencyManager.selectedCurrency))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    TextField("Your monthly price", text: $priceOverrideText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .tint(.luxuryPurple)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.luxuryPurple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: - Computed
    private var effectivePriceText: String {
        guard let pricing = selectedTierPricing else { return "N/A" }

        let price: Double
        if selectedBillingFrequency == .yearly {
            price = pricing.annualPriceUSD ?? pricing.monthlyPriceUSD * 12
        } else {
            price = pricing.monthlyPriceUSD
        }

        return "\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(price))/\(selectedBillingFrequency == .yearly ? "yr" : "mo")"
    }

    private var annualTotalText: String {
        guard let pricing = selectedTierPricing,
              let annual = pricing.annualPriceUSD else { return "" }
        return "\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(annual))/yr"
    }

    private func parsePriceOverride() -> Decimal? {
        guard isOverridingPrice, !priceOverrideText.isEmpty else { return nil }
        let cleaned = priceOverrideText.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }
}

// MARK: - Premium Tier Row
struct PremiumTierRow: View {
    let tier: PricingTier
    let tierPricing: TierPricing?
    let isSelected: Bool
    let currencyManager: CurrencyManager
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.luxuryPurple : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.luxuryPurple, .luxuryPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)
                    }
                }

                // Tier icon
                Image(systemName: tier.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .luxuryPurple : .white.opacity(0.4))
                    .frame(width: 32)

                // Tier info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tier.displayName)
                            .font(.system(size: 16, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundColor(.white)

                        if tierPricing?.isBestValue == true {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: [.luxuryPurple, .luxuryPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(4)
                        }
                    }

                    Text(tierDescription)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Price
                if let pricing = tierPricing {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD))/mo")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.luxuryPurple.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.luxuryPurple.opacity(0.5) : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
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

    private var tierDescription: String {
        switch tier {
        case .individual: return "For one person"
        case .family: return "Up to \(tier.maxUsers ?? 6) members"
        case .student: return "Verified students only"
        case .duo: return "For two people"
        case .team: return "Flexible team size"
        case .enterprise: return "Custom pricing"
        }
    }
}

// MARK: - Billing Toggle Button
struct BillingToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if isSelected {
                        LinearGradient(
                            colors: [.luxuryPurple, .luxuryPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.clear
                    }
                }
                .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TierSelectionSheet(
        entry: CatalogEntry(
            id: UUID(),
            bundleId: "com.netflix.Netflix",
            name: "Netflix",
            category: .entertainment,
            description: "Stream thousands of TV shows, movies, and originals.",
            iconName: "tv",
            appStoreProductId: nil,
            websiteURL: "https://netflix.com",
            cancellationURL: nil,
            trialDays: 0,
            canPause: true,
            supportedTiers: [
                TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.49, annualPriceUSD: 139.99, isBestValue: false),
                TierPricing(tier: .family, region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 229.99, isBestValue: true),
                TierPricing(tier: .student, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: nil, isBestValue: false),
            ],
            lastUpdated: Date()
        ),
        onSelect: { _, _, _, _ in }
    )
}
