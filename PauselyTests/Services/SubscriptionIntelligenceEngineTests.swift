import XCTest
@testable import Pausely

final class SubscriptionIntelligenceEngineTests: XCTestCase {

    // MARK: Fixtures

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private var now: Date { date(2026, 10, 7) }
    private let engine = SubscriptionIntelligenceEngine()
    private var counter = 0

    private func signal(_ domain: String,
                        name: String = "",
                        on day: Date,
                        amount: Decimal? = nil,
                        currency: String? = "CAD",
                        kind: EmailKind = .charge,
                        hint: String? = nil,
                        renewal: Bool = false,
                        oneTime: Bool = false,
                        promo: Bool = false,
                        platform: String = "direct",
                        cadence: BillingFrequency? = nil,
                        trialDays: Int? = nil) -> ReceiptSignal {
        counter += 1
        return ReceiptSignal(id: "m\(counter)", date: day, senderDomain: domain, senderName: name, merchantHint: hint,
                             platform: platform, kind: kind, amount: amount, currency: currency, cadenceHint: cadence,
                             trialDays: trialDays, renewalLanguage: renewal, oneTimeLanguage: oneTime, promotional: promo)
    }

    private func analyze(_ signals: [ReceiptSignal]) -> IntelligenceReport {
        engine.analyze(signals: signals, now: now, calendar: calendar, defaultCurrency: "CAD")
    }

    private func monthly(_ domain: String, name: String = "", amount: Decimal, months: [(Int, Int)], hint: String? = nil,
                         renewal: Bool = true, year: Int = 2026) -> [ReceiptSignal] {
        months.map { signal(domain, name: name, on: date(year, $0.0, $0.1), amount: amount, hint: hint, renewal: renewal) }
    }

    // MARK: True positives

    func testNetflixMonthly_isConfirmedWithEvidence() {
        let report = analyze(monthly("netflix.com", name: "Netflix", amount: 14.99, months: [(6, 12), (7, 12), (8, 12), (9, 12)]))
        let sub = report.subscriptions.first { $0.name == "Netflix" }
        XCTAssertNotNil(sub)
        XCTAssertEqual(sub?.tier, .confirmed)
        XCTAssertEqual(sub?.frequency, .monthly)
        XCTAssertEqual(sub?.evidence.count, 4)
        XCTAssertEqual(sub?.status, .active)
        XCTAssertEqual(sub.flatMap { calendar.component(.day, from: $0.nextBillingDate ?? now) }, 12)
        XCTAssertFalse(sub?.reasons.isEmpty ?? true)
    }

    func testUnknownMerchantWithThreeSteadyCharges_isDetected() {
        let report = analyze(monthly("brightgym.ca", name: "Bright Gym", amount: 29.99, months: [(7, 3), (8, 3), (9, 3)]))
        let sub = report.subscriptions.first { $0.name == "Bright Gym" }
        XCTAssertNotNil(sub)
        XCTAssertGreaterThanOrEqual(sub?.tier ?? .hidden, .likely)
    }

    func testYearlyPlan_isDetectedAndFlaggedWhenRenewalIsNear() {
        let signals = [
            signal("adobe.com", name: "Adobe", on: date(2024, 10, 20), amount: 779.88, renewal: true),
            signal("adobe.com", name: "Adobe", on: date(2025, 10, 20), amount: 779.88, renewal: true)
        ]
        let report = analyze(signals)
        let sub = report.subscriptions.first { $0.name.contains("Adobe") }
        XCTAssertEqual(sub?.frequency, .yearly)
        XCTAssertTrue(report.insights.contains { $0.kind == .renewalSoon })
    }

    func testPriceIncrease_isDetectedWithAnnualImpact() {
        var signals = monthly("spotify.com", name: "Spotify", amount: 10.99, months: [(6, 5), (7, 5), (8, 5)])
        signals.append(signal("spotify.com", name: "Spotify", on: date(2026, 9, 5), amount: 11.99, renewal: true))
        let report = analyze(signals)
        let sub = report.subscriptions.first { $0.name == "Spotify" }
        XCTAssertEqual(sub?.status, .priceIncreased)
        let insight = report.insights.first { $0.kind == .priceIncrease }
        XCTAssertEqual(insight?.annualImpact, 12)
    }

    func testFreeTrial_isCaughtBeforeFirstCharge() {
        let signals = [signal("notion.so", name: "Notion", on: date(2026, 10, 5), kind: .trialStarted, renewal: true, trialDays: 7)]
        let report = analyze(signals)
        let sub = report.subscriptions.first { $0.name == "Notion" }
        XCTAssertEqual(sub?.status, .trial)
        XCTAssertTrue(report.insights.contains { $0.kind == .trialEnding })
    }

    func testAmazonPrimeViaProductHint_isDetected() {
        let report = analyze(monthly("amazon.ca", name: "Amazon.ca", amount: 9.99, months: [(7, 9), (8, 9), (9, 9)], hint: "Amazon Prime"))
        XCTAssertNotNil(report.subscriptions.first { $0.name == "Amazon Prime" })
    }

    func testAppleSubscriptionSingleReceipt_isLikely() {
        let s = signal("apple.com", name: "Apple", on: date(2026, 9, 20), amount: 12.99, hint: "Apple Music", renewal: true, platform: "apple", cadence: .monthly)
        let sub = analyze([s]).subscriptions.first { $0.name == "Apple Music" }
        XCTAssertNotNil(sub)
        XCTAssertGreaterThanOrEqual(sub?.tier ?? .hidden, .likely)
    }

    // MARK: Junk from the real demo — all of it must be rejected

    func testOneTimeTicketPurchase_isNotASubscription() {
        let s = signal("frontgatetickets.com", name: "Frontgate Tickets", on: date(2026, 9, 1), amount: 394.99, oneTime: true)
        XCTAssertTrue(analyze([s]).subscriptions.isEmpty)
    }

    func testDateFragmentSender_isRejected() {
        let s = signal("sendgrid.net", name: "Dec 26", on: date(2026, 8, 3), amount: 134.99, renewal: true)
        XCTAssertTrue(analyze([s]).subscriptions.isEmpty)
    }

    func testGenericSenderNames_areRejected() {
        let payments = signal("sendgrid.net", name: "Payments", on: date(2026, 9, 1), amount: 40.00)
        let account = signal("mailer.net", name: "Account", on: date(2026, 9, 2), amount: 59.99)
        let em = signal("mailgun.org", name: "Em", on: date(2026, 9, 3), amount: 34.00)
        XCTAssertTrue(analyze([payments, account, em]).subscriptions.isEmpty)
    }

    func testDeliveryOrdersFromMixedMerchant_areNotSubscriptions() {
        let amounts: [Decimal] = [33.83, 21.50, 48.04, 12.90, 27.30]
        let orders = amounts.enumerated().map { signal("doordash.com", name: "DoorDash", on: date(2026, 5 + $0.offset, 9), amount: $0.element, oneTime: true) }
        XCTAssertTrue(analyze(orders).subscriptions.isEmpty)
    }

    func testDoorDashOrdersDoNotHideARealDashPass() {
        var signals = (0..<4).map { signal("doordash.com", name: "DoorDash", on: date(2026, 6 + $0 % 3, 20 + $0), amount: Decimal(20 + $0 * 7), oneTime: true) }
        signals += monthly("doordash.com", name: "DoorDash", amount: 9.99, months: [(7, 2), (8, 2), (9, 2)], hint: "DashPass")
        let report = analyze(signals)
        XCTAssertNotNil(report.subscriptions.first { $0.name == "DashPass" })
        XCTAssertNil(report.subscriptions.first { $0.name == "DoorDash" })
    }

    func testSingleUnknownSmallCharge_isIgnored() {
        let s = signal("honk.com", name: "Honkmobile", on: date(2026, 9, 14), amount: 5.35)
        XCTAssertTrue(analyze([s]).subscriptions.isEmpty)
    }

    func testPromotionalEmails_neverCreateSubscriptions() {
        let promo = signal("netflix.com", name: "Netflix", on: date(2026, 9, 1), amount: 5.99, renewal: true, promo: true)
        XCTAssertTrue(analyze([promo]).subscriptions.isEmpty)
    }

    func testVariableAmountsFromUnknownMerchant_areNotASubscription() {
        let signals = [signal("shopx.com", name: "ShopX", on: date(2026, 7, 4), amount: 12.50),
                       signal("shopx.com", name: "ShopX", on: date(2026, 8, 5), amount: 88.10),
                       signal("shopx.com", name: "ShopX", on: date(2026, 9, 4), amount: 41.75)]
        XCTAssertTrue(analyze(signals).subscriptions.filter { $0.tier >= .likely }.isEmpty)
    }

    // MARK: Lifecycle

    func testLapsedSubscription_isMarkedLikelyEnded_andNotPreselected() {
        let report = analyze(monthly("hulu.com", name: "Hulu", amount: 11.99, months: [(1, 8), (2, 8), (3, 8)]))
        let sub = report.subscriptions.first { $0.name == "Hulu" }
        XCTAssertEqual(sub?.status, .likelyEnded)
        XCTAssertNotEqual(sub?.tier, .confirmed)
        XCTAssertNil(sub?.nextBillingDate)
    }

    func testChargeAfterCancellation_isFlagged() {
        var signals = monthly("netflix.com", name: "Netflix", amount: 14.99, months: [(6, 12), (7, 12), (8, 12)])
        signals.append(signal("netflix.com", name: "Netflix", on: date(2026, 8, 20), kind: .cancellation))
        signals.append(signal("netflix.com", name: "Netflix", on: date(2026, 9, 12), amount: 14.99, renewal: true))
        let report = analyze(signals)
        XCTAssertTrue(report.insights.contains { $0.kind == .chargedAfterCancel })
    }

    func testDuplicateMessageIds_areCountedOnce() {
        let one = signal("netflix.com", name: "Netflix", on: date(2026, 9, 12), amount: 14.99, renewal: true)
        let report = analyze([one, one, one])
        XCTAssertEqual(report.subscriptions.first { $0.name == "Netflix" }?.evidence.count, 1)
    }

    func testTotalsOnlyCountLikelyOrBetter() {
        var signals = monthly("netflix.com", name: "Netflix", amount: 14.99, months: [(6, 12), (7, 12), (8, 12), (9, 12)])
        signals.append(signal("honk.com", name: "Honkmobile", on: date(2026, 9, 14), amount: 500))
        XCTAssertEqual(analyze(signals).monthlyTotal, 14.99)
    }

    // MARK: Text analyzer

    func testAmountExtraction_prefersChargedAmountOverMarketingFigures() {
        let body = "Order summary\nSubtotal $394.99\nSave $20 with code\nStarting at $4.99 for Plus\nTotal charged: $14.99 per month"
        let money = ReceiptTextAnalyzer.extractChargeAmount(subject: "Your receipt", body: body)
        XCTAssertEqual(money?.amount, 14.99)
    }

    func testAmountExtraction_readsCurrencyCodes() {
        XCTAssertEqual(ReceiptTextAnalyzer.extractChargeAmount(subject: "", body: "You were charged C$12.50")?.currency, "CAD")
        XCTAssertEqual(ReceiptTextAnalyzer.extractChargeAmount(subject: "", body: "Amount paid 9.99 EUR")?.currency, "EUR")
    }

    func testAmountExtraction_ignoresPurePromotions() {
        XCTAssertNil(ReceiptTextAnalyzer.extractChargeAmount(subject: "Sale", body: "Save $5 on your first order. Up to $20 off"))
    }

    func testOneTimeLanguage_isRecognized() {
        let flags = ReceiptTextAnalyzer.languageFlags(subject: "Your order has shipped", body: "Order #12345, tracking number 1Z999", promotional: false)
        XCTAssertTrue(flags.oneTime)
        XCTAssertFalse(flags.renewal)
    }

    func testRenewalAndTrialLanguage_areRecognized() {
        let flags = ReceiptTextAnalyzer.languageFlags(subject: "Your trial ends in 3 days", body: "Your subscription will renew automatically", promotional: false)
        XCTAssertTrue(flags.renewal)
        XCTAssertTrue(flags.trialEnding)
        XCTAssertEqual(ReceiptTextAnalyzer.extractTrialDays("Enjoy your 14-day free trial"), 14)
    }

    func testProductHint_findsMembershipInsideBigBrands() {
        XCTAssertEqual(ReceiptTextAnalyzer.productHint(subject: "Your Amazon Prime membership", body: ""), "Amazon Prime")
        XCTAssertEqual(ReceiptTextAnalyzer.productHint(subject: "Receipt", body: "DashPass monthly fee"), "DashPass")
    }
}
