import Combine
import Foundation
import XCTest
@testable import Pausely

/// `CurrencyManager` holds the display currency and the live rates. Screens convert through
/// `convertToSelected` and `ratesTable`, and format through `format`; those are what is tested here.
final class CurrencyManagerTests: XCTestCase {

    private var manager: CurrencyManager!
    private var savedCurrency = "USD"
    private var savedRates: [String: Double] = [:]
    private var savedSource: (() async throws -> ExchangeRateResponse)!
    private var savedDate: Date?
    private var savedDefaults: [String: Any] = [:]
    private let defaultsKeys = ["cached_exchange_rates", "exchange_rates_date"]

    override func setUp() {
        super.setUp()
        manager = CurrencyManager.shared
        savedCurrency = manager.selectedCurrency
        savedRates = manager.exchangeRates
        savedSource = manager.loadLiveRates
        savedDate = manager.lastUpdated
        savedDefaults = Dictionary(uniqueKeysWithValues: defaultsKeys.compactMap { key in
            UserDefaults.standard.object(forKey: key).map { (key, $0) }
        })
    }

    override func tearDown() {
        manager.exchangeRates = savedRates
        manager.selectedCurrency = savedCurrency
        manager.loadLiveRates = savedSource
        manager.lastUpdated = savedDate
        for key in defaultsKeys { UserDefaults.standard.set(savedDefaults[key], forKey: key) }
        super.tearDown()
    }

    /// A full answer from the rates service: every currency the app knows, with one rate chosen by the test.
    private static func world(cad: Double) -> [String: Double] {
        var rates = CurrencyRates.fallback.perUSD.mapValues { NSDecimalNumber(decimal: $0).doubleValue }
        rates["CAD"] = cad
        return rates
    }

    private func answer(_ rates: [String: Double], base: String = "USD") -> ExchangeRateResponse {
        ExchangeRateResponse(rates: rates, base: base, date: "2026-11-11")
    }

    /// Later than any rates this simulator holds, so a refresh is due.
    private var later: Date { Date().addingTimeInterval(86_400) }

    // MARK: - Live rates

    /// Live rates used to be stored from whichever thread the download finished on, while every
    /// screen was reading them on the main thread.
    func testLiveRatesAreStoredOnTheMainThreadWhoeverAsks() async {
        let manager = self.manager!
        let later = self.later
        let live = answer(Self.world(cad: 1.5))
        manager.loadLiveRates = { live }
        var storedOnMainThread: [Bool] = []
        let watching = manager.$exchangeRates.dropFirst().sink { _ in storedOnMainThread.append(Thread.isMainThread) }
        await Task.detached { await manager.refreshRates(now: later) }.value
        watching.cancel()
        XCTAssertEqual(storedOnMainThread, [true])
        XCTAssertEqual(manager.ratesTable.convert(100, from: "USD", to: "CAD"), 150)
    }

    /// What Currency settings says the rates are from: the last live load, else the built-in table's day.
    func testTheDateOfTheRatesInUse() async {
        manager.lastUpdated = nil
        XCTAssertEqual(ReminderPlanner.dayStamp(manager.ratesDate, Calendar(identifier: .gregorian)).prefix(7), CurrencyRates.fallbackDate.prefix(7))
        let live = answer(Self.world(cad: 1.5))
        manager.loadLiveRates = { live }
        let loaded = later
        await manager.refreshRates(now: loaded)
        XCTAssertEqual(manager.ratesDate, loaded)
    }

    func testRatesLoadedWithinTheHourAreNotAskedForAgain() async {
        var asked = 0
        let live = answer(Self.world(cad: 1.5))
        manager.loadLiveRates = { asked += 1; return live }
        let start = later
        await manager.refreshRates(now: start)
        await manager.refreshRates(now: start.addingTimeInterval(3_599))
        XCTAssertEqual(asked, 1)
        await manager.refreshRates(now: start.addingTimeInterval(3_601))
        XCTAssertEqual(asked, 2)
    }

    func testWhenLiveRatesCannotBeLoadedTheOnesHeldStay() async {
        manager.exchangeRates = ["CAD": 1.25]
        manager.loadLiveRates = { throw URLError(.notConnectedToInternet) }
        await manager.refreshRates(now: later, tries: 1)
        XCTAssertEqual(manager.exchangeRates, ["CAD": 1.25])

        let cutShort = answer(["USD": 1, "CAD": 99])
        manager.loadLiveRates = { cutShort }
        await manager.refreshRates(now: later, tries: 1)
        XCTAssertEqual(manager.exchangeRates, ["CAD": 1.25], "an answer that can't be trusted is the same as no answer")
    }

    /// Used whole or not at all: a list priced in another currency, or cut short, would misprice every total.
    func testOnlyAFullListPricedInDollarsIsUsed() {
        let full = Self.world(cad: 1.5)
        XCTAssertEqual(CurrencyManager.usable(answer(full))?["CAD"], 1.5)
        XCTAssertNil(CurrencyManager.usable(answer(full, base: "EUR")))
        var dollarIsNotOne = full
        dollarIsNotOne["USD"] = 0.92
        XCTAssertNil(CurrencyManager.usable(answer(dollarIsNotOne)))
        XCTAssertNil(CurrencyManager.usable(answer(["USD": 1, "CAD": 1.5])))

        var twoBroken = full
        twoBroken["CAD"] = 0
        twoBroken["EUR"] = .infinity
        let kept = CurrencyManager.usable(answer(twoBroken))
        XCTAssertEqual(kept?.count, full.count - 2, "a rate that isn't a positive number is left out; the built-in one covers it")
        XCTAssertNil(kept?["CAD"])
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
