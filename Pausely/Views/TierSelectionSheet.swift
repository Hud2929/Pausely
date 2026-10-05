//
//  TierSelectionSheet.swift
//  Pausely
//
//  Ultra-premium tier + billing frequency picker
//

import SwiftUI

// MARK: - Section appear animation helper
private extension View {
    func sectionAppear(_ appeared: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .animation(.spring(response: 0.52, dampingFraction: 0.82).delay(delay), value: appeared)
    }
}

struct TierSelectionSheet: View {
    let entry: CatalogEntry
    /// Parameters: tier, billingFreq, isPriceOverridden, overridePrice, nextBillingDate, trialEndsAt
    let onSelect: (PricingTier, BillingFrequency, Bool, Decimal?, Date, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedTier: PricingTier = .individual
    @State private var selectedBillingFrequency: BillingFrequency = .monthly
    @State private var isOverridingPrice = false
    @State private var priceOverrideText = ""
    @State private var priceError: String? = nil
    @State private var nextBillingDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var hasFreeTrial = false
    @State private var trialEndsAt: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var appeared = false

    // MARK: - Bindings with animation
    private var overrideBinding: Binding<Bool> {
        Binding(get: { isOverridingPrice },
                set: { val in withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { isOverridingPrice = val } })
    }
    private var trialBinding: Binding<Bool> {
        Binding(get: { hasFreeTrial },
                set: { val in withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { hasFreeTrial = val } })
    }

    // MARK: - Region
    private var userRegion: Region {
        switch currencyManager.selectedCurrency {
        case "USD": return .us
        case "CAD": return .ca
        case "GBP": return .uk
        case "EUR": return .eu
        case "AUD": return .au
        default:    return .us
        }
    }

    private var availableTierPricings: [TierPricing] {
        // For EVERY tier type the entry has, find the best pricing for this user's region.
        // Priority: user's region → global → US → any available.
        // This ensures all plan types (Individual/Family/Student) appear even if only
        // US pricing exists — non-US users get approximate pricing with the "≈" indicator.
        entry.availableTiers.compactMap { tier in
            entry.supportedTiers.first { $0.tier == tier && $0.region == userRegion }
                ?? entry.supportedTiers.first { $0.tier == tier && $0.region == .global }
                ?? entry.supportedTiers.first { $0.tier == tier && $0.region == .us }
                ?? entry.supportedTiers.first { $0.tier == tier }
        }
    }

    private var uniqueTiers: [PricingTier] {
        Array(Set(availableTierPricings.map { $0.tier })).sorted { $0.rawValue < $1.rawValue }
    }

    private var selectedTierPricing: TierPricing? {
        availableTierPricings.first { $0.tier == selectedTier }
    }

    private var showAnnualOption: Bool {
        (selectedTierPricing?.annualPriceUSD ?? 0) > 0
    }

    private var canAdd: Bool {
        if isOverridingPrice {
            guard let price = parsePriceOverride(), price > 0 else { return false }
        }
        return true
    }

    private var displayPriceText: String {
        if isOverridingPrice {
            if let price = parsePriceOverride(), price > 0 {
                return currencyManager.format(price)
            }
            return "—"
        }
        return effectivePriceText
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                    navBar
                        .padding(.horizontal, 20)
                        .sectionAppear(appeared, delay: 0)

                    headerCard
                        .padding(.horizontal, 20)
                        .sectionAppear(appeared, delay: 0.04)

                    tierSelectionSection
                        .padding(.horizontal, 20)
                        .sectionAppear(appeared, delay: 0.09)

                    if showAnnualOption {
                        billingToggleSection
                            .padding(.horizontal, 20)
                            .sectionAppear(appeared, delay: 0.13)
                    }

                    priceSummaryCard
                        .padding(.horizontal, 20)
                        .sectionAppear(appeared, delay: 0.17)

                    freeTrialToggleSection
                        .padding(.horizontal, 20)
                        .sectionAppear(appeared, delay: 0.20)

                    if hasFreeTrial {
                        freeTrialDateSection
                            .padding(.horizontal, 20)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    priceOverrideSection
                        .padding(.horizontal, 20)
                        .sectionAppear(appeared, delay: 0.23)

                    if !hasFreeTrial {
                        billingDateSection
                            .padding(.horizontal, 20)
                            .sectionAppear(appeared, delay: 0.26)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .safeAreaInset(edge: .bottom) {
            addButton
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { appeared = true }
            // Auto-select best value tier
            if let best = availableTierPricings.first(where: { $0.isBestValue }) {
                selectedTier = best.tier
            } else if uniqueTiers.contains(.individual) {
                selectedTier = .individual
            } else if let first = uniqueTiers.first {
                selectedTier = first
            }
        }
        .onChange(of: trialEndsAt) { _, newDate in
            if hasFreeTrial {
                nextBillingDate = Calendar.current.date(byAdding: .day, value: 1, to: newDate) ?? newDate
            }
        }
        .onChange(of: hasFreeTrial) { _, isOn in
            nextBillingDate = isOn
                ? (Calendar.current.date(byAdding: .day, value: 1, to: trialEndsAt) ?? nextBillingDate)
                : (Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
        }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button {
                STAnimation.impactLight()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.body.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text("Choose Your Plan")
                .font(STFont.headlineMedium)
                .foregroundColor(.white)
            Spacer()
            Text("Cancel").font(.body.weight(.medium)).foregroundColor(.clear).accessibilityHidden(true)
        }
    }

    // MARK: - Header Card — real brand logo, prominent
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Real brand logo via Clearbit / initial fallback
            ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 80)
                .shadow(color: iconColor.opacity(0.45), radius: 24, x: 0, y: 10)

            VStack(spacing: 6) {
                Text(entry.name)
                    .font(STFont.headlineLarge)
                    .foregroundColor(.white)

                Text(entry.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if entry.trialDays > 0 {
                    Label("\(entry.trialDays)-day free trial available", systemImage: "gift.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentMint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.accentMint.opacity(0.14)))
                        .padding(.top, 4)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    // MARK: - Tier Selection
    private var tierSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(uniqueTiers.count == 1 ? "Your Plan" : "Select Your Plan")
            VStack(spacing: 10) {
                ForEach(uniqueTiers, id: \.self) { tier in
                    PremiumTierRow(
                        tier: tier,
                        tierPricing: availableTierPricings.first { $0.tier == tier },
                        isSelected: selectedTier == tier,
                        isOnlyOption: uniqueTiers.count == 1,
                        currencyManager: currencyManager
                    ) {
                        STAnimation.impactMedium()
                        withAnimation(STAnimation.snappy) { selectedTier = tier }
                    }
                }
            }
        }
    }

    // MARK: - Billing Toggle
    private var billingToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Billing Cycle")
            HStack(spacing: 0) {
                BillingToggleButton(title: "Monthly", isSelected: selectedBillingFrequency == .monthly) {
                    STAnimation.impactLight()
                    withAnimation(STAnimation.snappy) { selectedBillingFrequency = .monthly }
                }
                BillingToggleButton(title: "Annual", isSelected: selectedBillingFrequency == .yearly) {
                    STAnimation.impactLight()
                    withAnimation(STAnimation.snappy) { selectedBillingFrequency = .yearly }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
        }
    }

    // MARK: - Price Summary
    private var priceSummaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Price")
                    .font(STFont.labelLarge)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(displayPriceText)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }

            if showAnnualOption && !isOverridingPrice && selectedBillingFrequency == .yearly {
                HStack {
                    Text("Billed annually")
                        .font(STFont.labelMedium)
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(annualTotalText)
                        .font(STFont.labelMedium)
                        .foregroundColor(.white.opacity(0.4))
                }
            } else if showAnnualOption && !isOverridingPrice && selectedBillingFrequency == .monthly {
                // Hint to switch to annual
                if let pricing = selectedTierPricing, let annual = pricing.annualPriceUSD {
                    let savings = pricing.monthlyPriceUSD - (annual / 12)
                    if savings > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle")
                                .font(.caption2.weight(.semibold))
                            Text("Switch to Annual, save \(currencyManager.formatCatalogPrice(savings * 12, sourceCurrency: pricing.currencyCode))/yr")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }

            if showAnnualOption,
               selectedBillingFrequency == .yearly,
               let pricing = selectedTierPricing,
               let annual = pricing.annualPriceUSD {
                let savings = pricing.monthlyPriceUSD - (annual / 12)
                if savings > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                        Text("Save \(currencyManager.formatCatalogPrice(savings * 12, sourceCurrency: pricing.currencyCode))/yr vs monthly")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentMint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(Color.accentMint.opacity(0.12))
                            .overlay(Capsule().stroke(Color.accentMint.opacity(0.25), lineWidth: 1))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }

    // MARK: - Free Trial Toggle
    private var freeTrialToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Free Trial")
            Toggle(isOn: trialBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("I'm currently in a free trial")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                    Text("We'll alert you before billing starts")
                        .font(.caption.weight(.regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .tint(.accentMint)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(hasFreeTrial ? Color.accentMint.opacity(0.09) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(hasFreeTrial ? Color.accentMint.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: hasFreeTrial)
        }
    }

    // MARK: - Free Trial Date (shown when hasFreeTrial = true)
    private var freeTrialDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Trial Ends On")
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    QuickDateChip(title: "+7 Days", icon: "7.circle") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            trialEndsAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        }
                    }
                    QuickDateChip(title: "+14 Days", icon: "14.circle") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            trialEndsAt = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
                        }
                    }
                    QuickDateChip(title: "+30 Days", icon: "30.circle") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            trialEndsAt = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                        }
                    }
                }
                DatePicker("Trial ends", selection: $trialEndsAt, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorMultiply(.accentMint)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentMint.opacity(0.22), lineWidth: 1))
                    )
            }
        }
    }

    // MARK: - Price Override
    @AppStorage("hasSeenCustomPriceHint") private var hasSeenCustomPriceHint = false

    private var priceOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Custom Price")

            if !hasSeenCustomPriceHint {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentMint)
                    Text("Got a promo, bundle, or discount? Enter what you actually pay.")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button {
                        withAnimation { hasSeenCustomPriceHint = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentMint.opacity(0.09))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentMint.opacity(0.2), lineWidth: 1))
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Toggle(isOn: overrideBinding) {
                Text("I pay a different amount")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .tint(.accentMint)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )

            if isOverridingPrice {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.55))
                        TextField("Your price per month", text: $priceOverrideText)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                            .tint(.accentMint)
                            .onChange(of: priceOverrideText) { _, val in
                                let clean = val.replacingOccurrences(of: ",", with: ".")
                                if let d = Decimal(string: clean), d <= 0 {
                                    priceError = "Enter an amount greater than $0"
                                } else {
                                    priceError = nil
                                }
                            }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(priceError != nil ? Color.red.opacity(0.5) : Color.accentMint.opacity(0.3), lineWidth: 1)
                            )
                    )

                    if let err = priceError {
                        Label(err, systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.red.opacity(0.75))
                            .padding(.leading, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Billing Date
    private var billingDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(hasFreeTrial ? "First Charge Date" : "Next Billing Date")

            VStack(spacing: 10) {
                if hasFreeTrial {
                    Label("Set automatically — 1 day after your trial ends", systemImage: "info.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    HStack(spacing: 8) {
                        QuickDateChip(title: "Today", icon: "calendar") {
                            withAnimation(.easeInOut(duration: 0.2)) { nextBillingDate = Date() }
                        }
                        QuickDateChip(title: "+7 Days", icon: "7.circle") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                nextBillingDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                            }
                        }
                        QuickDateChip(title: "+30 Days", icon: "30.circle") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                nextBillingDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                            }
                        }
                    }
                }

                DatePicker("Next Billing Date", selection: $nextBillingDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorMultiply(.accentMint)
                    .disabled(hasFreeTrial)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(hasFreeTrial ? 0.03 : 0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                    .animation(.easeInOut(duration: 0.15), value: hasFreeTrial)
            }
        }
    }

    // MARK: - Add Button (safeAreaInset)
    private var addButton: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.06))
            Button {
                guard canAdd else {
                    STAnimation.impactMedium()
                    priceError = "Enter an amount greater than $0"
                    return
                }
                STAnimation.success()
                let price = parsePriceOverride()
                onSelect(selectedTier, selectedBillingFrequency, isOverridingPrice, price, nextBillingDate, hasFreeTrial ? trialEndsAt : nil)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: hasFreeTrial ? "clock.badge.checkmark.fill" : "plus.circle.fill")
                        .font(.body.weight(.bold))
                    VStack(spacing: 1) {
                        Text(hasFreeTrial ? "Start Tracking Trial" : "Add \(entry.name)")
                            .font(.body.weight(.semibold))
                        if !hasFreeTrial {
                            Text(effectivePriceText)
                                .font(.caption2.weight(.medium))
                                .opacity(0.65)
                        }
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundColor(canAdd ? .black : .white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(canAdd ? Color.accentMint : Color.white.opacity(0.1))
                )
                .animation(.easeInOut(duration: 0.18), value: canAdd)
                .animation(.easeInOut(duration: 0.18), value: hasFreeTrial)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(STFont.labelLarge)
            .foregroundColor(.white.opacity(0.55))
            .padding(.leading, 4)
    }

    private var iconColor: Color {
        switch entry.category {
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

    private var effectivePriceText: String {
        guard let pricing = selectedTierPricing else { return "N/A" }
        let price: Double = selectedBillingFrequency == .yearly
            ? (pricing.annualPriceUSD ?? pricing.monthlyPriceUSD * 12)
            : pricing.monthlyPriceUSD
        return "\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(price, sourceCurrency: pricing.currencyCode))/\(selectedBillingFrequency == .yearly ? "yr" : "mo")"
    }

    private var annualTotalText: String {
        guard let pricing = selectedTierPricing, let annual = pricing.annualPriceUSD else { return "" }
        return "\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(annual, sourceCurrency: pricing.currencyCode))/yr"
    }

    private func parsePriceOverride() -> Decimal? {
        guard isOverridingPrice, !priceOverrideText.isEmpty else { return nil }
        return Decimal(string: priceOverrideText.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Premium Tier Row
struct PremiumTierRow: View {
    let tier: PricingTier
    let tierPricing: TierPricing?
    let isSelected: Bool
    var isOnlyOption: Bool = false
    let currencyManager: CurrencyManager
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: { if !isOnlyOption { onTap() } }) {
            HStack(spacing: 16) {
                // Radio indicator — hidden when only one plan (no choice to make)
                if !isOnlyOption {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.accentMint : Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        if isSelected {
                            Circle()
                                .fill(Color.accentMint)
                                .frame(width: 18, height: 18)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                } else {
                    // Single plan: show a small checkmark instead
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentMint)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(tier.displayName)
                            .font(.callout.weight(isSelected ? .semibold : .medium))
                            .foregroundColor(.white)
                        if tierPricing?.isBestValue == true {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentMint.cornerRadius(4))
                        }
                    }
                    Text(tierDescription)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()

                if let pricing = tierPricing {
                    Text("\(currencyManager.priceIndicator)\(currencyManager.formatCatalogPrice(pricing.monthlyPriceUSD, sourceCurrency: pricing.currencyCode))/mo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill((isSelected || isOnlyOption) ? Color.accentMint.opacity(0.10) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke((isSelected || isOnlyOption) ? Color.accentMint.opacity(0.4) : Color.white.opacity(0.08),
                                    lineWidth: (isSelected || isOnlyOption) ? 1.5 : 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(PremiumAnimations.fast) { isPressed = true } }
                .onEnded   { _ in withAnimation(STAnimation.snappy)     { isPressed = false } }
        )
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var tierDescription: String {
        switch tier {
        case .individual: return "For one person"
        case .family:     return "Up to \(tier.maxUsers ?? 6) members"
        case .student:    return "Verified students only"
        case .duo:        return "For two people"
        case .team:       return "Flexible team size"
        case .enterprise: return "Custom pricing"
        }
    }
}

// MARK: - Quick Date Chip
struct QuickDateChip: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.caption2.weight(.semibold))
                Text(title).font(.caption2.weight(.medium))
            }
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
            .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
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
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if isSelected {
                        Color.accentMint
                            .cornerRadius(10)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
            trialDays: 30,
            canPause: true,
            supportedTiers: [
                TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.49, annualPriceUSD: 139.99, isBestValue: false),
                TierPricing(tier: .family,     region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 229.99, isBestValue: true),
                TierPricing(tier: .student,    region: .us, monthlyPriceUSD: 7.99,  annualPriceUSD: nil,    isBestValue: false),
            ],
            lastUpdated: Date()
        ),
        onSelect: { _, _, _, _, _, _ in }
    )
}
