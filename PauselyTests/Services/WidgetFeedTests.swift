import XCTest
@testable import Pausely

/// What the widgets show is worked out on the day they draw, from the days the app published. So a
/// widget is right on a day the app wasn't opened.
@MainActor
final class WidgetFeedTests: XCTestCase {

    private let cal = Calendar.billing
    private var defaults: UserDefaults!
    private let suite = "test.pausely.widgetfeed"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func sub(_ name: String, _ amount: String = "10.00", anchor: Date?, frequency: BillingFrequency = .monthly,
                     status: SubscriptionStatus = .active, trialEnds: Date? = nil, currency: String = "USD") -> Subscription {
        Subscription(name: name, amount: Decimal(string: amount)!, currency: currency, billingFrequency: frequency,
                     nextBillingDate: anchor, trialEndsAt: trialEnds, status: status)
    }

    private func feed(_ subscriptions: [Subscription], now: Date) -> WidgetFeed {
        WidgetDataStore.feed(for: subscriptions, now: now, currency: "USD", rates: .fallback, language: nil)
    }

    // MARK: - What the app publishes

    func testEachChargingSubscriptionIsPublishedWithItsDaysAhead() {
        let published = feed([sub("Netflix", "15.49", anchor: day(2026, 11, 15)),
                              sub("Gone", anchor: day(2026, 11, 12), status: .cancelled),
                              sub("No date", anchor: nil)], now: day(2026, 11, 10))
        XCTAssertEqual(published.charges.map(\.name), ["Netflix"])
        XCTAssertEqual(published.charges.first?.amountText, MoneyFormat.string(Decimal(string: "15.49")!, "USD"))
        XCTAssertEqual(published.charges.first?.days.prefix(3), ["2026-11-15", "2026-12-15", "2027-01-15"])
        XCTAssertEqual(published.charges.first?.days.count, 12, "a year of a monthly subscription")
        XCTAssertTrue(published.hasSubscriptions)
    }

    func testAnAnchorInThePastIsRolledForward() {
        let published = feed([sub("Netflix", anchor: day(2026, 1, 31))], now: day(2026, 11, 10))
        XCTAssertEqual(published.charges.first?.days.prefix(3), ["2026-11-30", "2026-12-31", "2027-01-31"])
    }

    func testATrialsEndComesFirstAndIsMarked() {
        let published = feed([sub("Crave", anchor: day(2026, 11, 20), status: .trial, trialEnds: day(2026, 11, 20))],
                             now: day(2026, 11, 10))
        let charge = published.charges.first
        XCTAssertEqual(charge?.startsWithTrialEnd, true)
        XCTAssertEqual(charge?.days.prefix(2), ["2026-11-20", "2026-12-20"], "its end is the first charge, not counted twice")
    }

    func testTheTotalsAreTextInTheDisplayCurrencyAndSayWhenConverted() {
        let plain = feed([sub("A", "10.00", anchor: nil), sub("B", "5.00", anchor: nil)], now: day(2026, 11, 10))
        XCTAssertEqual(plain.monthlyText, MoneyFormat.string(Decimal(15), "USD"))
        XCTAssertEqual(plain.yearlyText, MoneyFormat.total(Decimal(180), "USD", converted: false, wholeUnits: true))

        let mixed = feed([sub("DAZN", "20.00", anchor: nil, currency: "EUR")], now: day(2026, 11, 10))
        XCTAssertTrue(mixed.monthlyText.hasPrefix("≈"))
    }

    func testAnEmptyListSaysSoAndHasNoTotals() {
        let empty = feed([], now: day(2026, 11, 10))
        XCTAssertFalse(empty.hasSubscriptions)
        XCTAssertEqual(empty.charges, [])
        XCTAssertEqual(empty.monthlyText, "")

        let onlyCancelled = feed([sub("Gone", anchor: day(2026, 11, 12), status: .cancelled)], now: day(2026, 11, 10))
        XCTAssertTrue(onlyCancelled.hasSubscriptions)
        XCTAssertEqual(onlyCancelled.monthlyText, "")
    }

    // MARK: - What a widget works out on the day it draws

    func testTheSoonestChargeComesFirst() {
        let published = feed([sub("Later", anchor: day(2026, 11, 25)), sub("Sooner", anchor: day(2026, 11, 12))],
                             now: day(2026, 11, 10))
        let upcoming = published.upcoming(on: day(2026, 11, 10))
        XCTAssertEqual(upcoming.map(\.charge.name), ["Sooner", "Later"])
        XCTAssertEqual(upcoming.map(\.daysAway), [2, 15])
    }

    /// From noon the day before a charge the small widget used to say "today": it counted whole
    /// 24-hour periods. Days are calendar days.
    func testTomorrowIsTomorrowAtAnyHour() {
        let published = feed([sub("Netflix", anchor: day(2026, 11, 15))], now: day(2026, 11, 10))
        XCTAssertEqual(published.upcoming(on: day(2026, 11, 14, hour: 0)).first?.daysAway, 1)
        XCTAssertEqual(published.upcoming(on: day(2026, 11, 14, hour: 23)).first?.daysAway, 1)
        XCTAssertEqual(published.upcoming(on: day(2026, 11, 15, hour: 8)).first?.daysAway, 0)
    }

    /// The app is not opened for six weeks. Before, the widget kept showing the charge it was last
    /// told about, as "today", every day. Now the next one takes its place.
    func testAChargeThatHasPassedGivesWayToTheNext() {
        let published = feed([sub("Netflix", anchor: day(2026, 11, 15))], now: day(2026, 11, 10))
        let later = published.upcoming(on: day(2026, 12, 28))
        XCTAssertEqual(later.first.map { cal.dayStamp($0.day) }, "2027-01-15")
        XCTAssertEqual(later.first?.daysAway, 18)
    }

    func testWhenThePublishedDaysRunOutNothingIsShownAsDue() {
        let published = feed([sub("Netflix", anchor: day(2026, 11, 15), frequency: .yearly)], now: day(2026, 11, 10))
        XCTAssertEqual(published.upcoming(on: day(2029, 1, 1)), [])
    }

    func testTrialsEndingAreTheirOwnList() {
        let published = feed([sub("Crave", anchor: day(2026, 11, 20), status: .trial, trialEnds: day(2026, 11, 20)),
                              sub("Netflix", anchor: day(2026, 11, 15))], now: day(2026, 11, 10))
        XCTAssertEqual(published.trialsEnding(on: day(2026, 11, 10)).map(\.charge.name), ["Crave"])
        // Once the trial has ended it is an ordinary subscription.
        XCTAssertEqual(published.trialsEnding(on: day(2026, 11, 21)), [])
        XCTAssertEqual(published.upcoming(on: day(2026, 11, 21)).map(\.charge.name), ["Netflix", "Crave"])
    }

    func testAWidgetDrawsAgainAtEachOfTheNextMidnights() {
        let now = day(2026, 11, 10, hour: 15)
        let moments = WidgetFeed.refreshMoments(from: now, days: 3)
        XCTAssertEqual(moments, [now, day(2026, 11, 11, hour: 0), day(2026, 11, 12, hour: 0), day(2026, 11, 13, hour: 0)])
    }

    // MARK: - Publishing

    func testPublishingWritesTheFeedRemovesWhatEarlierVersionsLeftAndRedrawsTheWidgets() {
        defaults.set("Netflix · $15.49 · in 3 days", forKey: "widget_topInsight")
        defaults.set("Netflix", forKey: "liveActivity_subscriptionName")
        var redraws = 0
        let store = WidgetDataStore.forTesting(defaults: defaults) { redraws += 1 }

        store.publish(subscriptions: [sub("Netflix", anchor: day(2026, 11, 15))], now: day(2026, 11, 10))

        XCTAssertEqual(store.readFeed()?.charges.map(\.name), ["Netflix"])
        XCTAssertNil(defaults.object(forKey: "widget_topInsight"))
        XCTAssertNil(defaults.object(forKey: "liveActivity_subscriptionName"))
        XCTAssertEqual(redraws, 1)
    }

    /// Nothing published (or nothing readable) is not the same as an empty list.
    func testNothingPublishedIsNotAnEmptyList() {
        XCTAssertNil(WidgetFeed.read(from: defaults))
        WidgetDataStore.forTesting(defaults: defaults).publish(subscriptions: [])
        XCTAssertEqual(WidgetFeed.read(from: defaults)?.hasSubscriptions, false)
    }

    func testTheChosenLanguageTravelsWithTheFeed() {
        let arabic = WidgetDataStore.feed(for: [], now: day(2026, 11, 10), currency: "USD", rates: .fallback, language: "ar")
        XCTAssertEqual(arabic.language, "ar")
    }
}
