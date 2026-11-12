//
//  CatalogAddSheet.swift
//  Pausely
//
//  Adding a service from the catalog: what the person pays, how often, and when it next charges.
//

import SwiftUI

struct CatalogAddSheet: View {
    let entry: CatalogEntry
    /// How often it bills, what the person pays, the next payment if they set one, and the day a free
    /// trial ends if they are in one.
    let onAdd: (BillingFrequency, Decimal, Date?, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    /// The amount is the one big thing on this screen; it grows with the reader's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 44

    @State private var frequency: BillingFrequency = .monthly
    /// What the person typed. Empty means "the typical price is right".
    @State private var amountText = ""
    /// Both nil until the person picks a day: a date is never filled in for them.
    @State private var nextBillingDate: Date?
    @State private var hasFreeTrial = false
    @State private var trialEndsAt: Date?
    @FocusState private var amountFocused: Bool

    // MARK: - Price

    /// A price Pausely read from the service's own page for this currency, if it has one
    /// (`TallyCatalog`). Otherwise the field starts empty and the person types what they pay.
    private var typical: Decimal? {
        frequency == .monthly
            ? TallyCatalog.price(forServiceNamed: entry.name, payingIn: currencyManager.selectedCurrency)
            : nil
    }

    private var typed: Decimal? { AmountText.parse(amountText, currency: currency) }
    private var amount: Decimal? { amountText.isEmpty ? typical : typed }
    /// A trial is tracked for the day it ends, so saying "I'm on a free trial" needs that day.
    private var canAdd: Bool { (amount ?? 0) > 0 && (!hasFreeTrial || trialEndsAt != nil) }
    private var currency: String { currencyManager.selectedCurrency }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        LeaveButton("Cancel") { dismiss() }
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
                        // On a free trial the day it ends is the first charge, and it becomes the renewal
                        // date then (`SubscriptionLifecycle.afterTrial`): one date is asked for, not two.
                        if !hasFreeTrial {
                            Hairline()
                            row(L10n.string("Next renewal")) {
                                OptionalDatePicker(title: L10n.string("Next renewal"), date: $nextBillingDate,
                                                   earliest: Calendar.billing.startOfDay(for: Date()))
                            }
                        }
                        Hairline()
                        Toggle(isOn: $hasFreeTrial.animation(Motion.unlessReduced(Motion.touch))) {
                            Text("I'm on a free trial")
                                .font(.body)
                                .foregroundStyle(Color.inkText)
                        }
                        .tint(Color.inkTextMuted)
                        .frame(minHeight: 54)
                        .accessibilityIdentifier("tierTrialToggle")
                        if hasFreeTrial {
                            Hairline()
                            row(L10n.string("Trial ends")) {
                                OptionalDatePicker(title: L10n.string("Trial ends"), date: $trialEndsAt,
                                                   earliest: Calendar.billing.startOfDay(for: Date()))
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
                // Saved as what the person confirmed, in their own currency.
                guard let amount else { return }
                onAdd(frequency, amount, hasFreeTrial ? nil : nextBillingDate, hasFreeTrial ? trialEndsAt : nil)
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
        .inkScreen()
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
                          prompt: Text(verbatim: typical.map { MoneyFormat.string($0, currency, locale: L10n.locale) }
                                                   ?? AmountText.text(for: 0, currency: currency))
                            .foregroundStyle(typical == nil ? Color.inkTextFaint : Color.inkText))
                    .font(.total(amountSize))
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
