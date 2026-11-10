import Foundation

// MARK: - The Tally (first run)
//
// Before asking for an account, Pausely asks one question ("What do you think you pay for
// subscriptions each month?"), lets the person tap what they pay for, and shows the gap between the
// guess and the total. Everything here is pure so it can be tested; `FirstRunView` draws it.

/// One service offered on the first-run grid.
struct TallyService: Identifiable, Hashable {
    let name: String
    let category: SubscriptionCategory
    /// The price of the plan most people have, in US dollars a month. Typical, not exact: the slip
    /// says "about", and every line can be corrected.
    let typicalUSD: Decimal
    /// Sold only in the United States; hidden for people who pay in another currency.
    var usOnly = false

    var id: String { name }
}

enum TallyCatalog {
    /// When the typical prices below were last compared with published prices.
    static let pricesCheckedOn = "2026-11"

    static let services: [TallyService] = [
        .init(name: "Netflix", category: .entertainment, typicalUSD: dollars("17.99")),
        .init(name: "Spotify", category: .music, typicalUSD: dollars("12.99")),
        .init(name: "YouTube Premium", category: .entertainment, typicalUSD: dollars("13.99")),
        .init(name: "Amazon Prime", category: .shopping, typicalUSD: dollars("14.99")),
        .init(name: "Disney+", category: .entertainment, typicalUSD: dollars("11.99")),
        .init(name: "Apple Music", category: .music, typicalUSD: dollars("10.99")),
        .init(name: "iCloud+", category: .cloudStorage, typicalUSD: dollars("2.99")),
        .init(name: "ChatGPT Plus", category: .productivity, typicalUSD: dollars("20.00")),
        .init(name: "Hulu", category: .entertainment, typicalUSD: dollars("11.99"), usOnly: true),
        .init(name: "HBO Max", category: .entertainment, typicalUSD: dollars("10.99")),
        .init(name: "Apple TV", category: .entertainment, typicalUSD: dollars("14.99")),
        .init(name: "Paramount+", category: .entertainment, typicalUSD: dollars("8.99")),
        .init(name: "Peacock", category: .entertainment, typicalUSD: dollars("10.99"), usOnly: true),
        .init(name: "Google One", category: .cloudStorage, typicalUSD: dollars("1.99")),
        .init(name: "PlayStation Plus", category: .entertainment, typicalUSD: dollars("9.99")),
        .init(name: "Audible", category: .entertainment, typicalUSD: dollars("14.95")),
        .init(name: "Microsoft 365", category: .productivity, typicalUSD: dollars("9.99")),
        .init(name: "Claude Pro", category: .productivity, typicalUSD: dollars("20.00")),
        .init(name: "Duolingo", category: .education, typicalUSD: dollars("12.99")),
        .init(name: "Crunchyroll", category: .entertainment, typicalUSD: dollars("7.99")),
        .init(name: "Discord Nitro", category: .social, typicalUSD: dollars("9.99")),
        .init(name: "Kindle Unlimited", category: .entertainment, typicalUSD: dollars("11.99")),
        .init(name: "Dropbox", category: .cloudStorage, typicalUSD: dollars("11.99")),
        .init(name: "Uber One", category: .food, typicalUSD: dollars("9.99")),
        .init(name: "DoorDash DashPass", category: .food, typicalUSD: dollars("9.99"), usOnly: true),
        .init(name: "Walmart+", category: .shopping, typicalUSD: dollars("12.95"), usOnly: true),
        .init(name: "Planet Fitness", category: .gym, typicalUSD: dollars("15.00"), usOnly: true),
    ]

    /// The grid for someone who pays in `currency`.
    static func services(payingIn currency: String) -> [TallyService] {
        MoneyFormat.normalizedCode(currency) == "USD" ? services : services.filter { !$0.usOnly }
    }

    private static func dollars(_ text: String) -> Decimal { Decimal(string: text) ?? 0 }
}

/// One printed line on the slip: a service and what the person pays for it each month.
struct TallyLine: Codable, Equatable, Identifiable {
    let name: String
    let category: String
    var amount: Decimal
    var currency: String
    /// True once the person typed the price themselves.
    var isConfirmed = false

    var id: String { name }
}

struct Tally: Codable, Equatable {
    /// The guess, in whole units of `currency`.
    var guess: Decimal = 0
    var currency: String
    private(set) var lines: [TallyLine] = []

    init(currency: String) { self.currency = MoneyFormat.normalizedCode(currency) }

    func contains(_ service: TallyService) -> Bool { lines.contains { $0.name == service.name } }

    /// What the service typically costs someone paying in `currency`, or nil when Pausely has no
    /// honest basis for a figure and the person must type it.
    ///
    /// Services don't price by exchange rate: a plan that is $17.99 in the US is about 18.99 in
    /// Canadian dollars, not 25. So each supported currency has a factor from published local
    /// prices, and a currency without one gets no guess at all.
    static func typicalAmount(_ service: TallyService, payingIn currency: String) -> Decimal? {
        guard let factor = typicalFactor[MoneyFormat.normalizedCode(currency)] else { return nil }
        return tidy(service.typicalUSD * factor, currency)
    }

    /// Local list price ÷ US list price, for the plans in `TallyCatalog`.
    static let typicalFactor: [String: Decimal] = [
        "USD": 1, "CAD": Decimal(string: "1.05")!, "AUD": Decimal(string: "1.1")!,
        "GBP": Decimal(string: "0.75")!, "EUR": Decimal(string: "0.8")!,
    ]

    /// Adds the service at `amount` (the typical price, or what the person typed), or removes it
    /// if it is already on the slip.
    mutating func toggle(_ service: TallyService, amount: Decimal? = nil, confirmed: Bool = false) {
        if let index = lines.firstIndex(where: { $0.name == service.name }) {
            lines.remove(at: index)
            return
        }
        guard let price = amount ?? Tally.typicalAmount(service, payingIn: currency), price >= 0 else { return }
        lines.append(TallyLine(name: service.name, category: service.category.rawValue,
                               amount: price, currency: currency, isConfirmed: confirmed))
    }

    /// The person corrected a price. Negative amounts are ignored.
    mutating func setAmount(_ amount: Decimal, for name: String) {
        guard amount >= 0, let index = lines.firstIndex(where: { $0.name == name }) else { return }
        lines[index].amount = amount
        lines[index].currency = currency
        lines[index].isConfirmed = true
    }

    /// The slip as subscriptions: monthly, no renewal date yet (the person adds it later).
    func subscriptions() -> [Subscription] {
        lines.map {
            Subscription(name: $0.name, category: $0.category, amount: $0.amount, currency: $0.currency,
                         billingFrequency: .monthly, nextBillingDate: nil)
        }
    }

    func monthlyTotal(rates: CurrencyRates) -> Decimal {
        subscriptions().monthlyTotal(in: currency, rates: rates)
    }

    func yearlyTotal(rates: CurrencyRates) -> Decimal {
        subscriptions().annualTotal(in: currency, rates: rates)
    }

    /// True while any price is a typical one, so the total is "about".
    var isApproximate: Bool { lines.contains { !$0.isConfirmed } }

    /// How the guess compares with the total.
    enum Verdict: Equatable {
        /// The total is more than the guess, by `monthly` each month.
        case more(monthly: Decimal, yearly: Decimal)
        /// Within 10% of the total either way.
        case close
        /// The guess was higher than the total.
        case less(monthly: Decimal)
    }

    func verdict(rates: CurrencyRates) -> Verdict {
        let total = monthlyTotal(rates: rates)
        let gap = total - guess
        let tolerance = total / 10
        if gap > tolerance { return .more(monthly: gap, yearly: gap * 12) }
        if gap < -tolerance { return .less(monthly: -gap) }
        return .close
    }

    /// Rounds a converted price to the currency's smallest everyday unit.
    static func tidy(_ amount: Decimal, _ currency: String) -> Decimal {
        var value = amount, result = Decimal()
        NSDecimalRound(&result, &value, MoneyFormat.fractionDigits(for: currency), .plain)
        return result
    }
}

// MARK: - Carrying the slip through sign-up

/// The slip made before the account existed. Kept on the device until the person signs in, then
/// added to their list and cleared.
enum PendingTally {
    private static let key = "pending_first_run_tally"

    static func save(_ tally: Tally, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(tally) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(defaults: UserDefaults = .standard) -> Tally? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Tally.self, from: data)
    }

    static func clear(defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key) }

    /// Which lines to add now and which must wait. Lines already in the list (same name, any case)
    /// are dropped. Without Pro, only `freeSlots` fit; the most expensive go first, because those
    /// are the ones worth a reminder.
    static func plan(lines: [TallyLine], existingNames: [String], freeSlots: Int?) -> (add: [TallyLine], wait: [TallyLine]) {
        let existing = Set(existingNames.map { $0.lowercased() })
        let fresh = lines.filter { !existing.contains($0.name.lowercased()) }
        guard let freeSlots else { return (fresh, []) }
        let ranked = fresh.sorted { $0.amount > $1.amount }
        let slots = max(freeSlots, 0)
        return (Array(ranked.prefix(slots)), Array(ranked.dropFirst(slots)))
    }
}

/// Adds the first-run slip to the signed-in person's list.
@MainActor
enum TallyImporter {
    private static let waitingKey = "first_run_tally_waiting"

    /// Lines that didn't fit under the free limit. The paywall offers the choice: pick which ones
    /// Pausely watches, or let Pro watch them all.
    static func waitingLines(defaults: UserDefaults = .standard) -> [TallyLine] {
        guard let data = defaults.data(forKey: waitingKey) else { return [] }
        return (try? JSONDecoder().decode([TallyLine].self, from: data)) ?? []
    }

    static func clearWaiting(defaults: UserDefaults = .standard) { defaults.removeObject(forKey: waitingKey) }

    static func importPending(into store: SubscriptionStore, payments: PaymentManager = .shared,
                              defaults: UserDefaults = .standard) async {
        guard let tally = PendingTally.load(defaults: defaults) else { return }
        // Clear first: a second run (another tab appearing, a relaunch mid-import) must not add twice.
        PendingTally.clear(defaults: defaults)

        let unlimited = payments.isUnlocked(.unlimitedSubscriptions)
        let slots = unlimited ? nil : FreeTier.subscriptionLimit - store.subscriptions.count
        let plan = PendingTally.plan(lines: tally.lines, existingNames: store.subscriptions.map(\.name), freeSlots: slots)

        var waiting = plan.wait
        // Added cheapest first, so the most expensive ends up at the top of the list.
        for line in plan.add.reversed() {
            let subscription = Subscription(name: line.name, category: line.category, amount: line.amount,
                                            currency: line.currency, billingFrequency: .monthly, nextBillingDate: nil)
            do { _ = try await store.addSubscription(subscription) } catch { waiting.append(line) }
        }
        if waiting.isEmpty {
            clearWaiting(defaults: defaults)
        } else if let data = try? JSONEncoder().encode(waiting) {
            defaults.set(data, forKey: waitingKey)
        }
    }
}

#if DEBUG
enum DemoTally {
    /// A filled slip for `--demo-first-run=tally` and `=reveal`.
    static func make() -> Tally {
        var tally = Tally(currency: CurrencyManager.shared.selectedCurrency)
        tally.guess = 40
        for name in ["Netflix", "Spotify", "YouTube Premium", "Amazon Prime", "iCloud+", "ChatGPT Plus", "Disney+", "Audible"] {
            if let service = TallyCatalog.services.first(where: { $0.name == name }) {
                tally.toggle(service, amount: Tally.typicalAmount(service, payingIn: tally.currency) ?? service.typicalUSD)
            }
        }
        return tally
    }
}
#endif
