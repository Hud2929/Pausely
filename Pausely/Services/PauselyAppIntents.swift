
import AppIntents
import Foundation

// MARK: - Get Monthly Spend Intent
struct GetMonthlySpendIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Monthly Spend"
    static var description = IntentDescription("What your subscriptions cost each month.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try ShortcutProblem.requireSignedIn()
        let store = SubscriptionStore.shared
        let formatted = MoneyFormat.total(store.totalMonthlySpend, CurrencyManager.shared.selectedCurrency,
                                          converted: store.totalIsConverted)

        return .result(value: "Your subscriptions cost \(formatted) a month.")
    }
}

// MARK: - Get Upcoming Renewals Intent
struct GetUpcomingRenewalsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Upcoming Renewals"
    static var description = IntentDescription("See which subscriptions are renewing soon.")

    @Parameter(title: "Days Ahead", default: 7)
    var daysAhead: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try ShortcutProblem.requireSignedIn()
        let store = SubscriptionStore.shared
        let calendar = Calendar.billing
        let cutoff = calendar.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()

        let upcoming = store.activeSubscriptions
            .filter { sub in
                guard let nextDate = sub.calculatedNextBillingDate else { return false }
                return nextDate <= cutoff
            }
            .sorted { ($0.calculatedNextBillingDate ?? .distantFuture) < ($1.calculatedNextBillingDate ?? .distantFuture) }

        guard !upcoming.isEmpty else {
            return .result(value: "No subscriptions renewing in the next \(daysAhead) days.")
        }

        let lines = upcoming.map { sub in
            let days = sub.daysUntilRenewal ?? 0
            let amount = sub.chargeText  // the real charge, in its own currency
            let dayText = days == 0 ? "today" : days == 1 ? "tomorrow" : "in \(days) days"
            return "\(sub.name): \(amount) \(dayText)"
        }

        return .result(value: lines.joined(separator: ". "))
    }
}

// MARK: - Get Subscription Count Intent
struct GetSubscriptionCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Count Subscriptions"
    static var description = IntentDescription("Count how many subscriptions you're tracking.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try ShortcutProblem.requireSignedIn()
        let store = SubscriptionStore.shared
        let active = store.activeSubscriptions.count
        let total = store.subscriptions.count

        return .result(value: "You're tracking \(total) subscriptions, \(active) active.")
    }
}

// MARK: - Add Subscription Intent
struct AddSubscriptionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Subscription"
    static var description = IntentDescription("Quickly add a new subscription to track.")

    @Parameter(title: "Name", requestValueDialog: "What's the name of the subscription?")
    var name: String

    @Parameter(title: "Monthly Cost", requestValueDialog: "How much does it cost per month?")
    var monthlyCost: Double

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try ShortcutProblem.requireSignedIn()
        let store = SubscriptionStore.shared

        let sub = Subscription(
            name: name,
            category: SubscriptionCategory.other.rawValue,
            amount: MoneyFormat.decimal(monthlyCost),
            currency: CurrencyManager.shared.selectedCurrency,
            billingFrequency: .monthly,
            // No renewal date was given, so none is made up: Home asks "When does it renew?".
            nextBillingDate: nil,
            status: .active
        )

        try await store.addSubscription(sub)

        let amount = sub.chargeText

        return .result(value: "Added \(name) at \(amount) per month.")
    }
}

// MARK: - Get Subscription Detail Intent
struct GetSubscriptionDetailIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Subscription Detail"
    static var description = IntentDescription("Get details about a specific subscription.")

    @Parameter(title: "Subscription Name", requestValueDialog: "Which subscription?")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try ShortcutProblem.requireSignedIn()
        let store = SubscriptionStore.shared

        let sub: Subscription
        switch NamedSubscription.find(name, in: store.subscriptions) {
        case .one(let found): sub = found
        case .none, .several: return .result(value: NamedSubscription.find(name, in: store.subscriptions).problem(for: name))
        }

        let amount = MoneyFormat.string(sub.monthlyCost, sub.currency)
        // Only something that will charge has a renewal to report.
        let renewal: String
        if !sub.renewsAutomatically {
            renewal = ""
        } else if let days = sub.daysUntilRenewal {
            renewal = days == 0 ? " Renews today." : " Renews in \(days) day\(days == 1 ? "" : "s")."
        } else {
            renewal = " No renewal date."
        }
        return .result(value: "\(sub.name): \(amount)/month, \(sub.status.displayName).\(renewal)")
    }
}

// MARK: - Delete Subscription Intent
struct DeleteSubscriptionIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete Subscription"
    static var description = IntentDescription("Remove a subscription from tracking.")

    @Parameter(title: "Subscription Name", requestValueDialog: "Which subscription do you want to delete?")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        try ShortcutProblem.requireSignedIn()
        let store = SubscriptionStore.shared

        // Removing is not undone, so the name has to mean exactly one subscription.
        switch NamedSubscription.find(name, in: store.subscriptions) {
        case .one(let sub):
            await store.deleteSubscription(id: sub.id)
            return .result(value: "Deleted \(sub.name).")
        case let other:
            return .result(value: other.problem(for: name))
        }
    }
}

// MARK: - Who a Shortcut answers

/// Shortcuts answer only for the person signed in on this iPhone. Signed out, the list is out of
/// memory (`SubscriptionStore.hideList`), so an answer would be wrong and an add would be lost.
enum ShortcutProblem: Error, CustomLocalizedStringResourceConvertible {
    case signedOut

    var localizedStringResource: LocalizedStringResource {
        "Open Pausely and sign in first."
    }

    @MainActor static var isSignedIn: () -> Bool = { RevolutionaryAuthManager.shared.isAuthenticated }

    @MainActor
    static func requireSignedIn() throws {
        guard isSignedIn() else { throw ShortcutProblem.signedOut }
    }
}

// MARK: - Which subscription a name means

/// The subscription a spoken or typed name means: the one with exactly that name, or the only one
/// whose name contains it. Never a pick between several ("Apple" with Apple One and Apple Music).
enum NamedSubscription {
    case one(Subscription)
    case none
    case several([String])

    static func find(_ name: String, in subscriptions: [Subscription]) -> NamedSubscription {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !wanted.isEmpty else { return .none }
        if let exact = subscriptions.first(where: { $0.name.lowercased() == wanted }) { return .one(exact) }
        let containing = subscriptions.filter { $0.name.lowercased().contains(wanted) }
        switch containing.count {
        case 0: return .none
        case 1: return .one(containing[0])
        default: return .several(containing.map(\.name))
        }
    }

    /// What to say when the name didn't mean exactly one.
    func problem(for name: String) -> String {
        switch self {
        case .one: return ""
        case .none: return "No subscription found matching '\(name)'."
        case .several(let names): return "\(names.count) subscriptions match '\(name)': \(names.joined(separator: ", ")). Say the full name."
        }
    }
}
