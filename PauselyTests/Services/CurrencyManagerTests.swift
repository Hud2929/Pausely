import Foundation
import XCTest
@testable import Pausely

/// `CurrencyManager` holds the display currency and the live rates. Screens convert through
/// `convertToSelected` and `ratesTable`, and format through `format`; those are what is tested here.
final class CurrencyManagerTests: XCTestCase {

    private var manager: CurrencyManager!
    private var savedCurrency = "USD"
    private var savedRates: [String: Double] = [:]

    override func setUp() {
        super.setUp()
        manager = CurrencyManager.shared
        savedCurrency = manager.selectedCurrency
        savedRates = manager.exchangeRates
    }

    override func tearDown() {
        manager.exchangeRates = savedRates
        manager.selectedCurrency = savedCurrency
        super.tearDown()
    }

    private func d(_ text: String) -> Decimal { Decimal(string: text)! }

    func testThePickerOffersTheMajorCurrencies() {
        let codes = Set(manager.allCurrencies.map(\.code))
        XCTAssertTrue(codes.isSuperset(of: ["USD", "EUR", "GBP", "CAD", "JPY", "SAR"]))
        XCTAssertEqual(codes.count, manager.allCurrencies.count, "no currency is listed twice")
    }

    // MARK: - Conversion

    func testConvertToSelected() {
        manager.selectedCurrency = "EUR"
        manager.exchangeRates = ["USD": 1.0, "EUR": 0.85]
        XCTAssertEqual(manager.convertToSelected(Decimal(100), from: "USD"), Decimal(85))
    }

    /// Without live rates, conversions use the built-in table instead of returning dollars as euros.
    func testConvertToSelectedUsesBuiltInRatesWhenOffline() throws {
        manager.selectedCurrency = "EUR"
        manager.exchangeRates = [:]
        let builtIn = try XCTUnwrap(CurrencyRates.fallback.perUSD["EUR"])
        XCTAssertEqual(manager.convertToSelected(Decimal(100), from: "USD"), 100 * builtIn)
        XCTAssertNotEqual(manager.convertToSelected(Decimal(100), from: "USD"), 100)
    }

    /// Live rates win over the built-in table; currencies the live rates lack still come from it.
    func testLiveRatesOverrideBuiltInRates() throws {
        manager.exchangeRates = ["CAD": 1.25]
        XCTAssertEqual(manager.ratesTable.convert(Decimal(100), from: "USD", to: "CAD"), 125)
        let yen = try XCTUnwrap(CurrencyRates.fallback.perUSD["JPY"])
        XCTAssertEqual(manager.ratesTable.convert(Decimal(1), from: "USD", to: "JPY"), yen)
    }

    /// A currency with no rate does not convert. It never comes back as the same number in another currency.
    func testAnUnknownCurrencyDoesNotConvert() {
        manager.exchangeRates = ["EUR": 0.85]
        XCTAssertNil(manager.ratesTable.convert(Decimal(100), from: "ZZZ", to: "EUR"))
        XCTAssertNil(manager.ratesTable.convert(Decimal(100), from: "USD", to: "ZZZ"))
        XCTAssertEqual(manager.ratesTable.convert(Decimal(100), from: "ZZZ", to: "ZZZ"), 100, "the same currency needs no rate")
    }

    // MARK: - Formatting

    func testFormatUsesTheCurrencyGiven() {
        XCTAssertEqual(manager.format(d("99.99"), currencyCode: "USD"), MoneyFormat.string(d("99.99"), "USD"))
        XCTAssertEqual(manager.format(d("49.5"), currencyCode: "EUR"), MoneyFormat.string(d("49.5"), "EUR"))
    }

    func testFormatFallsBackToTheDisplayCurrency() {
        manager.selectedCurrency = "GBP"
        XCTAssertEqual(manager.format(d("12")), MoneyFormat.string(d("12"), "GBP"))
    }
}
