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

    /// A place freed on the free list goes to what was kept for later, the most expensive first, and the rest
    /// keep waiting: the place went to the next add while two waited (the rating of 2026-11-23).
    func testAFreedPlaceGoesToWhatWaitedForIt() async throws {
        for index in 1...FreeTier.subscriptionLimit {
            _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Existing \(index)", amount: 5, billingFrequency: .monthly))
        }
        await TallyImporter.add([line("Amazon Prime", "14.99"), line("Adobe", "239.88", .yearly)], into: store, defaults: defaults)
        XCTAssertEqual(Set(TallyImporter.waitingLines(defaults: defaults).map(\.name)), ["Amazon Prime", "Adobe"])

        let freed = try XCTUnwrap(store.subscriptions.first { $0.name == "Existing 1" })
        await store.deleteSubscription(id: freed.id)
        XCTAssertEqual(FreeTier.room(in: store.subscriptions), 1)
        await TallyImporter.importWaiting(into: store, defaults: defaults)

        XCTAssertTrue(store.subscriptions.contains { $0.name == "Adobe" }, "the most expensive takes the place")
        XCTAssertEqual(TallyImporter.waitingLines(defaults: defaults).map(\.name), ["Amazon Prime"], "the other keeps waiting")
        XCTAssertEqual(store.subscriptions.count, FreeTier.subscriptionLimit)
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
                        trialEnds: Date? = nil, currency: String = "USD") -> ProvenSubscription {
        ProvenSubscription(id: "\(name.lowercased())|\(frequency.rawValue)|\(currency)", name: name, merchantKey: name.lowercased(), category: category,
                           cancelURL: nil, amount: Decimal(string: amount)!, currency: currency, frequency: frequency,
                           lastChargeDate: lastCharge, nextBillingDate: next, status: status, score: 90, tier: .confirmed,
                           evidence: [], reasons: [], previousAmount: nil, trialEndsOn: trialEnds)
    }

    /// The total on the results slip: what is ticked (or everything found, with nothing ticked), each
    /// converted first. Receipts in another currency mark it "≈": a mailbox of Canadian receipts read
    /// "¥16,027" to someone who sees yen (2026-11-16). It counted rows nobody ticked (2026-11-22).
    @MainActor
    func testTheSlipAddsUpWhatIsTickedAndMarksAConvertedTotal() throws {
        let netflix = FoundSubscription(proven: proven("Netflix", currency: "CAD"))
        let spotify = FoundSubscription(proven: proven("Spotify", amount: "12.99", currency: "CAD"))
        let notion = FoundSubscription(proven: proven("Notion", amount: "10", currency: "USD"))
        let canadian = InboxImportView.slipTotal([netflix, spotify], in: "CAD", rates: .fallback)
        XCTAssertEqual(canadian.monthly, Decimal(string: "28.48"))
        XCTAssertFalse(canadian.converted)
        XCTAssertFalse(InboxImportView.slipTotal([netflix], in: "cad", rates: .fallback).converted)
        XCTAssertTrue(InboxImportView.slipTotal([netflix], in: "JPY", rates: .fallback).converted)
        XCTAssertTrue(InboxImportView.slipTotal([netflix, notion], in: "CAD", rates: .fallback).converted, "one is enough")
        XCTAssertEqual(InboxImportView.slipTotal([netflix], in: "CAD", rates: .fallback).monthly, Decimal(string: "15.49"),
                       "only what is passed: the ticked rows")

        XCTAssertEqual(MoneyFormat.total(16027, "JPY", converted: true, locale: Locale(identifier: "ja_JP")).first, "≈")
        let screen = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Pausely/Views/InboxImportView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: screen.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: screen, encoding: .utf8)
        XCTAssertTrue(source.contains("let base = picked.isEmpty ? live.filter { !isOnList($0) } : picked"))
        XCTAssertTrue(source.contains(#"ProofLine(label: L10n.string("Each month"), value: MoneyFormat.total(monthly, currency, converted: converted), emphasised: true)"#))
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

    /// "This isn't a subscription" can be undone, back to exactly what the person had said before: a tap
    /// meant for the row's box hid a real subscription for good (the rating of 2026-11-22).
    func testHidingAFindingCanBeUndoneToWhatWasSaidBefore() throws {
        let suite = "undo-hide-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let scanner = InboxScanner.shared
        let netflix = FoundSubscription(proven: proven("Netflix"))

        XCTAssertNil(scanner.markNotSubscription(netflix, defaults: defaults), "nothing was said before")
        XCTAssertEqual(UserCorrections.load(defaults: defaults)["netflix"], .notSubscription)
        scanner.undoNotSubscription(netflix, previous: nil, defaults: defaults)
        XCTAssertNil(UserCorrections.load(defaults: defaults)["netflix"], "undone, it is as if nothing was said")

        UserCorrections.set("netflix", .trusted, defaults: defaults)
        XCTAssertEqual(scanner.markNotSubscription(netflix, defaults: defaults), .trusted)
        XCTAssertEqual(UserCorrections.load(defaults: defaults)["netflix"], .notSubscription)
        scanner.undoNotSubscription(netflix, previous: .trusted, defaults: defaults)
        XCTAssertEqual(UserCorrections.load(defaults: defaults)["netflix"], .trusted, "what was said before comes back")
    }

    /// The reason is said only where there is a doubt to act on: a confirmed row, a trial (its date is the
    /// thing to check) and an ended one carry none.
    func testOnlyARowWorthALookSaysWhyItIsUnsure() {
        var unsure = proven("Fathom")
        unsure.tier = .likely
        unsure.doubt = "Two charges so far; a third would confirm it"
        XCTAssertEqual(FoundRow.doubt(for: unsure), "Two charges so far; a third would confirm it")
        var confirmed = unsure
        confirmed.tier = .confirmed
        XCTAssertNil(FoundRow.doubt(for: confirmed))
        var trial = unsure
        trial.status = .trial
        XCTAssertNil(FoundRow.doubt(for: trial))
        var ended = unsure
        ended.status = .likelyEnded
        XCTAssertNil(FoundRow.doubt(for: ended))
    }

    /// A receipt names the plan where a person types the service: "Claude Pro" is the "Claude" on the list.
    /// Only plan words may differ, so a different service by the same company is not taken for it.
    func testAPlanNameIsTheServiceOnTheList() {
        XCTAssertTrue(ServiceName.same("Claude", "Claude Pro"))
        XCTAssertTrue(ServiceName.same("chatgpt plus", "ChatGPT"))
        XCTAssertTrue(ServiceName.same("Spotify", "Spotify Premium Family"))
        XCTAssertTrue(ServiceName.same("Crème", "creme"))
        XCTAssertFalse(ServiceName.same("Apple", "Apple Music"))
        XCTAssertFalse(ServiceName.same("YouTube", "YouTube TV"))
        XCTAssertFalse(ServiceName.same("Google One", "Google Play"))
        XCTAssertFalse(ServiceName.same("Max", "Disney+"))
        let plan = PendingTally.plan(lines: [line("Claude Pro", "20"), line("Notion", "10")], existingNames: ["Claude"], freeSlots: nil)
        XCTAssertEqual(plan.add.map(\.name), ["Notion"], "the listed Claude is not added again as Claude Pro")
    }

    /// A trial whose email gave no later price says the usual one where the catalog has it in the reader's
    /// currency, or that the email doesn't say; a trial with a stated price needs neither.
    func testATrialWithNoStatedPriceSaysWhatItUsuallyCosts() {
        let netflix = FoundSubscription(proven: proven("Netflix", status: .trial, amount: "0", trialEnds: day(2026, 12, 1), currency: "CAD"))
        let usual = TallyCatalog.price(forServiceNamed: "Netflix", payingIn: "CAD")
        XCTAssertNotNil(usual, "the catalog prices Netflix in Canadian dollars")
        XCTAssertEqual(FoundRow.afterTrial(for: netflix, currency: "CAD"),
                       "Usually \(MoneyFormat.string(usual ?? 0, "CAD")) a month after the trial")
        let unknown = FoundSubscription(proven: proven("Fathom Notes", status: .trial, amount: "0", trialEnds: day(2026, 12, 1)))
        XCTAssertEqual(FoundRow.afterTrial(for: unknown, currency: "USD"), "The email doesn't say what it costs after the trial")
        let priced = FoundSubscription(proven: proven("Netflix", status: .trial, amount: "16.49", trialEnds: day(2026, 12, 1)))
        XCTAssertNil(FoundRow.afterTrial(for: priced, currency: "USD"))
    }

    /// The search says how long is left from its own pace, in whole minutes rounded up, and nothing under
    /// a minute: a first Gmail search is about six minutes on Google's quota, and the page never said so.
    func testTheSearchSaysTheMinutesLeftFromItsOwnPace() {
        XCTAssertEqual(InboxScanner.minutesLeft(done: 330, total: 2_000, elapsed: 60), 6, "1,670 left at 330 a minute")
        XCTAssertNil(InboxScanner.minutesLeft(done: 1_900, total: 2_000, elapsed: 345), "under a minute: nothing said")
        XCTAssertNil(InboxScanner.minutesLeft(done: 0, total: 2_000, elapsed: 10))
        XCTAssertNil(InboxScanner.minutesLeft(done: 2_000, total: 2_000, elapsed: 360))
    }

    /// A port typed on an Arabic keyboard is read, not silently replaced by 993; nonsense is not a port.
    func testAPortTypedInAnyDigitsIsRead() {
        XCTAssertEqual(IMAPConnectView.port("1144"), 1144)
        XCTAssertEqual(IMAPConnectView.port("١١٤٤"), 1144, "Arabic-Indic digits")
        XCTAssertEqual(IMAPConnectView.port("۹۹۳"), 993, "Eastern Arabic-Indic digits")
        XCTAssertNil(IMAPConnectView.port(""))
        XCTAssertNil(IMAPConnectView.port("99999"))
        XCTAssertNil(IMAPConnectView.port("abc"))
    }

    /// The free-limit note names what is added now and what waits, ranked as the importer ranks: by yearly
    /// cost in one currency. By raw number, ¥990 a month ranked above $34.99 (the rating of 2026-11-22).
    @MainActor
    func testTheFreeLimitSaysWhichAreAddedRankedInOneCurrency() {
        let yen = FoundSubscription(proven: proven("Disney+", amount: "990", currency: "JPY"))
        let gym = FoundSubscription(proven: proven("Ironside Fitness", amount: "34.99", currency: "USD"))
        let tv = FoundSubscription(proven: proven("Netflix", amount: "15.49", currency: "USD"))
        let split = InboxImportView.freeLimitSplit([yen, gym, tv], existing: ["Claude"], slots: 2, in: "USD", rates: .fallback)
        XCTAssertEqual(split.add, ["Ironside Fitness", "Netflix"], "¥990 is about $6.50: it waits")
        XCTAssertEqual(split.wait, ["Disney+"])
    }

    func testAFindingKeepsItsIdentityAcrossAReanalysis() {
        let first = FoundSubscription(proven: proven("Netflix", lastCharge: day(2026, 10, 12)))
        let again = FoundSubscription(proven: proven("Netflix", lastCharge: day(2026, 11, 12)))
        XCTAssertEqual(first.id, again.id, "what was ticked stays ticked when the list is worked out again")
    }

    /// A row whose "$" was only taken as a dollar keeps its tick when another dollar is chosen: the currency was
    /// in its identity, and "Change" to US Dollar unticked nine rows (the rating of 2026-11-23). A currency a
    /// receipt stated stays part of it.
    func testChoosingAnotherDollarKeepsWhatWasTicked() {
        var canadian = proven("Netflix", currency: "CAD")
        canadian.currencyAssumed = true
        var american = proven("Netflix", currency: "USD")
        american.currencyAssumed = true
        XCTAssertEqual(FoundSubscription(proven: canadian).id, FoundSubscription(proven: american).id)
        XCTAssertEqual(FoundSubscription(proven: canadian).id, "netflix|monthly|$")
        XCTAssertNotEqual(FoundSubscription(proven: proven("Netflix", currency: "CAD")).id,
                          FoundSubscription(proven: proven("Netflix", currency: "USD")).id, "a stated currency is part of it")
    }

    /// The bar's share for headers comes from how many of those checked so far looked like receipts: guessed
    /// at a quarter, a mailbox of receipts stood at 77% on "Read 1 of 111" (the rating of 2026-11-23).
    func testTheBodiesToReadAreProjectedFromTheHeadersChecked() {
        XCTAssertEqual(InboxScanner.projectedReads(wanted: 99, checked: 100, of: 112), 111)
        XCTAssertEqual(InboxScanner.projectedReads(wanted: 30, checked: 100, of: 1_500), 400, "never more than one search reads")
        XCTAssertEqual(InboxScanner.projectedReads(wanted: 10, checked: 100, of: 1_500), 150)
        XCTAssertEqual(InboxScanner.projectedReads(wanted: 0, checked: 100, of: 1_500), 1)
        XCTAssertEqual(InboxScanner.projectedReads(wanted: 0, checked: 0, of: 1_500), 375, "a quarter until a header is read")
    }

    /// What was read stays with what it found: after a relaunch the slip lost "Emails checked: 112" while the
    /// findings came back (the rating of 2026-11-23).
    @MainActor
    func testTheLastSearchIsKeptAndForgotten() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "lastSearch-\(UUID().uuidString)"))
        var stats = InboxScanner.ScanStats(emailsChecked: 112, bodiesRead: 111, receipts: 120, aiAssisted: 0, purchasesIgnored: 5, confirmed: 16)
        stats.perAccount["a"] = InboxScanner.AccountStats(candidates: 112, checked: 112, read: 111, receipts: 120, incremental: true, capped: false)
        InboxScanner.saveStats(stats, defaults: defaults)
        XCTAssertEqual(InboxScanner.savedStats(defaults: defaults), stats)
        XCTAssertTrue(InboxScanner.savedStats(defaults: defaults)?.onlyNewMail == true)
        InboxScanner.saveStats(nil, defaults: defaults)
        XCTAssertNil(InboxScanner.savedStats(defaults: defaults))
        XCTAssertTrue(LocalUserData.personalKeys.contains(InboxScanner.lastSearchKey), "signing out forgets it")
    }

    /// Under a minute an inbox was searched "just now": counted in seconds, its row grew a line and shrank
    /// again (the rating of 2026-11-23).
    @MainActor
    func testAnInboxSearchedUnderAMinuteAgoWasSearchedJustNow() {
        let now = day(2026, 11, 23)
        var account = MailboxAccount(id: "a", kind: .imap, address: "a@b.test", presetID: "icloud", host: "imap.mail.me.com",
                                     port: 993, addedAt: now)
        XCTAssertEqual(InboxAccountRow.detail(for: account, error: nil, now: now), account.providerName)
        account.lastScan = now.addingTimeInterval(-45)
        XCTAssertEqual(InboxAccountRow.detail(for: account, error: nil, now: now), "\(account.providerName) · searched just now")
        account.lastScan = now.addingTimeInterval(-600)
        XCTAssertNotEqual(InboxAccountRow.detail(for: account, error: nil, now: now), "\(account.providerName) · searched just now")
        XCTAssertEqual(InboxAccountRow.detail(for: account, error: "Your sign-in expired.", now: now), "Your sign-in expired.")
    }

    /// A subscription already listed takes what its receipts show only when asked: their price where it differs,
    /// and their last charge as its renewal day where it has none. Spotify kept "Add its renewal date" while its
    /// receipts showed every charge (the rating of 2026-11-23).
    @MainActor
    func testAListedSubscriptionCanTakeItsReceiptsPriceAndDay() {
        let spotify = FoundSubscription(proven: proven("Spotify", amount: "10.99", lastCharge: day(2026, 11, 5), currency: "EUR"))
        let undated = TestFactories.makeSubscription(name: "Spotify", amount: Decimal(string: "11.99")!, currency: "EUR", nextBillingDate: nil)
        XCTAssertTrue(FoundRow.fillsDate(undated, for: spotify))
        let both = FoundRow.updatedFromReceipts(undated, by: spotify)
        XCTAssertEqual(both.amount, Decimal(string: "10.99"))
        XCTAssertEqual(both.nextBillingDate, day(2026, 11, 5), "the last real charge is the anchor")
        XCTAssertEqual(both.id, undated.id)
        XCTAssertNotNil(FoundRow.useReceiptsLabel(undated, for: spotify))

        let dated = TestFactories.makeSubscription(name: "Spotify", amount: Decimal(string: "10.99")!, currency: "EUR",
                                                   nextBillingDate: day(2026, 12, 20))
        XCTAssertFalse(FoundRow.fillsDate(dated, for: spotify), "a day the person entered is kept")
        XCTAssertEqual(FoundRow.updatedFromReceipts(dated, by: spotify), dated, "nothing to change")
        XCTAssertNil(FoundRow.useReceiptsLabel(dated, for: spotify))

        let yearly = TestFactories.makeSubscription(name: "Spotify", amount: Decimal(string: "10.99")!, currency: "EUR",
                                                    billingFrequency: .yearly, nextBillingDate: nil)
        XCTAssertNotNil(FoundRow.listedPrice(yearly, for: spotify), "another period is another price")
        XCTAssertEqual(FoundRow.updatedFromReceipts(yearly, by: spotify).billingFrequency, .monthly)
        XCTAssertEqual(FoundRow.updatedFromReceipts(yearly, by: spotify).nextBillingDate, day(2026, 11, 5))
    }

    /// What was ticked is kept on this iPhone: a relaunch ticked eleven the person had unticked (the rating of
    /// 2026-11-23). Forgotten with the rest on sign-out.
    @MainActor
    func testTicksSurviveARelaunch() {
        let scanner = InboxScanner.shared
        let before = scanner.savedSelection
        defer { scanner.savedSelection = before }
        scanner.savedSelection = ["netflix|monthly|$", "adobe|yearly|USD"]
        XCTAssertEqual(UserDefaults.standard.array(forKey: InboxScanner.selectionKey) as? [String], ["adobe|yearly|USD", "netflix|monthly|$"])
        XCTAssertEqual(scanner.savedSelection, ["netflix|monthly|$", "adobe|yearly|USD"])
        scanner.savedSelection = []
        XCTAssertEqual(scanner.savedSelection, [], "nothing ticked is a choice too")
        scanner.savedSelection = nil
        XCTAssertNil(UserDefaults.standard.object(forKey: InboxScanner.selectionKey))
        XCTAssertTrue(LocalUserData.personalKeys.contains(InboxScanner.selectionKey))
    }

    /// A running search names an inbox by its provider, or by its address where the provider would only be a
    /// server ("Read 41 of 111 in 127.0.0.1", the rating of 2026-11-23).
    func testASearchNamesAnInboxAPersonKnows() {
        let custom = MailboxAccount(id: "a", kind: .imap, address: "me@corner.example", presetID: nil, host: "127.0.0.1", port: 1147, addedAt: Date())
        XCTAssertEqual(custom.searchName, "me@corner.example")
        let icloud = MailboxAccount(id: "b", kind: .imap, address: "me@icloud.com", presetID: "icloud", host: "imap.mail.me.com", port: 993, addedAt: Date())
        XCTAssertEqual(icloud.searchName, icloud.providerName)
        XCTAssertEqual(MailboxAccount(id: "c", kind: .gmail, address: "me@gmail.com", addedAt: Date()).searchName, "Gmail")
    }

    /// Words a subject starts with are never a sender's name: "Your" was listed among the other senders.
    func testASubjectsFirstWordIsNotAMerchant() {
        XCTAssertFalse(MerchantCatalog.isPlausibleMerchantName("Your"))
        XCTAssertFalse(MerchantCatalog.isPlausibleMerchantName("The"))
        XCTAssertFalse(MerchantCatalog.isPlausibleMerchantName("Thank you"))
        XCTAssertTrue(MerchantCatalog.isPlausibleMerchantName("City Hydro"))
        XCTAssertTrue(MerchantCatalog.isPlausibleMerchantName("The Daily Brief"))
    }

    /// "Worth knowing" draws what each fact is: a question mark on "renews in 31 days" read as a doubt.
    @MainActor
    func testWorthKnowingDrawsWhatEachFactIs() {
        XCTAssertEqual(FoundInsights.symbol(for: .renewalSoon), "calendar")
        XCTAssertEqual(FoundInsights.symbol(for: .priceIncrease), "arrow.up")
        XCTAssertEqual(FoundInsights.symbol(for: .trialEnding), "hourglass")
        XCTAssertEqual(FoundInsights.state(for: .renewalSoon), .decide, "still amber: something to decide")
        XCTAssertFalse([IntelligenceInsight.Kind.renewalSoon, .priceIncrease, .priceChangeNotice, .trialEnding]
            .map(FoundInsights.symbol(for:)).contains("questionmark"))
    }

    /// At the accessibility text sizes the first page offers the inboxes before the promise, which alone was
    /// five screens (the reach rating of 2026-11-23).
    func testAtTheLargestTextTheInboxesComeFirst() {
        XCTAssertTrue(InboxImportView.inboxesFirst(largeText: true))
        XCTAssertFalse(InboxImportView.inboxesFirst(largeText: false))
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
