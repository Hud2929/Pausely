import Foundation
import XCTest
@testable import Pausely

@MainActor
final class WidgetDataStoreTests: XCTestCase {

    private var sut: WidgetDataStore!
    private var testDefaults: UserDefaults!
    private var originalCurrency = "USD"
    private var originalRates: [String: Double] = [:]

    override func setUp() {
        super.setUp()
        originalCurrency = CurrencyManager.shared.selectedCurrency
        originalRates = CurrencyManager.shared.exchangeRates
        CurrencyManager.shared.selectedCurrency = "USD"
        testDefaults = UserDefaults(suiteName: "test.pausely.widget")
        testDefaults.removePersistentDomain(forName: "test.pausely.widget")
        sut = WidgetDataStore.forTesting(defaults: testDefaults)
    }

    override func tearDown() {
        CurrencyManager.shared.selectedCurrency = originalCurrency
        CurrencyManager.shared.exchangeRates = originalRates
        testDefaults.removePersistentDomain(forName: "test.pausely.widget")
        sut = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Publish & Read

    func testPublish_emptySubscriptions() {
        sut.publish(subscriptions: [])
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 0)
        XCTAssertEqual(summary.activeCount, 0)
        XCTAssertEqual(summary.upcomingCount, 0)
        XCTAssertEqual(summary.topInsight, "Add what you pay for in Pausely")
    }

    func testPublish_singleActiveSubscription() {
        let sub = TestFactories.makeSubscription(
            name: "Netflix",
            amount: 15.99,
            billingFrequency: .monthly,
            status: .active
        )
        sut.publish(subscriptions: [sub])
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 15.99, accuracy: 0.01)
        XCTAssertEqual(summary.activeCount, 1)
        XCTAssertEqual(summary.upcomingCount, 0)
    }

    func testPublish_ignoresCancelledSubscriptionsInSpend() {
        let active = TestFactories.makeSubscription(
            name: "Netflix",
            amount: 15.99,
            status: .active
        )
        let cancelled = TestFactories.makeSubscription(
            name: "Spotify",
            amount: 9.99,
            status: .cancelled
        )
        sut.publish(subscriptions: [active, cancelled])
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 15.99, accuracy: 0.01)
        XCTAssertEqual(summary.activeCount, 1)
    }

    func testPublish_multipleSubscriptions() {
        let subs = [
            TestFactories.makeSubscription(name: "A", amount: 10, status: .active),
            TestFactories.makeSubscription(name: "B", amount: 20, status: .active),
            TestFactories.makeSubscription(name: "C", amount: 30, status: .active)
        ]
        sut.publish(subscriptions: subs)
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 60, accuracy: 0.01)
        XCTAssertEqual(summary.activeCount, 3)
    }

    // The widget's top line is the next charge: who, how much, when. It never comments on the
    // person's spending ("review for savings", "great job saving").

    func testTopLineIsTheNextCharge() {
        let calendar = Calendar.current
        let soon = TestFactories.makeSubscription(name: "Spotify", amount: Decimal(string: "10.99")!, status: .active,
                                                  nextBillingDate: calendar.date(byAdding: .day, value: 3, to: Date()))
        let later = TestFactories.makeSubscription(name: "Netflix", amount: 250, status: .active,
                                                   nextBillingDate: calendar.date(byAdding: .day, value: 20, to: Date()))
        sut.publish(subscriptions: [later, soon])
        let line = sut.readSummary().topInsight

        XCTAssertTrue(line.hasPrefix("Spotify"), line)
        XCTAssertTrue(line.contains("10.99"), line)
        XCTAssertTrue(line.contains("in 3 days"), line)
        XCTAssertFalse(line.contains("review") || line.contains("great job"), line)
    }

    func testTopLineSaysTomorrowAndToday() {
        let calendar = Calendar.current
        let tomorrow = TestFactories.makeSubscription(name: "Hulu", amount: 8, status: .active,
                                                      nextBillingDate: calendar.date(byAdding: .day, value: 1, to: Date()))
        sut.publish(subscriptions: [tomorrow])
        XCTAssertTrue(sut.readSummary().topInsight.hasSuffix("tomorrow"), sut.readSummary().topInsight)

        let today = TestFactories.makeSubscription(name: "Hulu", amount: 8, status: .active, nextBillingDate: Date())
        sut.publish(subscriptions: [today])
        XCTAssertTrue(sut.readSummary().topInsight.hasSuffix("today"), sut.readSummary().topInsight)
    }

    func testTopLineAsksForDatesWhenNoneAreKnown() {
        sut.publish(subscriptions: [TestFactories.makeSubscription(amount: 10, status: .active, nextBillingDate: nil)])
        XCTAssertEqual(sut.readSummary().topInsight, "Add renewal dates to see what's next")
    }

    /// The widget's total converts every subscription, and arrives formatted by the app.
    func testPublish_convertsMixedCurrenciesAndSendsFormattedText() {
        CurrencyManager.shared.exchangeRates = ["CAD": 1.4]
        let subs = [
            TestFactories.makeSubscription(name: "Netflix", amount: 10, currency: "USD", status: .active),
            TestFactories.makeSubscription(name: "Crave", amount: 14, currency: "CAD", status: .active)
        ]
        sut.publish(subscriptions: subs)
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 20, accuracy: 0.001)
        XCTAssertEqual(summary.currencyCode, "USD")
        XCTAssertEqual(summary.monthlySpendText, MoneyFormat.string(Decimal(20), "USD"))
        XCTAssertEqual(summary.yearlySpendWholeText, MoneyFormat.string(Decimal(240), "USD", wholeUnits: true))
    }

    // MARK: - Next charge (PauselyWidget/WidgetReader reads these values exactly as written)

    func testNextChargeIsTheSoonestOneInItsOwnCurrency() {
        let soon = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let later = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let netflix = TestFactories.makeSubscription(name: "Netflix", amount: 15.49, status: .active, nextBillingDate: later)
        let crave = TestFactories.makeSubscription(name: "Crave", amount: 99.99, currency: "CAD",
                                                   billingFrequency: .yearly, status: .active, nextBillingDate: soon)
        // Both renew this week and Netflix is first in the list: the sooner charge still wins.
        sut.publish(subscriptions: [netflix, crave])

        XCTAssertEqual(testDefaults.string(forKey: "liveActivity_subscriptionName"), "Crave")
        XCTAssertEqual(testDefaults.string(forKey: "liveActivity_amountText"), MoneyFormat.string(Decimal(string: "99.99")!, "CAD"))
        let shown = Date(timeIntervalSince1970: testDefaults.double(forKey: "liveActivity_renewalDate"))
        XCTAssertTrue(Calendar.current.isDate(shown, inSameDayAs: soon), "the widget shows the day of the charge")
    }

    func testNextChargeLooksPastThisWeek() {
        let far = Calendar.current.date(byAdding: .day, value: 40, to: Date())!
        let nearer = Calendar.current.date(byAdding: .day, value: 20, to: Date())!
        let first = TestFactories.makeSubscription(name: "Disney+", amount: 7.99, status: .active, nextBillingDate: far)
        let second = TestFactories.makeSubscription(name: "Spotify", amount: 11.99, status: .active, nextBillingDate: nearer)
        sut.publish(subscriptions: [first, second])
        XCTAssertEqual(testDefaults.string(forKey: "liveActivity_subscriptionName"), "Spotify")
        XCTAssertEqual(testDefaults.string(forKey: "liveActivity_amountText"), second.chargeText)
    }

    /// The saved date is only the anchor. A monthly plan anchored 45 days ago next charges 15 days or so
    /// from now, and that is the day the widget must show: never a day already gone.
    func testNextChargeRollsAnOldAnchorForward() throws {
        let now = Date()
        let anchor = Calendar.current.date(byAdding: .day, value: -45, to: now)!
        let hulu = TestFactories.makeSubscription(name: "Hulu", amount: 9.99, billingFrequency: .monthly, status: .active, nextBillingDate: anchor)
        sut.publish(subscriptions: [hulu])

        let shown = Date(timeIntervalSince1970: testDefaults.double(forKey: "liveActivity_renewalDate"))
        XCTAssertGreaterThanOrEqual(shown, Calendar.current.startOfDay(for: now))
        XCTAssertEqual(shown.timeIntervalSince1970, try XCTUnwrap(hulu.nextRenewal(onOrAfter: now)).timeIntervalSince1970, accuracy: 1)
        XCTAssertLessThan(shown, Calendar.current.date(byAdding: .day, value: 32, to: now)!)
    }

    /// When the last subscription is cancelled the widget must stop naming it.
    func testNextChargeIsClearedWhenNothingIsActive() {
        let soon = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let netflix = TestFactories.makeSubscription(name: "Netflix", amount: 15.49, status: .active, nextBillingDate: soon)
        sut.publish(subscriptions: [netflix])
        XCTAssertEqual(testDefaults.string(forKey: "liveActivity_subscriptionName"), "Netflix")

        var cancelled = netflix
        cancelled.status = .cancelled
        sut.publish(subscriptions: [cancelled])
        XCTAssertNil(testDefaults.string(forKey: "liveActivity_subscriptionName"))
        XCTAssertNil(testDefaults.string(forKey: "liveActivity_amountText"))
        XCTAssertEqual(testDefaults.double(forKey: "liveActivity_renewalDate"), 0)
    }
}
