import SwiftUI

struct SmartURLInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var urlParser = SmartURLParser.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared

    @State private var urlText = ""
    @State private var isParsing = false
    @State private var parsedResult: ParsedSubscription?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAddDetails = false
    @State private var showingPaywall = false

    // Subscription details (editable)
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedCurrency: String = "USD"
    @State private var frequency: BillingFrequency = .monthly
    @State private var category: ServiceCategory = .other
    @State private var nextBillingDate: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // URL Input Section
                        urlInputSection

                        if let parsed = parsedResult {
                            // Parsed Result Card
                            ParsedResultCard(result: parsed)

                            // Edit Details Section
                            if showAddDetails {
                                editDetailsSection
                            }

                            // Action Buttons
                            actionButtons
                        }

                        // Recent Parses
                        if !urlParser.recentParses.isEmpty && parsedResult == nil {
                            recentParsesSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add from URL")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Connection Issue", isPresented: $showError) {
                if isTableNotFoundError(errorMessage) {
                    Button("Continue", role: .none) {
                        // Data is already saved locally; dismiss and continue
                        dismiss()
                    }
                    Button("Try Again", role: .none) {
                        // Just dismiss and let user try again
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingPaywall) {
                StoreKitUpgradeView(currentSubscriptionCount: 0)
            }
        }
    }

    /// Checks if error message indicates table not found
    private func isTableNotFoundError(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("database") ||
               lowercased.contains("connection") ||
               lowercased.contains("could not find") ||
               lowercased.contains("does not exist") ||
               lowercased.contains("schema cache") ||
               lowercased.contains("offline")
    }

    private var urlInputSection: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(AppTypography.displayLarge)
                    .foregroundStyle(Color.luxuryGold)

                Text("Paste Subscription URL")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.white)

                Text("Paste a link to Netflix, Spotify, or any subscription service")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            // URL Input
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.white.opacity(0.5))

                TextField("https://...", text: $urlText)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("urlTextField")

                if !urlText.isEmpty {
                    Button(action: { urlText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .accessibilityLabel("Clear URL")
                }

                Button(action: parseURL) {
                    if isParsing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.luxuryGold)
                    }
                }
                .accessibilityLabel("Parse URL")
                .disabled(urlText.isEmpty || isParsing)
                .accessibilityHint(urlText.isEmpty ? "Please enter a URL first" : isParsing ? "Please wait, parsing URL" : "")
            }
            .padding()
            .glass(intensity: 0.2, tint: .white)

            // Paste Button
            Button(action: pasteFromClipboard) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste from Clipboard")
                }
                .font(AppTypography.bodySmall)
                .foregroundStyle(Color.luxuryGold)
            }
            .accessibilityIdentifier("pasteFromClipboardButton")
            .accessibilityLabel("Paste URL from clipboard")
        }
    }

    private var editDetailsSection: some View {
        VStack(spacing: 20) {
            Text("Subscription Details")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Name
            EnhancedFormField(title: "Name") {
                TextField("Service name", text: $name)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("serviceNameTextField")
            }

            // Amount & Currency
            HStack(spacing: 12) {
                EnhancedFormField(title: "Amount") {
                    HStack {
                        Text(currencyManager.currencySymbol(for: selectedCurrency))
                            .foregroundStyle(Color.luxuryGold)
                        TextField("0.00", text: $amount)
                            .foregroundStyle(.white)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("amountTextField")
                    }
                }

                // Currency Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currency")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)

                    CurrencyPickerButton(selectedCurrency: $selectedCurrency)
                }
            }

            // Billing Frequency
            VStack(alignment: .leading, spacing: 8) {
                Text("Billing Frequency")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)

                Picker("Frequency", selection: $frequency) {
                    ForEach(BillingFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName)
                            .tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                .colorMultiply(.white)
            }

            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(ServiceCategory.allCases, id: \.self) { cat in
                        CategoryChip(
                            category: cat,
                            isSelected: category == cat
                        ) {
                            withAnimation {
                                category = cat
                            }
                        }
                    }
                }
            }

            // Next Billing Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Billing Date")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)

                DatePicker("", selection: $nextBillingDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .colorMultiply(.white)
                    .padding()
                    .glass(intensity: 0.1, tint: .white)
            }
        }
        .padding()
        .glass(intensity: 0.1, tint: .white)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !showAddDetails {
                Button(action: { showAddDetails = true }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Details")
                    }
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.luxuryPurple.opacity(0.3))
                    .cornerRadius(12)
                }
            }

            Button(action: saveSubscription) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Add Subscription")
                }
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.luxuryPurple, Color.luxuryPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(name.isEmpty || amount.isEmpty)
            .accessibilityHint(name.isEmpty || amount.isEmpty ? "Please enter a service name and amount" : "")
            .opacity(name.isEmpty || amount.isEmpty ? 0.6 : 1)
        }
    }

    private var recentParsesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)

            ForEach(urlParser.recentParses.prefix(3)) { parse in
                RecentParseRow(parse: parse)
                    .onTapGesture {
                        withAnimation {
                            parsedResult = parse
                            populateFromParsed(parse)
                        }
                    }
            }
        }
    }

    // MARK: - Actions

    private func parseURL() {
        guard !urlText.isEmpty else { return }

        isParsing = true
        HapticStyle.medium.trigger()

        Task {
            if let result = await urlParser.parseURL(urlText) {
                await MainActor.run {
                    self.parsedResult = result
                    self.populateFromParsed(result)
                    self.isParsing = false
                    HapticStyle.success.trigger()
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Could not recognize this URL. Please check the link and try again."
                    self.showError = true
                    self.isParsing = false
                    HapticStyle.error.trigger()
                }
            }
        }
    }

    private func pasteFromClipboard() {
        if let pasted = UIPasteboard.general.string {
            urlText = pasted
            parseURL()
        }
    }

    private func populateFromParsed(_ parsed: ParsedSubscription) {
        name = parsed.name
        amount = parsed.price.map { String(format: "%.2f", $0) } ?? ""
        selectedCurrency = parsed.currency
        category = parsed.category

        // Try to find the service in our database for more details
        if SubscriptionActionManager.shared.getService(for: parsed.name) != nil {
            // Use service details
        }
    }

    private func saveSubscription() {
        guard let price = Double(amount), !name.isEmpty else {
            HapticStyle.warning.trigger()
            return
        }

        // Check limit before attempting to save (UI-level enforcement)
        guard paymentManager.canAddSubscription(currentCount: store.subscriptions.count) else {
            showingPaywall = true
            return
        }

        HapticStyle.success.trigger()

        let newSubscription = Subscription(
            name: name,
            description: parsedResult?.description,
            logoUrl: parsedResult?.logoURL?.absoluteString,
            category: category.rawValue,
            amount: Decimal(price),
            currency: selectedCurrency,
            billingFrequency: frequency,
            nextBillingDate: nextBillingDate,
            canPause: parsedResult?.directPauseURL != nil,
            pauseUrl: parsedResult?.directPauseURL?.absoluteString
        )

        Task {
            do {
                _ = try await store.addSubscription(newSubscription)
                await MainActor.run { dismiss() }
            } catch _ as SubscriptionStore.SubscriptionLimitError {
                // Show paywall when subscription limit is reached
                await MainActor.run {
                    showingPaywall = true
                }
            } catch {
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

    /// Shows the database setup required alert
    private func showDatabaseSetupAlert() {
        errorMessage = """
        Database Not Set Up

        To fix this:
        1. Go to Supabase Dashboard
        2. Open SQL Editor
        3. Run FINAL_SUPABASE_SETUP.sql
        4. Return and try again

        Need help? Contact pausely@proton.me
        """
        showError = true
    }
}

struct SmartURLInputView_Previews: PreviewProvider {
    static var previews: some View {
        SmartURLInputView()
    }
}
