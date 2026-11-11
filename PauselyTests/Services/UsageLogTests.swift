import XCTest
@testable import Pausely

/// Hours a person types in for a subscription. "This month" has to mean this month.
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
        log.setMonthlyUsage(minutes: 150, for: "Netflix", now: day(2026, 11, 3))
        XCTAssertEqual(log.getCurrentMonthUsage(for: "Netflix", now: day(2026, 11, 28)), 150)
        XCTAssertEqual(log.calculateCostPerHour(monthlyCost: 15, subscriptionName: "Netflix", now: day(2026, 11, 28)), 6)
    }

    func testLastMonthsHoursAreNotThisMonths() {
        log.setMonthlyUsage(minutes: 150, for: "Netflix", now: day(2026, 10, 30))
        XCTAssertNil(log.getUsage(for: "Netflix", now: day(2026, 11, 1)), "a new month starts with nothing entered")
        XCTAssertEqual(log.getCurrentMonthUsage(for: "Netflix", now: day(2026, 11, 1)), 0)
        XCTAssertNil(log.calculateCostPerHour(monthlyCost: 15, subscriptionName: "Netflix", now: day(2026, 11, 1)))
    }

    func testNotAtAllIsAnAnswer_notTheSameAsNothingEntered() {
        XCTAssertNil(log.getUsage(for: "Calm", now: day(2026, 11, 3)))
        log.setMonthlyUsage(minutes: 0, for: "Calm", now: day(2026, 11, 3))
        XCTAssertEqual(log.getUsage(for: "Calm", now: day(2026, 11, 3)), UsageLog.Usage(minutesUsed: 0))
        XCTAssertNil(log.calculateCostPerHour(monthlyCost: 12, subscriptionName: "Calm", now: day(2026, 11, 3)), "no hours, no cost per hour")
    }

    func testAnEntryFromBeforeMonthsWereRecordedCountsOnceThenExpires() {
        defaults.set(90, forKey: "usage_Spotify")   // how earlier versions stored it
        XCTAssertEqual(log.getCurrentMonthUsage(for: "Spotify", now: day(2026, 11, 10)), 90)
        XCTAssertEqual(log.getCurrentMonthUsage(for: "Spotify", now: day(2026, 12, 2)), 0)
    }

    func testSubscriptionsAreKeptApart() {
        log.setMonthlyUsage(minutes: 60, for: "Netflix", now: day(2026, 11, 3))
        XCTAssertNil(log.getUsage(for: "Hulu", now: day(2026, 11, 3)))
    }
}
