import XCTest
@testable import Pausely

/// Verifies Slice 5 & Slice 6 everyday features: split-cost math, notes/payment method sync,
/// Cancel Concierge email drafts, community cancellation difficulty formatting, overlap detection,
/// and store-billed cancellation routing (T11).
@MainActor
final class EverydayPowerTests: XCTestCase {

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.billing.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    // MARK: - Split Cost, Notes & Billed-To

    func testSplitCostComputesPersonalShareAcrossMathAndHorizon() {
        let family = Subscription(
            name: "Spotify Family",
            category: "Music",
            amount: Decimal(string: "19.99")!,
            currency: "USD",
            billingFrequency: .monthly,
            nextBillingDate: day(2026, 12, 10),
            notes: "Shared with Alex and Sam",
            paymentMethod: "Apple",
            splitCount: 4
        )

        // 19.99 / 4 = 4.9975: one charge's share is shown as 5.00, and totals use the exact share, so a year is
        // 59.97 (a quarter of 239.88), not 12 × 5.00 (the rating of 2026-11-23).
        XCTAssertEqual(family.effectiveAmount, Decimal(string: "5.00"))
        XCTAssertEqual(family.monthlyCost, Decimal(string: "4.9975"))
        XCTAssertEqual(family.annualCost, Decimal(string: "59.97"))
        XCTAssertEqual(family.splitCount, 4)

        let charges = Horizon.charges(for: [family], now: day(2026, 12, 1))
        XCTAssertEqual(charges.count, 1)
        XCTAssertEqual(charges.first?.amount, Decimal(string: "5.00"))

        let event = LifecycleEvent(kind: .cancelled, subscription: family, date: day(2026, 12, 1))
        XCTAssertEqual(event.amount, Decimal(string: "4.9975"), "the exact share, so the receipt's year is the page's")
    }

    func testSplitCountClampsToValidRangeAndBackwardsDecodesLegacyJSON() throws {
        let clampedLow = Subscription(name: "Solo", category: "Other", amount: 10, currency: "USD",
                                      billingFrequency: .monthly, splitCount: 0)
        XCTAssertEqual(clampedLow.splitCount, 1)
        XCTAssertEqual(clampedLow.effectiveAmount, 10)

        let clampedHigh = Subscription(name: "Team", category: "Other", amount: 100, currency: "USD",
                                       billingFrequency: .monthly, splitCount: 99)
        XCTAssertEqual(clampedHigh.splitCount, 20)
        XCTAssertEqual(clampedHigh.effectiveAmount, 5)

        // Legacy cached JSON without notes / paymentMethod / splitCount must decode cleanly as splitCount = 1.
        let legacyJSON = """
        {"id":"11111111-1111-1111-1111-111111111111","name":"Netflix","category":"Entertainment",
         "amount":15.49,"currency":"USD","billingFrequency":"monthly","status":"active",
         "createdAt":0,"notifyBeforeDays":3}
        """
        let decoded = try JSONDecoder().decode(Subscription.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.splitCount, 1)
        XCTAssertNil(decoded.notes)
        XCTAssertNil(decoded.paymentMethod)
        XCTAssertEqual(decoded.effectiveAmount, Decimal(string: "15.49"))
    }

    func testEditDraftTracksAndAppliesSplitNotesAndPaymentMethod() {
        let original = Subscription(name: "YouTube Premium", category: "Entertainment",
                                    amount: Decimal(string: "22.99")!, currency: "USD",
                                    billingFrequency: .monthly)
        var draft = SubscriptionEditDraft(from: original)
        XCTAssertFalse(draft.isDirty(comparedTo: original))

        draft.splitCount = 2
        draft.paymentMethod = "  Apple  "
        draft.notes = "  Family plan with Sam  "
        XCTAssertTrue(draft.isDirty(comparedTo: original))
        // Half of 22.99 a month for a year: 137.94, the exact share as on the subscription's page (2026-11-23).
        XCTAssertEqual(draft.yearlyCost, Decimal(string: "137.94"))

        let updated = draft.applied(to: original)
        XCTAssertEqual(updated?.splitCount, 2)
        XCTAssertEqual(updated?.paymentMethod, "Apple")
        XCTAssertEqual(updated?.notes, "Family plan with Sam")

        // Clearing whitespace-only values normalizes back to nil.
        var clearing = SubscriptionEditDraft(from: updated!)
        clearing.paymentMethod = "   "
        clearing.notes = "\n"
        XCTAssertTrue(clearing.isDirty(comparedTo: updated!))
        XCTAssertNil(clearing.applied(to: updated!)?.paymentMethod)
        XCTAssertNil(clearing.applied(to: updated!)?.notes)
    }

    // MARK: - Cancel Concierge (Email & Refund Drafter)

    func testCancelConciergeDraftsIncludePlanDateAccountEmailAndMailtoURL() {
        let saved = UserDefaults.standard.object(forKey: L10n.languageKey)
        defer { UserDefaults.standard.set(saved, forKey: L10n.languageKey) }
        UserDefaults.standard.set("en", forKey: L10n.languageKey)

        let sub = Subscription(name: "Adobe Creative Cloud", category: "Productivity",
                               amount: Decimal(string: "59.99")!, currency: "USD",
                               billingFrequency: .monthly, nextBillingDate: day(2026, 12, 20),
                               paymentMethod: "Visa ···4242")
        let cancel = CancelConcierge.cancellationDraft(
            for: sub,
            accountEmail: "alex@example.com",
            now: day(2026, 12, 1),
            locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(cancel.subject.contains("Adobe Creative Cloud"))
        XCTAssertTrue(cancel.body.contains("Adobe Creative Cloud"))
        XCTAssertTrue(cancel.body.contains("59.99"))
        XCTAssertTrue(cancel.body.contains("alex@example.com"))
        XCTAssertTrue(cancel.body.contains("Visa ···4242"))
        XCTAssertTrue(cancel.body.contains("Dec"))

        let mailto = CancelConcierge.mailtoURL(for: cancel)
        XCTAssertEqual(mailto?.scheme, "mailto")
        XCTAssertEqual(mailto?.absoluteString.contains("subject="), true)

        let refund = CancelConcierge.refundDraft(for: sub, accountEmail: "alex@example.com", locale: Locale(identifier: "en_US"))
        XCTAssertTrue(refund.subject.contains("Adobe Creative Cloud"))
        XCTAssertTrue(refund.body.contains("59.99"))
        XCTAssertTrue(refund.body.contains("refund"))
        XCTAssertNotNil(CancelConcierge.appleRefundURL)

        let trialSub = Subscription(name: "Headspace", category: "Health & Fitness",
                                    amount: Decimal(string: "69.99")!, currency: "USD",
                                    billingFrequency: .yearly, status: .trial)
        let trialRefund = CancelConcierge.refundDraft(for: trialSub, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(trialRefund.body.contains("free trial"))
    }

    // MARK: - Community Cancellation Difficulty Ratings

    func testCancelDifficultySummaryRespectsThresholdBandsAndPostgresWireKeys() throws {
        let saved = UserDefaults.standard.object(forKey: L10n.languageKey)
        defer { UserDefaults.standard.set(saved, forKey: L10n.languageKey) }
        UserDefaults.standard.set("en", forKey: L10n.languageKey)

        // Verify wire contract matches `public.service_difficulty_scores` and `public.cancel_difficulty_ratings`.
        let serverRow = Data(#"{"service_name":"Netflix","rating_count":12,"avg_difficulty":4.4}"#.utf8)
        let decoded = try JSONDecoder().decode(CancelDifficultyService.Score.self, from: serverRow)
        XCTAssertEqual(decoded.serviceName, "Netflix")
        XCTAssertEqual(decoded.ratingCount, 12)
        XCTAssertEqual(decoded.avgDifficulty, 4.4, accuracy: 0.001)

        let insertData = try JSONEncoder().encode(
            CancelDifficultyService.RatingInsert(user_id: UUID(), service_name: "netflix", difficulty_rating: 4)
        )
        let insertJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: insertData) as? [String: Any])
        XCTAssertEqual(Set(insertJSON.keys), ["user_id", "service_name", "difficulty_rating"])

        let tooFew = CancelDifficultyService.Score(serviceName: "adobe", ratingCount: 2, avgDifficulty: 4.8)
        XCTAssertNil(CancelDifficultyService.summaryLine(for: tooFew, locale: Locale(identifier: "en_US")))

        let hard = CancelDifficultyService.Score(serviceName: "adobe", ratingCount: 12, avgDifficulty: 4.4)
        let hardLine = CancelDifficultyService.summaryLine(for: hard, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(hardLine?.contains("4.4"), true)
        XCTAssertEqual(hardLine?.contains("12"), true)
        XCTAssertEqual(hardLine?.contains("hard"), true)

        let easy = CancelDifficultyService.Score(serviceName: "netflix", ratingCount: 25, avgDifficulty: 1.4)
        let easyLine = CancelDifficultyService.summaryLine(for: easy, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(easyLine?.contains("quick"), true)

        let moderate = CancelDifficultyService.Score(serviceName: "nytimes", ratingCount: 8, avgDifficulty: 2.9)
        let moderateLine = CancelDifficultyService.summaryLine(for: moderate, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(moderateLine?.contains("Moderate"), true)
    }

    func testPriceHistoryTracksSharedSubscriptionsOnEffectiveAmountBasis() {
        var sub = Subscription(name: "Netflix", category: "Entertainment",
                               amount: Decimal(string: "20.00")!, currency: "USD",
                               billingFrequency: .monthly, splitCount: 2)
        let added = LifecycleEvent(kind: .added, subscription: sub, date: day(2026, 8, 1))
        sub.amount = Decimal(string: "24.00")!
        let hiked = LifecycleEvent(kind: .priceChanged, subscription: sub, date: day(2026, 11, 1),
                                   previousAmount: Decimal(string: "10.00")!)
        let change = PriceHistory.latestChange(for: sub, events: [added, hiked])
        XCTAssertEqual(change?.from, Decimal(string: "10.00"))
        XCTAssertEqual(change?.to, Decimal(string: "12.00"))
        XCTAssertEqual(change?.isIncrease, true)
    }

    // MARK: - Overlap Detector

    func testOverlapDetectorFindsRealClustersRejectsFalsePositivesAndBreaksTiesDeterministically() {
        let list = [
            Subscription(name: "Netflix", category: "Entertainment", amount: Decimal(string: "15.49")!, currency: "USD", billingFrequency: .monthly),
            Subscription(name: "Hulu", category: "Entertainment", amount: Decimal(string: "18.99")!, currency: "USD", billingFrequency: .monthly),
            Subscription(name: "Disney+", category: "Entertainment", amount: Decimal(string: "13.99")!, currency: "USD", billingFrequency: .monthly, status: .cancelled),
            Subscription(name: "ChatGPT Plus", category: "Productivity", amount: Decimal(string: "20.00")!, currency: "USD", billingFrequency: .monthly),
            Subscription(name: "Claude Pro", category: "Productivity", amount: Decimal(string: "20.00")!, currency: "USD", billingFrequency: .monthly),
            Subscription(name: "Spotify", category: "Music", amount: Decimal(string: "11.99")!, currency: "USD", billingFrequency: .monthly),
            Subscription(name: "Pausely Pro", category: "Productivity", amount: Decimal(string: "4.99")!, currency: "USD", billingFrequency: .monthly),
            Subscription(name: "Mystery Box", category: "Shopping", amount: Decimal(string: "30.00")!, currency: "USD", billingFrequency: .monthly),
            Subscription(name: "Gym Max", category: "Other", amount: Decimal(string: "45.00")!, currency: "USD", billingFrequency: .monthly),
        ]

        XCTAssertNil(OverlapDetector.cluster(for: Subscription(name: "Mystery Box", category: "Shopping", amount: 30, currency: "USD")))
        XCTAssertNil(OverlapDetector.cluster(for: Subscription(name: "Gym Max", category: "Other", amount: 45, currency: "USD")))
        XCTAssertNil(OverlapDetector.cluster(for: Subscription(name: "Acorns Personal", category: "Finance", amount: 3, currency: "USD")))
        XCTAssertFalse(PausePlanSchedule.isEligible(Subscription(name: "Acorns Personal", category: "Finance", amount: 3, currency: "USD")))
        XCTAssertNil(OverlapDetector.cluster(for: Subscription(name: "Rent the Runway", category: "Shopping", amount: 94, currency: "USD")))
        XCTAssertEqual(OverlapDetector.cluster(for: Subscription(name: "Runway", category: "AI & Creativity", amount: 15, currency: "USD")), .aiAssistants)
        XCTAssertEqual(OverlapDetector.cluster(for: Subscription(name: "RunwayML", category: "AI & Creativity", amount: 15, currency: "USD")), .aiAssistants)
        XCTAssertEqual(OverlapDetector.cluster(for: Subscription(name: "Acorn TV", category: "Entertainment", amount: 8, currency: "USD")), .videoStreaming)
        XCTAssertEqual(OverlapDetector.cluster(for: Subscription(name: "Max", category: "Entertainment", amount: 16, currency: "USD")), .videoStreaming)
        XCTAssertEqual(OverlapDetector.cluster(for: Subscription(name: "Box", category: "Cloud Storage", amount: 10, currency: "USD")), .cloudStorage)

        let groups = OverlapDetector.groups(in: list, currency: "USD", rates: .fallback)
        XCTAssertEqual(groups.map(\.cluster), [.aiAssistants, .videoStreaming])

        let ai = groups[0]
        XCTAssertEqual(ai.subscriptions.count, 2)
        XCTAssertEqual(ai.monthlyTotal, Decimal(string: "40.00"))
        XCTAssertEqual(ai.annualTotal, Decimal(string: "480.00"))

        let video = groups[1]
        XCTAssertEqual(video.subscriptions.map(\.name), ["Hulu", "Netflix"], "cancelled Disney+ excluded; ordered by cost")
        XCTAssertEqual(video.monthlyTotal, Decimal(string: "34.48"))
    }

    // MARK: - T11 Store-Billed Cancellation Routing

    func testStoreBilledPaymentMethodRoutesToStoreCancellationInsteadOfServiceSite() {
        // Netflix normally routes to netflix.com/cancelplan, but when billed through Apple/Amazon/Google Play,
        // CancelHelp must route to the billing store instead.
        let appleNetflix = Subscription(name: "Netflix", category: "Entertainment", amount: 15.49, currency: "USD",
                                        billingFrequency: .monthly, paymentMethod: "Apple")
        let appleHelp = CancelHelp.find(for: appleNetflix)
        XCTAssertEqual(appleHelp.kind, .appleSubscription)
        XCTAssertEqual(appleHelp.link, CancelHelp.applesSubscriptions)

        let primeCrunchyroll = Subscription(name: "Crunchyroll", category: "Entertainment", amount: 9.99, currency: "USD",
                                            billingFrequency: .monthly, paymentMethod: "Amazon Prime Video")
        let amazonHelp = CancelHelp.find(for: primeCrunchyroll)
        XCTAssertEqual(amazonHelp.kind, .cancellationPage)
        XCTAssertEqual(amazonHelp.link?.absoluteString, "https://www.amazon.com/gp/video/settings/channels")

        let googleSpotify = Subscription(name: "Spotify", category: "Music", amount: 11.99, currency: "USD",
                                         billingFrequency: .monthly, paymentMethod: "Google Play")
        let googleHelp = CancelHelp.find(for: googleSpotify)
        XCTAssertEqual(googleHelp.kind, .cancellationPage)
        XCTAssertEqual(googleHelp.link?.absoluteString, "https://play.google.com/store/account/subscriptions")
    }

    func testIntelligenceEngineTagsStoreBilledSubscriptionsWithStoreBillerAndCancelLink() {
        let engine = SubscriptionIntelligenceEngine(catalog: .builtin)
        let s1 = ReceiptSignal(
            id: "a1", date: day(2026, 9, 5), senderDomain: "email.apple.com", senderName: "Apple",
            merchantHint: "Crunchyroll", platform: "apple", kind: .charge,
            amount: Decimal(string: "9.99")!, currency: "USD",
            cadenceHint: .monthly, trialDays: nil, renewalLanguage: true, oneTimeLanguage: false,
            promotional: false
        )
        let s2 = ReceiptSignal(
            id: "a2", date: day(2026, 10, 5), senderDomain: "email.apple.com", senderName: "Apple",
            merchantHint: "Crunchyroll", platform: "apple", kind: .charge,
            amount: Decimal(string: "9.99")!, currency: "USD",
            cadenceHint: .monthly, trialDays: nil, renewalLanguage: true, oneTimeLanguage: false,
            promotional: false
        )
        let report = engine.analyze(signals: [s1, s2], now: day(2026, 10, 20), defaultCurrency: "USD")
        let sub = report.subscriptions.first { $0.name.localizedCaseInsensitiveContains("Crunchyroll") }
        XCTAssertEqual(sub?.billedThrough, "Apple")
        XCTAssertEqual(sub?.cancelURL, "https://apps.apple.com/account/subscriptions")

        // T11 must also tag store-billed free trials.
        let trialSignal = ReceiptSignal(
            id: "t1", date: day(2026, 11, 20), senderDomain: "email.apple.com", senderName: "Apple",
            merchantHint: "Headspace", platform: "apple", kind: .trialStarted,
            amount: Decimal(string: "69.99")!, currency: "USD",
            cadenceHint: .yearly, trialDays: 7, renewalLanguage: true, oneTimeLanguage: false,
            promotional: false
        )
        let trialReport = engine.analyze(signals: [trialSignal], now: day(2026, 11, 22), defaultCurrency: "USD")
        let trial = trialReport.subscriptions.first { $0.name.localizedCaseInsensitiveContains("Headspace") }
        XCTAssertEqual(trial?.billedThrough, "Apple")
        XCTAssertEqual(trial?.cancelURL, "https://apps.apple.com/account/subscriptions")
    }

    // MARK: - Two-Phase Gmail First-Time Quick Pass

    @MainActor
    func testGmailFirstTimeQuickPassReads90DayBodiesBeforeTwoYearSummaries() async throws {
        @MainActor
        final class RecordingGmailProvider: MailboxProvider {
            let account: MailboxAccount
            var events: [String] = []
            var candidateCallCount = 0

            init(account: MailboxAccount) { self.account = account }

            func open() async throws {}
            func close() async {}
            func revoke() async {}

            func candidates(plan: InboxSearchPlan, cursor: String?) async throws -> (refs: [MessageRef], cursor: String?) {
                candidateCallCount += 1
                if candidateCallCount == 1 {
                    events.append("candidates:recent")
                    return ([MessageRef(id: "recent-1")], "cursor-1")
                } else {
                    events.append("candidates:full")
                    return ([MessageRef(id: "recent-1"), MessageRef(id: "older-1")], "cursor-2")
                }
            }

            func summaries(_ refs: [MessageRef]) async throws -> [MessageSummary] {
                for ref in refs { events.append("summaries:\(ref.id)") }
                let now = Date()
                return refs.map { ref in
                    MessageSummary(
                        ref: ref,
                        from: "info@account.netflix.com",
                        subject: "Your Netflix receipt",
                        snippet: "Total $15.49",
                        receivedDate: ref.id == "recent-1"
                            ? now.addingTimeInterval(-10 * 86_400)
                            : now.addingTimeInterval(-200 * 86_400)
                    )
                }
            }

            func rawMessage(_ ref: MessageRef) async throws -> Data? {
                events.append("raw:\(ref.id)")
                let mime = """
                From: Netflix <info@account.netflix.com>
                Subject: Your Netflix receipt
                Content-Type: text/plain; charset=utf-8

                Your monthly Netflix subscription renewed for $15.49.
                """
                return Data(mime.utf8)
            }
        }

        let account = MailboxAccount(
            id: "test-gmail-quickpass-\(UUID().uuidString)",
            kind: .gmail,
            address: "alex@gmail.com",
            presetID: nil,
            host: nil,
            port: nil,
            addedAt: Date()
        )
        let provider = RecordingGmailProvider(account: account)
        let scanner = InboxScanner.shared
        defer {
            MailboxAccountStore.remove(account.id)
        }

        var aiBudget = 0
        let (signals, stats) = try await scanner.scan(
            account,
            provider: provider,
            catalog: .builtin,
            aiBudget: &aiBudget
        ) { _, _ in }

        guard let recentRawIndex = provider.events.firstIndex(of: "raw:recent-1"),
              let fullCandidatesIndex = provider.events.firstIndex(of: "candidates:full"),
              let olderSummaryIndex = provider.events.firstIndex(of: "summaries:older-1"),
              let olderRawIndex = provider.events.firstIndex(of: "raw:older-1") else {
            return XCTFail("Missing expected two-phase scan events: \(provider.events)")
        }

        XCTAssertLessThan(recentRawIndex, fullCandidatesIndex, "90-day receipts must be read before the 2-year history search runs")
        XCTAssertLessThan(recentRawIndex, olderSummaryIndex, "90-day receipts must be read before 2-year summaries are fetched")
        XCTAssertLessThan(olderSummaryIndex, olderRawIndex)
        XCTAssertEqual(provider.events.filter { $0 == "raw:recent-1" }.count, 1, "Recent receipt must not be fetched twice in Phase 2")
        XCTAssertEqual(stats.read, 2)
        XCTAssertFalse(signals.isEmpty)
    }
}
