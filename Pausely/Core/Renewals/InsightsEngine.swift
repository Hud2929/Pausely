import Foundation

/// Pure deterministic analytics powering the Insights tab: overview metrics, 12-month renewal
/// cash-flow forecast, flexible-vs-committed spend breakdown, actionable audit counts, and
/// interactive "what if I cut…" savings simulations.
///
/// Every monetary total converts through `CurrencyRates.convert` in `Decimal` first; unknown
/// currencies are never silently mixed into sums (`ENGINEERING_RULES.md`).
enum InsightsEngine {

    // MARK: - Overview Metrics

    struct Overview: Equatable {
        let monthlyTotal: Decimal
        let yearlyTotal: Decimal
        let dailyCost: Decimal
        let isConverted: Bool
        /// Percentage of monthly spend taken by the top 3 subscriptions (only when 4+ active exist).
        let topThreeSharePercent: Int?
    }

    static func overview(for subscriptions: [Subscription],
                         currency: String,
                         rates: CurrencyRates) -> Overview {
        let active = subscriptions.charging
        let monthly = active.monthlyTotal(in: currency, rates: rates)
        let yearly = active.annualTotal(in: currency, rates: rates)
        let converted = active.isConverted(to: currency)
        var daily = yearly / Decimal(365)
        var roundedDaily = Decimal()
        NSDecimalRound(&roundedDaily, &daily, MoneyFormat.fractionDigits(for: currency), .plain)

        let topThreeShare: Int? = {
            let convertedCosts = active.compactMap { $0.monthlyCost(in: currency, rates: rates) }.sorted(by: >)
            guard convertedCosts.count >= 4, monthly > 0 else { return nil }
            let topThree = convertedCosts.prefix(3).reduce(Decimal(0), +)
            let pct = NSDecimalNumber(decimal: (topThree / monthly) * 100).doubleValue.rounded(.down)
            let clamped = min(max(Int(pct), 1), 99)
            return clamped
        }()

        return Overview(
            monthlyTotal: monthly,
            yearlyTotal: yearly,
            dailyCost: roundedDaily,
            isConverted: converted,
            topThreeSharePercent: topThreeShare
        )
    }

    // MARK: - 12-Month Cash-Flow Forecast

    struct ForecastCharge: Identifiable, Equatable {
        let subscriptionId: UUID
        let name: String
        let category: String?
        let date: Date
        let dayStamp: String
        let amount: Decimal
        let currency: String
        let isTrialEnd: Bool

        var id: String { "\(subscriptionId.uuidString)|\(dayStamp)" }
    }

    struct MonthBucket: Identifiable, Equatable {
        /// -1 = remaining days of the current partial month; 0…11 = twelve complete calendar months.
        let offset: Int
        /// First day of the month at local noon.
        let monthStart: Date
        let total: Decimal
        let isConverted: Bool
        let hasUnconvertibleCharges: Bool
        let charges: [ForecastCharge]
        let isPeak: Bool

        var id: Int { offset }
    }

    struct ForecastSummary: Equatable {
        /// Non-nil when `now` is after day 1 of the month and at least one renewal is still due
        /// before the month ends, keeping the 12 main bars strictly complete calendar months.
        let remainingThisMonth: MonthBucket?
        /// Twelve complete upcoming calendar months (starting current month on day 1, else next month).
        let months: [MonthBucket]
        let averageMonthly: Decimal
        let isConverted: Bool
        let peakMonth: MonthBucket?
        let peakAboveAverage: Decimal?
        let undatedCount: Int
        let unconvertibleCount: Int

        var hasCharges: Bool {
            (remainingThisMonth?.charges.isEmpty == false) || months.contains { !$0.charges.isEmpty }
        }
    }

    /// Projects every renewing subscription across 12 complete upcoming calendar months (plus any
    /// charges still due in the remainder of the current month when `now` is past day 1).
    ///
    /// Keeping the 12 forecast bars as complete calendar months guarantees:
    /// - No annual renewal in the trailing days of month 12 is ever dropped.
    /// - `averageMonthly` and `peakMonth` are never skewed by a partial current month.
    /// - Free trials without `nextBillingDate` roll forward from `trialEndsAt`.
    static func monthlyForecast(for subscriptions: [Subscription],
                                now: Date,
                                currency: String,
                                rates: CurrencyRates,
                                calendar: Calendar = .billing) -> ForecastSummary {
        let today = calendar.startOfDay(for: now)
        let todayComps = calendar.dateComponents([.year, .month, .day], from: today)
        guard let curYear = todayComps.year, let curMonth = todayComps.month, let curDay = todayComps.day,
              let firstOfCurrentMonth = calendar.date(from: DateComponents(year: curYear, month: curMonth, day: 1, hour: 12)) else {
            return ForecastSummary(remainingThisMonth: nil, months: [], averageMonthly: 0, isConverted: false,
                                   peakMonth: nil, peakAboveAverage: nil, undatedCount: 0, unconvertibleCount: 0)
        }
        let isPartialCurrentMonth = curDay > 1
        guard let firstFullMonth = isPartialCurrentMonth
            ? calendar.date(byAdding: .month, value: 1, to: firstOfCurrentMonth)
            : firstOfCurrentMonth else {
            return ForecastSummary(remainingThisMonth: nil, months: [], averageMonthly: 0, isConverted: false,
                                   peakMonth: nil, peakAboveAverage: nil, undatedCount: 0, unconvertibleCount: 0)
        }
        let firstFullComps = calendar.dateComponents([.year, .month], from: firstFullMonth)
        guard let baseY = firstFullComps.year, let baseM = firstFullComps.month,
              let windowEndStart = calendar.date(byAdding: .month, value: 12, to: calendar.startOfDay(for: firstFullMonth)) else {
            return ForecastSummary(remainingThisMonth: nil, months: [], averageMonthly: 0, isConverted: false,
                                   peakMonth: nil, peakAboveAverage: nil, undatedCount: 0, unconvertibleCount: 0)
        }

        let displayCode = MoneyFormat.normalizedCode(currency)
        var partialCharges: [ForecastCharge] = []
        var partialTotal: Decimal = 0
        var partialConverted = false
        var partialUnconvertible = false

        var bucketCharges: [[ForecastCharge]] = Array(repeating: [], count: 12)
        var bucketTotals: [Decimal] = Array(repeating: 0, count: 12)
        var bucketConverted: [Bool] = Array(repeating: false, count: 12)
        var bucketUnconvertible: [Bool] = Array(repeating: false, count: 12)
        var undatedCount = 0
        var unconvertibleIDs: Set<UUID> = []

        for sub in subscriptions where sub.renewsAutomatically {
            let futureTrialEnd: Date? = (sub.status == .trial)
                ? sub.trialEndsAt.flatMap { calendar.startOfDay(for: $0) >= today ? calendar.noon(of: $0) : nil }
                : nil

            var occurrences: [(Date, Bool)] = []
            if let futureTrialEnd {
                occurrences.append((futureTrialEnd, true))
            }
            let recurringAnchor = sub.nextBillingDate ?? (sub.status == .trial ? sub.trialEndsAt : nil)
            if let anchor = recurringAnchor {
                let startAfter = futureTrialEnd.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } ?? today
                let maxCycles: Int = {
                    switch sub.billingFrequency {
                    case .weekly: return 60
                    case .biweekly: return 30
                    case .monthly: return 14
                    case .quarterly: return 6
                    case .semiannual: return 4
                    case .yearly: return 2
                    }
                }()
                let renewals = RenewalSchedule.upcomingRenewals(
                    anchor: anchor,
                    frequency: sub.billingFrequency,
                    onOrAfter: startAfter,
                    count: maxCycles,
                    calendar: calendar
                )
                occurrences.append(contentsOf: renewals.map { ($0, false) })
            }

            if occurrences.isEmpty {
                undatedCount += 1
                continue
            }

            let convertedAmount = rates.convert(sub.amount, from: sub.currency, to: currency)
            if convertedAmount == nil {
                unconvertibleIDs.insert(sub.id)
            }
            let needsConversion = MoneyFormat.normalizedCode(sub.currency) != displayCode

            for (date, isTrialEnd) in occurrences {
                let dayStart = calendar.startOfDay(for: date)
                guard dayStart >= today else { continue }
                guard dayStart < windowEndStart else { break }

                let charge = ForecastCharge(
                    subscriptionId: sub.id,
                    name: sub.name,
                    category: sub.category,
                    date: date,
                    dayStamp: calendar.dayStamp(date),
                    amount: sub.amount,
                    currency: sub.currency,
                    isTrialEnd: isTrialEnd
                )

                let comps = calendar.dateComponents([.year, .month], from: dayStart)
                guard let y = comps.year, let m = comps.month else { continue }

                if isPartialCurrentMonth && y == curYear && m == curMonth {
                    partialCharges.append(charge)
                    if let convertedAmount {
                        partialTotal += convertedAmount
                        if needsConversion { partialConverted = true }
                    } else {
                        partialUnconvertible = true
                    }
                    continue
                }

                let offset = (y - baseY) * 12 + (m - baseM)
                guard offset >= 0 && offset < 12 else { continue }

                bucketCharges[offset].append(charge)
                if let convertedAmount {
                    bucketTotals[offset] += convertedAmount
                    if needsConversion { bucketConverted[offset] = true }
                } else {
                    bucketUnconvertible[offset] = true
                }
            }
        }

        let sum12 = bucketTotals.reduce(Decimal(0), +)
        var avg = sum12 / Decimal(12)
        var roundedAvg = Decimal()
        NSDecimalRound(&roundedAvg, &avg, MoneyFormat.fractionDigits(for: currency), .plain)

        let maxTotal = bucketTotals.max() ?? 0
        let peakOffset: Int? = {
            guard maxTotal > 0 else { return nil }
            let threshold = roundedAvg * Decimal(string: "1.15")!
            guard maxTotal >= threshold else { return nil }
            return bucketTotals.firstIndex(of: maxTotal)
        }()

        let months: [MonthBucket] = (0..<12).compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: offset, to: firstFullMonth) else { return nil }
            let sorted = bucketCharges[offset].sorted { ($0.date, $0.name) < ($1.date, $1.name) }
            return MonthBucket(
                offset: offset,
                monthStart: start,
                total: bucketTotals[offset],
                isConverted: bucketConverted[offset],
                hasUnconvertibleCharges: bucketUnconvertible[offset],
                charges: sorted,
                isPeak: peakOffset == offset
            )
        }

        let remainingBucket: MonthBucket? = partialCharges.isEmpty ? nil : MonthBucket(
            offset: -1,
            monthStart: firstOfCurrentMonth,
            total: partialTotal,
            isConverted: partialConverted,
            hasUnconvertibleCharges: partialUnconvertible,
            charges: partialCharges.sorted { ($0.date, $0.name) < ($1.date, $1.name) },
            isPeak: false
        )

        let peak = peakOffset.flatMap { idx in months.first { $0.offset == idx } }
        let aboveAverage = peak.map { max(Decimal(0), $0.total - roundedAvg) }

        return ForecastSummary(
            remainingThisMonth: remainingBucket,
            months: months,
            averageMonthly: roundedAvg,
            isConverted: bucketConverted.contains(true),
            peakMonth: peak,
            peakAboveAverage: aboveAverage,
            undatedCount: undatedCount,
            unconvertibleCount: unconvertibleIDs.count
        )
    }

    // MARK: - Flexible vs. Committed Spend Mix

    struct CommitmentMix: Equatable {
        let flexibleYearly: Decimal
        let committedYearly: Decimal
        let flexibleCount: Int
        let committedCount: Int
        let isConverted: Bool

        var totalYearly: Decimal { flexibleYearly + committedYearly }

        var flexibleShare: Double {
            guard totalYearly > 0 else { return 0 }
            return min(max(NSDecimalNumber(decimal: flexibleYearly / totalYearly).doubleValue, 0), 1)
        }

        var committedShare: Double {
            guard totalYearly > 0 else { return 0 }
            return min(max(1 - flexibleShare, 0), 1)
        }
    }

    static func commitmentMix(for subscriptions: [Subscription],
                              currency: String,
                              rates: CurrencyRates) -> CommitmentMix? {
        var flexSum: Decimal = 0
        var commSum: Decimal = 0
        var flexCount = 0
        var commCount = 0
        var convertedAny = false
        let display = MoneyFormat.normalizedCode(currency)

        for sub in subscriptions.charging {
            guard let yearly = rates.convert(sub.annualCost, from: sub.currency, to: currency) else { continue }
            if MoneyFormat.normalizedCode(sub.currency) != display { convertedAny = true }
            switch sub.billingFrequency {
            case .weekly, .biweekly, .monthly:
                flexSum += yearly
                flexCount += 1
            case .quarterly, .semiannual, .yearly:
                commSum += yearly
                commCount += 1
            }
        }
        guard flexCount + commCount > 0 else { return nil }
        return CommitmentMix(
            flexibleYearly: flexSum,
            committedYearly: commSum,
            flexibleCount: flexCount,
            committedCount: commCount,
            isConverted: convertedAny
        )
    }

    // MARK: - Interactive Cut Simulator

    enum CutReason: Equatable {
        case unused
        case priceIncreased
        case overlapping

        var label: String {
            switch self {
            case .unused: return L10n.string("Not used")
            case .priceIncreased: return L10n.string("Price went up")
            case .overlapping: return L10n.string("Overlaps")
            }
        }

        var priority: Int {
            switch self {
            case .unused: return 0
            case .priceIncreased: return 1
            case .overlapping: return 2
            }
        }
    }

    struct CutCandidate: Identifiable, Equatable {
        let subscription: Subscription
        let yearlyInDisplay: Decimal
        let isConverted: Bool
        let reason: CutReason?

        var id: UUID { subscription.id }
    }

    struct CutSimulation: Equatable {
        let selectedCount: Int
        let monthlySaved: Decimal
        let yearlySaved: Decimal
        let fiveYearSaved: Decimal
        let remainingMonthly: Decimal
        let remainingYearly: Decimal
        let savedIsConverted: Bool
        let remainingIsConverted: Bool
    }

    /// Ranks active non-Pausely subscriptions for the Cut Simulator: flagged waste signals first
    /// (unused, price hiked, overlapping), then highest yearly cost first.
    static func cutCandidates(in subscriptions: [Subscription],
                              events: [LifecycleEvent],
                              minutesThisMonth: (Subscription) -> Int?,
                              currency: String,
                              rates: CurrencyRates) -> [CutCandidate] {
        let overlapIDs = Set(
            OverlapDetector.groups(in: subscriptions, currency: currency, rates: rates)
                .flatMap { $0.subscriptions.map(\.id) }
        )
        let display = MoneyFormat.normalizedCode(currency)

        return subscriptions.charging
            .filter { !$0.isPausely }
            .compactMap { sub -> CutCandidate? in
                guard let yearly = rates.convert(sub.annualCost, from: sub.currency, to: currency), yearly > 0 else { return nil }
                let reason: CutReason? = {
                    if let mins = minutesThisMonth(sub), mins == 0 { return .unused }
                    if let change = PriceHistory.latestChange(for: sub, events: events), change.isIncrease { return .priceIncreased }
                    if overlapIDs.contains(sub.id) { return .overlapping }
                    return nil
                }()
                return CutCandidate(
                    subscription: sub,
                    yearlyInDisplay: yearly,
                    isConverted: MoneyFormat.normalizedCode(sub.currency) != display,
                    reason: reason
                )
            }
            .sorted { lhs, rhs in
                let lp = lhs.reason?.priority ?? 99
                let rp = rhs.reason?.priority ?? 99
                if lp != rp { return lp < rp }
                if lhs.yearlyInDisplay != rhs.yearlyInDisplay { return lhs.yearlyInDisplay > rhs.yearlyInDisplay }
                return lhs.subscription.name.localizedCaseInsensitiveCompare(rhs.subscription.name) == .orderedAscending
            }
    }

    /// Pure deterministic arithmetic for selected cut toggles: exact 1-year and 5-year cash saved
    /// plus remaining monthly and yearly totals, tracking FX conversion independently for saved
    /// vs. remaining subsets.
    static func simulateCuts(selectedIDs: Set<UUID>,
                             in subscriptions: [Subscription],
                             currency: String,
                             rates: CurrencyRates) -> CutSimulation {
        let active = subscriptions.charging
        let totalMonthly = active.monthlyTotal(in: currency, rates: rates)
        let totalYearly = active.annualTotal(in: currency, rates: rates)
        let selected = active.filter { selectedIDs.contains($0.id) }
        let remaining = active.filter { !selectedIDs.contains($0.id) }
        let monthlySaved = selected.monthlyTotal(in: currency, rates: rates)
        let yearlySaved = selected.annualTotal(in: currency, rates: rates)
        return CutSimulation(
            selectedCount: selected.count,
            monthlySaved: monthlySaved,
            yearlySaved: yearlySaved,
            fiveYearSaved: yearlySaved * Decimal(5),
            remainingMonthly: max(Decimal(0), totalMonthly - monthlySaved),
            remainingYearly: max(Decimal(0), totalYearly - yearlySaved),
            savedIsConverted: selected.isConverted(to: currency),
            remainingIsConverted: remaining.isConverted(to: currency)
        )
    }
}
