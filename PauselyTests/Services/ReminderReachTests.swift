import XCTest
@testable import Pausely

/// Reminders that reach the person: the right charge is kept, nobody is left without their
/// day-before reminder when there are too many to hold, the plan says so before it runs out, and
/// "on" means seen.
final class ReminderReachTests: XCTestCase {

    private let cal = Calendar.billing

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func sub(_ name: String, anchor: Date, frequency: BillingFrequency = .monthly, remind: Int = 3,
                     status: SubscriptionStatus = .active, trialEnds: Date? = nil) -> Subscription {
        Subscription(name: name, amount: 10, currency: "USD", billingFrequency: frequency, nextBillingDate: anchor,
                     notifyBeforeDays: remind, trialEndsAt: trialEnds, status: status)
    }

    // MARK: - "Keep it" keeps the charge its reminder was about

    func testTheChargeAReminderWasAbout() {
        let netflix = sub("Netflix", anchor: day(2026, 11, 15))
        let ahead = RenewalDecisions.charge(for: netflix, onDay: "2026-11-15", now: day(2026, 11, 14))
        XCTAssertEqual(ahead?.date, day(2026, 11, 15))
        XCTAssertEqual(ahead?.isTrialEnd, false)

        // On the day itself it can still be kept.
        XCTAssertNotNil(RenewalDecisions.charge(for: netflix, onDay: "2026-11-15", now: day(2026, 11, 15, hour: 20)))
    }

    /// Before, "Keep it" pressed on an old reminder kept whichever charge was next: the day after the
    /// 15 November charge, it silenced every reminder for 15 December.
    func testAReminderAnsweredAfterItsChargeKeepsNothing() {
        let netflix = sub("Netflix", anchor: day(2026, 11, 15))
        XCTAssertNil(RenewalDecisions.charge(for: netflix, onDay: "2026-11-15", now: day(2026, 11, 16)))
    }

    func testADayThatIsNotOneOfItsChargesKeepsNothing() {
        let netflix = sub("Netflix", anchor: day(2026, 11, 15))
        XCTAssertNil(RenewalDecisions.charge(for: netflix, onDay: "2026-11-20", now: day(2026, 11, 14)))
        let cancelled = sub("Hulu", anchor: day(2026, 11, 15), status: .cancelled)
        XCTAssertNil(RenewalDecisions.charge(for: cancelled, onDay: "2026-11-15", now: day(2026, 11, 14)))
    }

    func testAReminderAboutATrialEndingKeepsTheTrialEnd() {
        let trial = sub("Crave", anchor: day(2026, 11, 20), status: .trial, trialEnds: day(2026, 11, 20))
        let charge = RenewalDecisions.charge(for: trial, onDay: "2026-11-20", now: day(2026, 11, 19))
        XCTAssertEqual(charge?.isTrialEnd, true)
    }

    // MARK: - More reminders than iOS will hold

    /// Thirty subscriptions want about ninety reminders for their next charge alone; iOS holds 64.
    /// Before, the soonest sixty won, and the subscriptions renewing latest in the month got none.
    func testEverySubscriptionKeepsItsDayBeforeReminder() {
        let now = day(2026, 11, 1)
        let subscriptions = (0..<30).map { sub("Sub \($0)", anchor: day(2026, 11, 3 + ($0 % 26))) }
        let plan = ReminderPlanner.plan(for: subscriptions, now: now)
        XCTAssertEqual(plan.count, ReminderPlanner.defaultBudget)
        let withDayBefore = Set(plan.filter { $0.kind == .renewalTomorrow }.map(\.subscriptionId))
        XCTAssertEqual(withDayBefore, Set(subscriptions.map(\.id)))
        XCTAssertEqual(plan, plan.sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }, "in the order they fire")
    }

    func testWithRoomEverythingIsPlannedAsBefore() {
        let netflix = sub("Netflix", anchor: day(2026, 11, 15))
        let plan = ReminderPlanner.plan(for: [netflix], now: day(2026, 11, 1))
        XCTAssertEqual(plan.map(\.kind), [.renewalHeadsUp, .renewalTomorrow, .renewalToday,
                                          .renewalHeadsUp, .renewalTomorrow, .renewalToday])
    }

    // MARK: - The plan says so before it runs out

    func testTheLastThingPlannedAsksToOpenTheApp() throws {
        let netflix = sub("Netflix", anchor: day(2026, 11, 15))
        let now = day(2026, 11, 1)
        let last = try XCTUnwrap(ReminderPlanner.plan(for: [netflix], now: now).last)
        XCTAssertEqual(cal.dateComponents([.month, .day], from: last.fireDate), DateComponents(month: 12, day: 15))

        let refill = try XCTUnwrap(ReminderPlanner.refillDate(for: [netflix], now: now))
        XCTAssertEqual(cal.dateComponents([.year, .month, .day, .hour], from: refill),
                       DateComponents(year: 2026, month: 12, day: 16, hour: 9), "nine on the morning after the last reminder")
    }

    /// When reminders had to be left out, the request comes before the first of them would have fired.
    func testWhenRemindersWereLeftOutTheRequestComesFirst() throws {
        let now = day(2026, 11, 1)
        let subscriptions = (0..<30).map { sub("Sub \($0)", anchor: day(2026, 11, 3 + ($0 % 26))) }
        let refill = try XCTUnwrap(ReminderPlanner.refillDate(for: subscriptions, now: now))
        let plannedIds = Set(ReminderPlanner.plan(for: subscriptions, now: now).map(\.identifier))
        let everything = ReminderPlanner.plan(for: subscriptions, now: now, budget: 10_000)
        let firstLeftOut = try XCTUnwrap(everything.filter { !plannedIds.contains($0.identifier) }.map(\.fireDate).min())
        XCTAssertLessThanOrEqual(refill, firstLeftOut)
        XCTAssertGreaterThan(refill, now)
    }

    func testNothingPlannedMeansNothingToAsk() {
        XCTAssertNil(ReminderPlanner.refillDate(for: [], now: day(2026, 11, 1)))
        let off = sub("Netflix", anchor: day(2026, 11, 15), remind: 0)
        XCTAssertNil(ReminderPlanner.refillDate(for: [off], now: day(2026, 11, 1)))
    }

    @MainActor
    func testTheRequestSaysWhatToDo() {
        let content = ReminderScheduler.refillContent()
        XCTAssertEqual(content.title, "Your renewal reminders need a refresh")
        XCTAssertEqual(content.body, "Open Pausely once and it plans the next ones.")
        XCTAssertNil(content.userInfo["subscription_id"], "a tap opens the app, not a subscription")
        XCTAssertTrue(ReminderScheduler.isPauselyReminder(ReminderPlanner.refillIdentifier), "removed and re-planned with the rest")
    }

    // MARK: - "On" means seen

    func testAllowedIsNotTheSameAsSeen() {
        XCTAssertEqual(ReminderDelivery(banners: true, lockScreen: true, notificationCenter: true, inScheduledSummary: false), .shown)
        XCTAssertEqual(ReminderDelivery(banners: false, lockScreen: false, notificationCenter: true, inScheduledSummary: false), .shown)
        XCTAssertEqual(ReminderDelivery(banners: false, lockScreen: false, notificationCenter: false, inScheduledSummary: false), .hidden)
        XCTAssertEqual(ReminderDelivery(banners: true, lockScreen: true, notificationCenter: true, inScheduledSummary: true), .late)
        XCTAssertEqual(ReminderDelivery(banners: false, lockScreen: false, notificationCenter: false, inScheduledSummary: true), .hidden,
                       "nowhere to appear is the worse of the two")
    }
}
