import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The amount is the one big thing on this screen; it grows with the reader's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 44
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: BillingFrequency = .monthly
    @State private var category: SubscriptionCategory = .other
    /// Nil until the person picks a day. A date is never filled in for them.
    @State private var nextPayment: Date?
    @State private var hasFreeTrial = false
    @State private var trialEndsAt: Date?
    @State private var reminderDays: Int = 3
    @State private var paymentMethod = ""
    @State private var notes = ""
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @FocusState private var focusedField: Field?
    /// What is missing, said under the amount when "Add" is pressed without it.
    @State private var problem: String?
    @State private var showingPaywall = false

    enum Field {
        case name, amount
    }

    /// `startName`: a name to begin with, from a sender Find in Email read but couldn't call a subscription.
    init(startName: String = "") {
        _name = State(initialValue: startName)
    }

    /// What the empty name field says: two examples, or "Name" at the accessibility text sizes.
    /// An empty field shows its hint on one line, and there the examples were cut off
    /// ("Netflix, Spo…").
    nonisolated static func nameHint(largeText: Bool) -> String {
        largeText ? L10n.string("Name") : L10n.string("Netflix, Spotify…")
    }

    var body: some View {
        ActionScreen(dismissesKeyboard: true) {
            VStack(alignment: .leading, spacing: 24) {
                // The way out and the name are one group, closer together than the groups below.
                VStack(alignment: .leading, spacing: 12) {
                    LeaveButton("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelButton")
                    TextField(text: $name, prompt: Hint.text(Self.nameHint(largeText: typeSize.isAccessibilitySize)), axis: .vertical) { EmptyView() }
                        .lineLimit(1...3)
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.leading)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                        .returnMovesOn(from: $name) { focusedField = .amount }
                        .accessibilityLabel(Text("Service name"))
                        .accessibilityIdentifier("serviceNameTextField")
                }

                VStack(alignment: .leading, spacing: 6) {
                    // The question fits the billing cycle, as on the plan sheet (it used to vanish
                    // for anything but monthly and yearly).
                    Text(frequency == .yearly ? L10n.string("What do you pay each year?")
                         : frequency == .monthly ? L10n.string("What do you pay each month?") : L10n.string("What do you pay each time?"))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField(text: $amount, prompt: Hint.text(AmountText.text(for: 0, currency: currencyManager.selectedCurrency))) { EmptyView() }
                            .amountFont(for: amount.isEmpty ? AmountText.text(for: 0, currency: currencyManager.selectedCurrency) : amount,
                                        base: amountSize)
                            .foregroundStyle(Color.inkText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                            .accessibilityLabel(Text("Amount"))
                            .accessibilityIdentifier("amountTextField")
                        Text(verbatim: currencyManager.selectedCurrency)
                            .font(.proof(.subheadline))
                            .foregroundStyle(Color.inkTextMuted)
                    }
                    if let problem { ProblemLine(message: problem, identifier: "addProblem") }
                }

                VStack(spacing: 0) {
                    row(L10n.string("Billing cycle")) {
                        Picker(L10n.string("Billing cycle"), selection: $frequency) {
                            ForEach(BillingFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.inkText)
                        .tapArea(.trailing)
                    }
                    if !hasFreeTrial {
                        Hairline()
                        row(L10n.string("Next renewal")) {
                            OptionalDatePicker(title: L10n.string("Next renewal"), date: $nextPayment,
                                               earliest: Calendar.billing.startOfDay(for: Date()))
                                .accessibilityIdentifier("nextPaymentPicker")
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
                    .accessibilityIdentifier("addTrialToggle")
                    if hasFreeTrial {
                        Hairline()
                        row(L10n.string("Trial ends")) {
                            OptionalDatePicker(title: L10n.string("Trial ends"), date: $trialEndsAt,
                                               earliest: Calendar.billing.startOfDay(for: Date()))
                        }
                        if trialEndsAt == nil {
                            Text("Add the day the trial ends, so Pausely can ask you before it charges.")
                                .font(.footnote)
                                .foregroundStyle(Color.decide)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                    Hairline()
                    row(L10n.string("Category")) {
                        Picker("Category", selection: $category) {
                            ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                                Text(verbatim: cat.localizedName).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.inkText)
                        .tapArea(.trailing)
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
                            .accessibilityIdentifier("addPaymentMethodField")
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
                            .accessibilityIdentifier("addNotesField")
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
            Button(action: saveSubscription) { Text("Add subscription") }
                .buttonStyle(.ink)
                .disabled(name.isEmpty || amount.isEmpty || (hasFreeTrial && trialEndsAt == nil))
                .accessibilityIdentifier("addSubscriptionButton")
                .accessibilityHint(
                    name.isEmpty || amount.isEmpty
                        ? L10n.string("Enter a name and an amount.")
                        : (hasFreeTrial && trialEndsAt == nil
                            ? L10n.string("Add the day the trial ends, so Pausely can ask you before it charges.")
                            : "")
                )
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
        .onAppear { focusedField = name.isEmpty ? .name : .amount }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView()
        }
        .onChange(of: name) { _, _ in problem = nil }
        .onChange(of: amount) { _, _ in problem = nil }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        AdaptiveRow(alignment: .center) {
            Text(verbatim: title)
                .font(.body)
                .foregroundStyle(Color.inkText)
        } value: {
            content()
        }
        .frame(minHeight: 54)
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

    func saveSubscription() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // "9,99" and "9.99" both work, and the amount stays an exact decimal.
        guard !trimmedName.isEmpty, let price = AmountText.parse(amount, currency: currencyManager.selectedCurrency) else {
            // Said on the form, beside what is missing (it was a system alert titled "Error").
            problem = L10n.string("Enter a name and an amount.")
            return
        }
        let trimmedPayment = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSub = Subscription(
            name: trimmedName,
            category: category.rawValue,
            amount: price,
            currency: currencyManager.selectedCurrency,
            billingFrequency: frequency,
            nextBillingDate: hasFreeTrial ? nil : nextPayment,
            notifyBeforeDays: reminderDays,
            trialEndsAt: hasFreeTrial ? trialEndsAt : nil,
            status: hasFreeTrial ? .trial : .active,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            paymentMethod: trimmedPayment.isEmpty ? nil : trimmedPayment
        )
        Task {
            do {
                _ = try await store.addSubscription(newSub)
                Feel.landed()
                dismiss()
            } catch SubscriptionStore.SubscriptionLimitError.freeTierLimitReached {
                // Free plan limit reached: keep what's typed and open Pro.
                showingPaywall = true
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}
