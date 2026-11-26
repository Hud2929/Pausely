import XCTest
@testable import Pausely

/// Verifies the retention, trial-protection, price-hike re-scan, annual-renewal radar, and ethical
/// review-velocity improvements from the Shark Tank audit.
@MainActor
final class SharkTankRetentionTests: XCTestCase {

    private var sandbox: StoreSandbox!
    private let rates = CurrencyRates(perUSD: ["USD": 1, "CAD": 2])

    override func setUp() async throws {
        sandbox = StoreSandbox()
    }

    override func tearDown() async throws {
        await sandbox.restore()
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.billing.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testProtectionSummaryExcludesPauselyConvertsStrictlyAndFindsNextCharge() {
        let now = day(2026, 11, 25)
        let pausely = Subscription(name: "Pausely Pro", amount: Decimal(string: "29.99")!, currency: "USD",
                                   billingFrequency: .yearly, trialEndsAt: day(2026, 12, 2), status: .trial)
        let netflix = Subscription(name: "Netflix", amount: Decimal(string: "20.00")!, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: day(2026, 12, 3))
        let crave = Subscription(name: "Crave", amount: Decimal(string: "20.00")!, currency: "CAD",
                                 billingFrequency: .monthly, nextBillingDate: day(2026, 11, 28))
        let cancelled = Subscription(name: "Hulu", amount: Decimal(string: "18.99")!, currency: "USD",
                                     billingFrequency: .monthly, status: .cancelled)

        let summary = ProtectionSummary.current(
            subscriptions: [pausely, netflix, crave, cancelled],
            displayCurrency: "USD",
            rates: rates,
            now: now
        )
        XCTAssertEqual(summary.watchedCount, 2)
        XCTAssertEqual(summary.isConverted, true)
        // Netflix $20*12 = $240 + Crave (CA$20/2)*12 = $120 -> $360
        XCTAssertEqual(summary.yearlySpend, Decimal(360))
        XCTAssertEqual(summary.nextCharge?.name, "Crave")
        XCTAssertEqual(summary.overFreeLimitCount, 0)

        let unknown = Subscription(name: "Mystery", amount: 10, currency: "XXX", billingFrequency: .monthly)
        let unknownSummary = ProtectionSummary.current(
            subscriptions: [netflix, unknown],
            displayCurrency: "USD",
            rates: rates,
            now: now
        )
        XCTAssertEqual(unknownSummary.watchedCount, 2)
        XCTAssertNil(unknownSummary.yearlySpend)
    }

    func testLaterLargeRenewalsCaptures32To90DayNonMonthlyChargesOnly() {
        let now = day(2026, 11, 25)
        let monthly = Subscription(name: "Spotify", amount: Decimal(string: "11.99")!, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: day(2027, 1, 10))
        let soonAnnual = Subscription(name: "AppleCare", amount: Decimal(string: "99.00")!, currency: "USD",
                                      billingFrequency: .yearly, nextBillingDate: day(2026, 12, 10))
        let midAnnual = Subscription(name: "Amazon Prime", amount: Decimal(string: "139.00")!, currency: "USD",
                                     billingFrequency: .yearly, nextBillingDate: day(2027, 1, 15))
        let midQuarterly = Subscription(name: "Box", amount: Decimal(string: "45.00")!, currency: "USD",
                                        billingFrequency: .quarterly, nextBillingDate: day(2027, 1, 5))
        let farAnnual = Subscription(name: "Domain", amount: Decimal(string: "20.00")!, currency: "USD",
                                     billingFrequency: .yearly, nextBillingDate: day(2027, 5, 1))

        let later = Horizon.laterLargeRenewals(for: [monthly, soonAnnual, midAnnual, midQuarterly, farAnnual], now: now)
        XCTAssertEqual(later.map(\.name), ["Box", "Amazon Prime"])
    }

    func testScreenshotPriceUpdateOptInRecordsPriceChangedEventWhileDefaultPreservesAmount() async throws {
        let suiteName = "SharkTankRetentionTests.priceUpdate.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let netflix = Subscription(name: "Netflix", amount: Decimal(string: "15.49")!, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: day(2026, 12, 15))
        _ = try await SubscriptionStore.shared.addSubscription(netflix, recordEvent: false)

        let scanned = [TallyLine(name: "Netflix", category: "Entertainment", amount: Decimal(string: "19.99")!,
                                 currency: "USD", frequency: .monthly, anchor: day(2026, 12, 15))]

        // Default add never alters an existing subscription's price.
        let defaultOutcome = await TallyImporter.add(scanned, into: SubscriptionStore.shared, defaults: defaults)
        XCTAssertTrue(defaultOutcome.pricesUpdated.isEmpty)
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.first?.amount, Decimal(string: "15.49"))

        // Confirmed screenshot re-scan updates the price and records a `.priceChanged` event.
        let updateOutcome = await TallyImporter.add(scanned, into: SubscriptionStore.shared,
                                                    updatePriceChanges: true, defaults: defaults)
        XCTAssertEqual(updateOutcome.pricesUpdated, ["Netflix"])
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.first?.amount, Decimal(string: "19.99"))
        XCTAssertTrue(LifecycleEventLog.shared.events.contains {
            $0.subscriptionId == netflix.id && $0.kind == .priceChanged
        })
    }

    func testReviewDecisionMilestones() {
        XCTAssertEqual(ReviewPromptManager.milestone(forDecisions: 0), 0)
        XCTAssertEqual(ReviewPromptManager.milestone(forDecisions: 2), 0)
        XCTAssertEqual(ReviewPromptManager.milestone(forDecisions: 3), 3)
        XCTAssertEqual(ReviewPromptManager.milestone(forDecisions: 9), 3)
        XCTAssertEqual(ReviewPromptManager.milestone(forDecisions: 10), 10)
        XCTAssertEqual(ReviewPromptManager.milestone(forDecisions: 42), 10)
    }

    func testOnboardingProfileTrialPlanAndReminderDaysApplication() async throws {
        let suiteName = "SharkTankRetentionTests.profile.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var profile = OnboardingProfile()
        profile.goal = .rotateStreaming
        profile.reminderDays = 7
        profile.save(defaults: defaults)

        let loaded = OnboardingProfile.load(defaults: defaults)
        XCTAssertEqual(loaded.goal, .rotateStreaming)
        XCTAssertEqual(loaded.validReminderDays, 7)
        XCTAssertEqual(loaded.curatedTrigger(waitingCount: 0, hasPauseEligible: true), .pausePlan)
        XCTAssertEqual(loaded.curatedTrigger(waitingCount: 2, hasPauseEligible: true), .unlimitedSubscriptions)

        let steps = loaded.trialPlanSteps(
            trialDays: 7, watchedCount: 6, waitingCount: 1,
            yearlyText: "$900", pauseYearlyText: "$240",
            reminderState: .ready, day3Date: "Nov 27",
            reminderDate: "Nov 30", reminderLeadDays: 2,
            firstChargeDate: "Dec 2", chargeText: "$29.99/year", lastDayToCancel: "Dec 1"
        )
        XCTAssertEqual(steps.map(\.id), ["day1", "day3", "reminder", "charge"])
        XCTAssertTrue(steps[1].detail.contains("$240"))

        let notAskedSteps = loaded.trialPlanSteps(
            trialDays: 7, watchedCount: 4, waitingCount: 0,
            yearlyText: "$480", pauseYearlyText: nil,
            reminderState: .notAsked, day3Date: "Nov 27",
            reminderDate: "Nov 30", reminderLeadDays: 2,
            firstChargeDate: "Dec 2", chargeText: "$29.99/year", lastDayToCancel: "Dec 1"
        )
        XCTAssertEqual(notAskedSteps[2].badge, L10n.string("Free"))

        let deniedSteps = loaded.trialPlanSteps(
            trialDays: 7, watchedCount: 4, waitingCount: 0,
            yearlyText: "$480", pauseYearlyText: nil,
            reminderState: .offOrHidden, day3Date: "Nov 27",
            reminderDate: "Nov 30", reminderLeadDays: 2,
            firstChargeDate: "Dec 2", chargeText: "$29.99/year", lastDayToCancel: "Dec 1"
        )
        XCTAssertEqual(deniedSteps[2].title, L10n.string("Reminder (alerts off)"))

        let sub = Subscription(name: "Netflix", amount: Decimal(string: "17.99")!, currency: "USD",
                               billingFrequency: .monthly, notifyBeforeDays: 3)
        _ = try await SubscriptionStore.shared.addSubscription(sub, recordEvent: false)
        await loaded.applyReminderDays(to: SubscriptionStore.shared, from: 3, defaults: defaults)
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.first?.notifyBeforeDays, 7)

        // Changing default again from 7 → 1 updates subscriptions still carrying the previous default.
        var updated = loaded
        updated.reminderDays = 1
        await updated.applyReminderDays(to: SubscriptionStore.shared, from: 7, defaults: defaults)
        XCTAssertEqual(SubscriptionStore.shared.subscriptions.first?.notifyBeforeDays, 1)
    }

    func testSavingsMilestoneRemindersAreLowestPriorityAndExcludedFromRefill() {
        let now = day(2026, 11, 25)
        let active = Subscription(name: "Spotify", amount: Decimal(string: "11.99")!, currency: "USD",
                                  billingFrequency: .monthly, nextBillingDate: day(2026, 11, 29), notifyBeforeDays: 3)
        let cancelled = Subscription(name: "Hulu", amount: Decimal(string: "18.99")!, currency: "USD",
                                     billingFrequency: .monthly, nextBillingDate: day(2026, 11, 27), status: .cancelled)
        let avoided = [ReminderPlanner.AvoidedCharge(subscriptionId: cancelled.id, date: day(2026, 11, 27), amountText: "$18.99")]

        // Default preferences leave savings milestones off so existing plans don't change unexpectedly.
        let defaultPlan = ReminderPlanner.plan(for: [active, cancelled], now: now, avoidedCharges: avoided)
        XCTAssertFalse(defaultPlan.contains { $0.kind == .savingsAvoided })

        // Opted-in includes savingsAvoided when room exists and preserves formatted avoided amount.
        var prefs = ReminderPlanner.Preferences()
        prefs.savingsMilestones = true
        let withMilestones = ReminderPlanner.plan(for: [active, cancelled], now: now,
                                                  preferences: prefs, avoidedCharges: avoided)
        let milestone = withMilestones.first { $0.kind == .savingsAvoided && $0.subscriptionId == cancelled.id }
        XCTAssertEqual(milestone?.amountText, "$18.99")

        // Budget of 1 keeps the active subscription's day-before renewal (rank 0), never displaced by rank 3 milestone.
        let tight = ReminderPlanner.plan(for: [active, cancelled], now: now, budget: 1,
                                         preferences: prefs, avoidedCharges: avoided)
        XCTAssertEqual(tight.count, 1)
        XCTAssertEqual(tight.first?.kind, .renewalTomorrow)

        // Refill date must NOT be pulled earlier by a cancelled subscription's avoided-charge milestone.
        let refillWithout = ReminderPlanner.refillDate(for: [active], now: now, preferences: prefs)
        let refillWith = ReminderPlanner.refillDate(for: [active, cancelled], now: now, preferences: prefs, avoidedCharges: avoided)
        XCTAssertEqual(refillWithout, refillWith)
    }

    func testWidgetFeedActivePauseTurnExpiresAfterMidnight() {
        var feed = WidgetFeed()
        feed.pauseTurnName = "Netflix"
        feed.pauseTurnEndText = "Nov 30"
        feed.pauseTurnEndStamp = "2026-11-30"

        XCTAssertEqual(feed.activePauseTurn(on: day(2026, 11, 30))?.name, "Netflix")
        XCTAssertNil(feed.activePauseTurn(on: day(2026, 12, 1)))
    }

    func testWinBackOfferFilteringBlocksActiveUsersAndCrossProductCollisions() {
        let monthlyID = StoreKitManager.ProductID.monthly.rawValue
        let annualID = StoreKitManager.ProductID.annual.rawValue

        // Lapsed Monthly subscriber with Win-Back offer "winback_7d" MUST match Monthly ONLY, never Annual.
        let lapsedMonthly = [
            StoreKitManager.StatusSnapshot(state: .expired,
                                           transactionProductID: monthlyID,
                                           renewalProductID: monthlyID,
                                           eligibleOfferIDs: ["winback_7d"])
        ]
        XCTAssertEqual(StoreKitManager.eligibleWinBackIDs(forProductID: monthlyID, statuses: lapsedMonthly), ["winback_7d"])
        XCTAssertEqual(StoreKitManager.eligibleWinBackIDs(forProductID: annualID, statuses: lapsedMonthly), [])

        // Active subscriber (even with an older expired status in the group) gets ZERO Win-Back offers.
        let activePlusOldExpired = lapsedMonthly + [
            StoreKitManager.StatusSnapshot(state: .subscribed,
                                           transactionProductID: annualID,
                                           renewalProductID: annualID,
                                           eligibleOfferIDs: [])
        ]
        XCTAssertEqual(StoreKitManager.eligibleWinBackIDs(forProductID: monthlyID, statuses: activePlusOldExpired), [])
        XCTAssertEqual(StoreKitManager.eligibleWinBackIDs(forProductID: annualID, statuses: activePlusOldExpired), [])
    }

    func testPaywallAutoSelectsPlanHoldingFreeWinBackOfferAndUsesReturnCopy() {
        // Lapsed Monthly Win-Back user lands on Monthly automatically instead of a paid Annual plan.
        XCTAssertEqual(
            StoreKitUpgradeView.preferredPlan(current: .annual, annualHasFreeOffer: false, monthlyHasFreeOffer: true),
            .monthly
        )
        // Normal new user eligible on both keeps Annual selected.
        XCTAssertEqual(
            StoreKitUpgradeView.preferredPlan(current: .annual, annualHasFreeOffer: true, monthlyHasFreeOffer: true),
            .annual
        )
        // Return plan uses truthful Win-Back labels ("Return reminder" & "Free days end").
        let profile = OnboardingProfile()
        let steps = profile.trialPlanSteps(
            trialDays: 7, isWinBack: true, watchedCount: 3, waitingCount: 0,
            yearlyText: "$300", pauseYearlyText: nil, reminderState: .ready,
            day3Date: "Nov 27", reminderDate: "Nov 30", reminderLeadDays: 2,
            firstChargeDate: "Dec 2", chargeText: "$4.99/month", lastDayToCancel: "Dec 1"
        )
        XCTAssertEqual(steps[2].title, L10n.string("Return reminder"))
        XCTAssertEqual(steps[3].title, L10n.string("Free days end"))
    }

    func testPaymentManagerCorrectedUpdatesRenewalDateAndStatusOnPlanSwitch() {
        let monthlyTrial = Subscription(
            name: PaymentManager.ownName,
            amount: Decimal(string: "4.99")!,
            currency: "USD",
            billingFrequency: .monthly,
            nextBillingDate: day(2026, 12, 3),
            trialEndsAt: day(2026, 12, 3),
            status: .trial
        )
        let annualOwn = StoreKitManager.OwnSubscription(
            tier: .proAnnual,
            price: Decimal(string: "29.99")!,
            currency: "USD",
            renews: day(2027, 11, 26),
            isTrial: false
        )
        let switchedToAnnual = PaymentManager.corrected(monthlyTrial, to: annualOwn)
        XCTAssertEqual(switchedToAnnual?.amount, Decimal(string: "29.99"))
        XCTAssertEqual(switchedToAnnual?.billingFrequency, .yearly)
        XCTAssertEqual(switchedToAnnual?.nextBillingDate, day(2027, 11, 26))
        XCTAssertEqual(switchedToAnnual?.status, .active)
        XCTAssertNil(switchedToAnnual?.trialEndsAt)

        // Switching Annual → Monthly updates renewal date and frequency back accurately too.
        let monthlyOwn = StoreKitManager.OwnSubscription(
            tier: .pro,
            price: Decimal(string: "4.99")!,
            currency: "USD",
            renews: day(2026, 12, 26),
            isTrial: false
        )
        let switchedToMonthly = switchedToAnnual.flatMap { PaymentManager.corrected($0, to: monthlyOwn) }
        XCTAssertEqual(switchedToMonthly?.amount, Decimal(string: "4.99"))
        XCTAssertEqual(switchedToMonthly?.billingFrequency, .monthly)
        XCTAssertEqual(switchedToMonthly?.nextBillingDate, day(2026, 12, 26))
        XCTAssertEqual(switchedToMonthly?.status, .active)
    }
}
