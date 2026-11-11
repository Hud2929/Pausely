import Foundation

// MARK: - Receipt Signal
/// Compact, privacy-preserving facts extracted from ONE email on-device.
/// It deliberately contains no subject line and no body text — only what the engine needs.
struct ReceiptSignal: Codable, Equatable, Identifiable {
    var id: String                       // Message-ID header when known (same receipt in two inboxes = one), else provider id
    var date: Date
    var senderDomain: String
    var senderName: String
    var merchantHint: String?            // from a platform parser or product detection
    var platform: String                 // direct | apple | googleplay | stripe | paypal | paddle
    var kind: EmailKind
    var amount: Decimal?
    var currency: String?
    var cadenceHint: BillingFrequency?
    var trialDays: Int?
    var renewalLanguage: Bool
    var oneTimeLanguage: Bool
    var promotional: Bool
    /// Structured (schema.org) receipt data found in the email, when present.
    var markup: StructuredReceiptParser.Kind? = nil
    var hasUnsubscribe: Bool? = nil
    var bulkMail: Bool? = nil
    /// Inboxes (account ids) this receipt was found in. Empty for receipts saved before multiple inboxes.
    var sources: [String]? = nil
    /// The sender claims to be a known merchant, but the receiving server's checks say the message isn't
    /// signed by it: never trusted as proof of a subscription.
    var spoofSuspected: Bool? = nil
    /// What the plan costs once an introductory price ends ("$134.99 for 1 year, then $269.99/year").
    var nextAmount: Decimal? = nil
    /// The introductory price as stated, before tax, so the rise is measured like with like.
    var introAmount: Decimal? = nil
}

// MARK: - Output Models

struct ChargeEvidence: Codable, Equatable, Identifiable {
    var id: String
    var date: Date
    var amount: Decimal
    var currency: String
}

struct ProvenSubscription: Identifiable, Equatable {
    enum Status: Equatable {
        case active
        case trial
        case priceIncreased
        case likelyEnded
        case cancelled
    }

    enum Tier: Int, Comparable {
        case hidden = 0
        case review = 1      // shown under "Worth a look", never pre-selected
        case likely = 2      // shown, not pre-selected
        case confirmed = 3   // pre-selected
        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    var name: String
    var merchantKey: String
    var category: String?
    var cancelURL: String?
    var amount: Decimal
    var currency: String
    var frequency: BillingFrequency
    var lastChargeDate: Date?
    var nextBillingDate: Date?
    var status: Status
    var score: Int
    var tier: Tier
    var evidence: [ChargeEvidence]
    var reasons: [String]
    var previousAmount: Decimal?
    var trialEndsOn: Date?
    var chargedAfterCancel: Bool = false

    var annualCost: Decimal { amount * ProvenSubscription.periodsPerYear(frequency) }
    var monthlyCost: Decimal { annualCost / 12 }

    static func periodsPerYear(_ f: BillingFrequency) -> Decimal {
        switch f {
        case .weekly: return 52
        case .biweekly: return 26
        case .monthly: return 12
        case .quarterly: return 4
        case .semiannual: return 2
        case .yearly: return 1
        }
    }
}

struct IntelligenceInsight: Identifiable, Equatable {
    enum Kind: Equatable { case priceIncrease, trialEnding, renewalSoon, likelyEnded, chargedAfterCancel, priceChangeNotice, paymentFailed }
    let id: String
    var kind: Kind
    var title: String
    var detail: String
    var subscriptionId: String?
    /// Positive = money the user could lose (or save) per year.
    var annualImpact: Decimal?
}

struct IntelligenceReport: Equatable {
    var subscriptions: [ProvenSubscription]
    var ignoredPurchaseGroups: Int
    var insights: [IntelligenceInsight]

    var active: [ProvenSubscription] {
        subscriptions.filter { $0.status != .likelyEnded && $0.status != .cancelled }
    }
    /// What the likely-or-better subscriptions cost a month in `currency`. A mailbox can hold
    /// receipts in several currencies, so each one is converted before adding.
    func monthlyTotal(in currency: String, rates: CurrencyRates = CurrencyManager.shared.rates) -> Decimal {
        MoneyMath.total(active.filter { $0.tier >= .likely }, in: currency, rates: rates,
                        amount: \.monthlyCost, currencyOf: \.currency)
    }
}

// MARK: - Engine

/// Turns a pile of per-email facts into the subscriptions a person truly pays for.
/// Core idea: a subscription is *proven by a pattern of charges over time*, not by one email that mentions a price.
struct SubscriptionIntelligenceEngine {

    var catalog: MerchantCatalog = .builtin

    // MARK: Cadence model

    private struct Cadence {
        let frequency: BillingFrequency
        let days: Double
        let tolerance: Double
    }

    private static let cadences: [Cadence] = [
        Cadence(frequency: .weekly, days: 7, tolerance: 2),
        Cadence(frequency: .biweekly, days: 14, tolerance: 3),
        Cadence(frequency: .monthly, days: 30.44, tolerance: 5),
        Cadence(frequency: .quarterly, days: 91.3, tolerance: 8),
        Cadence(frequency: .semiannual, days: 182.6, tolerance: 12),
        Cadence(frequency: .yearly, days: 365.25, tolerance: 20)
    ]

    private struct Sequence {
        var charges: [ReceiptSignal]
        var cadence: Cadence
        var regularity: Double
    }

    // MARK: Public entry

    func analyze(signals: [ReceiptSignal],
                 now: Date = Date(),
                 calendar: Calendar = .current,
                 defaultCurrency: String = "USD",
                 corrections: [String: UserVerdict] = [:]) -> IntelligenceReport {

        // 1. Dedupe by message id, and never trust a receipt whose sender failed authentication
        var seen = Set<String>()
        let unique = signals.filter { $0.spoofSuspected != true && seen.insert($0.id).inserted }

        // 2. Resolve merchants, drop junk identities
        var groups: [String: (merchant: ResolvedMerchant, signals: [ReceiptSignal])] = [:]
        for signal in unique {
            guard let merchant = catalog.resolve(hint: signal.merchantHint,
                                                 senderName: signal.senderName,
                                                 senderDomain: signal.senderDomain) else { continue }
            groups[merchant.key, default: (merchant, [])].signals.append(signal)
        }

        var detected: [ProvenSubscription] = []
        var insights: [IntelligenceInsight] = []
        var ignored = 0

        for (key, group) in groups {
            let verdict = corrections[key]
            // The user said "not a subscription": respect it silently and forever.
            if verdict == .notSubscription { continue }

            var results = analyzeGroup(merchant: group.merchant, signals: group.signals.sorted { $0.date < $1.date },
                                       now: now, calendar: calendar, defaultCurrency: defaultCurrency)
            if verdict == .trusted {
                results = results.map { sub in
                    var boosted = sub
                    boosted.score = min(100, sub.score + 30)
                    boosted.reasons.insert(L10n.string("You told Pausely this is a subscription"), at: 0)
                    boosted.tier = max(tier(for: boosted.score, status: boosted.status), .likely)
                    return boosted
                }
            }
            if results.isEmpty { if group.signals.contains(where: { $0.amount != nil }) { ignored += 1 } }
            detected.append(contentsOf: results)
        }

        for sub in detected { insights.append(contentsOf: makeInsights(for: sub, now: now, calendar: calendar)) }
        insights.append(contentsOf: priceChangeNotices(groups: groups, detected: detected))
        insights.append(contentsOf: introductoryPriceEnds(groups: groups, detected: detected))
        insights.append(contentsOf: failedPayments(groups: groups, detected: detected, now: now))

        detected = detected
            .filter { $0.tier >= .review }
            .sorted {
                if $0.tier != $1.tier { return $0.tier > $1.tier }
                return $0.annualCost > $1.annualCost
            }

        insights.sort { ($0.annualImpact ?? 0) > ($1.annualImpact ?? 0) }
        return IntelligenceReport(subscriptions: detected, ignoredPurchaseGroups: ignored, insights: insights)
    }

    // MARK: Group analysis

    private func analyzeGroup(merchant: ResolvedMerchant,
                              signals: [ReceiptSignal],
                              now: Date,
                              calendar: Calendar,
                              defaultCurrency: String) -> [ProvenSubscription] {

        let currency = modalCurrency(signals) ?? defaultCurrency

        // Charge candidates: real money movements that are not shipping/order/refund style
        let chargeSignals = signals.filter {
            ($0.kind == .charge || $0.kind == .renewalNotice) && $0.amount != nil && !$0.promotional
        }

        let isMixed = merchant.kind == .mixedCommerce
        let eligible = chargeSignals.filter { signal in
            // One-time language on a mixed/unknown merchant means it's an order, not a subscription charge.
            if signal.oneTimeLanguage && !signal.renewalLanguage { return merchant.kind == .pureSubscription && merchant.isKnown }
            if signal.oneTimeLanguage && (isMixed || !merchant.isKnown) { return false }
            return true
        }

        let cancellation = signals.last { $0.kind == .cancellation }
        let trialSignals = signals.filter { ($0.kind == .trialStarted || $0.kind == .trialEnding) && !$0.promotional }

        var results: [ProvenSubscription] = []

        if let sequence = bestSequence(from: collapse(eligible)) {
            if let sub = buildFromSequence(sequence, merchant: merchant, allSignals: signals, cancellation: cancellation,
                                           now: now, calendar: calendar, currency: currency) {
                results.append(sub)
            }
        } else if let single = singleSignalCandidate(eligible: eligible, merchant: merchant, signals: signals,
                                                     cancellation: cancellation, now: now, calendar: calendar, currency: currency) {
            results.append(single)
        }

        // Free trials are worth catching even before the first charge
        if results.isEmpty || results.allSatisfy({ $0.status == .likelyEnded }),
           let trial = trialCandidate(trialSignals: trialSignals, merchant: merchant, now: now, calendar: calendar, currency: currency) {
            results.append(trial)
        }

        // A trial that ended with no cancellation email most likely turned into a paid plan, and some services
        // (Amazon Prime, for one) never email a receipt for the renewals that follow.
        if results.isEmpty,
           let converted = convertedTrialCandidate(trialSignals: trialSignals, cancellation: cancellation, merchant: merchant,
                                                   now: now, calendar: calendar, currency: currency) {
            results.append(converted)
        }

        return results
    }

    // MARK: Sequence detection

    /// Two receipts for the same amount within 3 days are one charge (receipt + payment notice).
    private func collapse(_ signals: [ReceiptSignal]) -> [ReceiptSignal] {
        var out: [ReceiptSignal] = []
        for signal in signals.sorted(by: { $0.date < $1.date }) {
            if let last = out.last, let a = last.amount, let b = signal.amount,
               abs(signal.date.timeIntervalSince(last.date)) < 3 * 86_400, closeAmounts(a, b, tolerance: 0.02) {
                continue
            }
            out.append(signal)
        }
        return out
    }

    private func bestSequence(from charges: [ReceiptSignal]) -> Sequence? {
        guard charges.count >= 2 else { return nil }

        // A. Whole-merchant sequence (handles price changes)
        var candidates: [Sequence] = []
        if let whole = regularChain(charges) { candidates.append(whole) }

        // B. Per-amount clusters (handles mixed merchants with one real plan among many orders)
        for cluster in amountClusters(charges) where cluster.count >= 2 {
            if let seq = regularChain(cluster) { candidates.append(seq) }
        }

        let ranked = candidates.sorted { lhs, rhs in
            if lhs.charges.count != rhs.charges.count { return lhs.charges.count > rhs.charges.count }
            return lhs.regularity > rhs.regularity
        }
        guard let longest = ranked.first else { return nil }
        // The longest run is normally the plan. When it stopped long before the newest charge and another
        // run reaches that charge (monthly for a year, then one yearly price), the newer run is what's
        // billed today.
        if let newest = charges.max(by: { $0.date < $1.date }), let last = longest.charges.last, last.id != newest.id,
           newest.date.timeIntervalSince(last.date) / 86_400 > longest.cadence.days * 1.5,
           let current = ranked.first(where: { $0.charges.last?.id == newest.id }) {
            return current
        }
        return longest
    }

    /// The charges that bill on a schedule: the longest chain in which each charge follows the one before by
    /// one, two or three periods. A stray email between two receipts (a promotion read as a charge, a one-off
    /// purchase from the same company) is left out of the chain instead of breaking it, and an old gap of
    /// many months (deleted mail, a paused plan) starts the chain afresh.
    private func regularChain(_ charges: [ReceiptSignal]) -> Sequence? {
        let sorted = charges.sorted { $0.date < $1.date }
        guard sorted.count >= 2, let newest = sorted.last else { return nil }

        func better(_ a: Sequence?, _ b: Sequence?) -> Sequence? {
            guard let a else { return b }
            guard let b else { return a }
            if a.charges.count != b.charges.count { return a.charges.count > b.charges.count ? a : b }
            if abs(a.regularity - b.regularity) > 0.001 { return a.regularity > b.regularity ? a : b }
            // Equal on both: the period the receipts themselves state, then the one that reaches further forward.
            let aStated = statedShare(a), bStated = statedShare(b)
            if aStated != bStated { return aStated > bStated ? a : b }
            return (a.charges.last?.date ?? .distantPast) >= (b.charges.last?.date ?? .distantPast) ? a : b
        }

        var longest: Sequence?
        var reachingNewest: Sequence?
        for cadence in Self.cadences {
            let (overall, atEnd) = chains(sorted, cadence)
            longest = better(longest, overall)
            reachingNewest = better(reachingNewest, atEnd)
        }
        guard let longest else { return reachingNewest }
        // A plan that changed its schedule (monthly for a year, then yearly): the old chain is longer, but it
        // stopped long before the newest charge. What's billed now is the chain that reaches the newest one.
        if let current = reachingNewest, let last = longest.charges.last, last.id != newest.id,
           newest.date.timeIntervalSince(last.date) / 86_400 > longest.cadence.days * 1.5 {
            return current
        }
        return longest
    }

    /// How many of a chain's receipts state its billing period in words.
    private func statedShare(_ sequence: Sequence) -> Int {
        sequence.charges.filter { $0.cadenceHint == sequence.cadence.frequency }.count
    }

    /// For one billing period: the best chain anywhere in the history, and the best one ending at the newest
    /// charge. Either is nil when it is too irregular to be a schedule.
    private func chains(_ sorted: [ReceiptSignal], _ cadence: Cadence) -> (overall: Sequence?, atEnd: Sequence?) {
        let count = sorted.count
        var length = [Int](repeating: 1, count: count)
        var weight = [Double](repeating: 0, count: count)
        var previous = [Int?](repeating: nil, count: count)
        for i in 1..<count {
            for j in 0..<i {
                let interval = sorted[i].date.timeIntervalSince(sorted[j].date) / 86_400
                let periods = max(1.0, (interval / cadence.days).rounded())
                // One or two missing receipts are common; a longer gap is a new start, not the same run.
                guard periods <= 3, abs(interval - periods * cadence.days) <= cadence.tolerance * periods.squareRoot() else { continue }
                // A price rise or a bigger tier keeps the run going; a charge many times the size is another
                // plan (a year paid at once after months paid one by one), not the next charge of this one.
                if let later = sorted[i].amount, let earlier = sorted[j].amount {
                    let low = NSDecimalNumber(decimal: min(later, earlier)).doubleValue
                    let high = NSDecimalNumber(decimal: max(later, earlier)).doubleValue
                    if low > 0, high / low > 4 { continue }
                }
                let candidateLength = length[j] + 1
                let candidateWeight = weight[j] + (periods == 1 ? 1.0 : 0.6)
                if candidateLength > length[i] || (candidateLength == length[i] && candidateWeight > weight[i]) {
                    length[i] = candidateLength
                    weight[i] = candidateWeight
                    previous[i] = j
                }
            }
        }

        func sequence(endingAt end: Int) -> Sequence? {
            guard length[end] >= 2 else { return nil }
            var indexes: [Int] = []
            var cursor: Int? = end
            while let index = cursor { indexes.append(index); cursor = previous[index] }
            let regularity = weight[end] / Double(length[end] - 1)
            guard regularity >= 0.7 else { return nil }
            return Sequence(charges: indexes.reversed().map { sorted[$0] }, cadence: cadence, regularity: regularity)
        }

        var best: Int?
        for i in 0..<count where length[i] >= 2 {
            guard let current = best else { best = i; continue }
            // Longer first; then more regular; then the later one.
            if length[i] > length[current] || (length[i] == length[current] && weight[i] >= weight[current]) { best = i }
        }
        return (best.flatMap(sequence(endingAt:)), sequence(endingAt: count - 1))
    }

    private func amountClusters(_ charges: [ReceiptSignal]) -> [[ReceiptSignal]] {
        var clusters: [[ReceiptSignal]] = []
        for charge in charges {
            guard let amount = charge.amount else { continue }
            if let index = clusters.firstIndex(where: { cluster in
                guard let reference = cluster.first?.amount else { return false }
                return closeAmounts(reference, amount, tolerance: 0.015)
            }) {
                clusters[index].append(charge)
            } else {
                clusters.append([charge])
            }
        }
        return clusters
    }

    // MARK: Build detected subscription

    private func buildFromSequence(_ sequence: Sequence,
                                   merchant: ResolvedMerchant,
                                   allSignals: [ReceiptSignal],
                                   cancellation: ReceiptSignal?,
                                   now: Date,
                                   calendar: Calendar,
                                   currency: String) -> ProvenSubscription? {

        let charges = sequence.charges
        guard let latest = charges.last, let latestAmount = latest.amount else { return nil }
        let amounts = charges.compactMap(\.amount)
        let n = charges.count

        // --- Score ---
        var score = 0
        var reasons: [String] = []

        switch (n, sequence.regularity) {
        case (4..., 0.8...): score += 55
        case (3, 0.8...): score += 48
        case (2, 0.8...): score += 32
        case (3..., _): score += 38
        default: score += 22
        }
        reasons.append(chargedTimes(n, sequence.cadence.frequency))

        let allSame = amounts.allSatisfy { closeAmounts($0, latestAmount, tolerance: 0.005) }
        let coefficient = variation(amounts)
        // A plan whose price changed once or twice is still one plan; orders change every time.
        let stepped = !allSame && isStepped(amounts)
        if allSame { score += 10; reasons.append(L10n.string("Same amount each time (\(format(latestAmount, currency)))")) }
        else if coefficient <= 0.06 || stepped { score += 6 }
        else if coefficient > 0.25 { score -= 30; reasons.append(L10n.string("Amount varies a lot, which looks more like orders than a plan")) }

        let renewalCount = allSignals.filter { $0.renewalLanguage && !$0.promotional }.count
        if renewalCount >= 2 { score += 20; reasons.append(L10n.string("Emails mention renewing or a recurring plan")) }
        else if renewalCount == 1 { score += 12; reasons.append(L10n.string("An email mentions renewing or a recurring plan")) }

        let oneTimeShare = Double(charges.filter { $0.oneTimeLanguage }.count) / Double(n)
        if oneTimeShare > 0.5 { score -= 45; reasons.append(L10n.string("Receipts look like one-time orders")) }

        if merchant.isKnown {
            if merchant.kind == .pureSubscription { score += 20; reasons.append(L10n.string("\(merchant.displayName) is a known subscription service")) }
            else { score += 4 }
        }
        if charges.contains(where: { $0.markup == .subscription }) {
            score += 12; reasons.append(L10n.string("The receipts carry structured subscription data"))
        }
        if charges.contains(where: { $0.platform == "apple" || $0.platform == "googleplay" }) {
            score += 15; reasons.append(L10n.string("Billed through an app-store subscription"))
        }

        if latestAmount < 1 { score -= 18 }
        if latestAmount > 600 { score -= 20 }
        if !merchant.isKnown && merchant.nameQuality < 50 { score -= 12 }

        // Gating: unknown or mixed-commerce brands must PROVE recurrence
        let needsStrongProof = !merchant.isKnown || merchant.kind == .mixedCommerce
        if needsStrongProof {
            let steady = coefficient <= 0.06 || stepped
            let membershipEvidence = renewalCount >= 1 && (allSame || stepped) && n >= 2
            let strong = (n >= 3 && sequence.regularity >= 0.8 && steady) || membershipEvidence
            if !strong {
                // Steady, same-amount charges deserve a look. Varying amounts never surface: they are orders, not plans.
                let plausible = sequence.regularity >= 0.8 && (allSame || steady) && (n >= 3 || renewalCount >= 1)
                score = min(score, plausible ? 49 : 35)
                reasons.append(L10n.string("Not enough proof of a recurring plan yet"))
            }
        }
        score = max(0, min(100, score))

        // --- Dates & status ---
        let frequency = sequence.cadence.frequency
        let (next, missed) = nextBilling(after: latest.date, frequency: frequency, now: now, calendar: calendar)
        let lastDate = latest.date

        var status: ProvenSubscription.Status = .active
        var nextBillingDate: Date? = next
        let grace = graceDays(frequency)
        if missed >= 1, let expected = nextExpected(after: latest.date, frequency: frequency, calendar: calendar),
           now.timeIntervalSince(expected) / 86_400 > grace {
            status = .likelyEnded
            nextBillingDate = nil
            reasons.append(L10n.string("No charge since \(shortDate(lastDate)), so it may have ended"))
        }

        var chargedAfterCancel = false
        if let cancellation, cancellation.date > charges.first!.date {
            if latest.date > cancellation.date.addingTimeInterval(86_400) {
                chargedAfterCancel = true
                reasons.append(L10n.string("Charged again on \(shortDate(latest.date)) after a cancellation email on \(shortDate(cancellation.date))"))
            } else {
                status = .cancelled
                nextBillingDate = nil
                reasons.append(L10n.string("Cancelled on \(shortDate(cancellation.date))"))
            }
        }

        // Price change within the last 12 months
        var previousAmount: Decimal?
        if status != .cancelled, let change = lastPriceChange(charges), latestAmount > change.previous * Decimal(1.02),
           now.timeIntervalSince(change.date) < 400 * 86_400 {
            previousAmount = change.previous
            if status == .active { status = .priceIncreased }
            reasons.append(L10n.string("Price rose from \(format(change.previous, currency)) to \(format(latestAmount, currency))"))
        }

        if let next = nextBillingDate { reasons.append(L10n.string("Next charge expected around \(shortDate(next))")) }

        let tier = tier(for: score, status: status)
        let evidence = charges.suffix(8).compactMap { signal -> ChargeEvidence? in
            guard let amount = signal.amount else { return nil }
            return ChargeEvidence(id: signal.id, date: signal.date, amount: amount, currency: signal.currency ?? currency)
        }

        return ProvenSubscription(
            id: "\(merchant.key)|\(frequency.rawValue)|\(currency)",
            name: merchant.displayName, merchantKey: merchant.key, category: merchant.category, cancelURL: merchant.cancelURL,
            amount: latestAmount, currency: latest.currency ?? currency, frequency: frequency,
            lastChargeDate: lastDate, nextBillingDate: nextBillingDate, status: status, score: score, tier: tier,
            evidence: evidence, reasons: reasons, previousAmount: previousAmount, trialEndsOn: nil,
            chargedAfterCancel: chargedAfterCancel)
    }

    /// One strong email can still prove a subscription when a known service says it renews.
    private func singleSignalCandidate(eligible: [ReceiptSignal],
                                       merchant: ResolvedMerchant,
                                       signals: [ReceiptSignal],
                                       cancellation: ReceiptSignal?,
                                       now: Date,
                                       calendar: Calendar,
                                       currency: String) -> ProvenSubscription? {
        guard let signal = eligible.last, let amount = signal.amount else { return nil }
        let appStore = signal.platform == "apple" || signal.platform == "googleplay"
        // An app-store receipt is proof only when it says the item renews: the same stores sell one-off
        // purchases inside the same apps.
        guard signal.renewalLanguage else { return nil }
        let structured = signal.markup == .subscription
        let knownPure = merchant.isKnown && merchant.kind == .pureSubscription
        let storeSubscription = appStore && merchant.nameQuality >= 55
        guard knownPure || (structured && merchant.nameQuality >= 55) || storeSubscription else { return nil }

        let frequency = signal.cadenceHint ?? .monthly
        var score = 30 + 12 + (knownPure ? 20 : 0) + (structured ? 25 : 0)
        var reasons = [knownPure ? L10n.string("\(merchant.displayName) is a known subscription service")
                       : structured ? L10n.string("The receipt includes structured subscription data")
                       : L10n.string("Billed through an app-store subscription"),
                       L10n.string("The receipt says it renews on a schedule")]
        if signal.cadenceHint == nil { reasons.append(L10n.string("Billing period assumed monthly until a second charge confirms it")) ; score -= 6 }
        if appStore { score += knownPure ? 10 : 25 }
        if amount < 1 { score -= 18 }

        var status: ProvenSubscription.Status = .active
        let (next, missed) = nextBilling(after: signal.date, frequency: frequency, now: now, calendar: calendar)
        var nextDate: Date? = next
        if missed >= 1, let expected = nextExpected(after: signal.date, frequency: frequency, calendar: calendar),
           now.timeIntervalSince(expected) / 86_400 > graceDays(frequency) {
            let silent = MerchantCatalog.silentRenewalDomains.contains(MerchantCatalog.registrableDomain(signal.senderDomain))
            if silent, cancellation == nil {
                // The store told them it started and has not told them it stopped; it never sends renewal
                // receipts. Probably still running, and worth a look rather than a claim.
                score = min(score, 52)
                reasons = [L10n.string("Subscribed on \(shortDate(signal.date))"),
                           L10n.string("No cancellation email found. This store doesn't email a receipt for each renewal, so it is probably still running.")]
                if let next { reasons.append(L10n.string("Next charge expected around \(shortDate(next))")) }
            } else {
                status = .likelyEnded; nextDate = nil
                reasons.append(L10n.string("No later charge found since \(shortDate(signal.date))"))
            }
        }
        if let cancellation, cancellation.date >= signal.date { status = .cancelled; nextDate = nil; reasons.append(L10n.string("Cancelled on \(shortDate(cancellation.date))")) }

        score = max(0, min(100, score))
        return ProvenSubscription(
            id: "\(merchant.key)|\(frequency.rawValue)|\(currency)",
            name: merchant.displayName, merchantKey: merchant.key, category: merchant.category, cancelURL: merchant.cancelURL,
            amount: amount, currency: signal.currency ?? currency, frequency: frequency,
            lastChargeDate: signal.date, nextBillingDate: nextDate, status: status, score: score,
            tier: tier(for: score, status: status),
            evidence: [ChargeEvidence(id: signal.id, date: signal.date, amount: amount, currency: signal.currency ?? currency)],
            reasons: reasons, previousAmount: nil, trialEndsOn: nil)
    }

    private func trialCandidate(trialSignals: [ReceiptSignal],
                                merchant: ResolvedMerchant,
                                now: Date,
                                calendar: Calendar,
                                currency: String) -> ProvenSubscription? {
        guard merchant.isKnown || merchant.nameQuality >= 55, let latest = trialSignals.last else { return nil }
        let days = trialSignals.compactMap(\.trialDays).last
        let endsOn: Date?
        if latest.kind == .trialEnding { endsOn = calendar.date(byAdding: .day, value: 3, to: latest.date) }
        else if let days { endsOn = calendar.date(byAdding: .day, value: days, to: latest.date) }
        else { endsOn = calendar.date(byAdding: .day, value: 14, to: latest.date) }
        guard let endsOn, endsOn >= now.addingTimeInterval(-3 * 86_400) else { return nil }

        let amount = trialSignals.compactMap(\.amount).last ?? 0
        var reasons = [L10n.string("Free trial detected from your emails")]
        if days == nil { reasons.append(L10n.string("Trial length estimated; check the date in the original email")) }
        reasons.append(L10n.string("Trial ends around \(shortDate(endsOn))"))
        let score = merchant.isKnown ? 62 : 52
        return ProvenSubscription(
            id: "\(merchant.key)|trial|\(currency)", name: merchant.displayName, merchantKey: merchant.key,
            category: merchant.category, cancelURL: merchant.cancelURL, amount: amount, currency: currency,
            frequency: .monthly, lastChargeDate: nil, nextBillingDate: endsOn, status: .trial, score: score,
            tier: .likely, evidence: [], reasons: reasons, previousAmount: nil, trialEndsOn: endsOn)
    }

    private func convertedTrialCandidate(trialSignals: [ReceiptSignal],
                                         cancellation: ReceiptSignal?,
                                         merchant: ResolvedMerchant,
                                         now: Date,
                                         calendar: Calendar,
                                         currency: String) -> ProvenSubscription? {
        guard merchant.isKnown || merchant.nameQuality >= 55,
              let first = trialSignals.first, let latest = trialSignals.last,
              let amount = trialSignals.compactMap(\.amount).last, amount > 0 else { return nil }
        // Only when the trial's end is known; a guessed end date would invent a charge.
        let endsOn: Date?
        if latest.kind == .trialEnding { endsOn = calendar.date(byAdding: .day, value: 3, to: latest.date) }
        else { endsOn = trialSignals.compactMap(\.trialDays).last.flatMap { calendar.date(byAdding: .day, value: $0, to: latest.date) } }
        guard let endsOn, endsOn < now.addingTimeInterval(-3 * 86_400),
              now.timeIntervalSince(endsOn) < 400 * 86_400 else { return nil }
        if let cancellation, cancellation.date >= first.date.addingTimeInterval(-86_400) { return nil }

        let frequency = trialSignals.compactMap(\.cadenceHint).last ?? .monthly
        let (next, _) = nextBilling(after: endsOn, frequency: frequency, now: now, calendar: calendar)
        let price = format(amount, latest.currency ?? currency)
        var reasons = [L10n.string("Free trial ended around \(shortDate(endsOn))"),
                       L10n.string("No cancellation email found, so it most likely renewed at \(price) \(frequency.billingPeriodLabel)")]
        if let next { reasons.append(L10n.string("Next charge expected around \(shortDate(next))")) }
        return ProvenSubscription(
            id: "\(merchant.key)|\(frequency.rawValue)|\(currency)", name: merchant.displayName, merchantKey: merchant.key,
            category: merchant.category, cancelURL: merchant.cancelURL, amount: amount, currency: latest.currency ?? currency,
            frequency: frequency, lastChargeDate: nil, nextBillingDate: next, status: .active, score: 50,
            tier: tier(for: 50, status: .active), evidence: [], reasons: reasons, previousAmount: nil, trialEndsOn: nil)
    }

    // MARK: Tiering

    private func tier(for score: Int, status: ProvenSubscription.Status) -> ProvenSubscription.Tier {
        var tier: ProvenSubscription.Tier
        switch score {
        case 75...: tier = .confirmed
        case 55..<75: tier = .likely
        case 40..<55: tier = .review
        default: tier = .hidden
        }
        // Ended or cancelled items are never pre-selected
        if (status == .likelyEnded || status == .cancelled) && tier == .confirmed { tier = .likely }
        return tier
    }

    // MARK: Insights

    private func makeInsights(for sub: ProvenSubscription, now: Date, calendar: Calendar) -> [IntelligenceInsight] {
        guard sub.tier >= .likely else { return [] }
        var out: [IntelligenceInsight] = []

        if sub.status == .priceIncreased, let old = sub.previousAmount {
            let impact = (sub.amount - old) * ProvenSubscription.periodsPerYear(sub.frequency)
            out.append(IntelligenceInsight(
                id: "price|\(sub.id)", kind: .priceIncrease,
                title: L10n.string("\(sub.name) raised its price"),
                detail: L10n.string("From \(format(old, sub.currency)) to \(format(sub.amount, sub.currency)). That's \(format(impact, sub.currency)) more per year."),
                subscriptionId: sub.id, annualImpact: impact))
        }
        if sub.status == .trial, let ends = sub.trialEndsOn {
            let days = max(0, calendar.dateComponents([.day], from: now, to: ends).day ?? 0)
            out.append(IntelligenceInsight(
                id: "trial|\(sub.id)", kind: .trialEnding, title: L10n.string("\(sub.name) trial ends \(whenPhrase(days))"),
                detail: L10n.string("Cancel before \(shortDate(ends)) to avoid being charged."), subscriptionId: sub.id,
                annualImpact: sub.amount > 0 ? sub.annualCost : nil))
        }
        if sub.status == .active || sub.status == .priceIncreased, let next = sub.nextBillingDate {
            let days = calendar.dateComponents([.day], from: now, to: next).day ?? 999
            let window = sub.frequency == .yearly || sub.frequency == .semiannual ? 45 : 0
            if window > 0, days >= 0, days <= window {
                out.append(IntelligenceInsight(
                    id: "renew|\(sub.id)", kind: .renewalSoon, title: L10n.string("\(sub.name) renews \(whenPhrase(days))"),
                    detail: L10n.string("Expect a charge of \(format(sub.amount, sub.currency)) around \(shortDate(next)). Yearly renewals are the easiest to forget."),
                    subscriptionId: sub.id, annualImpact: sub.annualCost))
            }
        }
        if sub.status == .likelyEnded {
            out.append(IntelligenceInsight(
                id: "ended|\(sub.id)", kind: .likelyEnded, title: L10n.string("\(sub.name) looks like it ended"),
                detail: sub.lastChargeDate.map { L10n.string("No charge since \(shortDate($0)). Confirm it's really cancelled.") }
                    ?? L10n.string("No recent charge. Confirm it's really cancelled."),
                subscriptionId: sub.id, annualImpact: nil))
        }
        if sub.chargedAfterCancel {
            out.append(IntelligenceInsight(
                id: "afterCancel|\(sub.id)", kind: .chargedAfterCancel, title: L10n.string("Charged by \(sub.name) after cancelling"),
                detail: L10n.string("You received a cancellation email, then a later charge of \(format(sub.amount, sub.currency)). Worth disputing."),
                subscriptionId: sub.id, annualImpact: sub.annualCost))
        }
        return out
    }

    private func priceChangeNotices(groups: [String: (merchant: ResolvedMerchant, signals: [ReceiptSignal])],
                                    detected: [ProvenSubscription]) -> [IntelligenceInsight] {
        var out: [IntelligenceInsight] = []
        for sub in detected where sub.tier >= .likely {
            guard let group = groups[sub.merchantKey], group.signals.contains(where: { $0.kind == .priceChange }) else { continue }
            if sub.status == .priceIncreased { continue } // already covered by an exact price insight
            out.append(IntelligenceInsight(
                id: "notice|\(sub.id)", kind: .priceChangeNotice, title: L10n.string("\(sub.name) announced a price change"),
                detail: L10n.string("They emailed about new pricing. Check what you'll pay next billing."), subscriptionId: sub.id, annualImpact: nil))
        }
        return out
    }

    /// "$134.99 for the first year, then $269.99/year": the jump at the next renewal.
    private func introductoryPriceEnds(groups: [String: (merchant: ResolvedMerchant, signals: [ReceiptSignal])],
                                       detected: [ProvenSubscription]) -> [IntelligenceInsight] {
        var out: [IntelligenceInsight] = []
        for sub in detected where sub.tier >= .likely && (sub.status == .active || sub.status == .priceIncreased) {
            guard let group = groups[sub.merchantKey], let lastCharge = sub.lastChargeDate,
                  let signal = group.signals.last(where: {
                      ($0.kind == .charge || $0.kind == .renewalNotice) && $0.nextAmount != nil
                          && abs($0.date.timeIntervalSince(lastCharge)) < 3 * 86_400
                  }),
                  let next = signal.nextAmount else { continue }
            // The email's own two prices when it states both; the amount charged (tax included) otherwise.
            let intro = signal.introAmount ?? sub.amount
            guard next > intro else { continue }
            let impact = (next - intro) * ProvenSubscription.periodsPerYear(sub.frequency)
            let newPrice = format(next, sub.currency)
            let title = sub.nextBillingDate.map { L10n.string("\(sub.name) goes up to \(newPrice) on \(shortDate($0))") }
                ?? L10n.string("\(sub.name) goes up to \(newPrice) at the next renewal")
            out.append(IntelligenceInsight(
                id: "intro|\(sub.id)", kind: .priceChangeNotice,
                title: title,
                detail: L10n.string("You're on an introductory price of \(format(intro, sub.currency)). It renews at \(newPrice) unless you cancel or switch plans first."),
                subscriptionId: sub.id, annualImpact: impact))
        }
        return out
    }

    /// A declined card with no successful charge since: the plan may be paused or cancelled by the merchant.
    private func failedPayments(groups: [String: (merchant: ResolvedMerchant, signals: [ReceiptSignal])],
                                detected: [ProvenSubscription], now: Date) -> [IntelligenceInsight] {
        var out: [IntelligenceInsight] = []
        for sub in detected where sub.tier >= .likely && sub.status != .cancelled {
            guard let group = groups[sub.merchantKey],
                  let failure = group.signals.last(where: { $0.kind == .paymentFailed }),
                  now.timeIntervalSince(failure.date) < 45 * 86_400 else { continue }
            if let lastCharge = sub.lastChargeDate, lastCharge >= failure.date { continue }
            out.append(IntelligenceInsight(
                id: "failed|\(sub.id)", kind: .paymentFailed, title: L10n.string("Payment to \(sub.name) failed"),
                detail: L10n.string("Your card was declined on \(shortDate(failure.date)). Update it if you want to keep \(sub.name), or let it lapse if you don't."),
                subscriptionId: sub.id, annualImpact: nil))
        }
        return out
    }

    // MARK: Date helpers

    private func nextExpected(after date: Date, frequency: BillingFrequency, calendar: Calendar) -> Date? {
        switch frequency {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly: return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual: return calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }

    /// Rolls the schedule forward to the next date at or after `now`. `missed` counts skipped cycles.
    private func nextBilling(after last: Date, frequency: BillingFrequency, now: Date, calendar: Calendar) -> (Date?, Int) {
        var date = last
        var missed = 0
        var guardCount = 0
        while let next = nextExpected(after: date, frequency: frequency, calendar: calendar), guardCount < 400 {
            guardCount += 1
            if next >= calendar.startOfDay(for: now) { return (next, missed) }
            missed += 1
            date = next
        }
        return (nil, missed)
    }

    private func graceDays(_ frequency: BillingFrequency) -> Double {
        switch frequency {
        case .weekly: return 5
        case .biweekly: return 7
        case .monthly: return 10
        case .quarterly: return 16
        case .semiannual: return 25
        case .yearly: return 35
        }
    }

    // MARK: Utility

    private func closeAmounts(_ a: Decimal, _ b: Decimal, tolerance: Double) -> Bool {
        let x = NSDecimalNumber(decimal: a).doubleValue
        let y = NSDecimalNumber(decimal: b).doubleValue
        guard max(x, y) > 0 else { return true }
        return abs(x - y) / max(x, y) <= tolerance
    }

    /// The most recent change of price in a run of charges: what it was before, and the first charge at
    /// today's price. Nil when every charge was the same.
    private func lastPriceChange(_ charges: [ReceiptSignal]) -> (previous: Decimal, date: Date)? {
        guard let latest = charges.last?.amount else { return nil }
        for index in stride(from: charges.count - 1, through: 1, by: -1) {
            guard let earlier = charges[index - 1].amount else { continue }
            if !closeAmounts(earlier, latest, tolerance: 0.02) { return (earlier, charges[index].date) }
        }
        return nil
    }

    /// Amounts that hold steady and change at most twice (7.99, 7.99, 7.99, 9.99, 9.99): a plan whose price
    /// moved, not a run of unrelated orders.
    private func isStepped(_ amounts: [Decimal]) -> Bool {
        guard amounts.count >= 3 else { return false }
        var changes = 0
        var longestLevel = 1
        var level = 1
        for (earlier, later) in zip(amounts, amounts.dropFirst()) {
            if closeAmounts(earlier, later, tolerance: 0.005) {
                level += 1
                longestLevel = max(longestLevel, level)
            } else {
                let low = NSDecimalNumber(decimal: min(earlier, later)).doubleValue
                let high = NSDecimalNumber(decimal: max(earlier, later)).doubleValue
                guard low > 0, high / low <= 2.5 else { return false }
                changes += 1
                level = 1
            }
        }
        return (1...2).contains(changes) && longestLevel >= 2
    }

    private func variation(_ amounts: [Decimal]) -> Double {
        let values = amounts.map { NSDecimalNumber(decimal: $0).doubleValue }
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot() / mean
    }

    private func modalCurrency(_ signals: [ReceiptSignal]) -> String? {
        var counts: [String: Int] = [:]
        for code in signals.compactMap(\.currency) { counts[code, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }

    /// Whole sentences per period: "every month" can't be built from parts in every language.
    private func chargedTimes(_ n: Int, _ frequency: BillingFrequency) -> String {
        switch frequency {
        case .weekly: return L10n.string("Charged \(n) times, about every week")
        case .biweekly: return L10n.string("Charged \(n) times, about every 2 weeks")
        case .monthly: return L10n.string("Charged \(n) times, about every month")
        case .quarterly: return L10n.string("Charged \(n) times, about every 3 months")
        case .semiannual: return L10n.string("Charged \(n) times, about every 6 months")
        case .yearly: return L10n.string("Charged \(n) times, about every year")
        }
    }

    /// "today", "tomorrow", "in 3 days": the time phrase in insight titles.
    private func whenPhrase(_ days: Int) -> String {
        switch days {
        case ...0: return L10n.string("today")
        case 1: return L10n.string("tomorrow")
        default: return L10n.string("in \(days) days")
        }
    }

    private func format(_ amount: Decimal, _ currency: String) -> String {
        MoneyFormat.string(amount, currency)
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
    }
}
