import SwiftUI

struct LuxuryAddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: BillingFrequency = .monthly
    @State private var category: SubscriptionCategory = .other
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @FocusState private var focusedField: Field?
    @State private var showError = false
    @State private var errorMessage = ""

    enum Field {
        case name, amount
    }

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Subscription")
                            .font(AppTypography.displayMedium)
                            .foregroundStyle(.white)

                        Text("Track a new recurring expense")
                            .font(AppTypography.bodyLarge)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Service Name")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)

                            TextField("Netflix, Spotify...", text: $name)
                                .font(AppTypography.bodyLarge)
                                .foregroundStyle(.white)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .padding()
                                .glass(intensity: 0.2, tint: .white)
                                .accessibilityIdentifier("serviceNameTextField")
                        }

                        // Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)

                            HStack {
                                Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency))
                                    .font(AppTypography.headlineLarge)
                                    .foregroundStyle(Color.luxuryGold)

                                TextField("0.00", text: $amount)
                                    .font(AppTypography.displaySmall)
                                    .foregroundStyle(.white)
                                    .keyboardType(.decimalPad)
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .amount)
                                    .accessibilityIdentifier("amountTextField")
                            }
                            .padding()
                            .glass(intensity: 0.2, tint: .white)
                        }

                        // Frequency
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Billing Frequency")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)

                            Picker("Frequency", selection: $frequency) {
                                ForEach(BillingFrequency.allCases, id: \.self) { freq in
                                    Text(freq.displayName)
                                        .tag(freq)
                                        .foregroundStyle(.white)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            .glass(intensity: 0.2, tint: .white)
                        }

                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(AppTypography.labelLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)

                            Picker("Category", selection: $category) {
                                ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                                    Text(cat.rawValue.capitalized)
                                        .tag(cat)
                                        .foregroundStyle(.white)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .glass(intensity: 0.2, tint: .white)
                            .tint(.white)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Buttons
                    VStack(spacing: 16) {
                        Button(action: saveSubscription) {
                            Text("Add Subscription")
                                .premiumButton(gradient: [Color.luxuryPurple, Color.luxuryPink])
                        }
                        .disabled(name.isEmpty || amount.isEmpty)
                        .accessibilityIdentifier("addSubscriptionButton")
                        .accessibilityHint(name.isEmpty || amount.isEmpty ? "Please enter a service name and amount" : "")

                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(AppTypography.bodyLarge)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .accessibilityIdentifier("cancelButton")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    func saveSubscription() {
        guard let price = Double(amount), !name.isEmpty else {
            HapticStyle.warning.trigger()
            return
        }
        HapticStyle.success.trigger()
        let newSub = Subscription(
            name: name,
            category: category.rawValue,
            amount: Decimal(price),
            currency: currencyManager.selectedCurrency,
            billingFrequency: frequency
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

    /// Checks if error is a "table not found" error
    private func isTableNotFoundError(_ error: Error) -> Bool {
        if let dbError = error as? SubscriptionStore.DatabaseError {
            return dbError.isTableNotFound
        }

        let errorString = String(describing: error).lowercased()
        let tableNotFoundPatterns = [
            "could not find the table",
            "does not exist",
            "42p01",
            "relation",
            "schema cache"
        ]

        for pattern in tableNotFoundPatterns {
            if errorString.contains(pattern) {
                return true
            }
        }
        return false
    }
}

struct LuxuryAddSubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        LuxuryAddSubscriptionView()
    }
}
