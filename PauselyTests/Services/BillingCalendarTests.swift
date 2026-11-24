import UserNotifications
import XCTest
@testable import Pausely

/// Services bill by the Gregorian calendar, whatever calendar an iPhone shows. Every day Pausely works
/// out (a renewal, a reminder, an age, a month of use, a year) comes from `Calendar.billing`, never
/// from the phone's calendar.
///
/// Nothing in this file uses the phone's calendar either, so the class can be run on a simulator set
/// to the Buddhist or the Islamic calendar and must pass there unchanged (see GOLD_STANDARD.md, O2).
@MainActor
final class BillingCalendarTests: XCTestCase {

    private var gregorian: Calendar { .billing }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testTheBillingCalendarIsGregorianInThePhonesTimeZone() {
        // For the record of a run: which calendar the simulator itself is set to.
        print("PHONE CALENDAR: \(Locale.current.calendar.identifier) (\(Locale.current.identifier))")
        XCTAssertEqual(Calendar.billing.identifier, .gregorian)
        XCTAssertEqual(Calendar.billing.timeZone.secondsFromGMT(), TimeZone.current.secondsFromGMT())
    }

    func testNothingWorksOutADayInThePhonesCalendar() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        for folder in ["Pausely", "PauselyWidget", "Shared"] {
            let folderURL = root.appendingPathComponent(folder)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: folderURL.path), "Sources aren't readable from this test run")
            let files = try XCTUnwrap(FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                for (index, line) in text.components(separatedBy: "\n").enumerated() {
                    if line.contains("Calendar.current") || line.contains("Calendar.autoupdatingCurrent")
                        || line.contains("Calendar = .current") || line.contains("calendar: .current") {
                        offenders.append("\(file.path.dropFirst(root.path.count + 1)):\(index + 1)")
                    }
                }
            }
        }
        XCTAssertEqual(offenders, [], "Use Calendar.billing: the phone's calendar may be Islamic, Buddhist or Japanese")
    }

    // MARK: - Renewals

    func testAMonthlyRenewalIsAGregorianMonthLater() {
        // In the Islamic calendar the month after this one is 29 or 30 days on, and never the 31st.
        let next = RenewalSchedule.nextRenewal(anchor: day(2026, 1, 31), frequency: .monthly, onOrAfter: day(2026, 2, 1))
        XCTAssertEqual(next, day(2026, 2, 28))
        let after = RenewalSchedule.nextRenewal(anchor: day(2026, 1, 31), frequency: .monthly, onOrAfter: day(2026, 3, 1))
        XCTAssertEqual(after, day(2026, 3, 31))
    }

    func testAYearlyRenewalIsTheSameGregorianDayNextYear() {
        let next = RenewalSchedule.nextRenewal(anchor: day(2026, 11, 12), frequency: .yearly, onOrAfter: day(2026, 11, 13))
        XCTAssertEqual(next, day(2027, 11, 12))
    }

    func testASubscriptionsNextRenewalUsesTheBillingCalendarByDefault() {
        var subscription = Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly)
        subscription.nextBillingDate = day(2026, 1, 31)
        XCTAssertEqual(subscription.nextRenewal(onOrAfter: day(2026, 4, 1)), day(2026, 4, 30))
    }

    // MARK: - Reminders

    /// The notification center is handed Gregorian fields and told they are Gregorian. Asked when it
    /// will fire, it answers with the very moment that was planned: on a phone showing the Buddhist
    /// calendar too, where the year 2027 of its own era was 1,484 years ago.
    func testAReminderFiresAtTheMomentPlannedWhateverThePhonesCalendar() throws {
        let fire = day(2027, 3, 15, hour: 9)
        let components = ReminderScheduler.triggerDate(for: fire)
        XCTAssertEqual(components.year, 2027)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.calendar?.identifier, .gregorian)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        XCTAssertEqual(trigger.nextTriggerDate(), fire)
    }

    func testTheDayBeforeReminderIsTheGregorianDayBefore() throws {
        var subscription = Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly)
        subscription.nextBillingDate = day(2027, 3, 1)
        let plan = ReminderPlanner.plan(for: [subscription], now: day(2027, 2, 20),
                                        preferences: .init(renewals: true, trials: true), kept: [], pausePlan: nil)
        let tomorrow = try XCTUnwrap(plan.first { $0.kind == .renewalTomorrow })
        XCTAssertEqual(gregorian.dateComponents([.year, .month, .day], from: tomorrow.fireDate),
                       DateComponents(year: 2027, month: 2, day: 28))
    }

    // MARK: - Age, months, years

    func testAgeIsCountedInGregorianYears() {
        // Born 1 May 2011: 15 on 11 November 2026. In the Islamic calendar the count already says 16.
        XCTAssertEqual(AgeConsentManager.age(on: day(2026, 11, 11), birthDate: day(2011, 5, 1)), 15)
        XCTAssertEqual(AgeConsentManager.age(on: day(2027, 5, 1), birthDate: day(2011, 5, 1)), 16)
    }

    func testTypedHoursBelongToAGregorianMonth() throws {
        let suite = "BillingCalendarTests.hours"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let log = UsageLog(defaults: defaults)
        log.setMonthlyUsage(minutes: 120, for: "Netflix", now: day(2026, 11, 2))
        XCTAssertEqual(log.getUsage(for: "Netflix", now: day(2026, 11, 30))?.minutesUsed, 120)
        XCTAssertNil(log.getUsage(for: "Netflix", now: day(2026, 12, 1)))
    }

    func testTheYearSlipCountsAGregorianYear() {
        let stats = WrappedStats(subscriptions: [], events: [], now: day(2026, 11, 12), currency: "USD", rates: .fallback)
        XCTAssertTrue(stats.hasNothingToShow, "an empty list with nothing cancelled is not a year to print")
        XCTAssertEqual(stats.year, 2026)
    }
}
