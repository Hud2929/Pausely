import XCTest
@testable import Pausely

/// The first-run tally: what lands on the slip, what it adds up to, how the guess compares, and
/// what joins the list after sign-up.
final class TallyTests: XCTestCase {
    private let rates = CurrencyRates(perUSD: ["USD": 1, "CAD": Decimal(string: "1.4")!])
    private func service(_ name: String) -> TallyService {
        TallyCatalog.services.first { $0.name == name }!
    }

    func testTappingAddsAtTheTypicalPriceAndTappingAgainRemoves() {
        var tally = Tally(currency: "USD")
        tally.toggle(service("Netflix"))
        tally.toggle(service("Spotify"))
        XCTAssertEqual(tally.lines.map(\.name), ["Netflix", "Spotify"])
        XCTAssertEqual(tally.lines[0].amount, Decimal(string: "19.99"))
        XCTAssertEqual(tally.monthlyTotal(rates: rates), Decimal(string: "32.98"))
        XCTAssertEqual(tally.yearlyTotal(rates: rates), Decimal(string: "395.76"))

        tally.toggle(service("Netflix"))
        XCTAssertEqual(tally.lines.map(\.name), ["Spotify"])
    }

    func testCanadianPriceIsTheCanadianListPriceNotAnExchangeRate() {
        // $19.99 at the exchange rate would be about 28 Canadian dollars; Netflix charges 18.99 there.
        XCTAssertEqual(Tally.typicalAmount(service("Netflix"), payingIn: "CAD"), Decimal(string: "18.99"))
        var tally = Tally(currency: "cad")
        tally.toggle(service("Netflix"))
        XCTAssertEqual(tally.lines[0].currency, "CAD")
        XCTAssertEqual(tally.monthlyTotal(rates: rates), Decimal(string: "18.99"))
    }

    func testAServiceWithoutAPriceInThisCurrencyIsAskedNotGuessed() {
        // YouTube Premium's price is only known in US dollars.
        XCTAssertNil(Tally.typicalAmount(service("YouTube Premium"), payingIn: "CAD"))
        XCTAssertEqual(Tally.typicalAmount(service("YouTube Premium"), payingIn: "USD"), Decimal(string: "13.99"))
        XCTAssertNil(TallyCatalog.price(forServiceNamed: "netflix", payingIn: "JPY"))
        XCTAssertEqual(TallyCatalog.price(forServiceNamed: " netflix ", payingIn: "eur"), Decimal(string: "15.99"))
    }

    func testACurrencyWithoutLocalPricesGetsNoGuess() {
        XCTAssertNil(Tally.typicalAmount(service("Netflix"), payingIn: "INR"))
        var tally = Tally(currency: "INR")
        tally.toggle(service("Netflix"))
        XCTAssertTrue(tally.lines.isEmpty, "nothing is added until the person types a price")

        tally.toggle(service("Netflix"), amount: 649, confirmed: true)
        XCTAssertEqual(tally.lines.first?.amount, 649)
        XCTAssertFalse(tally.isApproximate)
    }

    func testCorrectingAPriceChangesTheTotalAndStopsItBeingApproximate() {
        var tally = Tally(currency: "USD")
        tally.toggle(service("Netflix"))
        XCTAssertTrue(tally.isApproximate)
        tally.setAmount(Decimal(string: "7.99")!, for: "Netflix")
        XCTAssertEqual(tally.monthlyTotal(rates: rates), Decimal(string: "7.99"))
        XCTAssertFalse(tally.isApproximate)

        tally.setAmount(-5, for: "Netflix")
        XCTAssertEqual(tally.lines[0].amount, Decimal(string: "7.99"), "a negative price is ignored")
    }

    func testVerdictComparesTheGuessWithTheTotal() {
        var tally = Tally(currency: "USD")
        tally.toggle(service("Netflix"))       // 19.99
        tally.toggle(service("ChatGPT Plus"))  // 20.00 → 39.99

        tally.guess = 20
        XCTAssertEqual(tally.verdict(rates: rates),
                       .more(monthly: Decimal(string: "19.99")!, yearly: Decimal(string: "239.88")!))
        tally.guess = 36
        XCTAssertEqual(tally.verdict(rates: rates), .close)
        tally.guess = 43
        XCTAssertEqual(tally.verdict(rates: rates), .close)
        tally.guess = 60
        XCTAssertEqual(tally.verdict(rates: rates), .less(monthly: Decimal(string: "20.01")!))
    }

    func testUSOnlyServicesAreHiddenElsewhere() {
        XCTAssertTrue(TallyCatalog.services(payingIn: "USD").contains { $0.name == "Hulu" })
        XCTAssertFalse(TallyCatalog.services(payingIn: "CAD").contains { $0.name == "Hulu" })
        XCTAssertTrue(TallyCatalog.services(payingIn: "CAD").contains { $0.name == "Netflix" })
    }

    func testCatalogHasNoDuplicatesAndEveryPriceIsPositive() {
        XCTAssertEqual(Set(TallyCatalog.services.map(\.name)).count, TallyCatalog.services.count)
        for service in TallyCatalog.services {
            XCTAssertGreaterThan(service.typicalUSD, 0, service.name)
            for (currency, price) in service.prices {
                XCTAssertGreaterThan(price, 0, "\(service.name) \(currency)")
            }
        }
    }

    func testSubscriptionsAreMonthlyWithNoRenewalDateInvented() {
        var tally = Tally(currency: "USD")
        tally.toggle(service("Audible"))
        let subscription = tally.subscriptions()[0]
        XCTAssertEqual(subscription.name, "Audible")
        XCTAssertEqual(subscription.amount, Decimal(string: "14.95"))
        XCTAssertEqual(subscription.billingFrequency, .monthly)
        XCTAssertNil(subscription.nextBillingDate)
    }

    func testPendingTallySurvivesSignUpAndClears() {
        let defaults = UserDefaults(suiteName: "TallyTests-\(UUID().uuidString)")!
        var tally = Tally(currency: "USD")
        tally.guess = 40
        tally.toggle(service("Netflix"))
        PendingTally.save(tally, defaults: defaults)
        XCTAssertEqual(PendingTally.load(defaults: defaults), tally)
        PendingTally.clear(defaults: defaults)
        XCTAssertNil(PendingTally.load(defaults: defaults))
    }

    func testImportPlanFillsFreeSlotsWithTheMostExpensiveAndSkipsWhatIsAlreadyListed() {
        func line(_ name: String, _ amount: String) -> TallyLine {
            TallyLine(name: name, category: "entertainment", amount: Decimal(string: amount)!, currency: "USD")
        }
        let lines = [line("iCloud+", "2.99"), line("Netflix", "17.99"), line("Spotify", "12.99"), line("Audible", "14.95")]

        let free = PendingTally.plan(lines: lines, existingNames: ["netflix"], freeSlots: 2)
        XCTAssertEqual(free.add.map(\.name), ["Audible", "Spotify"])
        XCTAssertEqual(free.wait.map(\.name), ["iCloud+"])

        let pro = PendingTally.plan(lines: lines, existingNames: [], freeSlots: nil)
        XCTAssertEqual(pro.add.count, 4)
        XCTAssertTrue(pro.wait.isEmpty)

        let full = PendingTally.plan(lines: lines, existingNames: [], freeSlots: -1)
        XCTAssertTrue(full.add.isEmpty)
        XCTAssertEqual(full.wait.count, 4)
    }
}
