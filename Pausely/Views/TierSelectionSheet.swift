//
//  TierSelectionSheet.swift
//  Pausely
//
//  Adding a service from the catalog: which plan, what it costs, how often, and when it next charges.
//

import SwiftUI

struct TierSelectionSheet: View {
    let entry: CatalogEntry
    /// Parameters: tier, billingFreq, isPriceOverridden, overridePrice, nextBillingDate, trialEndsAt
    let onSelect: (PricingTier, BillingFrequency, Bool, Decimal?, Date, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedTier: PricingTier = .individual
    @State private var frequency: BillingFrequency = .monthly
    /// What the person typed. Empty means "the typical price is right".
    @State private var amountText = ""
    @State private var nextBillingDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var hasFreeTrial = false
    @State private var trialEndsAt: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @FocusState private var amountFocused: Bool

    // MARK: - Prices

    /// The same price the add flow saves (see `CatalogEntry.pricing(for:payingIn:)`).
    private var pricings: [TierPricing] {
        let all = entry.availableTiers.compactMap { entry.pricing(for: $0, payingIn: currencyManager.selectedCurrency) }
        // Plans priced in another country's currency are that country's plans, not ones this
        // person can buy, so only plans in the same currency as the standard one are offered.
        guard let home = (all.first { $0.tier == .individual } ?? all.first)?.currencyCode else { return all }
        return all.filter { $0.currencyCode == home }
    }

    private var pricing: TierPricing? { pricings.first { $0.tier == selectedTier } }

    private var offersYearly: Bool { (pricing?.annualPriceUSD ?? 0) > 0 }

    /// The catalog's price for the chosen plan and cycle, in the catalog's currency for it.
    private var typical: (amount: Decimal, currency: String)? {
        guard let pricing else { return nil }
        let price = frequency == .yearly ? (pricing.annualPriceUSD ?? pricing.monthlyPriceUSD * 12) : pricing.monthlyPriceUSD
        return (MoneyFormat.decimal(price), pricing.currencyCode)
    }

    private var typed: Decimal? { SubscriptionEditDraft.parseAmount(amountText) }
    private var isOverridden: Bool { !amountText.isEmpty }
    private var canAdd: Bool { isOverridden ? (typed ?? 0) > 0 : typical != nil }
    private var currency: String { isOverridden ? currencyManager.selectedCurrency : (typical?.currency ?? currencyManager.selectedCurrency) }

    private func tierPrice(_ pricing: TierPricing) -> String {
        MoneyFormat.string(pricing.monthlyPriceUSD, pricing.currencyCode, locale: L10n.locale) + L10n.string("/month")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Button { dismiss() } label: {
                            Text("Cancel")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkTextMuted)
                                .frame(minHeight: Layout.tapTarget)
                                .contentShape(Rectangle())
                        }
                        Spacer()
                    }
                    .padding(.bottom, -12)

                    HStack(spacing: 12) {
                        ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 48)
                        Text(verbatim: entry.name)
                            .font(.question(.title))
                            .foregroundStyle(Color.inkText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }

                    amountSection

                    if pricings.count > 1 { planSection }

                    VStack(spacing: 0) {
                        if offersYearly {
                            row(L10n.string("Billing cycle")) {
                                Picker(L10n.string("Billing cycle"), selection: $frequency) {
                                    Text(BillingFrequency.monthly.displayName).tag(BillingFrequency.monthly)
                                    Text(BillingFrequency.yearly.displayName).tag(BillingFrequency.yearly)
                                }
                                .pickerStyle(.menu)
                                .tint(Color.inkText)
                            }
                            Hairline()
                        }
                        row(L10n.string("Next payment")) {
                            DatePicker(L10n.string("Next payment"), selection: $nextBillingDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                                .tint(Color.inkText)
                        }
                        Hairline()
                        Toggle(isOn: $hasFreeTrial.animation(Motion.unlessReduced(Motion.touch))) {
                            Text("I'm on a free trial")
                                .font(.body)
                                .foregroundStyle(Color.inkText)
                        }
                        .tint(Color.inkTextMuted)
                        .frame(minHeight: 54)
                        if hasFreeTrial {
                            Hairline()
                            row(L10n.string("Trial ends")) {
                                DatePicker(L10n.string("Trial ends"), selection: $trialEndsAt, in: Date()..., displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(Color.inkText)
                            }
                        }
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Button {
                Feel.tick()
                onSelect(selectedTier, frequency, isOverridden, isOverridden ? typed : nil,
                         nextBillingDate, hasFreeTrial ? trialEndsAt : nil)
                dismiss()
            } label: {
                Text(L10n.string("Add \(entry.name)"))
            }
            .buttonStyle(.ink)
            .disabled(!canAdd)
            .accessibilityIdentifier("tierAddButton")
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.ink)
        }
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            if !pricings.contains(where: { $0.tier == selectedTier }), let first = pricings.first { selectedTier = first.tier }
        }
        .onChange(of: selectedTier) { _, _ in
            if !offersYearly { frequency = .monthly }
        }
    }

    /// The price, as a question the person can answer by typing. The catalog's figure is only the
    /// starting suggestion.
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(frequency == .yearly ? L10n.string("What do you pay each year?") : L10n.string("What do you pay each month?"))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // The typical price is shown as a real figure, not a greyed-out hint: it is what
                // will be saved unless the person types over it.
                TextField("", text: $amountText,
                          prompt: Text(verbatim: typical.map { MoneyFormat.string($0.amount, $0.currency, locale: L10n.locale) } ?? "0.00")
                            .foregroundStyle(typical == nil ? Color.inkTextFaint : Color.inkText))
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundStyle(Color.inkText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .accessibilityLabel(Text("Amount"))
                    .accessibilityIdentifier("tierAmountField")
                Text(verbatim: currency)
                    .font(.proof(.subheadline))
                    .foregroundStyle(Color.inkTextMuted)
            }
            Text(isOverridden
                 ? L10n.string("Saved as what you pay.")
                 : L10n.string("This is a typical price. Type over it if you pay something else."))
                .font(.footnote)
                .foregroundStyle(Color.inkTextFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Plan")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
                .padding(.bottom, 4)
            ForEach(Array(pricings.enumerated()), id: \.element.id) { index, option in
                if index > 0 { Hairline() }
                let isOn = option.tier == selectedTier
                Button {
                    Feel.selection()
                    selectedTier = option.tier
                    amountText = ""
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                            .font(.title3)
                            .foregroundStyle(isOn ? Color.paper : Color.inkTextFaint)
                            .accessibilityHidden(true)
                        Text(option.tier.displayName)
                            .font(.body)
                            .foregroundStyle(Color.inkText)
                        Spacer(minLength: 8)
                        Text(verbatim: tierPrice(option))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(Color.inkTextMuted)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: title)
                .font(.body)
                .foregroundStyle(Color.inkText)
            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 54)
    }
}
