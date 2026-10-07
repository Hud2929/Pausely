import Foundation

// MARK: - Receipt Signal
/// Compact, privacy-preserving facts extracted from ONE email on-device.
/// It deliberately contains no subject line and no body text — only what the engine needs.
struct ReceiptSignal: Codable, Equatable, Identifiable {
    var id: String                       // Gmail message id (dedupe key)
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
    enum Kind: Equatable { case priceIncrease, trialEnding, renewalSoon, likelyEnded, chargedAfterCancel, priceChangeNotice }
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
    var monthlyTotal: Decimal { active.filter { $0.tier >= .likely }.reduce(0) { $0 + $1.monthlyCost } }
    var annualTotal: Decimal { monthlyTotal * 12 }
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
                 defaultCurrency: String = "USD") -> IntelligenceReport {

        // 1. Dedupe by message id
        var seen = Set<String>()
        let unique = signals.filter { seen.insert($0.id).inserted }

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

        for (_, group) in groups {
            let results = analyzeGroup(merchant: group.merchant, signals: group.signals.sorted { $0.date < $1.date },
                                       now: now, calendar: calendar, defaultCurrency: defaultCurrency)
            if results.isEmpty { if group.signals.contains(where: { $0.amount != nil }) { ignored += 1 } }
            detected.append(contentsOf: results)
        }

        for sub in detected { insights.append(contentsOf: makeInsights(for: sub, now: now, calendar: calendar)) }
        insights.append(contentsOf: priceChangeNotices(groups: groups, detected: detected))

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
        let trialSignals = signals.filter { $0.kind == .trialStarted || $0.kind == .trialEnding }

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
        if let whole = evaluateSequence(charges), whole.regularity >= 0.7 { candidates.append(whole) }

        // B. Per-amount clusters (handles mixed merchants with one real plan among many orders)
        for cluster in amountClusters(charges) where cluster.count >= 2 {
            if let seq = evaluateSequence(cluster), seq.regularity >= 0.7 { candidates.append(seq) }
        }

        return candidates.max { lhs, rhs in
            if lhs.charges.count != rhs.charges.count { return lhs.charges.count < rhs.charges.count }
            return lhs.regularity < rhs.regularity
        }
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

    private func evaluateSequence(_ charges: [ReceiptSignal]) -> Sequence? {
        let sorted = charges.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }
        let intervals = zip(sorted, sorted.dropFirst()).map { $1.date.timeIntervalSince($0.date) / 86_400 }

        var best: (cadence: Cadence, regularity: Double)?
        for cadence in Self.cadences {
            var score = 0.0
            for interval in intervals {
                let k = max(1.0, (interval / cadence.days).rounded())
                guard k <= 3 else { continue }
                let tolerance = cadence.tolerance * k.squareRoot()
                if abs(interval - k * cadence.days) <= tolerance { score += (k == 1 ? 1.0 : 0.6) }
            }
            let regularity = score / Double(intervals.count)
            if best == nil || regularity > best!.regularity + 0.001 { best = (cadence, regularity) }
        }
        guard let best else { return nil }
        return Sequence(charges: sorted, cadence: best.cadence, regularity: best.regularity)
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
        reasons.append("Charged \(n) times, about every \(describeInterval(sequence.cadence.frequency))")

        let allSame = amounts.allSatisfy { closeAmounts($0, latestAmount, tolerance: 0.005) }
        let coefficient = variation(amounts)
        if allSame { score += 10; reasons.append("Same amount each time (\(format(latestAmount, currency)))") }
        else if coefficient <= 0.06 { score += 6 }
        else if coefficient > 0.25 { score -= 30; reasons.append("Amount varies a lot, which looks more like orders than a plan") }

        let renewalCount = allSignals.filter { $0.renewalLanguage && !$0.promotional }.count
        if renewalCount >= 2 { score += 20; reasons.append("Emails mention renewing or a recurring plan") }
        else if renewalCount == 1 { score += 12; reasons.append("An email mentions renewing or a recurring plan") }

        let oneTimeShare = Double(charges.filter { $0.oneTimeLanguage }.count) / Double(n)
        if oneTimeShare > 0.5 { score -= 45; reasons.append("Receipts look like one-time orders") }

        if merchant.isKnown {
            if merchant.kind == .pureSubscription { score += 20; reasons.append("\(merchant.displayName) is a known subscription service") }
            else { score += 4 }
        }
        if charges.contains(where: { $0.platform == "apple" || $0.platform == "googleplay" }) {
            score += 15; reasons.append("Billed through an app-store subscription")
        }

        if latestAmount < 1 { score -= 18 }
        if latestAmount > 600 { score -= 20 }
        if !merchant.isKnown && merchant.nameQuality < 50 { score -= 12 }

        // Gating: unknown or mixed-commerce brands must PROVE recurrence
        let needsStrongProof = !merchant.isKnown || merchant.kind == .mixedCommerce
        if needsStrongProof {
            let membershipEvidence = renewalCount >= 1 && allSame && n >= 2
            let strong = (n >= 3 && sequence.regularity >= 0.8 && coefficient <= 0.06) || membershipEvidence
            if !strong { score = min(score, 49); reasons.append("Not enough proof of a recurring plan yet") }
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
            reasons.append("No charge since \(shortDate(lastDate)), so it may have ended")
        }

        var chargedAfterCancel = false
        if let cancellation, cancellation.date > charges.first!.date {
            if latest.date > cancellation.date.addingTimeInterval(86_400) {
                chargedAfterCancel = true
                reasons.append("Charged again on \(shortDate(latest.date)) after a cancellation email on \(shortDate(cancellation.date))")
            } else {
                status = .cancelled
                nextBillingDate = nil
                reasons.append("Cancelled on \(shortDate(cancellation.date))")
            }
        }

        // Price change within the last 12 months
        var previousAmount: Decimal?
        if charges.count >= 2, status != .cancelled {
            let prior = charges.dropLast().compactMap(\.amount).last
            if let prior, latestAmount > prior * Decimal(1.02),
               now.timeIntervalSince(latest.date) < 400 * 86_400 {
                previousAmount = prior
                if status == .active { status = .priceIncreased }
                reasons.append("Price rose from \(format(prior, currency)) to \(format(latestAmount, currency))")
            }
        }

        if let next = nextBillingDate { reasons.append("Next charge expected around \(shortDate(next))") }

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
        let explicit = signal.renewalLanguage || signal.platform == "apple" || signal.platform == "googleplay"
        guard explicit else { return nil }
        guard merchant.isKnown, merchant.kind == .pureSubscription else { return nil }

        let frequency = signal.cadenceHint ?? .monthly
        var score = 30 + 20 + 12
        var reasons = ["\(merchant.displayName) is a known subscription service", "The receipt says it renews on a schedule"]
        if signal.cadenceHint == nil { reasons.append("Billing period assumed monthly until a second charge confirms it") ; score -= 6 }
        if signal.platform == "apple" || signal.platform == "googleplay" { score += 10 }
        if amount < 1 { score -= 18 }

        var status: ProvenSubscription.Status = .active
        let (next, missed) = nextBilling(after: signal.date, frequency: frequency, now: now, calendar: calendar)
        var nextDate: Date? = next
        if missed >= 1, let expected = nextExpected(after: signal.date, frequency: frequency, calendar: calendar),
           now.timeIntervalSince(expected) / 86_400 > graceDays(frequency) {
            status = .likelyEnded; nextDate = nil
            reasons.append("No later charge found since \(shortDate(signal.date))")
        }
        if let cancellation, cancellation.date >= signal.date { status = .cancelled; nextDate = nil; reasons.append("Cancelled on \(shortDate(cancellation.date))") }

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
        var reasons = ["Free trial detected from your emails"]
        if days == nil { reasons.append("Trial length estimated; check the date in the original email") }
        reasons.append("Trial ends around \(shortDate(endsOn))")
        let score = merchant.isKnown ? 62 : 52
        return ProvenSubscription(
            id: "\(merchant.key)|trial|\(currency)", name: merchant.displayName, merchantKey: merchant.key,
            category: merchant.category, cancelURL: merchant.cancelURL, amount: amount, currency: currency,
            frequency: .monthly, lastChargeDate: nil, nextBillingDate: endsOn, status: .trial, score: score,
            tier: .likely, evidence: [], reasons: reasons, previousAmount: nil, trialEndsOn: endsOn)
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
                title: "\(sub.name) raised its price",
                detail: "From \(format(old, sub.currency)) to \(format(sub.amount, sub.currency)). That's \(format(impact, sub.currency)) more per year.",
                subscriptionId: sub.id, annualImpact: impact))
        }
        if sub.status == .trial, let ends = sub.trialEndsOn {
            let days = max(0, calendar.dateComponents([.day], from: now, to: ends).day ?? 0)
            out.append(IntelligenceInsight(
                id: "trial|\(sub.id)", kind: .trialEnding, title: "\(sub.name) trial ends in \(days) day\(days == 1 ? "" : "s")",
                detail: "Cancel before \(shortDate(ends)) to avoid being charged.", subscriptionId: sub.id,
                annualImpact: sub.amount > 0 ? sub.annualCost : nil))
        }
        if sub.status == .active || sub.status == .priceIncreased, let next = sub.nextBillingDate {
            let days = calendar.dateComponents([.day], from: now, to: next).day ?? 999
            let window = sub.frequency == .yearly || sub.frequency == .semiannual ? 45 : 0
            if window > 0, days >= 0, days <= window {
                out.append(IntelligenceInsight(
                    id: "renew|\(sub.id)", kind: .renewalSoon, title: "\(sub.name) renews in \(days) day\(days == 1 ? "" : "s")",
                    detail: "\(format(sub.amount, sub.currency)) \(sub.frequency.displayName.lowercased()) charge around \(shortDate(next)). Yearly renewals are the easiest to forget.",
                    subscriptionId: sub.id, annualImpact: sub.annualCost))
            }
        }
        if sub.status == .likelyEnded {
            out.append(IntelligenceInsight(
                id: "ended|\(sub.id)", kind: .likelyEnded, title: "\(sub.name) looks like it ended",
                detail: "No charge since \(sub.lastChargeDate.map(shortDate) ?? "a while"). Confirm it's really cancelled.",
                subscriptionId: sub.id, annualImpact: nil))
        }
        if sub.chargedAfterCancel {
            out.append(IntelligenceInsight(
                id: "afterCancel|\(sub.id)", kind: .chargedAfterCancel, title: "Charged by \(sub.name) after cancelling",
                detail: "You received a cancellation email, then a later charge of \(format(sub.amount, sub.currency)). Worth disputing.",
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
                id: "notice|\(sub.id)", kind: .priceChangeNotice, title: "\(sub.name) announced a price change",
                detail: "They emailed about new pricing. Check what you'll pay next billing.", subscriptionId: sub.id, annualImpact: nil))
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

    private func describeInterval(_ frequency: BillingFrequency) -> String {
        switch frequency {
        case .weekly: return "week"
        case .biweekly: return "2 weeks"
        case .monthly: return "month"
        case .quarterly: return "3 months"
        case .semiannual: return "6 months"
        case .yearly: return "year"
        }
    }

    private func format(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
