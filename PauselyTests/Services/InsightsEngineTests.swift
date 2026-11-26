import XCTest
@testable import Pausely

/// Verifies every pure deterministic calculation in `InsightsEngine`: overview daily burn (including
/// 3-decimal currencies) and top-3 concentration, lossless 12-month renewal cash-flow projection
/// across partial months, trailing annual renewals, free trials without `nextBillingDate`, DST
/// boundaries, undated/unconvertible safety, flexible-vs-committed spend mix, and cut simulator math
/// with independent saved/remaining FX conversion flags.
final class InsightsEngineTests: XCTestCase {

    private let rates = CurrencyRates(perUSD: ["USD": 1, "CAD": 2, "KWD": Decimal(string: "0.3")!])
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Toronto")!
        return cal
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testOverviewComputesDailyCostWithCurrencyPrecisionAndTopThreeShareOnlyWhenFourOrMore() {
        let s1 = Subscription(name: "Adobe", amount: 50, currency: "USD", billingFrequency: .monthly)
        let s2 = Subscription(name: "Netflix", amount: 20, currency: "USD", billingFrequency: .monthly)
        let s3 = Subscription(name: "Spotify", amount: 10, currency: "USD", billingFrequency: .monthly)
        let s4 = Subscription(name: "iCloud+", amount: 20, currency: "USD", billingFrequency: .monthly)

        // 3 active -> topThreeSharePercent is nil (avoid meaningless "100%").
        let small = InsightsEngine.overview(for: [s1, s2, s3], currency: "USD", rates: rates)
        XCTAssertNil(small.topThreeSharePercent)
        XCTAssertEqual(small.monthlyTotal, Decimal(80))
        XCTAssertEqual(small.yearlyTotal, Decimal(960))

        // 4 active ($50, $20, $20, $10 = $100/mo -> top 3 = $90 = 90%).
        let four = InsightsEngine.overview(for: [s1, s2, s3, s4], currency: "USD", rates: rates)
        XCTAssertEqual(four.topThreeSharePercent, 90)
        // $1200 / 365 = 3.2876... -> $3.29
        XCTAssertEqual(four.dailyCost, Decimal(string: "3.29"))

        // 3-decimal currency (KWD) preserves 3 fractional digits instead of truncating to 2.
        let kwdSub = Subscription(name: "Local", amount: Decimal(string: "36.500")!, currency: "KWD", billingFrequency: .monthly)
        // 36.5 * 12 / 365 = 1.200 -> exact; test non-zero 3rd digit: 10 * 12 / 365 = 0.32876... -> 0.329
        let kwdExact = Subscription(name: "Gym", amount: Decimal(10), currency: "KWD", billingFrequency: .monthly)
        let kwdOverview = InsightsEngine.overview(for: [kwdExact], currency: "KWD", rates: rates)
        XCTAssertEqual(kwdOverview.dailyCost, Decimal(string: "0.329"))
        _ = kwdSub
    }

    func testMonthlyForecastProjectsFullMonthsCapturesTrailingAnnualAndSurfacesRemainingThisMonth() {
        let now = day(2026, 11, 26)
        // Monthly billed Nov 28 -> appears in remainingThisMonth AND all 12 full months (Dec 2026…Nov 2027).
        let netflix = Subscription(name: "Netflix", amount: 20, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: day(2026, 11, 28))
        // Annual billed Nov 10 -> next occurrence is Nov 10, 2027 (months[11]), MUST NOT be dropped!
        let trailingAnnual = Subscription(name: "Domain", amount: 120, currency: "USD",
                                          billingFrequency: .yearly, nextBillingDate: day(2026, 11, 10))
        // Annual peak in March 2027 (months[3]: Dec=0, Jan=1, Feb=2, Mar=3).
        let prime = Subscription(name: "Amazon Prime", amount: 140, currency: "USD",
                                 billingFrequency: .yearly, nextBillingDate: day(2027, 3, 15))
        let crave = Subscription(name: "Crave", amount: 20, currency: "CAD",
                                 billingFrequency: .monthly, nextBillingDate: day(2026, 12, 10))
        let undated = Subscription(name: "Mystery Box", amount: 15, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: nil)
        let unknownCurrency = Subscription(name: "Foreign", amount: 100, currency: "ZZZ",
                                           billingFrequency: .monthly, nextBillingDate: day(2026, 12, 12))

        let summary = InsightsEngine.monthlyForecast(
            for: [netflix, trailingAnnual, prime, crave, undated, unknownCurrency],
            now: now,
            currency: "USD",
            rates: rates,
            calendar: calendar
        )

        XCTAssertEqual(summary.months.count, 12)
        XCTAssertEqual(summary.undatedCount, 1)
        XCTAssertEqual(summary.unconvertibleCount, 1)
        XCTAssertTrue(summary.isConverted)

        // Remaining days of Nov 2026 hold Netflix ($20 on Nov 28).
        XCTAssertEqual(summary.remainingThisMonth?.offset, -1)
        XCTAssertEqual(summary.remainingThisMonth?.total, Decimal(20))
        XCTAssertEqual(summary.remainingThisMonth?.charges.map(\.name), ["Netflix"])

        // Months[0] = Dec 2026: Netflix $20 + Crave $10 = $30; Foreign flagged unconvertible, never added.
        XCTAssertEqual(summary.months[0].total, Decimal(30))
        XCTAssertTrue(summary.months[0].hasUnconvertibleCharges)

        // Months[3] = Mar 2027: Netflix $20 + Crave $10 + Prime $140 = $170 (peak!).
        let march = summary.months[3]
        XCTAssertEqual(march.total, Decimal(170))
        XCTAssertTrue(march.isPeak)
        XCTAssertEqual(summary.peakMonth?.offset, 3)

        // Months[11] = Nov 2027: Netflix $20 + Crave $10 + trailing annual Domain $120 = $150 (NOT dropped!).
        let nov2027 = summary.months[11]
        XCTAssertEqual(nov2027.total, Decimal(150))
        XCTAssertTrue(nov2027.charges.contains { $0.name == "Domain" })
    }

    func testMonthlyForecastOnDayOneHasNoPartialMonthAndFlatMonthlyNeverCreatesFalsePeak() {
        let day1 = day(2026, 11, 1)
        let sub = Subscription(name: "Spotify", amount: 12, currency: "USD",
                               billingFrequency: .monthly, nextBillingDate: day(2026, 11, 15))
        let summaryDay1 = InsightsEngine.monthlyForecast(for: [sub], now: day1, currency: "USD", rates: rates, calendar: calendar)
        XCTAssertNil(summaryDay1.remainingThisMonth)
        XCTAssertEqual(summaryDay1.averageMonthly, Decimal(12))
        XCTAssertNil(summaryDay1.peakMonth)
        XCTAssertEqual(summaryDay1.months[0].total, Decimal(12))

        // Mid-month (Nov 26) flat monthly also has exact $12 average and NO false peak.
        let midMonth = day(2026, 11, 26)
        let summaryMid = InsightsEngine.monthlyForecast(for: [sub], now: midMonth, currency: "USD", rates: rates, calendar: calendar)
        XCTAssertNil(summaryMid.remainingThisMonth)
        XCTAssertEqual(summaryMid.averageMonthly, Decimal(12))
        XCTAssertNil(summaryMid.peakMonth)
        XCTAssertTrue(summaryMid.months.allSatisfy { $0.total == Decimal(12) })
    }

    func testMonthlyForecastRollsFreeTrialWithoutNextBillingDateAcrossAllTwelveMonths() {
        let now = day(2026, 11, 26)
        // Matches AddSubscriptionView / CatalogAddSheet: trial sets `trialEndsAt` with `nextBillingDate == nil`.
        let trial = Subscription(name: "Claude Pro", amount: 20, currency: "USD",
                                 billingFrequency: .monthly, nextBillingDate: nil,
                                 trialEndsAt: day(2026, 12, 5), status: .trial)

        let summary = InsightsEngine.monthlyForecast(for: [trial], now: now, currency: "USD", rates: rates, calendar: calendar)
        XCTAssertEqual(summary.undatedCount, 0)
        // Dec 2026 has trial-end charge marked isTrialEnd = true; Jan…Nov 2027 all have recurring paid charges.
        XCTAssertEqual(summary.months[0].charges.first?.isTrialEnd, true)
        XCTAssertEqual(summary.months[0].total, Decimal(20))
        for offset in 1..<12 {
            XCTAssertEqual(summary.months[offset].total, Decimal(20), "month \(offset) should carry recurring paid charge")
            XCTAssertEqual(summary.months[offset].charges.first?.isTrialEnd, false)
        }
    }

    func testMonthlyForecastHandlesDSTTransitionMonthsCleanly() {
        // America/Toronto springs forward in March and falls back in November.
        let now = day(2026, 11, 1)
        let sub = Subscription(name: "iCloud+", amount: 10, currency: "USD",
                               billingFrequency: .monthly, nextBillingDate: day(2026, 11, 1))
        let summary = InsightsEngine.monthlyForecast(for: [sub], now: now, currency: "USD", rates: rates, calendar: calendar)
        XCTAssertEqual(summary.months.count, 12)
        // Every single month (including Nov DST fall-back and Mar DST spring-forward) gets exactly 1 charge.
        for bucket in summary.months {
            XCTAssertEqual(bucket.charges.count, 1)
            XCTAssertEqual(bucket.total, Decimal(10))
        }
    }

    func testCommitmentMixSeparatesFlexibleAndCommittedYearlySpend() {
        let monthly = Subscription(name: "Spotify", amount: 10, currency: "USD", billingFrequency: .monthly)
        let annual = Subscription(name: "Prime", amount: 120, currency: "USD", billingFrequency: .yearly)
        let quarterly = Subscription(name: "Box", amount: 30, currency: "USD", billingFrequency: .quarterly)

        let mix = InsightsEngine.commitmentMix(for: [monthly, annual, quarterly], currency: "USD", rates: rates)
        XCTAssertEqual(mix?.flexibleCount, 1)
        XCTAssertEqual(mix?.committedCount, 2)
        XCTAssertEqual(mix?.flexibleYearly, Decimal(120))
        XCTAssertEqual(mix?.committedYearly, Decimal(240))
        XCTAssertEqual(mix?.flexibleShare ?? 0, 1.0 / 3.0, accuracy: 0.001)
    }

    func testCutSimulatorPrioritizesWasteSignalsAndSplitsSavedVsRemainingFXFlags() {
        let now = day(2026, 11, 26)
        let netflix = Subscription(name: "Netflix", amount: 20, currency: "USD", billingFrequency: .monthly)
        let hulu = Subscription(name: "Hulu", amount: 15, currency: "USD", billingFrequency: .monthly)
        let crave = Subscription(name: "Crave", amount: 20, currency: "CAD", billingFrequency: .monthly)
        let gym = Subscription(name: "Gym", amount: 50, currency: "USD", billingFrequency: .monthly)
        let pausely = Subscription(name: PaymentManager.ownName, amount: 29.99, currency: "USD", billingFrequency: .yearly)

        let events = [
            LifecycleEvent(id: UUID(), kind: .added, subscriptionId: hulu.id, subscriptionName: hulu.name,
                           date: day(2026, 9, 1), amount: 10, currency: "USD", frequency: .monthly),
            LifecycleEvent(id: UUID(), kind: .priceChanged, subscriptionId: hulu.id, subscriptionName: hulu.name,
                           date: now, amount: 15, currency: "USD", frequency: .monthly, previousAmount: 10),
        ]

        let candidates = InsightsEngine.cutCandidates(
            in: [netflix, hulu, gym, pausely],
            events: events,
            minutesThisMonth: { $0.id == gym.id ? 0 : 120 },
            currency: "USD",
            rates: rates
        )
        XCTAssertEqual(candidates.map(\.subscription.name), ["Gym", "Hulu", "Netflix"])
        XCTAssertEqual(candidates[0].reason, .unused)
        XCTAssertEqual(candidates[1].reason, .priceIncreased)
        XCTAssertEqual(candidates[2].reason, .overlapping)

        // Selecting USD-only Gym in a mixed USD+CAD portfolio: saved is NOT converted, remaining IS converted.
        let usdOnlyCut = InsightsEngine.simulateCuts(selectedIDs: [gym.id], in: [gym, crave], currency: "USD", rates: rates)
        XCTAssertEqual(usdOnlyCut.yearlySaved, Decimal(600))
        XCTAssertEqual(usdOnlyCut.fiveYearSaved, Decimal(3000))
        XCTAssertEqual(usdOnlyCut.remainingMonthly, Decimal(10))
        XCTAssertFalse(usdOnlyCut.savedIsConverted)
        XCTAssertTrue(usdOnlyCut.remainingIsConverted)

        // Selecting CAD-only Crave: saved IS converted, remaining USD Gym is NOT converted.
        let cadOnlyCut = InsightsEngine.simulateCuts(selectedIDs: [crave.id], in: [gym, crave], currency: "USD", rates: rates)
        XCTAssertTrue(cadOnlyCut.savedIsConverted)
        XCTAssertFalse(cadOnlyCut.remainingIsConverted)

        // Empty selection ("Clear"): saved is never marked converted.
        let emptyCut = InsightsEngine.simulateCuts(selectedIDs: [], in: [gym, crave], currency: "USD", rates: rates)
        XCTAssertEqual(emptyCut.yearlySaved, Decimal(0))
        XCTAssertFalse(emptyCut.savedIsConverted)
        XCTAssertTrue(emptyCut.remainingIsConverted)
    }

    func testSpendForecastPaywallContextAndGoalTriggerWiring() {
        var profile = OnboardingProfile()
        profile.goal = .watchAnnualAndHikes
        XCTAssertEqual(profile.curatedTrigger(waitingCount: 0, hasPauseEligible: false), .spendForecast)

        let ctx = PaywallContext(
            trigger: .spendForecast,
            forecastPeakMonth: "March",
            forecastPeakAmount: Decimal(170),
            forecastCurrency: "USD",
            forecastIsConverted: false,
            simulatorYearlySavings: Decimal(840)
        )
        XCTAssertEqual(ctx.trigger, .spendForecast)
        XCTAssertEqual(ctx.forecastPeakMonth, "March")
        XCTAssertEqual(ctx.simulatorYearlySavings, Decimal(840))
    }
}
