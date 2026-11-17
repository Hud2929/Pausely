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
        // Discord's page states its price in US dollars only.
        XCTAssertNil(Tally.typicalAmount(service("Discord Nitro"), payingIn: "CAD"))
        XCTAssertEqual(Tally.typicalAmount(service("Discord Nitro"), payingIn: "USD"), Decimal(string: "9.99"))
        // YouTube's page shows no price to read, so there is none in any currency.
        XCTAssertNil(Tally.typicalAmount(service("YouTube Premium"), payingIn: "USD"))
        var tally = Tally(currency: "USD")
        tally.toggle(service("YouTube Premium"))
        XCTAssertTrue(tally.lines.isEmpty, "nothing is added at a made-up price")
        tally.toggle(service("YouTube Premium"), amount: Decimal(string: "13.99"), confirmed: true)
        XCTAssertEqual(tally.lines.map(\.amount), [Decimal(string: "13.99")], "it goes on at the price the person types")
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
        tally.toggle(service("Claude Pro"))    // 20.00 → 39.99

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

    /// A price is on the grid only with the page it was read from and the day. Prices used to come
    /// from press round-ups as well; two of the eight that could be checked were wrong.
    func testEveryPriceNamesThePageItWasReadFromAndTheDay() {
        XCTAssertEqual(Set(TallyCatalog.services.map(\.name)).count, TallyCatalog.services.count)
        for service in TallyCatalog.services {
            for (currency, price) in service.prices {
                XCTAssertGreaterThan(price, 0, "\(service.name) \(currency)")
            }
            if service.prices.isEmpty {
                XCTAssertNil(service.source, service.name)
            } else {
                XCTAssertEqual(service.source?.isEmpty, false, service.name)
                XCTAssertNotNil(service.checkedOn?.range(of: #"^2026-\d{2}-\d{2}$"#, options: .regularExpression), service.name)
            }
        }
        XCTAssertEqual(TallyCatalog.services.filter { !$0.prices.isEmpty }.count, 16)
        XCTAssertEqual(Tally.typicalAmount(service("PlayStation Plus"), payingIn: "USD"), Decimal(string: "10.99"), "not the 9.99 a round-up gave")
        XCTAssertEqual(Tally.typicalAmount(service("Disney+"), payingIn: "USD"), Decimal(string: "12.49"), "not 11.99")
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

    /// Someone who ticks nine learnt on Home, after making the account, that the free plan
    /// tracks five. The reveal says it under "Keep my list" when the slip holds more, in the
    /// words of what the importer then does.
    func testTheRevealSaysTheFreeLimitBeforeTheAccountWhenTheSlipHoldsMore() throws {
        var tally = Tally(currency: "USD")
        let priced = TallyCatalog.services.filter { Tally.typicalAmount($0, payingIn: "USD") != nil }
        for service in priced.prefix(FreeTier.subscriptionLimit) { tally.toggle(service) }
        XCTAssertEqual(tally.lines.count, FreeTier.subscriptionLimit)
        XCTAssertFalse(FreeTier.isExceeded(by: tally.subscriptions()), "five fit: nothing to say")
        tally.toggle(priced[FreeTier.subscriptionLimit])
        XCTAssertTrue(FreeTier.isExceeded(by: tally.subscriptions()))

        // The sentence is true of the importer: the most expensive are added, the rest wait.
        let plan = PendingTally.plan(lines: tally.lines, existingNames: [], freeSlots: FreeTier.subscriptionLimit)
        XCTAssertEqual(plan.add.count, FreeTier.subscriptionLimit)
        XCTAssertEqual(plan.wait.count, 1)
        let cheapestAdded = try XCTUnwrap(plan.add.map(\.yearlyCost).min())
        XCTAssertTrue(plan.wait.allSatisfy { $0.yearlyCost <= cheapestAdded })

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let screen = root.appendingPathComponent("Pausely/Views/FirstRun/RevealStep.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: screen.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: screen, encoding: .utf8)
        let button = try XCTUnwrap(source.range(of: ".accessibilityIdentifier(\"keepListButton\")"))
        let under = String(source[button.upperBound...].prefix(1100))
        XCTAssertTrue(under.contains("if FreeTier.isExceeded(by: tally.subscriptions()) {"))
        XCTAssertTrue(under.contains("L10n.string(\"Free tracks \\(FreeTier.subscriptionLimit), the most expensive first. The rest wait until you make room or go Pro.\")"))
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
