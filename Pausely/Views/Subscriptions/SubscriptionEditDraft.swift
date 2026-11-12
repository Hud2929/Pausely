import Foundation

/// The editable fields of a subscription, plus validation and change detection.
/// Pure value logic so the edit screen stays thin and every rule is unit tested.
struct SubscriptionEditDraft: Equatable {
    var name: String
    var amountText: String
    var currency: String
    var frequency: BillingFrequency
    var nextBillingDate: Date?
    var category: String?
    /// Days before renewal to remind. 0 means no reminder.
    var reminderDays: Int

    static let reminderOptions: [Int] = [0, 1, 3, 7]

    init(from subscription: Subscription) {
        name = subscription.name
        amountText = AmountText.text(for: subscription.amount, currency: subscription.currency)
        currency = subscription.currency
        frequency = subscription.billingFrequency
        // Show the upcoming renewal, not an anchor that may be months in the past.
        nextBillingDate = subscription.calculatedNextBillingDate
        category = subscription.category
        reminderDays = subscription.notifyBeforeDays
    }

    // MARK: Amount

    /// What is in the amount field, read as an amount in the chosen currency (`AmountText`).
    var parsedAmount: Decimal? { AmountText.parse(amountText, currency: currency) }

    // MARK: Validation

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var nameError: String? { trimmedName.isEmpty ? L10n.string("Add a name") : nil }

    var amountError: String? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return L10n.string("Enter the amount") }
        if parsedAmount != nil { return nil }
        return AmountText.isTooLarge(amountText, currency: currency)
            ? L10n.string("That is more than Pausely can track.")
            : L10n.string("Enter a valid amount")
    }

    var isValid: Bool { nameError == nil && amountError == nil }

    // MARK: Change tracking

    func isDirty(comparedTo original: Subscription) -> Bool {
        let amountChanged: Bool
        if let amount = parsedAmount {
            // Compared at the currency's own precision: 16.49 typed equals 16.49 stored, and a price in
            // dinars is not "changed" by being shown.
            amountChanged = amount != AmountText.rounded(original.amount, currency: currency)
        } else {
            amountChanged = amountText != AmountText.text(for: original.amount, currency: original.currency)
        }
        return amountChanged || differsOutsideAmount(original)
    }

    private func differsOutsideAmount(_ original: Subscription) -> Bool {
        trimmedName != original.name
            || currency != original.currency
            || frequency != original.billingFrequency
            || category != original.category
            || reminderDays != original.notifyBeforeDays
            || !sameDay(nextBillingDate, original.calculatedNextBillingDate)
    }

    private func sameDay(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return Calendar.current.isDate(x, inSameDayAs: y)
        default: return false
        }
    }

    /// The subscription with these edits applied. Everything not editable here is preserved.
    func applied(to original: Subscription, now: Date = Date()) -> Subscription? {
        guard isValid, let amount = parsedAmount else { return nil }
        var updated = original
        updated.name = trimmedName
        updated.amount = amount
        updated.currency = currency
        updated.billingFrequency = frequency
        // The stored date is the renewal anchor. Keep it unless the user picked a different day, so a
        // subscription that renews on the 31st keeps doing so (see RenewalSchedule).
        if !sameDay(nextBillingDate, original.calculatedNextBillingDate) {
            updated.nextBillingDate = nextBillingDate.map { Calendar.current.noon(of: $0) }
        }
        updated.category = category
        updated.notifyBeforeDays = reminderDays
        updated.updatedAt = now
        return updated
    }

    // MARK: Display helpers

    static func reminderLabel(_ days: Int) -> String {
        switch days {
        case 0: return "Off"
        case 1: return "1 day before"
        default: return "\(days) days before"
        }
    }

    /// Yearly cost for the live "that's X a year" hint.
    var yearlyCost: Decimal? {
        guard let amount = parsedAmount else { return nil }
        return amount * ProvenSubscription.periodsPerYear(frequency)
    }
}
