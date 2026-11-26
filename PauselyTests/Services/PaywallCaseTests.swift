import XCTest
@testable import Pausely

/// The sentence on the paywall that compares a year of Pro with the person's own subscriptions.
final class PaywallCaseTests: XCTestCase {
    private let rates = CurrencyRates(perUSD: ["USD": 1, "CAD": 2])

    private func subscription(_ name: String, _ amount: String, currency: String = "USD",
                              frequency: BillingFrequency = .monthly, status: SubscriptionStatus = .active) -> Subscription {
        Subscription(name: name, amount: Decimal(string: amount)!, currency: currency,
                     billingFrequency: frequency, status: status)
    }

    func testComparesWithTheMostExpensiveSubscription() {
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("iCloud+", "2.99"), subscription("Netflix", "17.99")],
                                            rates: rates)
        // 29.99 is more than one month of Netflix (17.99) and less than two (35.98).
        XCTAssertEqual(result, .init(name: "Netflix", months: 2))
    }

    func testOneMonthWhenASingleChargeAlreadyCostsMore() {
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Gym", "45.00")], rates: rates)
        XCTAssertEqual(result, .init(name: "Gym", months: 1))
    }

    func testExactMultipleIsNotCalledLess() {
        // Two months cost exactly 30.00: "less than 2 months" would be false, so it says 3.
        let result = PaywallCase.comparison(proYearly: 30, proCurrency: "USD",
                                            subscriptions: [subscription("Music", "15.00")], rates: rates)
        XCTAssertEqual(result, .init(name: "Music", months: 3))
    }

    func testConvertsBeforeComparingAndIgnoresWhatItCannotConvert() {
        // 20 CAD is 10 USD here, so the USD subscription at 12 is the most expensive.
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Crave", "20.00", currency: "CAD"),
                                                            subscription("Spotify", "12.00"),
                                                            subscription("Mystery", "900.00", currency: "XXX")],
                                            rates: rates)
        XCTAssertEqual(result, .init(name: "Spotify", months: 3))
    }

    func testCancelledSubscriptionsAreNotUsed() {
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Old gym", "60.00", status: .cancelled)],
                                            rates: rates)
        XCTAssertNil(result)
    }

    func testNoComparisonWhenItWouldTakeMoreThanSixMonthsOrThereIsNoPrice() {
        XCTAssertNil(PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("iCloud+", "0.99")], rates: rates))
        XCTAssertNil(PaywallCase.comparison(proYearly: 0, proCurrency: "USD",
                                            subscriptions: [subscription("Netflix", "17.99")], rates: rates))
        XCTAssertNil(PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [], rates: rates))
    }

    func testYearlySubscriptionsAreComparedByTheirMonthlyCost() {
        // 120 a year is 10 a month: a year of Pro (29.99) is less than 3 months of it.
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Prime", "120.00", frequency: .yearly)], rates: rates)
        XCTAssertEqual(result, .init(name: "Prime", months: 3))
    }

    /// Prices are the App Store's. Until it has answered the paywall has none to print, and it says
    /// which of the two it is: still asking, or not answered.
    func testThePaywallSaysWhetherItHasPrices() {
        XCTAssertEqual(PaywallCase.prices(loaded: true, isLoading: false), .known)
        XCTAssertEqual(PaywallCase.prices(loaded: true, isLoading: true), .known, "a purchase in flight keeps the prices on screen")
        XCTAssertEqual(PaywallCase.prices(loaded: false, isLoading: true), .loading)
        XCTAssertEqual(PaywallCase.prices(loaded: false, isLoading: false), .unavailable)
    }

    func testPausePlanROIComputesFloorMultipleAndRejectsUnknownCurrencies() {
        let roi = PaywallCase.pausePlanROI(
            yearlySavings: Decimal(string: "347.76")!, savingsCurrency: "USD",
            serviceNames: ["Netflix", "Disney+", "Max"],
            proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates
        )
        XCTAssertEqual(roi?.coversPro, true)
        XCTAssertEqual(roi?.wholeMultiple, 11, "347.76 / 29.99 = 11.59 -> floored to 11, never rounded up")

        // Converts CAD savings (60 CAD = 30 USD) against 29.99 USD Pro.
        let cad = PaywallCase.pausePlanROI(
            yearlySavings: 60, savingsCurrency: "CAD", serviceNames: ["Netflix", "Crave"],
            proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates
        )
        XCTAssertEqual(cad?.coversPro, true)
        XCTAssertNil(cad?.wholeMultiple, "1.0x is below 2x so no whole multiple badge")

        XCTAssertNil(PaywallCase.pausePlanROI(
            yearlySavings: 300, savingsCurrency: "XXX", serviceNames: ["A", "B"],
            proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates
        ), "never guesses across unknown currencies")
    }

    func testWaitingRiskSumsYearlySpendAndFlagsWhenExceedingPro() {
        let lines = [
            TallyLine(name: "Netflix", category: "Entertainment", amount: Decimal(string: "17.99")!, currency: "USD", frequency: .monthly),
            TallyLine(name: "Crave", category: "Entertainment", amount: Decimal(string: "20.00")!, currency: "CAD", frequency: .monthly),
        ]
        let risk = PaywallCase.waitingRisk(lines: lines, displayCurrency: "USD",
                                           proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates)
        XCTAssertEqual(risk?.count, 2)
        XCTAssertEqual(risk?.isConverted, true)
        XCTAssertEqual(risk?.exceedsPro, true)
        XCTAssertEqual(risk?.names, ["Netflix", "Crave"])
        // 17.99 * 12 + (20 / 2) * 12 = 215.88 + 120 = 335.88
        XCTAssertEqual(risk?.yearlyAmount, Decimal(string: "335.88"))

        let unknown = [TallyLine(name: "Mystery", category: "Other", amount: 50, currency: "XXX", frequency: .monthly)]
        XCTAssertNil(PaywallCase.waitingRisk(lines: unknown, displayCurrency: "USD",
                                             proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates))
    }

    func testSavingsProofRequiresCoveringProAndFloorsToOneDecimal() {
        let proof = PaywallCase.savingsProof(onTrack: Decimal(string: "191.88")!, summaryCurrency: "USD", isConverted: false,
                                             proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates)
        // 191.88 / 29.99 = 6.398 -> floored to 6.3
        XCTAssertEqual(proof?.multiple, Decimal(string: "6.3"))

        XCTAssertNil(PaywallCase.savingsProof(onTrack: Decimal(string: "20.00")!, summaryCurrency: "USD", isConverted: false,
                                              proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates))
    }

    func testSingleChargeCoversProOrderedFeaturesAndDynamicTrialDays() {
        XCTAssertTrue(PaywallCase.singleChargeCoversPro(amount: Decimal(string: "69.99")!, currency: "USD",
                                                        proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates))
        XCTAssertFalse(PaywallCase.singleChargeCoversPro(amount: Decimal(string: "9.99")!, currency: "USD",
                                                         proYearly: Decimal(string: "29.99")!, proCurrency: "USD", rates: rates))
        XCTAssertEqual(PaywallCase.orderedFeatures(prioritizing: .cancelConcierge).first, .cancelConcierge)
        XCTAssertEqual(Set(PaywallCase.orderedFeatures(prioritizing: .cancelConcierge)), Set(ProFeature.allCases))
        XCTAssertEqual(PaywallCase.trialDays(value: 1, unit: .week), 7)
        XCTAssertEqual(PaywallCase.trialDays(value: 14, unit: .day), 14)
        XCTAssertEqual(PaywallCase.trialDays(value: 1, unit: .month), 30)
        XCTAssertNil(PaywallCase.trialDays(value: 0, unit: .day))
    }

    func testTotalSubscriptionsNeverUndercountsCombinedSavedAndPendingWaiting() {
        // RevealStep: 8 tally lines, 0 active yet, 3 pending overflow -> 8
        XCTAssertEqual(PaywallCase.totalSubscriptions(pendingTotalCount: 8, activeCount: 0, waitingCount: 3), 8)
        // ScreenshotImport with no prior saved waiting: 5 active + 3 new -> 8
        XCTAssertEqual(PaywallCase.totalSubscriptions(pendingTotalCount: 8, activeCount: 5, waitingCount: 3), 8)
        // ScreenshotImport with 2 prior saved waiting + 3 new (= 5 waiting total): must report 10, not 8
        XCTAssertEqual(PaywallCase.totalSubscriptions(pendingTotalCount: 8, activeCount: 5, waitingCount: 5), 10)
        // Dashboard/Subscriptions with no pending context: 5 active + 2 saved waiting -> 7
        XCTAssertEqual(PaywallCase.totalSubscriptions(pendingTotalCount: nil, activeCount: 5, waitingCount: 2), 7)
    }
}
