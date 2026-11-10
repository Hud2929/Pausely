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

    @State private var frequency: BillingFrequency = .monthly
    /// What the person typed. Empty means "the typical price is right".
    @State private var amountText = ""
    @State private var nextBillingDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var hasFreeTrial = false
    @State private var trialEndsAt: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @FocusState private var amountFocused: Bool

    // MARK: - Price

    /// A price Pausely read from the service's own page for this currency, if it has one. The
    /// catalog's own plans and prices are not shown: they are not reliable enough to present as fact.
    private var typical: Decimal? {
        frequency == .monthly
            ? TallyCatalog.price(forServiceNamed: entry.name, payingIn: currencyManager.selectedCurrency)
            : nil
    }

    private var typed: Decimal? { SubscriptionEditDraft.parseAmount(amountText) }
    private var amount: Decimal? { amountText.isEmpty ? typical : typed }
    private var canAdd: Bool { (amount ?? 0) > 0 }
    private var currency: String { currencyManager.selectedCurrency }

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

                    VStack(spacing: 0) {
                        row(L10n.string("Billing cycle")) {
                            Picker(L10n.string("Billing cycle"), selection: $frequency) {
                                ForEach(BillingFrequency.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.inkText)
                        }
                        Hairline()
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
                // Always saved as what the person confirmed, in their own currency.
                onSelect(.individual, frequency, true, amount, nextBillingDate, hasFreeTrial ? trialEndsAt : nil)
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
    }

    /// The price, as a question the person can answer by typing. The catalog's figure is only the
    /// starting suggestion.
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(frequency == .yearly ? L10n.string("What do you pay each year?")
                 : frequency == .monthly ? L10n.string("What do you pay each month?") : L10n.string("What do you pay each time?"))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // The typical price is shown as a real figure, not a greyed-out hint: it is what
                // will be saved unless the person types over it.
                TextField("", text: $amountText,
                          prompt: Text(verbatim: typical.map { MoneyFormat.string($0, currency, locale: L10n.locale) } ?? "0.00")
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
            if amountText.isEmpty, typical != nil {
                Text("This is a typical price. Type over it if you pay something else.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        AdaptiveRow {
            Text(verbatim: title)
                .font(.body)
                .foregroundStyle(Color.inkText)
        } value: {
            content()
        }
        .frame(minHeight: 54)
    }
}
