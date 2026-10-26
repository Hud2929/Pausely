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
        XCTAssertEqual(filled.rate("CAD"), Decimal(string: "1.4"))
        XCTAssertEqual(filled.rate("JPY"), CurrencyRates.fallback.rate("JPY"))
    }

    func testRatesFromTheAPIKeepTheirDigits() {
        let api = CurrencyRates(apiRates: ["CAD": 1.38])
        XCTAssertEqual(api.rate("CAD"), Decimal(string: "1.38"))
    }

    /// Every currency someone can pick converts, online or not.
    func testBuiltInRatesCoverEveryCurrencyInThePicker() {
        let missing = CurrencyManager.shared.allCurrencies.map(\.code).filter { CurrencyRates.fallback.rate($0) == nil }
        XCTAssertEqual(missing, [], "Add rates for \(missing) to CurrencyRates.fallback")
    }

    func testEveryCurrencyInThePickerIsARealISOCode() {
        let unknown = CurrencyManager.shared.allCurrencies.map(\.code).filter { !MoneyFormat.isKnown($0) }
        XCTAssertEqual(unknown, [])
    }

    func testBuiltInRatesArePlausible() {
        XCTAssertEqual(CurrencyRates.fallback.rate("USD"), 1)
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
}
