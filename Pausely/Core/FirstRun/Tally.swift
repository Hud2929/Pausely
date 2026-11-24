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
    /// The monthly price of the plan most people have, by currency, each read from the service's
    /// own page. A currency that is missing has no figure Pausely can stand behind, so the person
    /// is asked what they pay instead.
    let prices: [String: Decimal]
    /// The page the prices were read from, and the day. Nil for a service with no prices.
    var source: String?
    var checkedOn: String?
    /// Sold only in the United States; hidden for people who pay in another currency.
    var usOnly = false

    var id: String { name }
}

enum TallyCatalog {
    /// Every price here was read from the service's own page, named beside it with the day it was
    /// read. Nothing comes from press round-ups any more: of the eight such prices that could be
    /// checked against the service's own page on 2026-11-11, two were wrong (PlayStation Plus,
    /// Disney+). A service whose page could not be read has no price, and the person is asked.
    static let services: [TallyService] = [
        priced("Netflix", .entertainment, usd: "19.99", cad: "18.99", gbp: "13.99", eur: "15.99", aud: "20.99",
               from: "help.netflix.com", on: "2026-11-10"),
        priced("Spotify", .music, usd: "12.99", cad: "13.99", gbp: "12.99", eur: "12.99", aud: "15.99",
               from: "spotify.com", on: "2026-11-10"),
        asked("YouTube Premium", .entertainment),
        asked("Amazon Prime", .shopping),
        priced("Disney+", .entertainment, usd: "12.49", from: "disneyplus.com/en-us", on: "2026-11-11"),
        priced("Apple Music", .music, usd: "11.99", cad: "11.99", gbp: "11.99", eur: "11.99", aud: "14.99",
               from: "apple.com", on: "2026-11-10"),
        priced("iCloud+", .cloudStorage, usd: "2.99", cad: "3.99", gbp: "2.99", eur: "2.99", aud: "4.49",
               from: "support.apple.com (iCloud+ price list)", on: "2026-11-10"),
        asked("ChatGPT Plus", .productivity),
        asked("Hulu", .entertainment, usOnly: true),
        priced("HBO Max", .entertainment, usd: "10.99", from: "hbomax.com/us/en", on: "2026-11-11"),
        priced("Apple TV", .entertainment, usd: "14.99", cad: "14.99", gbp: "9.99", eur: "9.99",
               from: "apple.com", on: "2026-11-10"),
        priced("Paramount+", .entertainment, cad: "7.99", from: "paramountplus.com/ca", on: "2026-11-11"),
        asked("Peacock", .entertainment, usOnly: true),
        priced("Google One", .cloudStorage, cad: "2.79", from: "one.google.com/about/plans", on: "2026-11-11"),
        priced("PlayStation Plus", .entertainment, usd: "10.99", from: "playstation.com/en-us/ps-plus", on: "2026-11-11"),
        priced("Audible", .entertainment, usd: "14.95", from: "audible.com/ep/memberbenefits", on: "2026-11-11"),
        priced("Microsoft 365", .productivity, usd: "9.99", from: "microsoft.com/en-us/microsoft-365", on: "2026-11-11"),
        priced("Claude Pro", .productivity, usd: "20.00", from: "claude.com", on: "2026-11-10"),
        asked("Duolingo", .education),
        asked("Crunchyroll", .entertainment),
        priced("Discord Nitro", .social, usd: "9.99", from: "discord.com/nitro", on: "2026-11-11"),
        asked("Kindle Unlimited", .entertainment),
        priced("Dropbox", .cloudStorage, cad: "12.99", from: "dropbox.com/plans", on: "2026-11-11"),
        priced("Uber One", .food, usd: "9.99", from: "uber.com/us/en/u/uber-one", on: "2026-11-11"),
        asked("DoorDash DashPass", .food, usOnly: true),
        asked("Walmart+", .shopping, usOnly: true),
        asked("Planet Fitness", .gym, usOnly: true),
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

    private static func priced(_ name: String, _ category: SubscriptionCategory, usd: String? = nil, cad: String? = nil,
                               gbp: String? = nil, eur: String? = nil, aud: String? = nil,
                               from source: String, on day: String) -> TallyService {
        var prices: [String: Decimal] = [:]
        for (code, text) in [("USD", usd), ("CAD", cad), ("GBP", gbp), ("EUR", eur), ("AUD", aud)] {
            if let text, let value = Decimal(string: text) { prices[code] = value }
        }
        return TallyService(name: name, category: category, prices: prices, source: source, checkedOn: day)
    }

    /// On the grid, with no price: the person is asked what they pay.
    private static func asked(_ name: String, _ category: SubscriptionCategory, usOnly: Bool = false) -> TallyService {
        TallyService(name: name, category: category, prices: [:], usOnly: usOnly)
    }
}

/// One printed line on the slip: a service and what the person pays for it each month.
struct TallyLine: Codable, Equatable, Identifiable {
    let name: String
    let category: String
    var amount: Decimal
    var currency: String
    /// True once the person typed the price themselves, or it was read from their own receipts.
    var isConfirmed = false
    /// How often it bills, when known (lines found in email). First-run lines are monthly.
    var frequency: BillingFrequency? = nil
    /// The day of the last charge the receipts show. A real date: the renewal schedule rolls it forward.
    var anchor: Date? = nil
    /// When a free trial ends, for a line found while it is still in its trial.
    var trialEndsAt: Date? = nil
    /// Store or payment method that bills this line (e.g. "Apple", "Amazon", "Google Play").
    var paymentMethod: String? = nil
    /// Preserved subscription identity and details when swapping an active item into waiting and back.
    var existingId: UUID? = nil
    var notes: String? = nil
    var notifyBeforeDays: Int = 3

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, category, amount, currency, isConfirmed, frequency, anchor, trialEndsAt
        case paymentMethod, existingId, notes, notifyBeforeDays
    }

    init(name: String, category: String, amount: Decimal, currency: String, isConfirmed: Bool = false,
         frequency: BillingFrequency? = nil, anchor: Date? = nil, trialEndsAt: Date? = nil,
         paymentMethod: String? = nil, existingId: UUID? = nil, notes: String? = nil,
         notifyBeforeDays: Int = 3) {
        self.name = name
        self.category = category
        self.amount = amount
        self.currency = currency
        self.isConfirmed = isConfirmed
        self.frequency = frequency
        self.anchor = anchor
        self.trialEndsAt = trialEndsAt
        self.paymentMethod = paymentMethod
        self.existingId = existingId
        self.notes = notes
        self.notifyBeforeDays = notifyBeforeDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(String.self, forKey: .category)
        amount = try c.decode(Decimal.self, forKey: .amount)
        currency = try c.decode(String.self, forKey: .currency)
        isConfirmed = try c.decodeIfPresent(Bool.self, forKey: .isConfirmed) ?? false
        frequency = try c.decodeIfPresent(BillingFrequency.self, forKey: .frequency)
        anchor = try c.decodeIfPresent(Date.self, forKey: .anchor)
        trialEndsAt = try c.decodeIfPresent(Date.self, forKey: .trialEndsAt)
        paymentMethod = try c.decodeIfPresent(String.self, forKey: .paymentMethod)
        existingId = try c.decodeIfPresent(UUID.self, forKey: .existingId)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        notifyBeforeDays = try c.decodeIfPresent(Int.self, forKey: .notifyBeforeDays) ?? 3
    }

    /// What a year of it costs, in its own currency: how lines are ranked when only some fit.
    var yearlyCost: Decimal {
        amount * ProvenSubscription.periodsPerYear(frequency ?? .monthly)
    }

    /// The subscription this line becomes.
    func subscription(now: Date = Date()) -> Subscription {
        let inTrial = trialEndsAt.map { $0 > now } ?? false
        return Subscription(id: existingId ?? UUID(),
                            name: name, category: category, amount: amount, currency: currency,
                            billingFrequency: frequency ?? .monthly, nextBillingDate: anchor ?? (inTrial ? trialEndsAt : nil),
                            notifyBeforeDays: notifyBeforeDays,
                            trialEndsAt: inTrial ? trialEndsAt : nil, status: inTrial ? .trial : .active,
                            notes: notes, paymentMethod: paymentMethod)
    }
}

struct Tally: Codable, Equatable {
    /// The guess, in whole units of `currency`.
    var guess: Decimal = 0
    var currency: String
    private(set) var lines: [TallyLine] = []
    /// Services the person specifically picked to occupy their free slots when the slip holds more.
    var preferredNames: Set<String> = []

    init(currency: String) { self.currency = MoneyFormat.normalizedCode(currency) }

    enum CodingKeys: String, CodingKey {
        case guess, currency, lines, preferredNames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guess = try c.decodeIfPresent(Decimal.self, forKey: .guess) ?? 0
        currency = try c.decode(String.self, forKey: .currency)
        lines = try c.decodeIfPresent([TallyLine].self, forKey: .lines) ?? []
        preferredNames = try c.decodeIfPresent(Set<String>.self, forKey: .preferredNames) ?? []
    }

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

    /// The person corrected a price. Preserves the line's own currency (e.g. a foreign-currency
    /// service read from a screenshot). Negative amounts are ignored.
    mutating func setAmount(_ amount: Decimal, for name: String) {
        guard amount >= 0, let index = lines.firstIndex(where: { $0.name == name }) else { return }
        lines[index].amount = amount
        lines[index].isConfirmed = true
    }

    /// Merges subscriptions read from screenshots into the first-run slip without duplicating entries.
    mutating func mergeDetected(_ detected: [TallyLine]) {
        for line in detected where line.amount > 0 {
            if let index = lines.firstIndex(where: { ServiceName.same($0.name, line.name) }) {
                lines[index].amount = line.amount
                lines[index].currency = line.currency
                lines[index].isConfirmed = true
                if let freq = line.frequency { lines[index].frequency = freq }
                if let anchor = line.anchor { lines[index].anchor = anchor }
                if let trial = line.trialEndsAt { lines[index].trialEndsAt = trial }
                if let method = line.paymentMethod { lines[index].paymentMethod = method }
            } else {
                lines.append(line)
            }
        }
    }

    /// The slip as subscriptions, preserving billing cycle, renewal dates, trials, and store billing.
    func subscriptions() -> [Subscription] {
        lines.map { $0.subscription() }
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

    /// Which lines to add now and which must wait. Lines already in the list (`ServiceName.same`)
    /// are dropped. Without Pro, only `freeSlots` fit; lines the person chose (`preferredNames`) go
    /// first, then the most expensive, because those are the ones worth a reminder.
    static func plan(lines: [TallyLine], existingNames: [String], freeSlots: Int?,
                     preferredNames: Set<String> = [],
                     cost: (TallyLine) -> Decimal = { $0.yearlyCost }) -> (add: [TallyLine], wait: [TallyLine]) {
        var seen: [String] = []
        let fresh = lines.filter { line in
            guard !existingNames.contains(where: { ServiceName.same($0, line.name) }),
                  !seen.contains(where: { ServiceName.same($0, line.name) }) else { return false }
            seen.append(line.name)
            return true
        }
        guard let freeSlots else { return (fresh, []) }
        let preferred = Set(preferredNames.map { $0.lowercased() })
        let ranked = fresh.sorted { lhs, rhs in
            let lPref = preferred.contains(lhs.name.lowercased())
            let rPref = preferred.contains(rhs.name.lowercased())
            if lPref != rPref { return lPref }
            return cost(lhs) > cost(rhs)
        }
        let slots = max(freeSlots, 0)
        return (Array(ranked.prefix(slots)), Array(ranked.dropFirst(slots)))
    }
}

/// Adds lines to the person's list: the first-run slip after sign-up, and what a search of their email
/// found. One path, so the free limit is handled the same way everywhere, and in the open.
@MainActor
enum TallyImporter {
    static let waitingKey = "first_run_tally_waiting"
    static let waitingVersionKey = "first_run_tally_waiting_version"
    private static let waitingFilename = "waiting_lines.json"

    /// What happened to each line, by name, so the screen can say it.
    struct Outcome: Equatable {
        /// Now on the list and watched.
        var added: [String] = []
        /// Didn't fit under the free limit. Kept, and added the moment Pro starts.
        var waiting: [String] = []
        /// Already on the list (same name, any case).
        var alreadyListed: [String] = []
        /// Already on the list without a renewal date, which the receipts supplied.
        var datesFilled: [String] = []
    }

    /// Lines that didn't fit under the free limit. Stored under iOS hardware data protection on device
    /// (with isolated UserDefaults fallback when unit tests supply a dedicated suite).
    static func waitingLines(defaults: UserDefaults = .standard) -> [TallyLine] {
        let data: Data
        if defaults === UserDefaults.standard {
            data = ProtectedBlobStore.read(filename: waitingFilename, legacyKey: waitingKey, defaults: defaults)
        } else {
            data = defaults.data(forKey: waitingKey) ?? Data()
        }
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([TallyLine].self, from: data)) ?? []
    }

    static func clearWaiting(defaults: UserDefaults = .standard) {
        if defaults === UserDefaults.standard {
            ProtectedBlobStore.write(Data(), filename: waitingFilename, legacyKey: waitingKey, defaults: defaults)
        } else {
            defaults.removeObject(forKey: waitingKey)
        }
        bumpWaitingVersion(defaults: defaults)
    }

    #if DEBUG
    /// `--demo-waiting`: three lines that did not fit, so Home's row about them can be looked at.
    static func keepWaitingForDemo() {
        let currency = CurrencyManager.shared.selectedCurrency
        saveWaiting([TallyLine(name: "Hulu", category: "Entertainment", amount: Decimal(string: "18.99")!, currency: currency),
                     TallyLine(name: "Audible", category: "Entertainment", amount: Decimal(string: "14.95")!, currency: currency),
                     TallyLine(name: "Dropbox", category: "Cloud Storage", amount: Decimal(string: "11.99")!, currency: currency)],
                    defaults: .standard)
    }
    #endif

    private static func saveWaiting(_ lines: [TallyLine], defaults: UserDefaults) {
        if lines.isEmpty {
            clearWaiting(defaults: defaults)
            return
        }
        guard let data = try? JSONEncoder().encode(lines) else { return }
        if defaults === UserDefaults.standard {
            ProtectedBlobStore.write(data, filename: waitingFilename, legacyKey: waitingKey, defaults: defaults)
        } else {
            defaults.set(data, forKey: waitingKey)
        }
        bumpWaitingVersion(defaults: defaults)
    }

    private static func bumpWaitingVersion(defaults: UserDefaults) {
        defaults.set(defaults.integer(forKey: waitingVersionKey) &+ 1, forKey: waitingVersionKey)
    }

    static func importPending(into store: SubscriptionStore, payments: PaymentManager = .shared,
                              defaults: UserDefaults = .standard) async {
        guard let tally = PendingTally.load(defaults: defaults) else { return }
        // Clear first: a second run (another tab appearing, a relaunch mid-import) must not add twice.
        PendingTally.clear(defaults: defaults)
        await add(tally.lines, into: store, payments: payments, preferredNames: tally.preferredNames, defaults: defaults)
    }

    /// Adds what fits, keeps the rest waiting, and fills in a missing renewal date on a subscription that
    /// is already listed when the line has one from a receipt. Nothing is dropped without being reported.
    @discardableResult
    static func add(_ lines: [TallyLine], into store: SubscriptionStore, payments: PaymentManager = .shared,
                    rates: CurrencyRates = CurrencyManager.shared.rates,
                    preferredNames: Set<String> = [],
                    defaults: UserDefaults = .standard) async -> Outcome {
        var outcome = Outcome()

        // Already listed: never added twice. A date read from receipts fills an empty one, when the
        // billing period agrees; an amount or a date the person entered is never changed.
        for line in lines {
            guard let existing = store.subscriptions.first(where: { ServiceName.same($0.name, line.name) }) else { continue }
            outcome.alreadyListed.append(existing.name)
            if existing.nextBillingDate == nil, let anchor = line.anchor, existing.billingFrequency == (line.frequency ?? .monthly) {
                var updated = existing
                updated.nextBillingDate = anchor
                await store.updateSubscription(updated)
                outcome.datesFilled.append(existing.name)
            }
        }

        let unlimited = payments.isUnlocked(.unlimitedSubscriptions)
        let slots = unlimited ? nil : FreeTier.room(in: store.subscriptions)
        let display = CurrencyManager.shared.selectedCurrency
        let plan = PendingTally.plan(lines: lines, existingNames: store.subscriptions.map(\.name),
                                     freeSlots: slots, preferredNames: preferredNames) { line in
            // Ranked in one currency; a currency with no rate ranks last instead of by its raw number.
            rates.convert(line.yearlyCost, from: line.currency, to: display) ?? 0
        }

        var waiting = plan.wait
        // Added cheapest first, so the most expensive ends up at the top of the list.
        for line in plan.add.reversed() {
            do {
                _ = try await store.addSubscription(line.subscription(), recordEvent: line.existingId == nil)
                outcome.added.insert(line.name, at: 0)
            } catch {
                waiting.append(line)
            }
        }
        outcome.waiting = waiting.map(\.name)

        // What was already waiting stays; a line found again replaces its older copy.
        let names = Set(waiting.map { $0.name.lowercased() })
        let listed = Set(store.subscriptions.map { $0.name.lowercased() })
        let earlier = waitingLines(defaults: defaults).filter { !names.contains($0.name.lowercased()) && !listed.contains($0.name.lowercased()) }
        saveWaiting(earlier + waiting, defaults: defaults)
        return outcome
    }
}

extension TallyImporter {
    /// After Pro starts, or when a place on the free list is free (Home offers it): the lines that were
    /// waiting join the list, as many as fit and the most expensive first; the rest keep waiting.
    static func importWaiting(into store: SubscriptionStore, defaults: UserDefaults = .standard) async {
        let lines = waitingLines(defaults: defaults)
        guard !lines.isEmpty else { return }
        clearWaiting(defaults: defaults)
        await add(lines, into: store, defaults: defaults)
    }

    /// Lets a free user choose exactly which subscriptions fill their tracked slots across currently
    /// active subscriptions and waiting lines. Deselected active items move to `waitingLines` so
    /// nothing is lost if they later free a slot or upgrade to Pro.
    static func applyChoice(selectedNames: Set<String>, into store: SubscriptionStore,
                            payments: PaymentManager = .shared,
                            defaults: UserDefaults = .standard) async {
        let wanted = Set(selectedNames.map { $0.lowercased() })
        let active = store.subscriptions.charging
        let waiting = waitingLines(defaults: defaults)

        var newWaiting: [TallyLine] = []
        // Demote active subscriptions the user chose to swap out, preserving their id and fields.
        for sub in active where !wanted.contains(sub.name.lowercased()) {
            newWaiting.append(TallyLine(
                name: sub.name,
                category: sub.category ?? SubscriptionCategory.other.rawValue,
                amount: sub.amount,
                currency: sub.currency,
                isConfirmed: true,
                frequency: sub.billingFrequency,
                anchor: sub.nextBillingDate,
                trialEndsAt: sub.trialEndsAt,
                paymentMethod: sub.paymentMethod,
                existingId: sub.id,
                notes: sub.notes,
                notifyBeforeDays: sub.notifyBeforeDays
            ))
            await store.deleteSubscription(id: sub.id, recordEvent: false)
        }

        // Split waiting items into chosen vs still waiting.
        var toPromote: [TallyLine] = []
        for line in waiting {
            if wanted.contains(line.name.lowercased()) {
                toPromote.append(line)
            } else {
                newWaiting.append(line)
            }
        }

        clearWaiting(defaults: defaults)
        if !toPromote.isEmpty {
            await add(toPromote, into: store, payments: payments, preferredNames: selectedNames, defaults: defaults)
        }
        // Merge any items that couldn't fit with the newly deselected ones.
        let combined = waitingLines(defaults: defaults) + newWaiting
        var deduped: [TallyLine] = []
        var seen = Set(store.subscriptions.charging.map { $0.name.lowercased() })
        for line in combined where seen.insert(line.name.lowercased()).inserted {
            deduped.append(line)
        }
        saveWaiting(deduped, defaults: defaults)
    }
}

#if DEBUG
enum DemoTally {
    /// A filled slip for `--demo-first-run=tally` and `=reveal`.
    static func make() -> Tally {
        var tally = Tally(currency: CurrencyManager.shared.selectedCurrency)
        // `--demo-guess=N` sets the guess, so the reveal's three answers can each be looked at
        // (more than guessed, a good guess, less than guessed).
        tally.guess = LaunchFlag.value(of: "--demo-guess").flatMap { Decimal(string: $0) } ?? 40
        for name in ["Netflix", "Spotify", "YouTube Premium", "Amazon Prime", "iCloud+", "ChatGPT Plus", "Disney+", "Audible"] {
            guard let service = TallyCatalog.services.first(where: { $0.name == name }) else { continue }
            // A demo slip is full: where there is no typical price, a sample one stands in for what
            // the person would have typed.
            tally.toggle(service, amount: Tally.typicalAmount(service, payingIn: tally.currency) ?? Decimal(string: "13.99"),
                         confirmed: Tally.typicalAmount(service, payingIn: tally.currency) == nil)
        }
        return tally
    }
}
#endif

/// Whether two names are one service. Receipts name the plan ("Claude Pro", "ChatGPT Plus") where a person
/// types the service ("Claude"): matched by exact name, a listed subscription came back as a new finding
/// and could be added twice (T32, 2026-11-22). Only plan words may differ: "Apple" is not "Apple Music".
enum ServiceName {
    private static let planWords: Set<String> = [
        "pro", "plus", "premium", "basic", "standard", "family", "individual", "student", "duo", "ultra", "max",
        "membership", "subscription", "monthly", "annual", "yearly", "plan", "with", "ads", "ad", "tier",
        "personal", "team", "starter",
    ]

    static func words(_ name: String) -> [String] {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "+" })
            .map(String.init)
    }

    static func same(_ a: String, _ b: String) -> Bool {
        let x = words(a), y = words(b)
        guard !x.isEmpty, !y.isEmpty else { return a.caseInsensitiveCompare(b) == .orderedSame }
        if x == y { return true }
        let (short, long) = x.count <= y.count ? (x, y) : (y, x)
        guard Array(long.prefix(short.count)) == short else { return false }
        return long.dropFirst(short.count).allSatisfy(planWords.contains)
    }
}
