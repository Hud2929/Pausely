import Foundation

/// The charges of one merchant that bill on a schedule: which charges, how often, and how regular the
/// run is. A subscription is proven by this pattern, not by one email that mentions a price, so finding
/// the pattern is kept apart from what the engine makes of it (`SubscriptionIntelligenceEngine`).
struct ChargeSchedule {

    struct Cadence {
        let frequency: BillingFrequency
        let days: Double
        let tolerance: Double
    }

    var charges: [ReceiptSignal]
    var cadence: Cadence
    var regularity: Double
    /// The receipts its period expects between its charges that the mailbox does not hold.
    var missed: Int
    /// How many times the price differs from one charge of the chain to the next. A plan whose price
    /// rose once has one; a chain with another purchase in the middle of it has two.
    var priceBreaks: Int
    /// Charges for the same plan after the chain's last one that the chain left out because their amount
    /// moved too far to be the same price (a plan change): newest last. They set what is current (the
    /// price, the last charge, the next one) and nothing about how regular the plan is.
    var laterCharges: [ReceiptSignal] = []
    /// Charges for the same plan before the chain's first one that it left out (an older price): oldest
    /// first. The last of them is what the plan cost before.
    var earlierCharges: [ReceiptSignal] = []

    private static let cadences: [Cadence] = [
        Cadence(frequency: .weekly, days: 7, tolerance: 2),
        Cadence(frequency: .biweekly, days: 14, tolerance: 3),
        Cadence(frequency: .monthly, days: 30.44, tolerance: 5),
        Cadence(frequency: .quarterly, days: 91.3, tolerance: 8),
        Cadence(frequency: .semiannual, days: 182.6, tolerance: 12),
        Cadence(frequency: .yearly, days: 365.25, tolerance: 20)
    ]

    /// Two receipts for the same amount within 3 days are one charge (receipt + payment notice).
    static func collapsing(_ signals: [ReceiptSignal]) -> [ReceiptSignal] {
        var out: [ReceiptSignal] = []
        for signal in signals.sorted(by: { $0.date < $1.date }) {
            if let last = out.last, let a = last.amount, let b = signal.amount,
               abs(signal.date.timeIntervalSince(last.date)) < 3 * 86_400, sameAmount(a, b, tolerance: 0.02) {
                continue
            }
            out.append(signal)
        }
        return out
    }

    /// The schedule in one merchant's charges, or nil when they follow none.
    static func best(in charges: [ReceiptSignal]) -> ChargeSchedule? {
        guard charges.count >= 2 else { return nil }

        // A. Whole-merchant sequence (handles price changes)
        var candidates: [ChargeSchedule] = []
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

    /// The charges that bill on a schedule: a chain in which each charge follows the one before by one, two
    /// or three periods. A stray email between two receipts (a promotion read as a charge, a one-off
    /// purchase from the same company) is left out of the chain instead of breaking it, and an old gap of
    /// many months (deleted mail, a paused plan) starts the chain afresh.
    ///
    /// Every billing period gives its own reading of the same charges. The one kept is, first, the one
    /// that leaves out the fewest charges at the plan's own price (a plan does not charge off its own
    /// schedule, so each of those speaks against the reading); then the one that leaves the least
    /// unexplained, counting the receipts it has to suppose were lost and the other charges it has to
    /// leave out; then the one whose price changes least from charge to charge. The longest chain used
    /// to win outright: a monthly plan with one other purchase in the middle of a month was read as
    /// fortnightly with receipts missing (five charges in the chain beat four), a quarterly plan with a
    /// purchase a month after its first charge as monthly, a yearly one as six-monthly.
    private static func regularChain(_ charges: [ReceiptSignal]) -> ChargeSchedule? {
        let sorted = charges.sorted { $0.date < $1.date }
        guard sorted.count >= 2, let newest = sorted.last else { return nil }

        /// What a reading leaves out: charges at the price the plan stands at, and all the others.
        func leftOut(_ reading: ChargeSchedule) -> (atThePlansPrice: Int, others: Int) {
            let inTheChain = Set(reading.charges.map(\.id))
            let rest = sorted.filter { !inTheChain.contains($0.id) }
            guard let price = reading.charges.last?.amount else { return (0, rest.count) }
            let same = rest.filter { $0.amount.map { sameAmount($0, price, tolerance: 0.02) } ?? false }.count
            return (same, rest.count - same)
        }

        func better(_ a: ChargeSchedule?, _ b: ChargeSchedule?) -> ChargeSchedule? {
            guard let a else { return b }
            guard let b else { return a }
            let aLeft = leftOut(a), bLeft = leftOut(b)
            if aLeft.atThePlansPrice != bLeft.atThePlansPrice { return aLeft.atThePlansPrice < bLeft.atThePlansPrice ? a : b }
            let aLoose = a.missed + aLeft.others, bLoose = b.missed + bLeft.others
            if aLoose != bLoose { return aLoose < bLoose ? a : b }
            if a.priceBreaks != b.priceBreaks { return a.priceBreaks < b.priceBreaks ? a : b }
            if a.charges.count != b.charges.count { return a.charges.count > b.charges.count ? a : b }
            if abs(a.regularity - b.regularity) > 0.001 { return a.regularity > b.regularity ? a : b }
            // Equal on both: the period the receipts themselves state, then the one that reaches further forward.
            let aStated = statedShare(a), bStated = statedShare(b)
            if aStated != bStated { return aStated > bStated ? a : b }
            return (a.charges.last?.date ?? .distantPast) >= (b.charges.last?.date ?? .distantPast) ? a : b
        }

        var longest: ChargeSchedule?
        var reachingNewest: ChargeSchedule?
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
    private static func statedShare(_ sequence: ChargeSchedule) -> Int {
        sequence.charges.filter { $0.cadenceHint == sequence.cadence.frequency }.count
    }

    /// For one billing period: the best chain anywhere in the history, and the best one ending at the newest
    /// charge. Either is nil when it is too irregular to be a schedule.
    private static func chains(_ sorted: [ReceiptSignal], _ cadence: Cadence) -> (overall: ChargeSchedule?, atEnd: ChargeSchedule?) {
        let count = sorted.count
        var length = [Int](repeating: 1, count: count)
        var weight = [Double](repeating: 0, count: count)
        var previous = [Int?](repeating: nil, count: count)
        var missed = [Int](repeating: 0, count: count)
        var breaks = [Int](repeating: 0, count: count)
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
                // Two charges can each be the one before this: a renewal, and another purchase a few days
                // from it. As long and as regular either way, the chain is the one that stays at one price.
                var samePrice = true
                if let earlier = sorted[j].amount, let later = sorted[i].amount {
                    samePrice = sameAmount(earlier, later, tolerance: 0.02)
                }
                let candidateBreaks = breaks[j] + (samePrice ? 0 : 1)
                let asLongAndRegular = candidateLength == length[i] && abs(candidateWeight - weight[i]) < 1e-9
                if candidateLength > length[i] || (candidateLength == length[i] && candidateWeight > weight[i])
                    || (asLongAndRegular && candidateBreaks < breaks[i]) {
                    length[i] = candidateLength
                    weight[i] = candidateWeight
                    previous[i] = j
                    missed[i] = missed[j] + Int(periods) - 1
                    breaks[i] = candidateBreaks
                }
            }
        }

        func sequence(endingAt end: Int) -> ChargeSchedule? {
            guard length[end] >= 2 else { return nil }
            var indexes: [Int] = []
            var cursor: Int? = end
            while let index = cursor { indexes.append(index); cursor = previous[index] }
            let regularity = weight[end] / Double(length[end] - 1)
            guard regularity >= 0.7 else { return nil }
            return ChargeSchedule(charges: indexes.reversed().map { sorted[$0] }, cadence: cadence, regularity: regularity,
                                  missed: missed[end], priceBreaks: breaks[end])
        }

        var best: Int?
        for i in 0..<count where length[i] >= 2 {
            guard let current = best else { best = i; continue }
            // Longer first; then more regular; then the one that stays at one price; then the later one.
            let asLong = length[i] == length[current]
            let asRegular = abs(weight[i] - weight[current]) < 1e-9
            if length[i] > length[current] || (asLong && !asRegular && weight[i] > weight[current])
                || (asLong && asRegular && breaks[i] <= breaks[current]) { best = i }
        }
        return (best.flatMap(sequence(endingAt:)), sequence(endingAt: count - 1))
    }

    private static func amountClusters(_ charges: [ReceiptSignal]) -> [[ReceiptSignal]] {
        var clusters: [[ReceiptSignal]] = []
        for charge in charges {
            guard let amount = charge.amount else { continue }
            if let index = clusters.firstIndex(where: { cluster in
                guard let reference = cluster.first?.amount else { return false }
                return sameAmount(reference, amount, tolerance: 0.015)
            }) {
                clusters[index].append(charge)
            } else {
                clusters.append([charge])
            }
        }
        return clusters
    }

    /// Whether two amounts are the same to within a share of the larger one (0.02 is two percent).
    static func sameAmount(_ a: Decimal, _ b: Decimal, tolerance: Double) -> Bool {
        let x = NSDecimalNumber(decimal: a).doubleValue
        let y = NSDecimalNumber(decimal: b).doubleValue
        guard max(x, y) > 0 else { return true }
        return abs(x - y) / max(x, y) <= tolerance
    }
}
