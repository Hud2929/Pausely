import SwiftUI

/// A calm, single-purpose edit form: name, amount, and four quiet rows. Save really saves.
struct SubscriptionEditView: View {
    let original: Subscription
    var onSaved: ((Subscription) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var draft: SubscriptionEditDraft
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showDiscardConfirm = false
    @State private var showValidation = false
    @FocusState private var focus: Field?

    private enum Field { case name, amount }

    init(subscription: Subscription, onSaved: ((Subscription) -> Void)? = nil) {
        self.original = subscription
        self.onSaved = onSaved
        _draft = State(initialValue: SubscriptionEditDraft(from: subscription))
    }

    private var isDirty: Bool { draft.isDirty(comparedTo: original) }

    private var categoryOptions: [String] {
        var options = SubscriptionCategory.allCases.map(\.displayName)
        if let current = draft.category, !options.contains(current) { options.insert(current, at: 0) }
        return options
    }

    private var currencySymbol: String {
        currencyManager.currencies.first { $0.code == draft.currency }?.symbol ?? draft.currency
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidianBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        header
                        amountField
                        detailsCard
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if isDirty { showDiscardConfirm = true } else { dismiss() }
                    }
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .accessibilityIdentifier("editCancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color.accentMint)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(isDirty ? Color.accentMint : Color.obsidianTextTertiary)
                    .disabled(!isDirty || isSaving)
                    .accessibilityIdentifier("editSaveButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                        .foregroundStyle(Color.accentMint)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog("Discard your changes?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ServiceLogoView(name: draft.trimmedName.isEmpty ? original.name : draft.trimmedName,
                            category: draft.category, size: 64)
                .accessibilityHidden(true)

            TextField("Name", text: $draft.name)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focus, equals: .name)
                .onSubmit { focus = .amount }
                .accessibilityLabel("Name")
                .accessibilityIdentifier("editNameField")

            if showValidation, let error = draft.nameError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Amount

    private var amountField: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Spacer(minLength: 0)
                Menu {
                    ForEach(currencyManager.currencies, id: \.code) { currency in
                        Button {
                            draft.currency = currency.code
                        } label: {
                            if currency.code == draft.currency {
                                Label("\(currency.code) · \(currency.name)", systemImage: "checkmark")
                            } else {
                                Text("\(currency.code) · \(currency.name)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(currencySymbol)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.accentMint.opacity(0.7))
                }
                .accessibilityLabel("Currency, \(draft.currency)")

                TextField("0.00", text: $draft.amountText)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Color.accentMint)
                    .keyboardType(.decimalPad)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 90)
                    .focused($focus, equals: .amount)
                    .accessibilityLabel("Amount")
                    .accessibilityIdentifier("editAmountField")
                Spacer(minLength: 0)
            }

            if showValidation, let error = draft.amountError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
            } else {
                Text(draft.frequency.billingPeriodLabel)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = .amount }
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: 0) {
            row("Billing cycle") {
                Menu {
                    ForEach(BillingFrequency.allCases) { frequency in
                        Button {
                            draft.frequency = frequency
                        } label: {
                            if frequency == draft.frequency {
                                Label(frequency.displayName, systemImage: "checkmark")
                            } else {
                                Text(frequency.displayName)
                            }
                        }
                    }
                } label: {
                    valueLabel(draft.frequency.displayName)
                }
                .accessibilityLabel("Billing cycle, \(draft.frequency.displayName)")
            }

            divider

            row("Next payment") {
                if draft.nextBillingDate != nil {
                    DatePicker("Next payment", selection: Binding(
                        get: { draft.nextBillingDate ?? Date() },
                        set: { draft.nextBillingDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                    .tint(Color.accentMint)
                } else {
                    Button {
                        HapticStyle.light.trigger()
                        draft.nextBillingDate = Date()
                    } label: {
                        Text("Set date")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.accentMint)
                    }
                }
            }

            divider

            row("Category") {
                Menu {
                    ForEach(categoryOptions, id: \.self) { option in
                        Button {
                            draft.category = option
                        } label: {
                            if option == draft.category {
                                Label(option, systemImage: "checkmark")
                            } else {
                                Text(option)
                            }
                        }
                    }
                } label: {
                    valueLabel(draft.category ?? "Other")
                }
                .accessibilityLabel("Category, \(draft.category ?? "Other")")
            }

            divider

            row("Remind me") {
                Menu {
                    ForEach(SubscriptionEditDraft.reminderOptions, id: \.self) { days in
                        Button {
                            draft.reminderDays = days
                        } label: {
                            if days == draft.reminderDays {
                                Label(SubscriptionEditDraft.reminderLabel(days), systemImage: "checkmark")
                            } else {
                                Text(SubscriptionEditDraft.reminderLabel(days))
                            }
                        }
                    }
                } label: {
                    valueLabel(SubscriptionEditDraft.reminderLabel(draft.reminderDays))
                }
                .accessibilityLabel("Remind me, \(SubscriptionEditDraft.reminderLabel(draft.reminderDays))")
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
    }

    @ViewBuilder
    private var footnote: some View {
        VStack(spacing: 6) {
            if let yearly = draft.yearlyCost {
                Text("That's \(MoneyFormat.string(yearly, draft.currency)) a year")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            if draft.reminderDays > 0 && draft.nextBillingDate == nil {
                Text("Set a payment date to get reminders.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Pieces

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 12)
            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
    }

    private func valueLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.obsidianTextTertiary)
        }
    }

    private var divider: some View {
        Divider()
            .overlay(Color.white.opacity(0.06))
            .padding(.leading, 16)
    }

    // MARK: - Save

    private func save() async {
        focus = nil
        guard let updated = draft.applied(to: original) else {
            showValidation = true
            HapticStyle.error.trigger()
            focus = draft.nameError != nil ? .name : .amount
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await SubscriptionStore.shared.updateSubscription(updated)
            HapticStyle.success.trigger()
            onSaved?(updated)
            dismiss()
        } catch {
            HapticStyle.error.trigger()
            saveError = "Your changes weren't saved. \(error.localizedDescription)"
        }
    }
}

#Preview {
    SubscriptionEditView(subscription: Subscription(name: "Netflix", price: 16.49, category: "Entertainment", billingFrequency: .monthly))
}
