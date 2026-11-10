import SwiftUI

struct LuxuryAddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: BillingFrequency = .monthly
    @State private var category: SubscriptionCategory = .other
    @State private var nextPayment = LuxuryAddSubscriptionView.onePeriod(after: Date(), .monthly)
    @State private var nextPaymentEdited = false
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @FocusState private var focusedField: Field?
    @State private var showError = false
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

                    TextField("Netflix, Spotify...", text: $name)
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                        .accessibilityLabel(Text("Service Name"))
                        .accessibilityIdentifier("serviceNameTextField")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(frequency == .yearly ? L10n.string("What do you pay each year?") : L10n.string("What do you pay each month?"))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .opacity(frequency == .monthly || frequency == .yearly ? 1 : 0)
                            .accessibilityHidden(!(frequency == .monthly || frequency == .yearly))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TextField("0.00", text: $amount)
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
                            .onChange(of: frequency) { _, newValue in
                                if !nextPaymentEdited { nextPayment = Self.onePeriod(after: Date(), newValue) }
                            }
                        }
                        Hairline()
                        row(L10n.string("Next payment")) {
                            DatePicker("Next payment", selection: Binding(get: { nextPayment }, set: { nextPayment = $0; nextPaymentEdited = true }),
                                       in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                                .labelsHidden()
                                .tint(Color.inkText)
                                .accessibilityIdentifier("nextPaymentPicker")
                        }
                        Hairline()
                        row(L10n.string("Category")) {
                            Picker("Category", selection: $category) {
                                ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                                    Text(cat.displayName).tag(cat)
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

            Button(action: saveSubscription) { Text("Add Subscription") }
                .buttonStyle(.ink)
                .disabled(name.isEmpty || amount.isEmpty)
                .accessibilityIdentifier("addSubscriptionButton")
                .accessibilityHint(name.isEmpty || amount.isEmpty ? "Please enter a service name and amount" : "")
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.ink)
        }
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { focusedField = .name }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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

    static func onePeriod(after date: Date, _ frequency: BillingFrequency, calendar: Calendar = .current) -> Date {
        let step: DateComponents
        switch frequency {
        case .weekly:     step = DateComponents(day: 7)
        case .biweekly:   step = DateComponents(day: 14)
        case .monthly:    step = DateComponents(month: 1)
        case .quarterly:  step = DateComponents(month: 3)
        case .semiannual: step = DateComponents(month: 6)
        case .yearly:     step = DateComponents(year: 1)
        }
        return calendar.date(byAdding: step, to: date) ?? date
    }

    func saveSubscription() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // "9,99" and "9.99" both work, and the amount stays an exact decimal.
        guard !trimmedName.isEmpty, let price = SubscriptionEditDraft.parseAmount(amount), price > 0 else {
            errorMessage = L10n.string("Enter a name and an amount.")
            showError = true
            return
        }
        Feel.landed()
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
                await MainActor.run { dismiss() }
            } catch {
                PauselyLogger.error("Error adding subscription: \(error)", category: "AddSubscription")
                await MainActor.run {
                    errorMessage = formatErrorMessage(error)
                    showError = true
                }
            }
        }
    }

    /// Formats database errors into user-friendly messages
    private func formatErrorMessage(_ error: Error) -> String {
        // Check if it's our custom DatabaseError
        if let dbError = error as? SubscriptionStore.DatabaseError {
            return dbError.detailedMessage
        }

        let errorString = String(describing: error).lowercased()
        let localizedError = error.localizedDescription.lowercased()

        // Check for table not found error (multiple patterns)
        let tableNotFoundPatterns = [
            "could not find the table",
            "does not exist",
            "42p01",
            "relation",
            "schema cache"
        ]

        for pattern in tableNotFoundPatterns {
            if errorString.contains(pattern) || localizedError.contains(pattern) {
                return """
                Database Not Set Up

                To fix this:
                1. Go to Supabase Dashboard
                2. Open SQL Editor
                3. Run FINAL_SUPABASE_SETUP.sql
                4. Return and try again

                Need help? Contact pausely@proton.me
                """
            }
        }

        // Check for authentication errors
        if errorString.contains("not authenticated") ||
           errorString.contains("jwt") ||
           localizedError.contains("unauthorized") {
            return "Please sign in to add subscriptions."
        }

        // Check for network errors
        if errorString.contains("network") ||
           errorString.contains("connection") ||
           errorString.contains("offline") ||
           errorString.contains("timeout") {
            return "Network error. Please check your internet connection and try again."
        }

        // Default: return the error description
        return error.localizedDescription
    }

}

struct LuxuryAddSubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        LuxuryAddSubscriptionView()
    }
}
