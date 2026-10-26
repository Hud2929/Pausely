import Foundation
import XCTest
@testable import Pausely

final class CurrencyManagerTests: XCTestCase {

    var manager: CurrencyManager!

    override func setUp() {
        super.setUp()
        manager = CurrencyManager.shared
    }

    override func tearDown() {
        // Reset to safe defaults
        manager.exchangeRates = [:]
        manager.selectedCurrency = "USD"
        super.tearDown()
    }

    // MARK: - Currency Lookup

    func testCurrencyForCode() {
        let usd = manager.currency(for: "USD")
        XCTAssertNotNil(usd)
        XCTAssertEqual(usd?.code, "USD")
    }

    func testCurrencyForUnknownCode() {
        let unknown = manager.currency(for: "XXX")
        XCTAssertNil(unknown)
    }

    func testAllCurrenciesNotEmpty() {
        XCTAssertFalse(manager.allCurrencies.isEmpty)
        XCTAssertTrue(manager.allCurrencies.contains { $0.code == "USD" })
        XCTAssertTrue(manager.allCurrencies.contains { $0.code == "EUR" })
    }

    // MARK: - Symbol & Flag

    /// Symbols follow the reader's locale: "$" in the US, "US$" in Canada (see MoneyFormatTests).
    func testCurrencySymbol() {
        XCTAssertTrue(manager.currencySymbol(for: "USD").hasSuffix("$"))
        XCTAssertTrue(manager.currencySymbol(for: "GBP").hasSuffix("£"))
        XCTAssertEqual(manager.currencySymbol(for: "EUR"), "€")
    }

    /// A currency Pausely doesn't know shows as its code, never as a borrowed "$".
    func testCurrencySymbolUnknown() {
        XCTAssertEqual(manager.currencySymbol(for: "ZZZ"), "ZZZ")
    }

    func testCurrencyFlag() {
        XCTAssertEqual(manager.currencyFlag(for: "USD"), "🇺🇸")
    }

    func testCurrencyFlagUnknown() {
        XCTAssertEqual(manager.currencyFlag(for: "ZZZ"), "🏳️")
    }

    // MARK: - Conversion

    func testConvertSameCurrency() throws {
        let result = try manager.convert(Decimal(100), from: "USD", to: "USD")
        XCTAssertEqual(result, 100)
    }

    func testConvertWithRates() throws {
        manager.exchangeRates = ["USD": 1.0, "EUR": 0.85]
        let result = try manager.convert(Decimal(100), from: "USD", to: "EUR")
        XCTAssertEqual(result, Decimal(85))
    }

    func testConvertUnknownSourceThrows() {
        manager.exchangeRates = ["EUR": 0.85]
        XCTAssertThrowsError(try manager.convert(Decimal(100), from: "ZZZ", to: "EUR")) { error in
            guard case CurrencyError.rateNotAvailable = error else {
                XCTFail("Expected rateNotAvailable")
                return
            }
        }
    }

    func testConvertUnknownTargetThrows() {
        manager.exchangeRates = ["USD": 1.0]
        XCTAssertThrowsError(try manager.convert(Decimal(100), from: "USD", to: "ZZZ")) { error in
            guard case CurrencyError.rateNotAvailable = error else {
                XCTFail("Expected rateNotAvailable")
                return
            }
        }
    }

    func testConvertToSelected() {
        manager.selectedCurrency = "EUR"
        manager.exchangeRates = ["USD": 1.0, "EUR": 0.85]
        let result = manager.convertToSelected(Decimal(100), from: "USD")
        XCTAssertEqual(result, Decimal(85))
    }

    /// Without live rates, conversions use the built-in table instead of returning dollars as euros.
    func testConvertToSelectedUsesBuiltInRatesWhenOffline() {
        manager.selectedCurrency = "EUR"
        manager.exchangeRates = [:]
        let result = manager.convertToSelected(Decimal(100), from: "USD")
        XCTAssertEqual(result, 100 * CurrencyRates.fallback.rate("EUR")!)
        XCTAssertNotEqual(result, 100)
    }

    /// Live rates win over the built-in table.
    func testLiveRatesOverrideBuiltInRates() throws {
        manager.exchangeRates = ["CAD": 1.25]
        XCTAssertEqual(try manager.convert(Decimal(100), from: "USD", to: "CAD"), 125)
    }

    // MARK: - Formatting

    func testFormatUSD() {
        let formatted = manager.format(Decimal(99.99), currencyCode: "USD")
        XCTAssertTrue(formatted.contains("$") || formatted.contains("USD"))
    }

    func testFormatEUR() {
        let formatted = manager.format(Decimal(49.50), currencyCode: "EUR")
        XCTAssertTrue(formatted.contains("€") || formatted.contains("EUR"))
    }

    // MARK: - Catalog Price Helpers

    func testConvertFromUSD() {
        manager.exchangeRates = ["EUR": 0.85]
        manager.selectedCurrency = "EUR"
        let converted = manager.convertFromUSD(10.0)
        XCTAssertEqual(converted, 8.5)
    }

    func testPriceIndicatorUSD() {
        manager.selectedCurrency = "USD"
        XCTAssertEqual(manager.priceIndicator, "")
    }

    func testPriceIndicatorNonUSD() {
        manager.selectedCurrency = "EUR"
        XCTAssertEqual(manager.priceIndicator, "≈")
    }

    // MARK: - Rate Calculation

    func testGetRate() throws {
        manager.exchangeRates = ["USD": 1.0, "EUR": 0.85]
        let rate = try manager.getRate(from: "USD", to: "EUR")
        XCTAssertEqual(rate, 0.85)
    }

    func testGetRateSameCurrency() throws {
        let rate = try manager.getRate(from: "USD", to: "USD")
        XCTAssertEqual(rate, 1.0)
    }

    func testGetRateUnknownThrows() {
        manager.exchangeRates = [:]
        XCTAssertThrowsError(try manager.getRate(from: "USD", to: "ZZZ")) { error in
            guard case CurrencyError.rateNotAvailable = error else {
                XCTFail("Expected rateNotAvailable")
                return
            }
        }
    }

    // MARK: - Historical Rate

    func testHistoricalRateChange() {
        let previous = HistoricalRate(date: Date(), fromCurrency: "USD", toCurrency: "EUR", rate: 0.80)
        let current = HistoricalRate(date: Date(), fromCurrency: "USD", toCurrency: "EUR", rate: 0.85)
        let change = current.change(from: previous)
        XCTAssertNotNil(change)
        XCTAssertEqual(change ?? 0, 6.25, accuracy: 0.01)
    }

    func testHistoricalRateFormattedChange() {
        let previous = HistoricalRate(date: Date(), fromCurrency: "USD", toCurrency: "EUR", rate: 0.80)
        let current = HistoricalRate(date: Date(), fromCurrency: "USD", toCurrency: "EUR", rate: 0.85)
        let formatted = current.formattedChange(from: previous)
        XCTAssertEqual(formatted, "↑ 6.25%")
    }

    // MARK: - Double Rounding

    func testDoubleRoundedToCurrency() {
        XCTAssertEqual(10.555.roundedToCurrency(decimals: 2), 10.56)
        XCTAssertEqual(10.554.roundedToCurrency(decimals: 2), 10.55)
    }
}
