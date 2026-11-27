import XCTest
@testable import Pausely

/// Regression suite pinning every P0 and P1 bug surfaced across the 5-squad full-app audit.
final class AuditRegressionTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    // MARK: - Security & Privacy (Wave 1)

    func testInfoPlistContainsNoLiveSecrets() throws {
        let url = root.appendingPathComponent("Configuration/Info.plist")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Source tree unavailable")
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(text.contains("SUPPORT_ADMIN_KEY"), "Admin key must never ship in the client binary")
        XCTAssertFalse(text.contains("psa_live_"))
        XCTAssertFalse(text.contains("sk_live_"))
        XCTAssertFalse(text.contains("service_role"))
    }

    // MARK: - Money, Verdicts & Cancellation (Wave 2)

    func testAmountTextLeadingZeroAndIndianGrouping() {
        XCTAssertEqual(AmountText.parse("0.500", currency: "USD"), Decimal(string: "0.50"))
        XCTAssertEqual(AmountText.parse("0,500", currency: "EUR"), Decimal(string: "0.50"))
        XCTAssertEqual(AmountText.parse("0.500", currency: "KWD"), Decimal(string: "0.500"))
        XCTAssertEqual(AmountText.parse("1,00,000", currency: "INR"), Decimal(string: "100000"))
        XCTAssertEqual(AmountText.parse("12,34,567.50", currency: "INR"), Decimal(string: "1234567.50"))
    }

    func testSavingsLedgerSameTimestampTieBreakingIsDeterministic() {
        let cal = Calendar.billing
        let subId = UUID()
        let day = cal.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        let next = cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 12))!
        let cancelled = LifecycleEvent(
            id: UUID(), kind: .cancelled, subscriptionId: subId, subscriptionName: "TestFlix",
            date: day, amount: Decimal(15), currency: "USD",
            frequency: .monthly, renewalDate: next
        )
        let reactivated = LifecycleEvent(
            id: UUID(), kind: .reactivated, subscriptionId: subId, subscriptionName: "TestFlix",
            date: day, amount: Decimal(15), currency: "USD",
            frequency: .monthly, renewalDate: next
        )
        let forward = SavingsLedger.lines(from: [cancelled, reactivated], now: now, calendar: cal)
        let reverse = SavingsLedger.lines(from: [reactivated, cancelled], now: now, calendar: cal)
        // Same-timestamp cancel + reactivate must close immediately (zero avoided charges, no ghost savings line)
        // regardless of input order.
        XCTAssertEqual(forward, [])
        XCTAssertEqual(reverse, [])
    }

    func testTrialVerdictWindowOpensAtLeastTwoDaysBeforeEnd() {
        let cal = Calendar.billing
        let today = cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let inTwoDays = cal.date(byAdding: .day, value: 2, to: today)!
        let trial = Subscription(
            name: "TrialApp", category: "Productivity", amount: Decimal(string: "9.99")!,
            currency: "USD", billingFrequency: .monthly, nextBillingDate: nil,
            notifyBeforeDays: 1, trialEndsAt: inTwoDays, status: .trial
        )
        let pending = RenewalDecisions.pending(in: [trial], events: [], now: today, calendar: cal)
        XCTAssertEqual(pending.count, 1, "Free trials must enter verdict window at least 2 days ahead of Apple's 24h cutoff")
    }

    @MainActor
    func testServiceMatcherPlayStoreAmazonChannelsAndCrunchyroll() {
        let googleSub = Subscription(
            name: "Spotify", category: "Music", amount: Decimal(11.99), currency: "USD",
            billingFrequency: .monthly, status: .active, paymentMethod: "Google Play"
        )
        XCTAssertEqual(CancelHelp.find(for: googleSub).kind, .googlePlay)

        let channelSub = Subscription(
            name: "Paramount+", category: "Entertainment", amount: Decimal(12.99), currency: "USD",
            billingFrequency: .monthly, status: .active, paymentMethod: "Amazon Channels"
        )
        XCTAssertEqual(CancelHelp.find(for: channelSub).kind, .amazonChannel)

        let primeSub = Subscription(
            name: "Amazon Prime", category: "Shopping", amount: Decimal(14.99), currency: "USD",
            billingFrequency: .monthly, status: .active, paymentMethod: "Amazon"
        )
        XCTAssertNotEqual(CancelHelp.find(for: primeSub).kind, .amazonChannel)

        let crunchy = CancelHelp.service(named: "Crunchyroll")
        XCTAssertEqual(crunchy?.cancelURL, "https://www.crunchyroll.com/account/membership")
    }

    func testCancelConciergeMailtoEncodingAndPrivacyAndZeroAmount() {
        let sample = CancelConcierge.Draft(subject: "Cancel A+B", body: "Line 1\nLine 2")
        let url = CancelConcierge.mailtoURL(for: sample)
        XCTAssertNotNil(url)
        let absolute = url?.absoluteString ?? ""
        XCTAssertTrue(absolute.contains("Cancel%20A%2BB"), absolute)
        XCTAssertTrue(absolute.contains("%0D%0A"), absolute)

        let trial = Subscription(
            name: "StreamCo", category: "Entertainment", amount: Decimal(string: "12.99")!,
            currency: "USD", billingFrequency: .monthly, nextBillingDate: nil,
            trialEndsAt: Date().addingTimeInterval(3 * 86_400), status: .trial
        )
        let draft = CancelConcierge.cancellationDraft(for: trial, accountEmail: "abc@privaterelay.appleid.com")
        XCTAssertFalse(draft.body.contains("privaterelay.appleid.com"))
        XCTAssertTrue(draft.body.lowercased().contains("free trial"))

        let zeroSub = TestFactories.makeSubscription(name: "ZeroPlan", amount: 0)
        let refund = CancelConcierge.refundDraft(for: zeroSub, accountEmail: nil)
        XCTAssertFalse(refund.body.contains("$0.00"))
    }

    // MARK: - Overlap, Usage & Screenshot / Email Parsing (Waves 3 & 4)

    func testOverlapDetectorWordBoundaryAndUnconvertibleCount() {
        let coffee = TestFactories.makeSubscription(name: "Medium Roast Coffee", amount: 18, category: "Food & Drink")
        let nyt = TestFactories.makeSubscription(name: "New York Times", amount: 17, category: "News")
        let overlaps = OverlapDetector.groups(in: [coffee, nyt], currency: "USD", rates: .fallback)
        XCTAssertTrue(overlaps.isEmpty, "Word 'Medium' inside 'Medium Roast Coffee' must not match Medium news")

        let a = TestFactories.makeSubscription(name: "Netflix", amount: 15, currency: "USD", category: "Entertainment")
        let b = TestFactories.makeSubscription(name: "Hulu", amount: 12, currency: "XYZ", category: "Entertainment")
        let mixed = OverlapDetector.groups(in: [a, b], currency: "USD", rates: .fallback)
        XCTAssertEqual(mixed.first?.unconvertibleCount, 1)
    }

    func testUsageFactsExactDecimalCostPerHour() {
        let sub = TestFactories.makeSubscription(name: "Music", amount: Decimal(string: "10.00")!, billingFrequency: .monthly)
        let result = UsageFacts.lines(for: [sub], minutesThisMonth: { _ in 150 }, currency: "USD", rates: .fallback)
        XCTAssertEqual(result.used.first?.costPerHour, Decimal(string: "4.00")!)
    }

    func testNordicCurrencyInferenceNeverDefaultsKrToUSD() {
        XCTAssertEqual(ReceiptTextAnalyzer.inferNordicCurrency(in: "Faktura 149 kr Norge mva"), "NOK")
        XCTAssertEqual(ReceiptTextAnalyzer.inferNordicCurrency(in: "Kvittering 99 kr. Danmark moms"), "DKK")
        XCTAssertEqual(ReceiptTextAnalyzer.inferNordicCurrency(in: "Kvitto 129 kr Sverige moms"), "SEK")
        XCTAssertNil(ReceiptTextAnalyzer.inferNordicCurrency(in: "Total 129 kr"))
    }

    func testReceiptTextAnalyzerPrioritizesRefundBeforeRenewalNotice() {
        let parsed = ReceiptTextAnalyzer.analyze(
            subject: "Your Spotify renewal receipt has been refunded",
            body: "We issued a refund of $11.99 for your Spotify Premium subscription renewal."
        )
        XCTAssertTrue(parsed.flags.refund)
        XCTAssertEqual(parsed.kind, .other, "Refunds must never classify as charges or renewals")
    }

    func testScreenshotDatesRejectsTwentyFourSevenAndOutOfRangeYears() {
        let cal = Calendar.billing
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))!
        XCTAssertNil(ScreenshotParser.extractDateInfo(in: "24/7 support included", now: now, calendar: cal).date)
        XCTAssertNil(ScreenshotParser.extractDateInfo(in: "Expires 12/31/1999", now: now, calendar: cal).date)
        XCTAssertNil(ScreenshotParser.extractDateInfo(in: "Since 2099-01-01", now: now, calendar: cal).date)
    }

    func testScreenshotParserDoesNotMarkFreeTrialExpiresAsCancelled() {
        let cal = Calendar.billing
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let obs: [ScreenshotParser.TextObservation] = [
            .init(text: "Apple TV+", boundingBox: CGRect(x: 0.1, y: 0.85, width: 0.3, height: 0.03)),
            .init(text: "$9.99/mo", boundingBox: CGRect(x: 0.7, y: 0.85, width: 0.2, height: 0.03)),
            .init(text: "Free trial expires Nov 17", boundingBox: CGRect(x: 0.1, y: 0.81, width: 0.5, height: 0.025)),
        ]
        let items = ScreenshotParser.parse(pages: [obs], defaultCurrency: "USD", now: now, calendar: cal, rates: .fallback)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.isCancelled, false)
        XCTAssertEqual(items.first?.isTrial, true)
    }

    func testScreenshotImportSupportDetectsCycleAndCurrencyUpdates() {
        let existing = TestFactories.makeSubscription(name: "Spotify", amount: 11.99, currency: "USD", billingFrequency: .monthly)
        let yearly = ScreenshotParser.DetectedItem(
            id: "spotify", name: "Spotify", category: "Music", amount: 11.99, currency: "USD",
            frequency: .yearly, renewalDate: nil, trialEndsAt: nil, isCancelled: false, paymentMethod: nil
        )
        XCTAssertTrue(ScreenshotImportSupport.canUpdatePrice(existing: existing, item: yearly))
        let eur = ScreenshotParser.DetectedItem(
            id: "spotify", name: "Spotify", category: "Music", amount: 11.99, currency: "EUR",
            frequency: .monthly, renewalDate: nil, trialEndsAt: nil, isCancelled: false, paymentMethod: nil
        )
        XCTAssertTrue(ScreenshotImportSupport.canUpdatePrice(existing: existing, item: eur))
    }

    func testReceiptLedgerAddWithStatusFailsCleanlyOnInvalidURL() {
        let badURL = URL(fileURLWithPath: "/nonexistent_dir_pausely_test/sub/ledger.json")
        let result = ReceiptLedger.addWithStatus([], to: badURL)
        XCTAssertFalse(result.saved)
    }

    func testIMAPPortValidationRejectsOutOfRangeAndParsesArabicDigits() {
        XCTAssertEqual(IMAPConnectView.port("٩٩٣"), 993)
        XCTAssertNil(IMAPConnectView.port("0"))
        XCTAssertNil(IMAPConnectView.port("70000"))
        XCTAssertNil(IMAPConnectView.port("abc"))
    }

    // MARK: - Widgets, Notifications & AppIntents (Wave 5)

    func testWidgetFeedRollsPausePlanAndSavingsAcrossMidnights() {
        let cal = Calendar.billing
        var feed = WidgetFeed()
        feed.hasChargingSubscriptions = true
        feed.onTrackText = "$180"
        feed.savingsSnapshots = [
            .init(stamp: "2026-11-10", savedSoFarText: "$0.00", savedSoFarIsZero: true),
            .init(stamp: "2026-11-15", savedSoFarText: "$15.00", savedSoFarIsZero: false),
        ]
        feed.pauseTurns = [
            .init(name: "Netflix", startStamp: "", endStamp: "2026-12-01", endText: "Dec 1", nextName: "Hulu"),
            .init(name: "Hulu", startStamp: "2026-12-01", endStamp: "2027-01-01", endText: "Jan 1", nextName: "Netflix"),
        ]

        let nov10 = cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let nov15 = cal.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 0, minute: 5))!
        let dec1 = cal.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 0, minute: 5))!

        XCTAssertTrue(feed.savings(on: nov10, calendar: cal).savedSoFarIsZero)
        XCTAssertEqual(feed.savings(on: nov15, calendar: cal).savedSoFarText, "$15.00")
        XCTAssertFalse(feed.savings(on: nov15, calendar: cal).savedSoFarIsZero)

        XCTAssertEqual(feed.activePauseTurn(on: nov15, calendar: cal)?.name, "Netflix")
        XCTAssertEqual(feed.activePauseTurn(on: dec1, calendar: cal)?.name, "Hulu")
    }

    func testReminderPlannerKeepsRotatingTrialAlertsWhenRenewalsOff() {
        let cal = Calendar.billing
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 8))!
        let trialEnd = cal.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))!
        let subA = Subscription(name: "Netflix", category: "Entertainment", amount: Decimal(15.49),
                                currency: "USD", billingFrequency: .monthly, nextBillingDate: trialEnd, status: .active)
        let subB = Subscription(name: "Hulu", category: "Entertainment", amount: Decimal(17.99),
                                currency: "USD", billingFrequency: .monthly, nextBillingDate: nil, trialEndsAt: trialEnd, status: .trial)
        let plan = PausePlan(subscriptionIds: [subA.id, subB.id], startedOn: now)
        let prefs = ReminderPlanner.Preferences(renewals: false, trials: true, savingsMilestones: false)
        let planned = ReminderPlanner.plan(for: [subA, subB], now: now, calendar: cal, preferences: prefs, pausePlan: plan)
        XCTAssertTrue(planned.contains { $0.subscriptionId == subB.id && $0.kind == .trialHeadsUp })
        XCTAssertTrue(planned.contains { $0.subscriptionId == subB.id && $0.kind == .trialEnding })
    }

    func testPausePlanRemindersHonorRemindMeOff() {
        let cal = Calendar.billing
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 8))!
        let renewal = cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!
        let subA = Subscription(name: "Netflix", category: "Entertainment", amount: Decimal(15.49),
                                currency: "USD", billingFrequency: .monthly, nextBillingDate: renewal, notifyBeforeDays: 0, status: .active)
        let subB = Subscription(name: "Hulu", category: "Entertainment", amount: Decimal(17.99),
                                currency: "USD", billingFrequency: .monthly, nextBillingDate: renewal, notifyBeforeDays: 0, status: .active)
        let plan = PausePlan(subscriptionIds: [subA.id, subB.id], startedOn: now)
        let reminders = PausePlanSchedule.reminders(plan, subscriptions: [subA, subB], now: now, calendar: cal)
        XCTAssertTrue(reminders.filter { $0.kind == .planCancel }.isEmpty, "notifyBeforeDays == 0 must silence planCancel")
    }

    func testMarkStartedNotificationActionRequiresUnlockAndForeground() {
        XCTAssertTrue(ReminderActions.markStartedOptions.contains(.authenticationRequired))
        XCTAssertTrue(ReminderActions.markStartedOptions.contains(.foreground))
    }

    func testShortcutAnswersUsesTrialWordingAndDefaultReminderDays() throws {
        let cal = Calendar.billing
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let end = cal.date(byAdding: .day, value: 3, to: now)!
        let trial = Subscription(
            name: "StreamTrial", category: "Entertainment", amount: Decimal(string: "9.99")!,
            currency: "USD", billingFrequency: .monthly, nextBillingDate: nil, trialEndsAt: end, status: .trial
        )
        let detail = ShortcutAnswers.detail(for: trial, now: now, calendar: cal, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(detail.contains("Trial ends"), detail)
        let created = try ShortcutAnswers.newSubscription(name: "Music", monthlyCost: 10.99, currency: "USD", notifyBeforeDays: 7)
        XCTAssertEqual(created.notifyBeforeDays, 7)
    }

    func testWhatsNewSheetNeverAdvertisesDisabledEmailImport() throws {
        let url = root.appendingPathComponent("Pausely/Views/Components/WhatsNewSheet.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Source tree unavailable")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(source.contains("Find in Email"), "Release What's New must not advertise disabled email import")
        XCTAssertFalse(source.lowercased().contains("search your inbox"))
    }

    func testScreenshotImportIsPriceIncreaseNormalizesCycleAndCurrency() {
        let monthly = TestFactories.makeSubscription(name: "Netflix", amount: Decimal(string: "15.49")!, currency: "USD", billingFrequency: .monthly)
        let cheaperYearly = ScreenshotParser.DetectedItem(
            id: "netflix", name: "Netflix", category: "Entertainment",
            amount: Decimal(string: "149.99")!, currency: "USD", frequency: .yearly,
            renewalDate: nil, trialEndsAt: nil, isCancelled: false, paymentMethod: nil
        )
        XCTAssertFalse(ScreenshotImportSupport.isPriceIncrease(existing: monthly, item: cheaperYearly, rates: .fallback))
        let cheaperJPY = ScreenshotParser.DetectedItem(
            id: "netflix", name: "Netflix", category: "Entertainment",
            amount: Decimal(1490), currency: "JPY", frequency: .monthly,
            renewalDate: nil, trialEndsAt: nil, isCancelled: false, paymentMethod: nil
        )
        XCTAssertFalse(ScreenshotImportSupport.isPriceIncrease(existing: monthly, item: cheaperJPY, rates: .fallback))
        let hike = ScreenshotParser.DetectedItem(
            id: "netflix", name: "Netflix", category: "Entertainment",
            amount: Decimal(string: "17.99")!, currency: "USD", frequency: .monthly,
            renewalDate: nil, trialEndsAt: nil, isCancelled: false, paymentMethod: nil
        )
        XCTAssertTrue(ScreenshotImportSupport.isPriceIncrease(existing: monthly, item: hike, rates: .fallback))
    }

    func testOverlapDetectorDetectsYearlyStreamingAndAIToolsCategory() {
        let nebula = TestFactories.makeSubscription(name: "Nebula", amount: 50, currency: "USD", billingFrequency: .yearly, category: "Entertainment")
        let dropout = TestFactories.makeSubscription(name: "Dropout", amount: 60, currency: "USD", billingFrequency: .yearly, category: "Entertainment")
        let groups = OverlapDetector.groups(in: [nebula, dropout], currency: "USD", rates: .fallback)
        XCTAssertEqual(groups.first?.cluster, .videoStreaming)

        let aiA = TestFactories.makeSubscription(name: "ToolAlpha", amount: 20, currency: "USD", category: SubscriptionCategory.aiTools.displayName)
        let aiB = TestFactories.makeSubscription(name: "ToolBeta", amount: 15, currency: "USD", category: SubscriptionCategory.aiTools.displayName)
        let aiGroups = OverlapDetector.groups(in: [aiA, aiB], currency: "USD", rates: .fallback)
        XCTAssertEqual(aiGroups.first?.cluster, .aiAssistants)
    }

    func testMIMEParserExtractsForwardedRFC822AttachmentBody() {
        let raw = """
        From: friend@example.com
        Subject: Fwd: Your Spotify receipt
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="b1"

        --b1
        Content-Type: text/plain; charset=utf-8

        See attached receipt.
        --b1
        Content-Type: message/rfc822
        Content-Disposition: attachment; filename="receipt.eml"

        From: no-reply@spotify.com
        Subject: Your Spotify Premium receipt
        Content-Type: text/plain; charset=utf-8

        Your Spotify Premium subscription renewed for $11.99/month.
        --b1--
        """.replacingOccurrences(of: "\n", with: "\r\n")
        let parsed = MIMEParser.parse(Data(raw.utf8), id: "rfc822-test", receivedDate: Date())
        XCTAssertNotNil(parsed)
        let body = parsed?.bodyText ?? ""
        XCTAssertTrue(body.contains("$11.99") || body.contains("Spotify Premium"), body)
    }
}
