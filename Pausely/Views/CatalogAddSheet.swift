//
//  CatalogAddSheet.swift
//  Pausely
//
//  Adding a service from the catalog: what the person pays, how often, and when it next charges.
//

import SwiftUI

struct CatalogAddSheet: View {
    struct Extras: Equatable {
        var reminderDays: Int = 3
        var paymentMethod: String? = nil
        var notes: String? = nil
        var currency: String = CurrencyManager.shared.selectedCurrency
    }

    let entry: CatalogEntry
    /// How often it bills, what the person pays, the next payment if they set one, the day a free
    /// trial ends if they are in one, and optional everyday details.
    let onAdd: (BillingFrequency, Decimal, Date?, Date?, Extras) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    /// The amount is the one big thing on this screen; it grows with the reader's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 44

    @State private var frequency: BillingFrequency = .monthly
    @State private var selectedCurrency: String = CurrencyManager.shared.selectedCurrency
    /// What the person typed. Empty means "the typical price is right".
    @State private var amountText = ""
    /// Both nil until the person picks a day: a date is never filled in for them.
    @State private var nextBillingDate: Date?
    @State private var hasFreeTrial = false
    @State private var trialEndsAt: Date?
    @State private var reminderDays: Int = OnboardingProfile.load().validReminderDays
    @State private var paymentMethod = ""
    @State private var notes = ""
    @State private var isAdding = false
    @State private var showDiscardConfirm = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var amountFocused: Bool

    private var hasUnsavedChanges: Bool {
        !trimmedAmount.isEmpty || nextBillingDate != nil || trialEndsAt != nil
            || !paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Price

    /// A price Pausely read from the service's own page for this currency, if it has one
    /// (`TallyCatalog`). Otherwise the field starts empty and the person types what they pay.
    private var typical: Decimal? {
        frequency == .monthly
            ? TallyCatalog.price(forServiceNamed: entry.name, payingIn: selectedCurrency)
            : nil
    }

    private var trimmedAmount: String { amountText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var typed: Decimal? { AmountText.parse(amountText, currency: currency) }
    private var amount: Decimal? { trimmedAmount.isEmpty ? typical : typed }
    private var amountProblem: String? {
        guard !trimmedAmount.isEmpty, typed == nil else { return nil }
        return AmountText.isTooLarge(amountText, currency: currency)
            ? L10n.string("That is more than Pausely can track.")
            : L10n.string("Enter a valid amount")
    }
    /// A trial is tracked for the day it ends, so saying "I'm on a free trial" needs that day.
    private var canAdd: Bool { !isAdding && Self.canAdd(amount: amount, onTrial: hasFreeTrial, trialEnds: trialEndsAt) }

    nonisolated static func canAdd(amount: Decimal?, onTrial: Bool, trialEnds: Date?) -> Bool {
        (amount ?? 0) > 0 && !needsTrialDay(onTrial: onTrial, trialEnds: trialEnds)
    }

    /// True while a trial has no end day. The button is off then, and the sheet says why: with
    /// the switch on and nothing else said, the button simply went dim (first seen 2026-11-16,
    /// when the tour first captured this state in English).
    nonisolated static func needsTrialDay(onTrial: Bool, trialEnds: Date?) -> Bool {
        onTrial && trialEnds == nil
    }
    private var currency: String { selectedCurrency }

    // MARK: - Body

    var body: some View {
        NavigationStack {
        ActionScreen(dismissesKeyboard: true) {
            VStack(alignment: .leading, spacing: 24) {
                // The way out and the name are one group, closer together than the groups below.
                VStack(alignment: .leading, spacing: 12) {
                    LeaveButton("Cancel") {
                        if hasUnsavedChanges { showDiscardConfirm = true } else { dismiss() }
                    }
                    .disabled(isAdding)
                    .accessibilityIdentifier("catalogCancelButton")
                    .asksFirst(Text("Discard your changes?"), isPresented: $showDiscardConfirm,
                               largeText: typeSize.isAccessibilitySize) {
                        Button("Discard changes", role: .destructive) { dismiss() }
                        Button("Keep editing", role: .cancel) {}
                    }
                    MarkedWords(alignment: .center, spacing: 12) {
                        ServiceLogoView(name: entry.name, category: entry.category.rawValue, size: 48)
                    } words: {
                        Text(verbatim: entry.name)
                            .font(.question(.title))
                            .foregroundStyle(Color.inkText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if SubscriptionStore.shared.subscriptions.charging.contains(where: { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }) {
                        Text("Already on your list")
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                        .tapArea(.trailing)
                    }
                    // On a free trial the day it ends is the first charge, and it becomes the renewal
                    // date then (`SubscriptionLifecycle.afterTrial`): one date is asked for, not two.
                    if !hasFreeTrial {
                        Hairline()
                        row(L10n.string("Next renewal")) {
                            OptionalDatePicker(title: L10n.string("Next renewal"), date: $nextBillingDate,
                                               earliest: Calendar.billing.startOfDay(for: Date()),
                                               allowClear: true)
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
                        if Self.needsTrialDay(onTrial: hasFreeTrial, trialEnds: trialEndsAt) {
                            Text("Add the day the trial ends, so Pausely can ask you before it charges.")
                                .font(.footnote)
                                .foregroundStyle(Color.decide)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                                .accessibilityIdentifier("tierTrialDayNeeded")
                        }
                    }
                    Hairline()
                    row(L10n.string("Remind me")) {
                        Picker(L10n.string("Remind me"), selection: $reminderDays) {
                            ForEach(SubscriptionEditDraft.reminderOptions, id: \.self) { days in
                                Text(verbatim: SubscriptionEditDraft.reminderLabel(days)).tag(days)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.inkText)
                        .tapArea(.trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Billed to")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.inkTextMuted)
                            .accessibilityHidden(true)
                        InkTextField(placeholder: "", text: $paymentMethod, autocapitalization: .words)
                            .accessibilityLabel("Billed to")
                        Text("For example: Apple, Visa ending in 4242, or PayPal.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextFaint)
                            .fixedSize(horizontal: false, vertical: true)
                        LineOrStack(spacing: 8, lineSpacing: 8) {
                            billingPreset("Apple")
                            billingPreset("Google Play")
                            billingPreset("Amazon")
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.inkTextMuted)
                            .accessibilityHidden(true)
                        InkTextField(placeholder: "", text: $notes, autocapitalization: .sentences, multiline: true)
                            .accessibilityLabel("Notes")
                        Text("For example: Shared with Sarah, or promo rate ends in October.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        } actions: {
            Button {
                guard !isAdding, let amount else { return }
                isAdding = true
                Feel.tick()
                let trimmedPayment = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let extras = Extras(
                    reminderDays: reminderDays,
                    paymentMethod: trimmedPayment.isEmpty ? nil : trimmedPayment,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    currency: selectedCurrency
                )
                onAdd(frequency, amount, hasFreeTrial ? nil : nextBillingDate, hasFreeTrial ? trialEndsAt : nil, extras)
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
        }
        .inkScreen()
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
                    .foregroundStyle(Color.inkText)
            }
        }
        }
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
                let promptText = typical.map { AmountText.text(for: $0, currency: currency) }
                // The typical price is shown as a real figure, not a greyed-out hint: it is what
                // will be saved unless the person types over it.
                TextField(text: $amountText,
                          prompt: promptText.map { Text(verbatim: $0).foregroundStyle(Color.inkText) }
                                  ?? Hint.text(AmountText.text(for: 0, currency: currency))) { EmptyView() }
                    .amountFont(for: amountText.isEmpty
                                ? promptText ?? AmountText.text(for: 0, currency: currency)
                                : amountText,
                                base: amountSize)
                    .foregroundStyle(Color.inkText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .accessibilityLabel(Text("Amount"))
                    .accessibilityIdentifier("tierAmountField")
                Menu {
                    ForEach(currencyManager.currencies, id: \.code) { item in
                        Button {
                            selectedCurrency = item.code
                        } label: {
                            if item.code == selectedCurrency {
                                Label("\(item.code) · \(item.localizedName())", systemImage: "checkmark")
                            } else {
                                Text("\(item.code) · \(item.localizedName())")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(verbatim: currency)
                            .font(.proof(.subheadline))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.inkTextMuted)
                    .tapArea(.trailing)
                }
                .accessibilityLabel(Text("Currency, \(currency)"))
            }
            if let amountProblem {
                ProblemLine(message: amountProblem, identifier: "tierAmountProblem")
            } else if trimmedAmount.isEmpty, typical != nil {
                Text("This is a typical price. Type over it if you pay something else.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func billingPreset(_ label: String) -> some View {
        let selected = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(label) == .orderedSame
        return Button {
            Feel.selection()
            paymentMethod = selected ? "" : label
        } label: {
            Text(verbatim: label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(selected ? Color.paperInk : Color.inkTextMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.paper : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.paper : Color.outline, lineWidth: 1))
                .tapArea(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        AdaptiveRow(alignment: .center) {
            Text(verbatim: title)
                .font(.body)
                .foregroundStyle(Color.inkText)
                .accessibilityHidden(true)
        } value: {
            content()
        }
        .frame(minHeight: 54)
    }
}
