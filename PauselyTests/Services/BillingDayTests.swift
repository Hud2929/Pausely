import XCTest
@testable import Pausely

/// A renewal day names the same calendar day wherever it is read: typed in Toronto, read in Tokyo,
/// Auckland or Honolulu, it is still the 15th.
@MainActor
final class BillingDayTests: XCTestCase {

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func noon(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func ymd(_ date: Date, in calendar: Calendar) -> [Int] {
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return [parts.year!, parts.month!, parts.day!, parts.hour!]
    }

    private let zones = ["America/Toronto", "Asia/Tokyo", "Pacific/Auckland", "Pacific/Honolulu", "Europe/London",
                         "Pacific/Kiritimati", "Etc/GMT+12", "Asia/Kolkata", "America/St_Johns"]

    func testASavedDayIsNoonUTCOnThatDay() {
        let toronto = calendar("America/Toronto")
        let saved = BillingDay.stored(noon(2026, 11, 15, in: toronto), calendar: toronto)
        XCTAssertEqual(ymd(saved, in: calendar("UTC")), [2026, 11, 15, 12])
        XCTAssertTrue(BillingDay.isStoredForm(saved))
    }

    /// The fault this fixes: typed in Toronto, a day used to be saved as Toronto's noon, which is two
    /// in the morning of the next day in Tokyo.
    func testADayTypedInOneTimeZoneIsTheSameDayInEveryOther() {
        for typedIn in zones {
            let saved = BillingDay.stored(noon(2026, 11, 15, in: calendar(typedIn)), calendar: calendar(typedIn))
            for readIn in zones {
                let local = BillingDay.local(fromStored: saved, calendar: calendar(readIn))
                XCTAssertEqual(ymd(local, in: calendar(readIn)), [2026, 11, 15, 12], "typed in \(typedIn), read in \(readIn)")
            }
        }
    }

    /// What an earlier version saved (noon where it was typed) is read as the day it falls on here, as
    /// it always was, so nothing moves on the phone it was typed on.
    func testADaySavedByAnEarlierVersionStaysWhereItWasOnTheSamePhone() {
        for zone in zones where zone != "Europe/London" {
            let old = noon(2026, 7, 15, in: calendar(zone))   // July: London is not on UTC either
            XCTAssertEqual(BillingDay.isStoredForm(old), TimeZone(identifier: zone)!.secondsFromGMT(for: old) == 0)
            let local = BillingDay.local(fromStored: old, calendar: calendar(zone))
            XCTAssertEqual(ymd(local, in: calendar(zone)), [2026, 7, 15, 12], zone)
        }
    }

    func testSavingADayTwiceChangesNothing() {
        let tokyo = calendar("Asia/Tokyo")
        let once = BillingDay.stored(noon(2026, 2, 28, in: tokyo), calendar: tokyo)
        let again = BillingDay.stored(BillingDay.local(fromStored: once, calendar: tokyo), calendar: tokyo)
        XCTAssertEqual(once, again)
    }

    // MARK: - Where days are saved

    /// The copy kept on the iPhone and the history both hold the saved form, and give the day back.
    func testASubscriptionIsSavedWithItsDaysInTheSavedForm() throws {
        var subscription = Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly)
        subscription.nextBillingDate = Calendar.billing.noon(of: noon(2026, 11, 15, in: .billing))
        subscription.trialEndsAt = Calendar.billing.noon(of: noon(2026, 11, 20, in: .billing))

        let data = try JSONEncoder().encode(subscription)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let savedSeconds = try XCTUnwrap(json["nextBillingDate"] as? Double)
        XCTAssertTrue(BillingDay.isStoredForm(Date(timeIntervalSinceReferenceDate: savedSeconds)))

        let back = try JSONDecoder().decode(Subscription.self, from: data)
        XCTAssertEqual(back.nextBillingDate, subscription.nextBillingDate)
        XCTAssertEqual(back.trialEndsAt, subscription.trialEndsAt)
    }

    func testASubscriptionWithNoDaysIsSavedWithoutThem() throws {
        let subscription = Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly)
        let data = try JSONEncoder().encode(subscription)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["nextBillingDate"])
        XCTAssertNil(try JSONDecoder().decode(Subscription.self, from: data).nextBillingDate)
    }

    func testTheServerIsSentTheSavedFormAndGivesTheDayBack() throws {
        var subscription = Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly)
        subscription.nextBillingDate = noon(2026, 11, 15, in: .billing)
        let record = SubscriptionRecord(from: subscription)
        XCTAssertEqual(record.next_billing_date, "2026-11-15T12:00:00Z")
        XCTAssertEqual(record.toSubscription().nextBillingDate, subscription.nextBillingDate)
    }

    /// A row an earlier version sent (noon where it was typed) is still read as that day on this phone.
    func testARowFromAnEarlierVersionKeepsItsDay() {
        var subscription = Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly)
        subscription.nextBillingDate = noon(2026, 11, 15, in: .billing)
        var record = SubscriptionRecord(from: subscription)
        record.next_billing_date = noon(2026, 11, 15, in: .billing).iso8601String
        XCTAssertEqual(record.toSubscription().nextBillingDate, subscription.nextBillingDate)
    }

    // MARK: - A flight

    /// The whole of it: a renewal on the 15th, typed in Toronto. The phone lands in Tokyo. The renewal
    /// is still the 15th, and the day-before reminder is still the 14th.
    func testAfterAFlightEveryRenewalIsStillOnItsDay() async throws {
        let home = NSTimeZone.default
        defer { NSTimeZone.default = home }
        let sandbox = StoreSandbox()
        NSTimeZone.default = TimeZone(identifier: "America/Toronto")!

        var subscription = Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly)
        subscription.nextBillingDate = noon(2026, 11, 15, in: .billing)
        _ = try await SubscriptionStore.shared.addSubscription(subscription)

        NSTimeZone.default = TimeZone(identifier: "Asia/Tokyo")!
        SubscriptionStore.shared.timeZoneChanged()

        let anchor = try XCTUnwrap(SubscriptionStore.shared.subscriptions.first?.nextBillingDate)
        XCTAssertEqual(ymd(anchor, in: .billing), [2026, 11, 15, 12])
        let plan = ReminderPlanner.plan(for: SubscriptionStore.shared.subscriptions,
                                        now: noon(2026, 11, 10, in: .billing),
                                        preferences: .init(renewals: true, trials: true), kept: [], pausePlan: nil)
        let dayBefore = try XCTUnwrap(plan.first { $0.kind == .renewalTomorrow })
        XCTAssertEqual(Array(ymd(dayBefore.fireDate, in: .billing).prefix(3)), [2026, 11, 14])
        await sandbox.restore()
    }
}
