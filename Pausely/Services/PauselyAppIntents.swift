
import AppIntents
import Foundation

// MARK: - Get Monthly Spend Intent
struct GetMonthlySpendIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Monthly Spend"
    static var description = IntentDescription("Find out how much you're spending on subscriptions this month.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = SubscriptionStore.shared
        let currencyCode = CurrencyManager.shared.currentCurrency.code
        let formatted = LocalizationManager.shared.formattedCurrency(store.totalMonthlySpend, currencyCode: currencyCode)

        return .result(value: "Your monthly subscription spend is \(formatted)")
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
        let store = SubscriptionStore.shared
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()

        let upcoming = store.subscriptions
            .filter { $0.status == .active }
            .filter { sub in
                guard let nextDate = sub.nextBillingDate else { return false }
                return nextDate <= cutoff
            }
            .sorted { ($0.nextBillingDate ?? .distantFuture) < ($1.nextBillingDate ?? .distantFuture) }

        guard !upcoming.isEmpty else {
            return .result(value: "No subscriptions renewing in the next \(daysAhead) days.")
        }

        let currencyCode = CurrencyManager.shared.currentCurrency.code
        let lines = upcoming.map { sub in
            let days = sub.daysUntilRenewal ?? 0
            let amount = LocalizationManager.shared.formattedCurrency(sub.monthlyCost, currencyCode: currencyCode)
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
        let store = SubscriptionStore.shared
        let active = store.subscriptions.filter { $0.status == .active }.count
        let total = store.subscriptions.count

        return .result(value: "You're tracking \(total) subscriptions, \(active) active.")
    }
}

// MARK: - Get Best Value Subscription Intent
struct GetBestValueSubscriptionIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Best Value Subscription"
    static var description = IntentDescription("Find which subscription gives you the best value per hour of use.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = SubscriptionStore.shared
        let activeSubs = store.subscriptions.filter { $0.status == .active }

        guard !activeSubs.isEmpty else {
            return .result(value: "You don't have any active subscriptions.")
        }

        let bestValue = activeSubs.min { a, b in
            a.monthlyCost < b.monthlyCost
        }

        guard let best = bestValue else {
            return .result(value: "Could not determine best value subscription.")
        }

        let currencyCode = CurrencyManager.shared.currentCurrency.code
        let amount = LocalizationManager.shared.formattedCurrency(best.monthlyCost, currencyCode: currencyCode)

        return .result(value: "Your best value subscription is \(best.name) at \(amount) per month.")
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
        let store = SubscriptionStore.shared

        let sub = Subscription(
            name: name,
            bundleIdentifier: nil,
            description: nil,
            category: SubscriptionCategory.other.rawValue,
            amount: Decimal(monthlyCost),
            currency: CurrencyManager.shared.currentCurrency.code,
            billingFrequency: .monthly,
            nextBillingDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            status: .active,
            isDetected: false,
            canPause: true,
            selectedTier: .individual
        )

        try await store.addSubscription(sub)

        let currencyCode = CurrencyManager.shared.currentCurrency.code
        let amount = LocalizationManager.shared.formattedCurrency(Decimal(monthlyCost), currencyCode: currencyCode)

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
        let store = SubscriptionStore.shared
        let query = name.lowercased()

        guard let sub = store.subscriptions.first(where: { $0.name.lowercased().contains(query) }) else {
            return .result(value: "No subscription found matching '\(name)'.")
        }

        let currencyCode = CurrencyManager.shared.currentCurrency.code
        let amount = LocalizationManager.shared.formattedCurrency(sub.monthlyCost, currencyCode: currencyCode)
        let status = sub.status == .active ? "Active" : "Paused"
        let renewal = sub.daysUntilRenewal.map { "Renews in \($0) day\($0 == 1 ? "" : "s")" } ?? "No renewal date"

        return .result(value: "\(sub.name): \(amount)/month, \(status). \(renewal).")
    }
}

// MARK: - Pause Subscription Intent
struct PauseSubscriptionIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Subscription"
    static var description = IntentDescription("Pause a subscription to stop tracking it temporarily.")

    @Parameter(title: "Subscription Name", requestValueDialog: "Which subscription do you want to pause?")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = SubscriptionStore.shared
        let query = name.lowercased()

        guard let sub = store.subscriptions.first(where: { $0.name.lowercased().contains(query) }) else {
            return .result(value: "No subscription found matching '\(name)'.")
        }

        try await store.updateSubscriptionStatus(id: sub.id, status: .paused)
        return .result(value: "Paused \(sub.name).")
    }
}

// MARK: - Resume Subscription Intent
struct ResumeSubscriptionIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Subscription"
    static var description = IntentDescription("Resume a paused subscription.")

    @Parameter(title: "Subscription Name", requestValueDialog: "Which subscription do you want to resume?")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = SubscriptionStore.shared
        let query = name.lowercased()

        guard let sub = store.subscriptions.first(where: { $0.name.lowercased().contains(query) }) else {
            return .result(value: "No subscription found matching '\(name)'.")
        }

        try await store.updateSubscriptionStatus(id: sub.id, status: .active)
        return .result(value: "Resumed \(sub.name).")
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
        let store = SubscriptionStore.shared
        let query = name.lowercased()

        guard let sub = store.subscriptions.first(where: { $0.name.lowercased().contains(query) }) else {
            return .result(value: "No subscription found matching '\(name)'.")
        }

        try await store.deleteSubscription(id: sub.id)
        return .result(value: "Deleted \(sub.name).")
    }
}
