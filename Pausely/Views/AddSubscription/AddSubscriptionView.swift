import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: BillingFrequency = .monthly
    @State private var category: SubscriptionCategory = .other
    /// Nil until the person picks a day. A date is never filled in for them.
    @State private var nextPayment: Date?
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @FocusState private var focusedField: Field?
    @State private var showError = false
    @State private var showingPaywall = false
    @State private var errorMessage = ""

    enum Field {
        case name, amount
    }

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
                        .accessibilityIdentifier("cancelButton")
                        Spacer()
                    }
                    .padding(.bottom, -12)

                    TextField("Netflix, Spotify…", text: $name)
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                        .accessibilityLabel(Text("Service name"))
                        .accessibilityIdentifier("serviceNameTextField")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(frequency == .yearly ? L10n.string("What do you pay each year?") : L10n.string("What do you pay each month?"))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .opacity(frequency == .monthly || frequency == .yearly ? 1 : 0)
                            .accessibilityHidden(!(frequency == .monthly || frequency == .yearly))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TextField(text: $amount, prompt: Text(verbatim: AmountText.text(for: 0, currency: currencyManager.selectedCurrency))) { EmptyView() }
                                .font(.system(size: 44, weight: .bold, design: .serif))
                                .foregroundStyle(Color.inkText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .amount)
                                .accessibilityLabel(Text("Amount"))
                                .accessibilityIdentifier("amountTextField")
                            Text(verbatim: currencyManager.selectedCurrency)
                                .font(.proof(.subheadline))
                                .foregroundStyle(Color.inkTextMuted)
                        }
                    }

                    VStack(spacing: 0) {
                        row(L10n.string("Billing cycle")) {
                            Picker("Frequency", selection: $frequency) {
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
            }
            .scrollDismissesKeyboard(.interactively)

            Button(action: saveSubscription) { Text("Add subscription") }
                .buttonStyle(.ink)
                .disabled(name.isEmpty || amount.isEmpty)
                .accessibilityIdentifier("addSubscriptionButton")
                .accessibilityHint(name.isEmpty || amount.isEmpty ? "Enter a name and an amount." : "")
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.ink)
        }
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { focusedField = .name }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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

    func saveSubscription() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // "9,99" and "9.99" both work, and the amount stays an exact decimal.
        guard !trimmedName.isEmpty, let price = AmountText.parse(amount, currency: currencyManager.selectedCurrency) else {
            errorMessage = L10n.string("Enter a name and an amount.")
            showError = true
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
