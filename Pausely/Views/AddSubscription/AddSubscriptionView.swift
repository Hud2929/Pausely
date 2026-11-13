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
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @FocusState private var focusedField: Field?
    /// What is missing, said under the amount when "Add" is pressed without it.
    @State private var problem: String?
    @State private var showingPaywall = false

    enum Field {
        case name, amount
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
                    TextField(Self.nameHint(largeText: typeSize.isAccessibilitySize), text: $name, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
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
                        TextField(text: $amount, prompt: Text(verbatim: AmountText.text(for: 0, currency: currencyManager.selectedCurrency))) { EmptyView() }
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
                    }
                    Hairline()
                    row(L10n.string("Next renewal")) {
                        OptionalDatePicker(title: L10n.string("Next renewal"), date: $nextPayment,
                                           earliest: Calendar.billing.startOfDay(for: Date()))
                            .accessibilityIdentifier("nextPaymentPicker")
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
                    }
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        } actions: {
            Button(action: saveSubscription) { Text("Add subscription") }
                .buttonStyle(.ink)
                .disabled(name.isEmpty || amount.isEmpty)
                .accessibilityIdentifier("addSubscriptionButton")
                .accessibilityHint(name.isEmpty || amount.isEmpty ? "Enter a name and an amount." : "")
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
        .onAppear { focusedField = .name }
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

    func saveSubscription() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // "9,99" and "9.99" both work, and the amount stays an exact decimal.
        guard !trimmedName.isEmpty, let price = AmountText.parse(amount, currency: currencyManager.selectedCurrency) else {
            // Said on the form, beside what is missing (it was a system alert titled "Error").
            problem = L10n.string("Enter a name and an amount.")
            return
        }
        let newSub = Subscription(
            name: trimmedName,
            category: category.rawValue,
            amount: price,
            currency: currencyManager.selectedCurrency,
            billingFrequency: frequency,
            nextBillingDate: nextPayment
        )
        Task {
            do {
                _ = try await store.addSubscription(newSub)
                Feel.landed()
                dismiss()
            } catch {
                // Only a refusal throws (the free plan's limit): what's typed stays, and the way past it opens.
                showingPaywall = true
            }
        }
    }
}
