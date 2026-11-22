import XCTest
@testable import Pausely

/// The money engine (Core/Money): how amounts read in each locale, how currencies convert, and how
/// totals add up. See `.claude/skills/pausely-currency/SKILL.md`.
final class MoneyFormatTests: XCTestCase {

    /// Formatted text with non-breaking spaces made plain, so expectations are readable.
    private func text(_ amount: Decimal, _ code: String, _ locale: String, whole: Bool = false) -> String {
        MoneyFormat.string(amount, code, locale: Locale(identifier: locale), wholeUnits: whole)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// In Arabic "CA$" was drawn "$CA" on every price: the "$" took the paragraph's direction. A symbol
    /// of Latin letters and a sign is held left to right as one piece; nothing else changes.
    func testALatinCurrencySymbolStaysWholeInRightToLeftText() {
        let arabic = Locale(identifier: "ar_SA")
        let cad = MoneyFormat.string(Decimal(string: "16.49")!, "CAD", locale: arabic)
        XCTAssertTrue(cad.contains("\u{2066}CA$\u{2069}"), cad)
        let usd = MoneyFormat.string(Decimal(string: "20")!, "USD", locale: arabic)
        XCTAssertTrue(usd.contains("\u{2066}US$\u{2069}"), usd)
        let riyal = MoneyFormat.string(Decimal(string: "20")!, "SAR", locale: arabic)
        XCTAssertFalse(riyal.contains("\u{2066}"), "the riyal sign has no Latin letter: left as it is")
        XCTAssertEqual(MoneyFormat.string(Decimal(string: "16.49")!, "CAD", locale: Locale(identifier: "en_US")), "CA$16.49",
                       "left-to-right text is untouched")
        XCTAssertEqual(MoneyFormat.keepingSymbolWhole(cad, symbol: "CA$", locale: arabic), cad, "never wrapped twice")
    }

    func testCanadianReaderSeesDollarForCADAndUSDollarForUSD() {
        XCTAssertEqual(text(12.99, "CAD", "en_CA"), "$12.99")
        XCTAssertEqual(text(12.99, "USD", "en_CA"), "US$12.99")
    }

    func testAmericanReaderSeesDollarForUSDAndCAForCAD() {
        XCTAssertEqual(text(12.99, "USD", "en_US"), "$12.99")
        XCTAssertEqual(text(12.99, "CAD", "en_US"), "CA$12.99")
    }

    func testGermanReaderGetsCommaDecimalsAndTrailingEuro() {
        XCTAssertEqual(text(1234.5, "EUR", "de_DE"), "1.234,50 €")
    }

    func testYenHasNoDecimals() {
        let yen = text(1500, "JPY", "ja_JP")
        XCTAssertTrue(yen.hasSuffix("1,500"), yen)
        XCTAssertFalse(yen.contains("."), yen)
    }

    func testDecimalsFollowTheCurrency() {
        XCTAssertEqual(MoneyFormat.fractionDigits(for: "USD"), 2)
        XCTAssertEqual(MoneyFormat.fractionDigits(for: "JPY"), 0)
        XCTAssertEqual(MoneyFormat.fractionDigits(for: "KRW"), 0)
        XCTAssertEqual(MoneyFormat.fractionDigits(for: "KWD"), 3)
    }

    func testWholeUnitsRoundHalfUp() {
        XCTAssertEqual(text(1479.5, "USD", "en_US", whole: true), "$1,480")
    }

    /// The bug this engine exists to stop: an amount shown with a symbol that isn't its currency.
    func testUnknownCurrencyNeverBorrowsADollarSign() {
        let unknown = text(5, "ZZZ", "en_US")
        XCTAssertTrue(unknown.contains("ZZZ"), unknown)
        XCTAssertFalse(unknown.contains("$"), unknown)
        XCTAssertFalse(text(5, "", "en_US").contains("$"))
    }

    func testCodesAreNormalized() {
        XCTAssertEqual(text(5, " cad ", "en_CA"), "$5.00")
        XCTAssertEqual(MoneyFormat.normalizedCode(" eur\n"), "EUR")
    }

    func testSymbolDependsOnTheReader() {
        XCTAssertEqual(MoneyFormat.symbol(for: "USD", locale: Locale(identifier: "en_US")), "$")
        XCTAssertEqual(MoneyFormat.symbol(for: "USD", locale: Locale(identifier: "en_CA")), "US$")
        XCTAssertEqual(MoneyFormat.symbol(for: "ZZZ", locale: Locale(identifier: "en_US")), "ZZZ")
    }

    func testPlainNumbersForFilesUseTheCurrencysDecimals() {
        XCTAssertEqual(MoneyFormat.plainNumber(Decimal(string: "1.2908333")!, "USD"), "1.29")
        XCTAssertEqual(MoneyFormat.plainNumber(Decimal(string: "1500.4")!, "JPY"), "1500")
        XCTAssertEqual(MoneyFormat.plainNumber(Decimal(string: "1.25")!, "KWD"), "1.250")
        XCTAssertEqual(MoneyFormat.plainNumber(1234.5, "EUR"), "1234.50")
        // Half-way amounts round up, as on a receipt.
        XCTAssertEqual(MoneyFormat.plainNumber(Decimal(string: "15.495")!, "USD"), "15.50")
        XCTAssertEqual(MoneyFormat.plainNumber(Decimal(string: "1500.5")!, "JPY"), "1501")
    }

    func testDoublesBecomeDecimalsWithoutBinaryNoise() {
        XCTAssertEqual(MoneyFormat.decimal(12.99), Decimal(string: "12.99"))
        XCTAssertEqual(MoneyFormat.decimal(.nan), 0)
    }
}

final class CurrencyRatesTests: XCTestCase {

    private let rates = CurrencyRates(perUSD: ["CAD": Decimal(string: "1.4")!, "EUR": Decimal(string: "0.9")!])

    func testConvertsThroughTheDollar() {
        XCTAssertEqual(rates.convert(10, from: "USD", to: "CAD"), 14)
        XCTAssertEqual(rates.convert(14, from: "CAD", to: "USD"), 10)
        XCTAssertEqual(rates.convert(14, from: "CAD", to: "EUR"), 9)
        XCTAssertEqual(rates.convert(7, from: "EUR", to: "EUR"), 7)
    }

    /// Unknown currencies return nil, never the original number dressed up as another currency.
    func testUnknownCurrencyDoesNotConvert() {
        XCTAssertNil(rates.convert(10, from: "ZZZ", to: "USD"))
        XCTAssertNil(rates.convert(10, from: "USD", to: "JPY"))
    }

    func testLiveRatesWinAndTheBuiltInTableFillsGaps() {
        let filled = rates.fillingGaps()
        XCTAssertEqual(filled.perUSD["CAD"], Decimal(string: "1.4"))
        XCTAssertEqual(filled.perUSD["JPY"], CurrencyRates.fallback.perUSD["JPY"])
    }

    func testRatesFromTheAPIKeepTheirDigits() {
        let api = CurrencyRates(apiRates: ["CAD": 1.38])
        XCTAssertEqual(api.perUSD["CAD"], Decimal(string: "1.38"))
    }

    /// Every currency someone can pick converts, online or not.
    func testBuiltInRatesCoverEveryCurrencyInThePicker() {
        let missing = CurrencyManager.shared.allCurrencies.map(\.code).filter { CurrencyRates.fallback.perUSD[$0] == nil }
        XCTAssertEqual(missing, [], "Add rates for \(missing) to CurrencyRates.fallback")
    }

    func testEveryCurrencyInThePickerIsARealISOCode() {
        let iso = Set(Locale.Currency.isoCurrencies.map(\.identifier))
        let unknown = CurrencyManager.shared.allCurrencies.map(\.code).filter { !iso.contains($0) }
        XCTAssertEqual(unknown, [])
    }

    /// A currency nobody is charged in any more converts at the fixed rate that replaced it, whatever
    /// a feed says about it or leaves out. The lev became the euro on 2026-01-01 at 1.95583 (Council
    /// Regulation (EU) 2025/1409); the old leone became the new on 2022-07-01 at 1000 to 1.
    func testARetiredCurrencyConvertsAtItsFixedRate() {
        XCTAssertEqual(CurrencyRates.retired, [
            CurrencyRates.Retired(code: "BGN", replacedBy: "EUR", unitsPerNew: Decimal(string: "1.95583")!, since: "2026-01-01"),
            CurrencyRates.Retired(code: "SLL", replacedBy: "SLE", unitsPerNew: 1000, since: "2022-07-01"),
        ])
        // To the cent, as it is shown: a division by a rate does not come back to a round number.
        func cents(_ amount: Decimal?) -> Decimal? {
            guard var value = amount else { return nil }
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 2, .plain)
            return rounded
        }
        // A feed that has dropped the lev and misprices the old leone.
        let live = CurrencyRates(apiRates: ["EUR": 0.9, "SLE": 23.07, "SLL": 5]).fillingGaps()
        XCTAssertEqual(live.perUSD["BGN"], Decimal(string: "1.760247"), "0.9 euros to the dollar, 1.95583 leva to the euro")
        XCTAssertEqual(live.perUSD["SLL"], 23_070, "the feed's own figure for a retired currency is not used")
        XCTAssertEqual(cents(live.convert(Decimal(string: "19.56")!, from: "BGN", to: "EUR")), 10)
        XCTAssertEqual(cents(live.convert(10, from: "EUR", to: "BGN")), Decimal(string: "19.56"))
        XCTAssertEqual(cents(live.convert(1000, from: "SLL", to: "SLE")), 1)
        // Offline, from the built-in table.
        XCTAssertEqual(cents(CurrencyRates.fallback.convert(Decimal(string: "1.95583")!, from: "BGN", to: "EUR")), 1)
        XCTAssertEqual(cents(CurrencyRates.fallback.convert(23_000, from: "SLL", to: "SLE")), 23)
    }

    /// The picker offers what people are charged in today: the new leone, not the old, and no lev.
    /// A choice made in a retired currency, or an iPhone that still names one, becomes its successor.
    func testNoRetiredCurrencyIsOfferedAndItsSuccessorIs() {
        let offered = Set(CurrencyManager.shared.allCurrencies.map(\.code))
        for old in CurrencyRates.retired {
            XCTAssertFalse(offered.contains(old.code), "\(old.code) was retired on \(old.since)")
            XCTAssertTrue(offered.contains(old.replacedBy), "\(old.replacedBy) replaced \(old.code)")
            XCTAssertEqual(CurrencyManager.current(old.code), old.replacedBy)
        }
        XCTAssertEqual(CurrencyManager.current("BGN"), "EUR")
        XCTAssertEqual(CurrencyManager.current("SLL"), "SLE")
        XCTAssertEqual(CurrencyManager.current("USD"), "USD")
    }

    func testBuiltInRatesArePlausible() {
        XCTAssertEqual(CurrencyRates.fallback.perUSD["USD"], 1)
        XCTAssertTrue(CurrencyRates.fallback.perUSD.values.allSatisfy { $0 > 0 })
        XCTAssertFalse(CurrencyRates.fallbackDate.isEmpty)
    }
}

final class MoneyMathTests: XCTestCase {

    private let rates = CurrencyRates(perUSD: ["CAD": Decimal(string: "1.4")!])

    func testTotalsConvertEverySubscriptionFirst() {
        let subs = [
            TestFactories.makeSubscription(name: "Netflix", amount: 10, currency: "USD"),
            TestFactories.makeSubscription(name: "Crave", amount: 14, currency: "CAD")
        ]
        XCTAssertEqual(subs.monthlyTotal(in: "USD", rates: rates), 20)
        XCTAssertEqual(subs.monthlyTotal(in: "CAD", rates: rates), 28)
        XCTAssertEqual(subs.annualTotal(in: "USD", rates: rates), 240)
    }

    func testYearlyPlansCountAsATwelfthEachMonth() {
        let yearly = TestFactories.makeSubscription(amount: 120, currency: "USD", billingFrequency: .yearly)
        XCTAssertEqual([yearly].monthlyTotal(in: "USD", rates: rates), 10)
        XCTAssertEqual(yearly.monthlyCost(in: "CAD", rates: rates), 14)
    }

    func testAmountsThatCantBeConvertedAreLeftOutNotAddedRaw() {
        let subs = [
            TestFactories.makeSubscription(amount: 10, currency: "USD"),
            TestFactories.makeSubscription(amount: 5, currency: "ZZZ")
        ]
        XCTAssertEqual(subs.monthlyTotal(in: "USD", rates: rates), 10)
    }

    /// Receipt lines are shown in the receipt's currency so they add up to its total.
    func testReceiptLinesUseTheTotalsCurrency() {
        let summary = SavingsSummary(lines: [], currency: "CAD", savedSoFar: 0, onTrack: 0, pauselyYearlyCost: nil)
        XCTAssertEqual(summary.formatted(10, from: "USD", rates: rates), "≈" + MoneyFormat.string(Decimal(14), "CAD"))
        XCTAssertEqual(summary.formatted(10, from: "CAD", rates: rates), MoneyFormat.string(Decimal(10), "CAD"))
        XCTAssertEqual(summary.formatted(10, from: "ZZZ", rates: rates), MoneyFormat.string(Decimal(10), "ZZZ"))
    }

    /// A total that was worked out at an exchange rate says so. The receipt's two totals (on the
    /// receipt, on Home, on the year's slip and in the Pausely Promise) and what Pausely itself
    /// costs were drawn as exact figures whatever went into them; each converted line beside
    /// them was marked, the sums were not (found on the Japanese tour of 2026-11-16).
    func testSavingsTotalsSayWhenALineWasConverted() throws {
        func line(_ currency: String) -> SavingsLedger.Line {
            SavingsLedger.Line(id: UUID(), subscriptionId: UUID(), name: "Hulu", currency: currency, amountPerCharge: 10, frequency: .monthly,
                               cancelledOn: Date(timeIntervalSince1970: 0), endedOn: nil, avoidedCharges: [], avoidedSoFar: [])
        }
        let price = try XCTUnwrap(Decimal(string: "39.99"))
        let own = SavingsSummary(lines: [line("CAD")], currency: "CAD", savedSoFar: 10, onTrack: 120, pauselyYearlyCost: price, pauselyCurrency: "CAD")
        XCTAssertFalse(own.totalsAreConverted)
        XCTAssertEqual(own.total(120), MoneyFormat.string(Decimal(120), "CAD"))
        XCTAssertEqual(own.pauselyCostText, MoneyFormat.string(price, "CAD"))

        let mixed = SavingsSummary(lines: [line("CAD"), line("usd")], currency: "CAD", savedSoFar: 24, onTrack: 288, pauselyYearlyCost: 41, pauselyCurrency: "USD")
        XCTAssertTrue(mixed.totalsAreConverted)
        XCTAssertEqual(mixed.total(288), "≈" + MoneyFormat.string(Decimal(288), "CAD"))
        XCTAssertEqual(mixed.pauselyCostText, "≈" + MoneyFormat.string(Decimal(41), "CAD"))

        // Nothing is paid for Pausely: there is no cost to print, marked or not.
        XCTAssertNil(SavingsSummary(lines: [], currency: "CAD", savedSoFar: 0, onTrack: 0, pauselyYearlyCost: nil).pauselyCostText)
        XCTAssertFalse(SavingsSummary(lines: [], currency: "CAD", savedSoFar: 0, onTrack: 0, pauselyYearlyCost: nil).totalsAreConverted)
    }
}
