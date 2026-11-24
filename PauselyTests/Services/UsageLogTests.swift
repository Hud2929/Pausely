import XCTest
@testable import Pausely

/// Hours a person types in for a subscription. "This month" has to mean this month.
@MainActor
final class UsageLogTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suite = ""
    private var log: UsageLog!
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    override func setUp() {
        suite = "UsageLogTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        log = UsageLog(defaults: defaults, calendar: calendar)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testWhatIsEnteredThisMonthIsThisMonths() {
        let netflix = Subscription(name: "Netflix", amount: 15, billingFrequency: .monthly)
        log.setMonthlyUsage(minutes: 150, for: netflix, now: day(2026, 11, 3))
        XCTAssertEqual(log.getCurrentMonthUsage(for: netflix, now: day(2026, 11, 28)), 150)
        XCTAssertEqual(log.calculateCostPerHour(for: netflix, now: day(2026, 11, 28)), 6)
    }

    func testLastMonthsHoursAreNotThisMonths() {
        let netflix = Subscription(name: "Netflix", amount: 15, billingFrequency: .monthly)
        log.setMonthlyUsage(minutes: 150, for: netflix, now: day(2026, 10, 30))
        XCTAssertNil(log.getUsage(for: netflix, now: day(2026, 11, 1)), "a new month starts with nothing entered")
        XCTAssertEqual(log.getCurrentMonthUsage(for: netflix, now: day(2026, 11, 1)), 0)
        XCTAssertNil(log.calculateCostPerHour(for: netflix, now: day(2026, 11, 1)))
    }

    func testNotAtAllIsAnAnswer_notTheSameAsNothingEntered() {
        let calm = Subscription(name: "Calm", amount: 12, billingFrequency: .monthly)
        XCTAssertNil(log.getUsage(for: calm, now: day(2026, 11, 3)))
        log.setMonthlyUsage(minutes: 0, for: calm, now: day(2026, 11, 3))
        XCTAssertEqual(log.getUsage(for: calm, now: day(2026, 11, 3)), UsageLog.Usage(minutesUsed: 0))
        XCTAssertNil(log.calculateCostPerHour(for: calm, now: day(2026, 11, 3)), "no hours, no cost per hour")
    }

    func testAnEntryFromBeforeMonthsWereRecordedCountsOnceThenExpires() {
        let spotify = Subscription(name: "Spotify", amount: 11, billingFrequency: .monthly)
        defaults.set(90, forKey: "usage_Spotify")   // how earlier versions stored it
        XCTAssertEqual(log.getCurrentMonthUsage(for: spotify, now: day(2026, 11, 10)), 90)
        XCTAssertEqual(log.getCurrentMonthUsage(for: spotify, now: day(2026, 12, 2)), 0)
    }

    func testSubscriptionsAreKeptApart() {
        let netflix = Subscription(name: "Netflix", amount: 15, billingFrequency: .monthly)
        let hulu = Subscription(name: "Hulu", amount: 15, billingFrequency: .monthly)
        log.setMonthlyUsage(minutes: 60, for: netflix, now: day(2026, 11, 3))
        XCTAssertNil(log.getUsage(for: hulu, now: day(2026, 11, 3)))
    }

    func testUsageFollowsSubscriptionAcrossRename() {
        var sub = Subscription(name: "HBO Max", amount: Decimal(string: "16.99")!, billingFrequency: .monthly)
        log.setMonthlyUsage(minutes: 240, for: sub, now: day(2026, 11, 5))
        sub.name = "Max"
        XCTAssertEqual(log.getCurrentMonthUsage(for: sub, now: day(2026, 11, 10)), 240)
        XCTAssertEqual(log.calculateCostPerHour(for: sub, now: day(2026, 11, 10)), Decimal(string: "16.99")! / 4)
    }

    func testTwoSubscriptionsWithSameNameHaveSeparateUsage() {
        let personal = Subscription(name: "iCloud+", amount: 2.99, billingFrequency: .monthly)
        let family = Subscription(name: "iCloud+", amount: 9.99, billingFrequency: .monthly)
        log.setMonthlyUsage(minutes: 60, for: personal, now: day(2026, 11, 5))
        log.setMonthlyUsage(minutes: 600, for: family, now: day(2026, 11, 5))
        XCTAssertEqual(log.getCurrentMonthUsage(for: personal, now: day(2026, 11, 10)), 60)
        XCTAssertEqual(log.getCurrentMonthUsage(for: family, now: day(2026, 11, 10)), 600)
    }

    func testLegacyNameKeyMigratesToSubscriptionUUID() {
        let sub = Subscription(name: "Netflix", amount: 15.99, billingFrequency: .monthly)
        defaults.set(180, forKey: "usage_Netflix")
        defaults.set("2026-11", forKey: "usage_month_Netflix")
        XCTAssertEqual(log.getCurrentMonthUsage(for: sub, now: day(2026, 11, 8)), 180)
        // Updating via subscription clears the legacy key so another service with the same name won't inherit it.
        log.setMonthlyUsage(minutes: 300, for: sub, now: day(2026, 11, 9))
        let second = Subscription(name: "Netflix", amount: 15.99, billingFrequency: .monthly)
        XCTAssertNil(log.getUsage(for: second, now: day(2026, 11, 9)))
        XCTAssertEqual(log.getCurrentMonthUsage(for: sub, now: day(2026, 11, 9)), 300)
    }
}
