import XCTest
@testable import Pausely

/// Adding what a search of someone's email found (and the first-run slip) to their list. The old importer
/// tried every line, let the free limit throw, and reported nothing: a person who found nine and tapped
/// Import got five and silence. Every line must now end up added, waiting, or reported as already listed.
@MainActor
final class MailImportTests: XCTestCase {

    private let store = SubscriptionStore.shared
    private var sandbox: StoreSandbox!
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        sandbox = StoreSandbox()
        suiteName = "MailImportTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        CurrencyManager.shared.selectedCurrency = "USD"
        UserDefaults.standard.set(false, forKey: "debug_premium_override")
        UserDefaults.standard.set(false, forKey: "debug_free_pro")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        await sandbox.restore()
        sandbox = nil
    }

    private func line(_ name: String, _ amount: String, _ frequency: BillingFrequency = .monthly, currency: String = "USD",
                      anchor: Date? = nil) -> TallyLine {
        TallyLine(name: name, category: "Entertainment", amount: Decimal(string: amount)!, currency: currency,
                  isConfirmed: true, frequency: frequency, anchor: anchor)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func setPro(_ on: Bool) { UserDefaults.standard.set(on, forKey: "debug_premium_override") }

    // MARK: The free limit, in the open

    func testFreeLimitAddsWhatCostsMostAndKeepsTheRestWaiting() async throws {
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Gym", amount: 40, billingFrequency: .monthly))
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Phone", amount: 60, billingFrequency: .monthly))
        let lines = [
            line("iCloud+", "2.99"),                     // 35.88 a year
            line("Netflix", "15.49"),                    // 185.88
            line("Adobe", "239.88", .yearly),            // 239.88: a yearly plan outranks cheaper monthly ones
            line("Spotify", "10.99"),                    // 131.88
            line("Cloudvault", "6.00"),                  // 72.00
            line("Disney+", "990", currency: "JPY")      // about 77 dollars a year, not 11,880
        ]

        let outcome = await TallyImporter.add(lines, into: store, defaults: defaults)

        XCTAssertEqual(Set(outcome.added), ["Adobe", "Netflix", "Spotify"], "three free slots, filled by yearly cost")
        XCTAssertEqual(Set(outcome.waiting), ["iCloud+", "Cloudvault", "Disney+"])
        XCTAssertEqual(store.subscriptions.count, FreeTier.subscriptionLimit)
        XCTAssertEqual(Set(outcome.added).union(outcome.waiting).count, lines.count, "no line may vanish")
        XCTAssertEqual(Set(TallyImporter.waitingLines(defaults: defaults).map(\.name)), Set(outcome.waiting))
        XCTAssertEqual(store.subscriptions.first?.name, "Adobe", "the most expensive ends up on top")
    }

    func testAFullListMakesEverythingWaitAndSaysSo() async throws {
        for index in 1...FreeTier.subscriptionLimit {
            _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Existing \(index)", amount: 5, billingFrequency: .monthly))
        }
        let outcome = await TallyImporter.add([line("Netflix", "15.49"), line("Spotify", "10.99")], into: store, defaults: defaults)
        XCTAssertTrue(outcome.added.isEmpty)
        XCTAssertEqual(Set(outcome.waiting), ["Netflix", "Spotify"])
        XCTAssertEqual(store.subscriptions.count, FreeTier.subscriptionLimit)
    }

    func testProAddsEverything() async {
        setPro(true)
        let lines = (1...9).map { line("Service \($0)", "\($0).99") }
        let outcome = await TallyImporter.add(lines, into: store, defaults: defaults)
        XCTAssertEqual(outcome.added.count, 9)
        XCTAssertTrue(outcome.waiting.isEmpty)
        XCTAssertTrue(TallyImporter.waitingLines(defaults: defaults).isEmpty)
        XCTAssertEqual(store.subscriptions.count, 9)
    }

    func testWaitingLinesJoinTheListWhenProStarts() async {
        let lines = (1...8).map { line("Service \($0)", "\($0).99", anchor: day(2026, 10, $0)) }
        let first = await TallyImporter.add(lines, into: store, defaults: defaults)
        XCTAssertEqual(first.waiting.count, 3)

        setPro(true)
        await TallyImporter.importWaiting(into: store, defaults: defaults)
        XCTAssertEqual(store.subscriptions.count, 8)
        XCTAssertTrue(TallyImporter.waitingLines(defaults: defaults).isEmpty)
        let late = try? XCTUnwrap(store.subscriptions.first { $0.name == "Service 1" })
        XCTAssertEqual(late?.nextBillingDate.map { Calendar.current.component(.day, from: $0) }, 1,
                       "a line that waited keeps the date from its receipts")
    }

    func testAnEarlierWaitingLineIsKeptWhenMoreAreAdded() async throws {
        for index in 1...FreeTier.subscriptionLimit {
            _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Existing \(index)", amount: 5, billingFrequency: .monthly))
        }
        await TallyImporter.add([line("Netflix", "15.49")], into: store, defaults: defaults)
        await TallyImporter.add([line("Spotify", "10.99"), line("Netflix", "17.99")], into: store, defaults: defaults)
        let waiting = TallyImporter.waitingLines(defaults: defaults)
        XCTAssertEqual(Set(waiting.map(\.name)), ["Netflix", "Spotify"])
        XCTAssertEqual(waiting.first { $0.name == "Netflix" }?.amount, Decimal(string: "17.99"), "the newer finding replaces its older copy")
    }

    // MARK: What's already on the list

    func testAlreadyListedIsNeverAddedTwiceAndAMissingDateIsFilled() async throws {
        setPro(true)
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Netflix", amount: Decimal(string: "19.99")!,
                                                                           billingFrequency: .monthly, nextBillingDate: nil))
        let outcome = await TallyImporter.add([line("netflix", "15.49", anchor: day(2026, 10, 12))], into: store, defaults: defaults)

        XCTAssertEqual(outcome.alreadyListed, ["Netflix"])
        XCTAssertEqual(outcome.datesFilled, ["Netflix"])
        XCTAssertTrue(outcome.added.isEmpty)
        XCTAssertEqual(store.subscriptions.count, 1)
        let netflix = try XCTUnwrap(store.subscriptions.first)
        let filled = try XCTUnwrap(netflix.nextBillingDate)
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: filled), DateComponents(year: 2026, month: 10, day: 12))
        XCTAssertEqual(netflix.amount, Decimal(string: "19.99"), "an amount on the list is never changed by a receipt")
    }

    func testADateThePersonEnteredIsNeverReplaced() async throws {
        setPro(true)
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Netflix", amount: 15, billingFrequency: .monthly,
                                                                           nextBillingDate: day(2026, 11, 3)))
        let outcome = await TallyImporter.add([line("Netflix", "15.49", anchor: day(2026, 10, 12))], into: store, defaults: defaults)
        XCTAssertEqual(outcome.alreadyListed, ["Netflix"])
        XCTAssertTrue(outcome.datesFilled.isEmpty)
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate.map { Calendar.current.component(.day, from: $0) }, 3)
    }

    func testADateIsNotFilledWhenTheBillingPeriodDisagrees() async throws {
        setPro(true)
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Adobe", amount: 20, billingFrequency: .monthly, nextBillingDate: nil))
        let outcome = await TallyImporter.add([line("Adobe", "239.88", .yearly, anchor: day(2025, 12, 10))], into: store, defaults: defaults)
        XCTAssertEqual(outcome.alreadyListed, ["Adobe"])
        XCTAssertTrue(outcome.datesFilled.isEmpty, "a yearly charge date is not a monthly renewal date")
        XCTAssertNil(store.subscriptions.first?.nextBillingDate)
    }

    func testTheSameLineTwiceInOneImportIsAddedOnce() async {
        setPro(true)
        let outcome = await TallyImporter.add([line("Netflix", "15.49"), line("NETFLIX", "15.49")], into: store, defaults: defaults)
        XCTAssertEqual(outcome.added.count, 1)
        XCTAssertEqual(store.subscriptions.count, 1)
    }

    // MARK: From a finding to a line to a subscription

    private func proven(_ name: String, status: ProvenSubscription.Status = .active, amount: String = "15.49",
                        frequency: BillingFrequency = .monthly, lastCharge: Date? = nil, next: Date? = nil, category: String? = "Entertainment",
                        trialEnds: Date? = nil) -> ProvenSubscription {
        ProvenSubscription(id: "\(name.lowercased())|\(frequency.rawValue)|USD", name: name, merchantKey: name.lowercased(), category: category,
                           cancelURL: nil, amount: Decimal(string: amount)!, currency: "USD", frequency: frequency,
                           lastChargeDate: lastCharge, nextBillingDate: next, status: status, score: 90, tier: .confirmed,
                           evidence: [], reasons: [], previousAmount: nil, trialEndsOn: trialEnds)
    }

    func testTheAnchorIsTheLastRealChargeNotAWorkedOutDate() throws {
        let found = FoundSubscription(proven: proven("Netflix", lastCharge: day(2026, 1, 31), next: day(2026, 11, 30)))
        XCTAssertEqual(found.line.anchor, day(2026, 1, 31))

        // The schedule rolls the real date forward and keeps the 31st: stored as a worked-out
        // "Feb 28", every later renewal would have landed on the 28th.
        let subscription = found.line.subscription(now: day(2026, 2, 10))
        let march = try XCTUnwrap(subscription.nextRenewal(onOrAfter: day(2026, 3, 1)))
        XCTAssertEqual(Calendar.current.dateComponents([.month, .day], from: march), DateComponents(month: 3, day: 31))
        let february = try XCTUnwrap(subscription.nextRenewal(onOrAfter: day(2026, 2, 10)))
        XCTAssertEqual(Calendar.current.dateComponents([.month, .day], from: february), DateComponents(month: 2, day: 28))
        XCTAssertTrue(subscription.isDetected)
        XCTAssertEqual(subscription.status, .active)
    }

    func testATrialKeepsItsEndDateAndIsATrial() {
        let ends = day(2026, 11, 22)
        let found = FoundSubscription(proven: proven("Notion", status: .trial, amount: "10.00", next: ends, category: "Productivity", trialEnds: ends))
        XCTAssertNil(found.line.anchor)
        XCTAssertEqual(found.line.trialEndsAt, ends)

        let during = found.line.subscription(now: day(2026, 11, 10))
        XCTAssertEqual(during.status, .trial)
        XCTAssertEqual(during.trialEndsAt, ends)
        XCTAssertEqual(during.nextBillingDate, ends, "the first charge is the day the trial ends")

        let after = found.line.subscription(now: day(2026, 12, 1))
        XCTAssertEqual(after.status, .active, "a trial that has ended is not imported as a trial")
        XCTAssertNil(after.trialEndsAt)
    }

    func testATrialWithNoStatedPriceSaysSo() {
        let unknown = FoundSubscription(proven: proven("Notion", status: .trial, amount: "0", trialEnds: day(2026, 11, 22)))
        XCTAssertTrue(unknown.priceUnknown)
        XCTAssertFalse(FoundSubscription(proven: proven("Notion", status: .trial, amount: "10", trialEnds: day(2026, 11, 22))).priceUnknown)
        XCTAssertFalse(FoundSubscription(proven: proven("Netflix")).priceUnknown)
    }

    func testCancelledFindingsAreShownButNeverImported() async {
        setPro(true)
        let cancelled = FoundSubscription(proven: proven("Paramount+", status: .cancelled, lastCharge: day(2026, 9, 16)))
        XCTAssertTrue(cancelled.isCancelled)
        XCTAssertFalse(cancelled.isLive)
        let outcome = await InboxScanner.shared.importSubscriptions([cancelled])
        XCTAssertEqual(outcome, TallyImporter.Outcome())
        XCTAssertTrue(store.subscriptions.isEmpty)
    }

    func testAFindingKeepsItsIdentityAcrossAReanalysis() {
        let first = FoundSubscription(proven: proven("Netflix", lastCharge: day(2026, 10, 12)))
        let again = FoundSubscription(proven: proven("Netflix", lastCharge: day(2026, 11, 12)))
        XCTAssertEqual(first.id, again.id, "what was ticked stays ticked when the list is worked out again")
    }

    // MARK: Categories

    func testMerchantCategoriesBecomeTheAppsCategories() {
        XCTAssertEqual(SubscriptionCategory.matching("Entertainment"), .entertainment)
        XCTAssertEqual(SubscriptionCategory.matching("music"), .music)
        XCTAssertEqual(SubscriptionCategory.matching("Cloud Storage"), .cloudStorage)
        XCTAssertEqual(SubscriptionCategory.matching("cloudStorage"), .cloudStorage)
        XCTAssertEqual(SubscriptionCategory.matching("AI Tools"), .aiTools)
        XCTAssertEqual(SubscriptionCategory.matching("Health & Fitness"), .healthFitness)
        XCTAssertEqual(SubscriptionCategory.matching("Food & Delivery"), .food)
        XCTAssertEqual(SubscriptionCategory.matching("Utilities"), .utilities)
        XCTAssertEqual(SubscriptionCategory.matching("Gaming"), .gaming)
        XCTAssertEqual(SubscriptionCategory.matching(nil), .other)
        XCTAssertEqual(SubscriptionCategory.matching("Something else"), .other)
        XCTAssertEqual(FoundSubscription(proven: proven("ChatGPT Plus", category: "AI Tools")).line.category, "AI & Creativity")
        XCTAssertEqual(FoundSubscription(proven: proven("Corner Gym", category: nil)).line.category, "Other")
    }
}
