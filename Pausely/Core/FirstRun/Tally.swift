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
    /// The monthly price of the plan most people have, by currency. A currency that is missing
    /// has no figure Pausely can stand behind, so the person is asked instead.
    let prices: [String: Decimal]
    /// True when every price was read from the service's own pricing page (see `pricesCheckedOn`).
    /// False for US prices taken from press round-ups, which are less certain.
    var official = false
    /// Sold only in the United States; hidden for people who pay in another currency.
    var usOnly = false

    var id: String { name }

    /// For tests and previews: the US price.
    var typicalUSD: Decimal { prices["USD"] ?? 0 }
}

enum TallyCatalog {
    /// When the prices below were last read. Official ones come from each service's own page for
    /// that country (Netflix help centre, spotify.com, apple.com, Apple's iCloud+ price list,
    /// claude.com); the rest are US prices from press round-ups dated April to September 2026.
    static let pricesCheckedOn = "2026-11-10"

    static let services: [TallyService] = [
        official("Netflix", .entertainment, usd: "19.99", cad: "18.99", gbp: "13.99", eur: "15.99", aud: "20.99"),
        official("Spotify", .music, usd: "12.99", cad: "13.99", gbp: "12.99", eur: "12.99", aud: "15.99"),
        reported("YouTube Premium", .entertainment, usd: "13.99"),
        reported("Amazon Prime", .shopping, usd: "14.99"),
        reported("Disney+", .entertainment, usd: "11.99"),
        official("Apple Music", .music, usd: "11.99", cad: "11.99", gbp: "11.99", eur: "11.99", aud: "14.99"),
        official("iCloud+", .cloudStorage, usd: "2.99", cad: "3.99", gbp: "2.99", eur: "2.99", aud: "4.49"),
        reported("ChatGPT Plus", .productivity, usd: "20.00"),
        reported("Hulu", .entertainment, usd: "11.99", usOnly: true),
        reported("HBO Max", .entertainment, usd: "10.99"),
        official("Apple TV", .entertainment, usd: "14.99", cad: "14.99", gbp: "9.99", eur: "9.99", aud: nil),
        reported("Paramount+", .entertainment, usd: "8.99"),
        reported("Peacock", .entertainment, usd: "10.99", usOnly: true),
        reported("Google One", .cloudStorage, usd: "1.99"),
        reported("PlayStation Plus", .entertainment, usd: "9.99"),
        reported("Audible", .entertainment, usd: "14.95"),
        reported("Microsoft 365", .productivity, usd: "9.99"),
        official("Claude Pro", .productivity, usd: "20.00", cad: nil, gbp: nil, eur: nil, aud: nil),
        reported("Duolingo", .education, usd: "12.99"),
        reported("Crunchyroll", .entertainment, usd: "7.99"),
        reported("Discord Nitro", .social, usd: "9.99"),
        reported("Kindle Unlimited", .entertainment, usd: "11.99"),
        reported("Dropbox", .cloudStorage, usd: "11.99"),
        reported("Uber One", .food, usd: "9.99"),
        reported("DoorDash DashPass", .food, usd: "9.99", usOnly: true),
        reported("Walmart+", .shopping, usd: "12.95", usOnly: true),
        reported("Planet Fitness", .gym, usd: "15.00", usOnly: true),
    ]

    /// The grid for someone who pays in `currency`.
    static func services(payingIn currency: String) -> [TallyService] {
        MoneyFormat.normalizedCode(currency) == "USD" ? services : services.filter { !$0.usOnly }
    }

    /// The price for a service by name (any case), for the plan sheet's suggestion.
    static func price(forServiceNamed name: String, payingIn currency: String) -> Decimal? {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        return services.first { $0.name.lowercased() == key }?.prices[MoneyFormat.normalizedCode(currency)]
    }

    private static func official(_ name: String, _ category: SubscriptionCategory, usd: String, cad: String?, gbp: String?,
                                 eur: String?, aud: String?) -> TallyService {
        var prices: [String: Decimal] = [:]
        for (code, text) in [("USD", usd), ("CAD", cad), ("GBP", gbp), ("EUR", eur), ("AUD", aud)] {
            if let text, let value = Decimal(string: text) { prices[code] = value }
        }
        return TallyService(name: name, category: category, prices: prices, official: true)
    }

    private static func reported(_ name: String, _ category: SubscriptionCategory, usd: String, usOnly: Bool = false) -> TallyService {
        TallyService(name: name, category: category, prices: ["USD": Decimal(string: usd) ?? 0], usOnly: usOnly)
    }
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

    /// What the service costs someone paying in `currency`, or nil when Pausely has no figure it
    /// can stand behind and the person must type it. Prices are never converted by exchange rate:
    /// services set each country's price separately (Netflix is 19.99 in US dollars and 18.99 in
    /// Canadian dollars).
    static func typicalAmount(_ service: TallyService, payingIn currency: String) -> Decimal? {
        service.prices[MoneyFormat.normalizedCode(currency)]
    }

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

    /// Puts saved lines back on the slip.
    mutating func restore(_ saved: [TallyLine]) { lines = saved }

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

extension TallyImporter {
    /// After Pro starts: the lines that were waiting join the list.
    static func importWaiting(into store: SubscriptionStore, defaults: UserDefaults = .standard) async {
        let lines = waitingLines(defaults: defaults)
        guard !lines.isEmpty else { return }
        clearWaiting(defaults: defaults)
        var tally = Tally(currency: lines[0].currency)
        tally.restore(lines)
        PendingTally.save(tally, defaults: defaults)
        await importPending(into: store, defaults: defaults)
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
