import Foundation

// MARK: - Engine

/// Turns a pile of per-email facts into the subscriptions a person truly pays for.
/// Core idea: a subscription is *proven by a pattern of charges over time*, not by one email that mentions a price.
struct SubscriptionIntelligenceEngine {

    var catalog: MerchantCatalog = .builtin

    // MARK: Public entry

    func analyze(signals: [ReceiptSignal],
                 now: Date = Date(),
                 calendar: Calendar = .billing,
                 defaultCurrency: String = "USD",
                 corrections: [String: UserVerdict] = [:]) -> IntelligenceReport {

        // 1. Dedupe by message id, and never trust a receipt whose sender failed authentication
        var seen = Set<String>()
        let unique = signals.filter { $0.spoofSuspected != true && seen.insert($0.id).inserted }

        // 2. Resolve merchants, drop junk identities
        var groups: SubscriptionInsights.Groups = [:]
        for signal in unique {
            guard let merchant = catalog.resolve(hint: signal.merchantHint,
                                                 senderName: signal.senderName,
                                                 senderDomain: signal.senderDomain) else { continue }
            groups[merchant.key, default: (merchant, [])].signals.append(signal)
        }

        var detected: [ProvenSubscription] = []
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

        // What is worth saying is worked out from everything detected, before the weak ones are dropped.
        let insights = SubscriptionInsights.all(for: detected, groups: groups, now: now, calendar: calendar)
            .sorted { ($0.annualImpact ?? 0) > ($1.annualImpact ?? 0) }

        detected = detected
            .filter { $0.tier >= .review }
            .sorted {
                if $0.tier != $1.tier { return $0.tier > $1.tier }
                return $0.annualCost > $1.annualCost
            }

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

        if var sequence = ChargeSchedule.best(in: ChargeSchedule.collapsing(eligible)) {
            // A later charge for this plan that the regular chain left out (a plan change, a new price) is
            // still its newest charge. Dropped, "Last charged Oct 20, $31.64" stood after a $148.41 charge
            // on Nov 10 (a real inbox, 2026-11-22). Only charges whose own receipt says they recur count;
            // a one-off order from the same seller never moves the plan.
            if let chainEnd = sequence.charges.last {
                let inChain = Set(sequence.charges.map(\.id))
                sequence.laterCharges = eligible
                    .filter { $0.date > chainEnd.date && !inChain.contains($0.id) && $0.kind == .charge
                              && ($0.cadenceHint != nil || $0.renewalLanguage) && !$0.oneTimeLanguage }
                    .sorted { $0.date < $1.date }
            }
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

    // MARK: Build detected subscription

    private func buildFromSequence(_ sequence: ChargeSchedule,
                                   merchant: ResolvedMerchant,
                                   allSignals: [ReceiptSignal],
                                   cancellation: ReceiptSignal?,
                                   now: Date,
                                   calendar: Calendar,
                                   currency: String) -> ProvenSubscription? {

        let charges = sequence.charges
        guard let chainLatest = charges.last, let chainAmount = chainLatest.amount else { return nil }
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

        let allSame = amounts.allSatisfy { ChargeSchedule.sameAmount($0, chainAmount, tolerance: 0.005) }
        let coefficient = variation(amounts)
        // A plan whose price changed once or twice is still one plan; orders change every time.
        let stepped = !allSame && isStepped(amounts)
        if allSame { score += 10; reasons.append(L10n.string("Same amount each time (\(format(chainAmount, currency)))")) }
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

        if chainAmount < 1 { score -= 18 }
        if chainAmount > 600 { score -= 20 }
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
        // The newest charge of this plan says what is current, even one the chain left out.
        let latest = sequence.laterCharges.last ?? chainLatest
        let latestAmount = latest.amount ?? chainAmount
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
        var priceChange = lastPriceChange(charges)
        if latest.id != chainLatest.id, !ChargeSchedule.sameAmount(latestAmount, chainAmount, tolerance: 0.02) {
            priceChange = (previous: chainAmount, date: latest.date)
        }
        if status != .cancelled, let change = priceChange, latestAmount > change.previous * Decimal(1.02),
           now.timeIntervalSince(change.date) < 400 * 86_400 {
            previousAmount = change.previous
            if status == .active { status = .priceIncreased }
            if ProvenSubscription.isPlanChange(from: change.previous, to: latestAmount) {
                reasons.append(L10n.string("Up from \(format(change.previous, currency)) to \(format(latestAmount, currency)) on \(shortDate(change.date)): a new plan or a higher price"))
            } else {
                reasons.append(L10n.string("Price rose from \(format(change.previous, currency)) to \(format(latestAmount, currency))"))
            }
        }

        if let next = nextBillingDate { reasons.append(L10n.string("Next charge expected around \(shortDate(next))")) }

        let tier = tier(for: score, status: status)
        let evidence = (charges + sequence.laterCharges).suffix(8).compactMap { signal -> ChargeEvidence? in
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
        var lastCharge: Date? = signal.date
        var startedOn: Date?
        if missed >= 1, let expected = nextExpected(after: signal.date, frequency: frequency, calendar: calendar),
           now.timeIntervalSince(expected) / 86_400 > graceDays(frequency) {
            let silent = MerchantCatalog.silentRenewalDomains.contains(MerchantCatalog.registrableDomain(signal.senderDomain))
            if silent, cancellation == nil {
                // The store told them it started and has not told them it stopped; it never sends renewal
                // receipts. Probably still running, and worth a look rather than a claim.
                score = min(score, 52)
                // Its one email is the sign-up, not the latest of the charges that followed.
                lastCharge = nil
                startedOn = signal.date
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
            lastChargeDate: lastCharge, nextBillingDate: nextDate, status: status, score: score,
            tier: tier(for: score, status: status),
            evidence: [ChargeEvidence(id: signal.id, date: signal.date, amount: amount, currency: signal.currency ?? currency)],
            reasons: reasons, previousAmount: nil, trialEndsOn: nil, subscribedOn: startedOn)
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
            tier: tier(for: 50, status: .active), evidence: [], reasons: reasons, previousAmount: nil, trialEndsOn: nil,
            subscribedOn: first.date)
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

    /// The most recent change of price in a run of charges: what it was before, and the first charge at
    /// today's price. Nil when every charge was the same.
    private func lastPriceChange(_ charges: [ReceiptSignal]) -> (previous: Decimal, date: Date)? {
        guard let latest = charges.last?.amount else { return nil }
        for index in stride(from: charges.count - 1, through: 1, by: -1) {
            guard let earlier = charges[index - 1].amount else { continue }
            if !ChargeSchedule.sameAmount(earlier, latest, tolerance: 0.02) { return (earlier, charges[index].date) }
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
            if ChargeSchedule.sameAmount(earlier, later, tolerance: 0.005) {
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

    private func format(_ amount: Decimal, _ currency: String) -> String {
        MoneyFormat.string(amount, currency)
    }

    private func shortDate(_ date: Date) -> String {
        ReceiptWording.shortDate(date)
    }
}

/// Words the engine and its insights share.
enum ReceiptWording {
    /// "Nov 3": a day as the reasons and insights give it, in the app's language.
    static func shortDate(_ date: Date) -> String {
        DayText.date(date, locale: L10n.locale)
    }
}
