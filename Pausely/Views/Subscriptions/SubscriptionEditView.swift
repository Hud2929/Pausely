import SwiftUI

/// A calm, single-purpose edit form: name, amount, and four quiet rows. Save really saves.
struct SubscriptionEditView: View {
    let original: Subscription
    var onSaved: ((Subscription) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var draft: SubscriptionEditDraft
    /// The amount is the one big thing on this screen; it grows with the reader's text size.
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 52
    @State private var isSaving = false
    @State private var showDiscardConfirm = false
    /// The reader's text size, read on the screen: inside the navigation bar it is capped.
    @Environment(\.dynamicTypeSize) private var typeSize
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
        if let current = draft.category, !options.contains(SubscriptionCategory.label(for: current)) { options.insert(current, at: 0) }
        return options
    }

    /// The symbol in front of the amount field, as this person's locale writes it ("$", "US$", "€").
    private var amountPrefix: String {
        MoneyFormat.symbol(for: draft.currency)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        amountField
                        detailsCard
                        extraFields
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .readableScroll()
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if isDirty { showDiscardConfirm = true } else { dismiss() }
                    }
                    .foregroundStyle(Color.inkTextMuted)
                    .accessibilityIdentifier("editCancelButton")
                    .asksFirst(Text("Discard your changes?"), isPresented: $showDiscardConfirm,
                               largeText: typeSize.isAccessibilitySize) {
                        Button("Discard changes", role: .destructive) { dismiss() }
                        Button("Keep editing", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color.inkText)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(isDirty ? Color.inkText : Color.inkTextFaint)
                    .disabled(!isDirty || isSaving)
                    .accessibilityIdentifier("editSaveButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                        .foregroundStyle(Color.inkText)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isDirty)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ServiceLogoView(name: draft.trimmedName.isEmpty ? original.name : draft.trimmedName,
                                category: draft.category, size: 48)
                TextField(text: $draft.name, prompt: Hint.text(L10n.string("Name")), axis: .vertical) { Text("Name") }
                    .lineLimit(1...3)
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focus, equals: .name)
                    .onSubmit { focus = .amount }
                    .returnMovesOn(from: $draft.name) { focus = .amount }
                    .accessibilityLabel("Name")
                    .accessibilityIdentifier("editNameField")
            }
            if showValidation, let error = draft.nameError {
                ProblemLine(message: error, identifier: "editNameProblem")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Menu {
                    ForEach(currencyManager.currencies, id: \.code) { currency in
                        Button {
                            draft.currency = currency.code
                        } label: {
                            if currency.code == draft.currency {
                                Label("\(currency.code) · \(currency.localizedName())", systemImage: "checkmark")
                            } else {
                                Text("\(currency.code) · \(currency.localizedName())")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(amountPrefix)
                            .font(.question(.title))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color.inkTextMuted)
                }
                .accessibilityLabel("Currency, \(draft.currency)")

                TextField(text: $draft.amountText, prompt: Hint.text(AmountText.text(for: 0, currency: draft.currency))) { EmptyView() }
                    // As wide as the row, like the amount on the two forms that add a subscription, and
                    // drawn smaller when it is too long for the row: a field cuts off what does not fit.
                    .amountFont(for: draft.amountText.isEmpty ? AmountText.text(for: 0, currency: draft.currency) : draft.amountText,
                                base: amountSize)
                    .foregroundStyle(Color.inkText)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .amount)
                    .accessibilityLabel("Amount")
                    .accessibilityIdentifier("editAmountField")
            }

            if showValidation, let error = draft.amountError {
                ProblemLine(message: error, identifier: "editAmountProblem")
            } else {
                Text(draft.frequency.billingPeriodLabel)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
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

            if !draft.isTrial {
                divider

                row("Next renewal") {
                    OptionalDatePicker(title: L10n.string("Next renewal"), date: $draft.nextBillingDate)
                }
            }

            if original.status != .cancelled {
                divider
                Toggle(isOn: $draft.isTrial.animation(Motion.unlessReduced(Motion.touch))) {
                    Text("Free trial")
                        .font(.body)
                        .foregroundStyle(Color.inkText)
                }
                .tint(Color.inkTextMuted)
                .frame(minHeight: 54)
                .accessibilityIdentifier("editTrialToggle")

                if draft.isTrial {
                    divider
                    row("Trial ends") {
                        OptionalDatePicker(title: L10n.string("Trial ends"), date: $draft.trialEndsAt)
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
                            if option == SubscriptionCategory.label(for: draft.category) {
                                Label(SubscriptionCategory.localizedLabel(for: option), systemImage: "checkmark")
                            } else {
                                Text(verbatim: SubscriptionCategory.localizedLabel(for: option))
                            }
                        }
                    }
                } label: {
                    valueLabel(SubscriptionCategory.localizedLabel(for: draft.category))
                }
                .accessibilityLabel("Category, \(SubscriptionCategory.localizedLabel(for: draft.category))")
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

            divider

            row("Split between") {
                Menu {
                    ForEach(SubscriptionEditDraft.splitOptions, id: \.self) { count in
                        Button {
                            draft.splitCount = count
                        } label: {
                            if count == draft.splitCount {
                                Label(SubscriptionEditDraft.splitLabel(count), systemImage: "checkmark")
                            } else {
                                Text(SubscriptionEditDraft.splitLabel(count))
                            }
                        }
                    }
                } label: {
                    valueLabel(SubscriptionEditDraft.splitLabel(draft.splitCount))
                }
                .accessibilityLabel("Split between, \(SubscriptionEditDraft.splitLabel(draft.splitCount))")
                .accessibilityIdentifier("editSplitPicker")
            }

            if draft.splitCount > 1, let share = draft.perPeriodShare {
                Text(L10n.string("Your share: \(draft.frequency.priced(MoneyFormat.string(share, draft.currency)))"))
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
            }
        }
    }

    private var extraFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Billed to")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.inkTextMuted)
                InkTextField(placeholder: "", text: $draft.paymentMethod, autocapitalization: .words)
                    .accessibilityLabel("Billed to")
                    .accessibilityIdentifier("editPaymentMethodField")
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
                InkTextField(placeholder: "", text: $draft.notes, autocapitalization: .sentences)
                    .accessibilityLabel("Notes")
                    .accessibilityIdentifier("editNotesField")
                Text("For example: Shared with Sarah, or promo rate ends in October.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func billingPreset(_ label: String) -> some View {
        let selected = draft.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(label) == .orderedSame
        return Button {
            Feel.selection()
            draft.paymentMethod = selected ? "" : label
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

    @ViewBuilder
    private var footnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let yearly = draft.yearlyCost {
                Text(draft.splitCount > 1
                     ? L10n.string("Your share is \(MoneyFormat.string(yearly, draft.currency)) a year")
                     : L10n.string("That's \(MoneyFormat.string(yearly, draft.currency)) a year"))
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
            }
            if draft.reminderDays > 0 && draft.nextBillingDate == nil && !(draft.isTrial && draft.trialEndsAt != nil) {
                Text("Add its renewal date to get reminders.")
                    .font(.footnote)
                    .foregroundStyle(Color.decide)
            }
        }
    }

    // MARK: - Pieces

    private func row<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        AdaptiveRow(alignment: .center) {
            Text(title)
                .font(.body)
                .foregroundStyle(Color.inkText)
        } value: {
            content()
        }
        .frame(minHeight: 54)
    }

    private func valueLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.inkTextFaint)
        }
    }

    private var divider: some View { Hairline() }


    private func finishSaving(_ updated: Subscription) {
        Feel.landed()
        onSaved?(updated)
        dismiss()
    }

    private func save() async {
        focus = nil
        guard let updated = draft.applied(to: original) else {
            showValidation = true
            focus = draft.nameError != nil ? .name : .amount
            return
        }
        isSaving = true
        defer { isSaving = false }
        await SubscriptionStore.shared.updateSubscription(updated)
        finishSaving(updated)
    }
}

#Preview {
    SubscriptionEditView(subscription: Subscription(name: "Netflix", price: 16.49, category: "Entertainment", billingFrequency: .monthly))
}
