import Foundation

/// The editable fields of a subscription, plus validation and change detection.
/// Pure value logic so the edit screen stays thin and every rule is unit tested.
struct SubscriptionEditDraft: Equatable {
    var name: String
    var amountText: String
    var currency: String
    var frequency: BillingFrequency
    var nextBillingDate: Date?
    var isTrial: Bool
    var trialEndsAt: Date?
    var category: String?
    /// Days before renewal to remind. 0 means no reminder.
    var reminderDays: Int
    var paymentMethod: String
    var notes: String
    var splitCount: Int

    static let reminderOptions: [Int] = [0, 1, 3, 7]
    static let splitOptions: [Int] = [1, 2, 3, 4, 5, 6, 8, 10]

    init(from subscription: Subscription) {
        name = subscription.name
        amountText = AmountText.text(for: subscription.amount, currency: subscription.currency)
        currency = subscription.currency
        frequency = subscription.billingFrequency
        // Show the upcoming renewal, not an anchor that may be months in the past.
        nextBillingDate = subscription.calculatedNextBillingDate
        isTrial = subscription.status == .trial
        trialEndsAt = subscription.trialEndsAt
        category = subscription.category
        reminderDays = subscription.notifyBeforeDays
        paymentMethod = subscription.paymentMethod ?? ""
        notes = subscription.notes ?? ""
        splitCount = subscription.splitCount
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

    var normalizedPaymentMethod: String? {
        let trimmed = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func differsOutsideAmount(_ original: Subscription) -> Bool {
        trimmedName != original.name
            || currency != original.currency
            || frequency != original.billingFrequency
            || category != original.category
            || reminderDays != original.notifyBeforeDays
            || splitCount != original.splitCount
            || normalizedPaymentMethod != original.paymentMethod
            || normalizedNotes != original.notes
            || isTrial != (original.status == .trial)
            || !sameDay(isTrial ? trialEndsAt : nil, original.status == .trial ? original.trialEndsAt : nil)
            || !sameDay(nextBillingDate, original.calculatedNextBillingDate)
    }

    private func sameDay(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return Calendar.billing.isDate(x, inSameDayAs: y)
        default: return false
        }
    }

    /// The subscription with these edits applied. Everything not editable here is preserved.
    func applied(to original: Subscription) -> Subscription? {
        guard isValid, let amount = parsedAmount else { return nil }
        var updated = original
        updated.name = trimmedName
        updated.amount = amount
        updated.currency = currency
        updated.billingFrequency = frequency
        // The stored date is the renewal anchor. Keep it unless the user picked a different day, so a
        // subscription that renews on the 31st keeps doing so (see RenewalSchedule).
        if !sameDay(nextBillingDate, original.calculatedNextBillingDate) {
            updated.nextBillingDate = nextBillingDate.map { Calendar.billing.noon(of: $0) }
        }
        if isTrial {
            let end = trialEndsAt ?? updated.nextBillingDate
            updated.trialEndsAt = end.map { Calendar.billing.noon(of: $0) }
            if updated.status != .cancelled { updated.status = .trial }
        } else {
            updated.trialEndsAt = nil
            if updated.status == .trial { updated.status = .active }
        }
        updated.category = category
        updated.notifyBeforeDays = reminderDays
        updated.splitCount = max(1, min(20, splitCount))
        updated.paymentMethod = normalizedPaymentMethod
        updated.notes = normalizedNotes
        return updated
    }

    // MARK: Display helpers

    /// "Off", "1 day before", "3 days before", in the reader's language and digits.
    static func reminderLabel(_ days: Int) -> String {
        days == 0 ? L10n.string("Off") : L10n.string("\(days) days before")
    }

    /// "Just me" or "N people", in the reader's language and digits.
    static func splitLabel(_ count: Int) -> String {
        count <= 1 ? L10n.string("Just me") : L10n.string("\(count) people")
    }

    /// The user's per-period share when splitting a subscription.
    var perPeriodShare: Decimal? {
        guard let amount = parsedAmount else { return nil }
        return splitCount > 1
            ? AmountText.rounded(amount / Decimal(splitCount), currency: currency)
            : amount
    }

    /// Yearly cost for the live "that's X a year" hint: the exact share times the charges in a year, as on the
    /// subscription's page (rounded first, a split year was $72.00 here and $71.96 there, 2026-11-23).
    var yearlyCost: Decimal? {
        guard let amount = parsedAmount else { return nil }
        return amount / Decimal(max(1, splitCount)) * ProvenSubscription.periodsPerYear(frequency)
    }
}
