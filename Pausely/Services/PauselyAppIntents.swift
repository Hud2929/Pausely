import AppIntents
import Foundation

// Shortcuts and Siri: what renews next, what it all costs a month, one subscription's details, and
// adding one. Every answer is built in the reader's language (`ShortcutAnswers`), from the same pieces
// the screens use. Nothing here deletes: removing a subscription by voice has no undo.

// MARK: - What it all costs

struct GetMonthlySpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Monthly Spend"
    static let description = IntentDescription("What your subscriptions cost each month.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        try ShortcutProblem.requireSignedIn()
        let store = SubscriptionStore.shared
        let answer = ShortcutAnswers.monthlySpend(store.totalMonthlySpend, currency: CurrencyManager.shared.selectedCurrency,
                                                  converted: store.totalIsConverted)
        return .result(value: answer, dialog: "\(answer)")
    }
}

// MARK: - What renews next

struct GetUpcomingRenewalsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Upcoming Renewals"
    static let description = IntentDescription("See which subscriptions are renewing soon.")

    @Parameter(title: "Days Ahead", default: 7, inclusiveRange: (1, 365))
    var daysAhead: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        try ShortcutProblem.requireSignedIn()
        let answer = ShortcutAnswers.upcoming(SubscriptionStore.shared.subscriptions, daysAhead: daysAhead, now: Date())
        return .result(value: answer, dialog: "\(answer)")
    }
}

// MARK: - Add one

struct AddSubscriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Subscription"
    static let description = IntentDescription("Quickly add a new subscription to track.")

    @Parameter(title: "Name", requestValueDialog: "What's the name of the subscription?")
    var name: String

    @Parameter(title: "Monthly Cost", requestValueDialog: "How much does it cost per month?")
    var monthlyCost: Double

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        try ShortcutProblem.requireSignedIn()
        let currency = CurrencyManager.shared.selectedCurrency
        let subscription = try ShortcutAnswers.newSubscription(name: name, monthlyCost: monthlyCost, currency: currency)
        // At the free plan's limit this throws, and the Shortcut says the paywall's own sentence.
        try await SubscriptionStore.shared.addSubscription(subscription)
        let answer = ShortcutAnswers.added(subscription)
        return .result(value: answer, dialog: "\(answer)")
    }
}

// MARK: - One subscription

struct GetSubscriptionDetailIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Subscription Detail"
    static let description = IntentDescription("Get details about a specific subscription.")

    @Parameter(title: "Subscription Name", requestValueDialog: "Which subscription?")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        try ShortcutProblem.requireSignedIn()
        let subscription = try NamedSubscription.find(name, in: SubscriptionStore.shared.subscriptions).one(asked: name)
        let answer = ShortcutAnswers.detail(for: subscription, now: Date())
        return .result(value: answer, dialog: "\(answer)")
    }
}

// MARK: - Siri

/// The two questions worth asking out loud.
struct PauselyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: GetUpcomingRenewalsIntent(),
                    phrases: ["What renews next in \(.applicationName)", "What charges next in \(.applicationName)"],
                    shortTitle: "Get Upcoming Renewals", systemImageName: "calendar")
        AppShortcut(intent: GetMonthlySpendIntent(),
                    phrases: ["What do my subscriptions cost in \(.applicationName)"],
                    shortTitle: "Get Monthly Spend", systemImageName: "sum")
    }
}

// MARK: - The answers

/// What a Shortcut says, in the reader's language. Pure, so every sentence has a test.
enum ShortcutAnswers {

    static func monthlySpend(_ total: Decimal, currency: String, converted: Bool) -> String {
        L10n.string("Your subscriptions cost \(MoneyFormat.total(total, currency, converted: converted, locale: L10n.locale)) a month.")
    }

    /// One line for each charge in the next `daysAhead` days, soonest first: "Netflix · $15.49 · tomorrow".
    /// A free trial about to end is a charge.
    static func upcoming(_ subscriptions: [Subscription], daysAhead: Int, now: Date, calendar: Calendar = .billing,
                         locale: Locale = L10n.locale) -> String {
        let lines = subscriptions.compactMap { subscription -> (day: Date, line: String)? in
            guard let charge = RenewalDecisions.upcomingCharge(for: subscription, now: now, calendar: calendar) else { return nil }
            let daysAway = calendar.calendarDays(from: now, to: charge.date)
            guard daysAway <= daysAhead else { return nil }
            let when = DayText.text(daysAway: daysAway, day: charge.date, locale: locale)
            let amount = MoneyFormat.string(subscription.amount, subscription.currency, locale: locale)
            return (charge.date, "\(subscription.name) · \(amount) · \(when)")
        }
        .sorted { ($0.day, $0.line) < ($1.day, $1.line) }
        .map(\.line)
        return lines.isEmpty ? L10n.string("Nothing renews in that time.") : lines.joined(separator: "\n")
    }

    /// "Netflix · $15.49 a month · Active · Renews tomorrow". The last part only for something that
    /// will charge; "No renewal date" when it will and no date was given.
    static func detail(for subscription: Subscription, now: Date, calendar: Calendar = .billing,
                       locale: Locale = L10n.locale) -> String {
        var parts = [subscription.name,
                     L10n.string("\(MoneyFormat.string(subscription.monthlyCost, subscription.currency, locale: locale)) a month"),
                     subscription.status.displayName]
        if subscription.renewsAutomatically {
            if let charge = RenewalDecisions.upcomingCharge(for: subscription, now: now, calendar: calendar) {
                let when = DayText.text(daysAway: calendar.calendarDays(from: now, to: charge.date), day: charge.date, locale: locale)
                parts.append(L10n.string("Renews \(when)"))
            } else {
                parts.append(L10n.string("No renewal date"))
            }
        }
        return parts.joined(separator: " · ")
    }

    /// The subscription a Shortcut adds: a name, and a price that is a price. No renewal date is made
    /// up: Home asks "When does it renew?".
    static func newSubscription(name: String, monthlyCost: Double, currency: String) throws -> Subscription {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ShortcutProblem.noName }
        guard monthlyCost.isFinite, monthlyCost > 0 else { throw ShortcutProblem.notAPrice }
        let amount = AmountText.rounded(MoneyFormat.decimal(monthlyCost), currency: currency)
        guard amount > 0 else { throw ShortcutProblem.notAPrice }
        guard amount <= AmountText.ceiling(for: currency) else { throw ShortcutProblem.tooLarge }
        return Subscription(name: trimmed, category: SubscriptionCategory.other.rawValue, amount: amount,
                            currency: currency, billingFrequency: .monthly, nextBillingDate: nil, status: .active)
    }

    static func added(_ subscription: Subscription, locale: Locale = L10n.locale) -> String {
        L10n.string("Added \(subscription.name) at \(MoneyFormat.string(subscription.amount, subscription.currency, locale: locale)) a month.")
    }
}

// MARK: - What can stop a Shortcut

/// Said by Siri or shown by Shortcuts, in the reader's language.
enum ShortcutProblem: Error, Equatable, CustomLocalizedStringResourceConvertible {
    /// Shortcuts answer only for the person signed in on this iPhone. Signed out, the list is out of
    /// memory (`SubscriptionStore.hideList`), so an answer would be wrong and an add would be lost.
    case signedOut
    case noName
    case notAPrice
    case tooLarge
    case notFound(String)
    case several(String, [String])

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .signedOut: "Open Pausely and sign in first."
        case .noName: "A subscription needs a name."
        case .notAPrice: "Enter a valid amount"
        case .tooLarge: "That is more than Pausely can track."
        case .notFound(let name): "No subscription is called \(name)."
        case .several(let name, let names): "More than one subscription matches \(name): \(names.joined(separator: ", "))."
        }
    }

    /// A launch before the phone's first unlock can read nothing it saved, and must save nothing over
    /// it (`SavedData`): a Shortcut run then is told to sign in, and touches no list.
    @MainActor static var isSignedIn: () -> Bool = { !LockedLaunchDelegate.isActive && AuthManager.shared.isAuthenticated }

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

    /// The one it means, or the reason there isn't one.
    func one(asked name: String) throws -> Subscription {
        switch self {
        case .one(let subscription): return subscription
        case .none: throw ShortcutProblem.notFound(name)
        case .several(let names): throw ShortcutProblem.several(name, names)
        }
    }
}
