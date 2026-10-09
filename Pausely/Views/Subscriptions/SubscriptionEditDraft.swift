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
    static let maxAmount: Decimal = 100_000

    init(from subscription: Subscription) {
        name = subscription.name
        amountText = SubscriptionEditDraft.text(for: subscription.amount)
        currency = subscription.currency
        frequency = subscription.billingFrequency
        nextBillingDate = subscription.nextBillingDate
        category = subscription.category
        reminderDays = subscription.notifyBeforeDays
    }

    // MARK: Amount

    /// Accepts "9.99", "9,99", "$9.99", "C$ 1,299.00", "1.299,00".
    static func parseAmount(_ raw: String) -> Decimal? {
        if raw.contains("-") { return nil }
        if raw.contains("-") { return nil }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !text.isEmpty else { return nil }

        let lastDot = text.lastIndex(of: ".")
        let lastComma = text.lastIndex(of: ",")
        switch (lastDot, lastComma) {
        case let (dot?, comma?):
            // Whichever separator comes last is the decimal mark; the other groups thousands.
            if dot > comma { text = text.replacingOccurrences(of: ",", with: "") }
            else { text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
        case (nil, _?):
            // Only commas: "9,99" is a decimal; "1,299" (exactly 3 digits after a single comma) is a thousands group.
            let parts = text.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2, parts[1].count == 3, parts[0].count <= 3, !parts[0].isEmpty { text = text.replacingOccurrences(of: ",", with: "") }
            else { text = text.replacingOccurrences(of: ",", with: ".") }
        default:
            break
        }
        guard let value = Decimal(string: text), value > 0, value <= maxAmount else { return nil }
        return value
    }

    static func text(for amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    var parsedAmount: Decimal? { SubscriptionEditDraft.parseAmount(amountText) }

    // MARK: Validation

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var nameError: String? { trimmedName.isEmpty ? "Add a name" : nil }

    var amountError: String? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Enter the amount" }
        return parsedAmount == nil ? "Enter a valid amount" : nil
    }

    var isValid: Bool { nameError == nil && amountError == nil }

    // MARK: Change tracking

    func isDirty(comparedTo original: Subscription) -> Bool {
        let amountChanged: Bool
        if let amount = parsedAmount {
            amountChanged = SubscriptionEditDraft.cents(amount) != SubscriptionEditDraft.cents(original.amount)
        } else {
            amountChanged = amountText != SubscriptionEditDraft.text(for: original.amount)
        }
        return amountChanged || differsOutsideAmount(original)
    }

    /// Rounds to cents so 16.49 typed by a user equals 16.49 stored as a floating-point-derived Decimal.
    static func cents(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    private func differsOutsideAmount(_ original: Subscription) -> Bool {
        trimmedName != original.name
            || currency != original.currency
            || frequency != original.billingFrequency
            || category != original.category
            || reminderDays != original.notifyBeforeDays
            || !sameDay(nextBillingDate, original.nextBillingDate)
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
        updated.nextBillingDate = nextBillingDate
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
