import XCTest
@testable import Pausely

/// Shapes taken from real inboxes during testing (rewritten with made-up details): each one was mis-read
/// before, and each test pins the fix.
final class RealWorldReceiptShapesTests: XCTestCase {

    private let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private var counter = 0

    private func email(_ date: Date, from: String, subject: String, text: String) -> RawEmail {
        counter += 1
        return RawEmail(id: "shape\(counter)", date: date, from: from, subject: subject, bodyText: text, bodyHTML: nil,
                        headers: [:], labelIds: [])
    }

    private func analyze(_ emails: [RawEmail], now: Date) -> IntelligenceReport {
        let signals = emails.compactMap { EmailSignalExtractor.extract($0)?.signal }
        return SubscriptionIntelligenceEngine().analyze(signals: signals, now: now, calendar: utc, defaultCurrency: "CAD")
    }

    // MARK: Stripe-style SaaS invoices: "Qty 1" plus a service period

    private func saasReceipt(_ month: Int) -> RawEmail {
        let start = ["", "", "", "", "", "", "", "Jul", "Aug", "Sep", "Oct"][month]
        let end = ["", "", "", "", "", "", "", "Aug", "Sep", "Oct", "Nov"][month]
        return email(day(2026, month, 20), from: "\"Inkwell Labs, Inc.\" <invoice+statements@mail.inkwell-labs.com>",
                     subject: "Your receipt from Inkwell Labs, Inc. #2804-\(month)",
                     text: """
                     Receipt from Inkwell Labs, Inc. CA$22.60 Paid on \(start) 20, 2026
                     Receipt #2804-\(month) \(start) 20–\(end) 20, 2026 Inkwell Pro Qty 1 CA$20.00 Subtotal CA$20.00
                     HST - Canada (13%) CA$2.60 Total CA$22.60 Amount paid CA$22.60
                     Questions? Visit our support site. Powered by Stripe
                     """)
    }

    func testServicePeriod_readsInvoicePeriods() {
        XCTAssertEqual(ReceiptTextAnalyzer.servicePeriod(in: "Receipt #1 Oct 20–Nov 20, 2026 Pro Qty 1"), .monthly)
        XCTAssertEqual(ReceiptTextAnalyzer.servicePeriod(in: "Period: Sep 26, 2025 – Sep 26, 2026"), .yearly)
        XCTAssertEqual(ReceiptTextAnalyzer.servicePeriod(in: "Billing period 20 Oct – 20 Nov 2026"), .monthly)
        XCTAssertEqual(ReceiptTextAnalyzer.servicePeriod(in: "Service: 2026-10-20 – 2026-11-20"), .monthly)
        XCTAssertEqual(ReceiptTextAnalyzer.servicePeriod(in: "Dec 15 – Jan 15, 2027 Team plan"), .monthly, "a period across New Year")
        XCTAssertEqual(ReceiptTextAnalyzer.servicePeriod(in: "Jan 1 – Apr 1, 2026"), .quarterly)
    }

    func testServicePeriod_ignoresTrialsAndShortStays() {
        XCTAssertNil(ReceiptTextAnalyzer.servicePeriod(in: "Trial period\n2025 -10- 19—2025-10-26"))
        XCTAssertNil(ReceiptTextAnalyzer.servicePeriod(in: "Your free trial runs Oct 1 – Oct 31, 2026"))
        XCTAssertNil(ReceiptTextAnalyzer.servicePeriod(in: "Check-in Oct 20 – Oct 23, 2026"))
        XCTAssertNil(ReceiptTextAnalyzer.servicePeriod(in: "Order placed Oct 20, 2026"))
    }

    func testStripeInvoice_withQtyAndPeriod_isRecurring() throws {
        let signal = try XCTUnwrap(EmailSignalExtractor.extract(saasReceipt(10))?.signal)
        XCTAssertFalse(signal.oneTimeLanguage, "\"Qty 1\" on a subscription invoice is not an order")
        XCTAssertTrue(signal.renewalLanguage)
        XCTAssertEqual(signal.cadenceHint, .monthly)
        XCTAssertEqual(signal.amount, Decimal(string: "22.60"), "the amount paid, tax included")
        XCTAssertEqual(signal.currency, "CAD")
    }

    func testThreeStripeInvoices_fromAnUnknownCompany_areConfirmed() throws {
        let report = analyze([saasReceipt(8), saasReceipt(9), saasReceipt(10)], now: day(2026, 10, 28))
        let sub = try XCTUnwrap(report.subscriptions.first)
        XCTAssertEqual(sub.frequency, .monthly)
        XCTAssertEqual(sub.amount, Decimal(string: "22.60"))
        XCTAssertGreaterThanOrEqual(sub.tier, .likely)
        XCTAssertEqual(sub.status, .active)
    }

    func testGapsInReceiptHistory_doNotHideAMonthlyPlan() throws {
        // Receipts from Oct, Mar, Jun, Aug, Sep, Oct: deleted mail and a paused month in between.
        let months = [(2025, 10), (2026, 3), (2026, 6), (2026, 8), (2026, 9), (2026, 10)]
        let receipts = months.map { year, month in
            email(day(year, month, 20), from: "\"Inkwell Labs, Inc.\" <invoice+statements@mail.inkwell-labs.com>",
                  subject: "Your receipt from Inkwell Labs, Inc. #\(year)-\(month)",
                  text: "Receipt #\(month) Inkwell Pro Qty 1 Billing period: 20 Oct – 20 Nov 2026. Total CA$22.60 Amount paid CA$22.60")
        }
        let sub = try XCTUnwrap(analyze(receipts, now: day(2026, 10, 28)).subscriptions.first)
        XCTAssertEqual(sub.frequency, .monthly)
        XCTAssertEqual(sub.tier, .confirmed)
        XCTAssertGreaterThanOrEqual(sub.evidence.count, 3)
    }

    // MARK: Lifecycle wording

    func testCancellationPolicyLine_isNotACancellation() {
        let flags = ReceiptTextAnalyzer.languageFlags(
            subject: "Welcome to Prime!",
            body: "Plan type: 30-day Free Trial. Renewal date: May 2, 2026. After your trial, your membership renews at $9.99 plus tax per month. Here's your cancellation policy: cancel at any time.",
            promotional: false)
        XCTAssertFalse(flags.cancelled)
        XCTAssertTrue(flags.trialStart)
        XCTAssertFalse(flags.oneTime)
    }

    func testWillNotRenew_isACancellation() {
        for text in ["Your Plus subscription will not renew and will be canceled, but is still available until March 4.",
                     "Your Google One subscription from Google LLC on Google Play will be cancelled on 2 Feb 2026.",
                     "Your subscription to Lumière on Prime Video was recently canceled because you opted out of the automatic renewal selection."] {
            XCTAssertTrue(ReceiptTextAnalyzer.languageFlags(subject: "", body: text, promotional: false).cancelled, text)
        }
    }

    func testFooters_doNotFlipTheMeaning() {
        let footer = "You received this email because you have a paid account. Need a refund? View the Refund Policy."
        let flags = ReceiptTextAnalyzer.languageFlags(subject: "Your plan renews soon", body: footer, promotional: false)
        XCTAssertFalse(flags.oneTime, "\"You received this email\" is not a money transfer")
        XCTAssertFalse(flags.refund, "a refund policy link is not a refund")
        XCTAssertTrue(ReceiptTextAnalyzer.languageFlags(subject: "", body: "We've refunded $9.99 to your card.", promotional: false).refund)
    }

    func testTrialWelcome_thenNoCancellation_isWorthALook() throws {
        let welcome = email(day(2026, 4, 2), from: "Amazon Prime <prime@amazon.ca>", subject: "Welcome to Prime!",
                            text: "Plan name: Prime. Plan type: 30-day Free Trial. After your trial, your membership renews at $9.99 plus tax per month. Here's your cancellation policy. Fast, free shipping. See the Amazon Prime Terms.")
        let signal = try XCTUnwrap(EmailSignalExtractor.extract(welcome)?.signal)
        XCTAssertEqual(signal.kind, .trialStarted)
        XCTAssertEqual(signal.merchantHint, "Amazon Prime")

        let report = analyze([welcome], now: day(2026, 10, 28))
        let sub = try XCTUnwrap(report.subscriptions.first)
        XCTAssertEqual(sub.name, "Amazon Prime")
        XCTAssertEqual(sub.amount, Decimal(string: "9.99"))
        XCTAssertEqual(sub.tier, .review, "never pre-selected without a receipt")
        XCTAssertEqual(sub.status, .active)

        let cancelled = email(day(2026, 4, 20), from: "Amazon Prime <prime@amazon.ca>", subject: "Your Prime membership has ended",
                              text: "Your Amazon Prime membership has ended. You won't be charged again.")
        XCTAssertTrue(analyze([welcome, cancelled], now: day(2026, 10, 28)).subscriptions.isEmpty)
    }

    // MARK: Introductory prices and failed payments

    func testIntroPrice_chargesTheFirstPrice_andWarnsAboutTheSecond() throws {
        let receipt = email(day(2026, 3, 3), from: "Google Play <googleplay-noreply@google.com>",
                            subject: "Your Google Play Order Receipt from Mar 3, 2026",
                            text: """
                            You've made a subscription purchase from Google LLC on Google Play. You will be automatically charged $99.99 for 1 year, then $199.99/year starting Mar 3, 2027, unless canceled.
                            Order number: SOP.0000-0000-0000-00000
                            Item Price
                            Google One 2 TB (Google One) (by Google LLC) $99.99
                            Auto-renewing subscription
                            Tax: $13.00
                            Total: $112.99
                            """)
        let signal = try XCTUnwrap(EmailSignalExtractor.extract(receipt)?.signal)
        XCTAssertEqual(signal.amount, Decimal(string: "99.99"))
        XCTAssertEqual(signal.nextAmount, Decimal(string: "199.99"))
        XCTAssertEqual(signal.merchantHint, "Google One")
        XCTAssertFalse(signal.oneTimeLanguage, "\"Order number\" on an auto-renewing purchase is not an order")

        let report = analyze([receipt], now: day(2026, 10, 28))
        XCTAssertEqual(report.subscriptions.first?.frequency, .yearly)
        let insight = try XCTUnwrap(report.insights.first { $0.id.hasPrefix("intro|") })
        XCTAssertEqual(insight.annualImpact, Decimal(100))
    }

    func testFailedPayment_isNotACharge_andIsFlaggedUntilAPaymentGoesThrough() throws {
        let receipts = [8, 9].map { saasReceipt($0) }
        let failed = email(day(2026, 10, 20), from: "\"Inkwell Labs, Inc.\" <failed-payments@mail.inkwell-labs.com>",
                           subject: "CA$22.60 payment to Inkwell Labs, Inc. was unsuccessful",
                           text: "We were unable to charge your Visa ending in 0000 for your Inkwell Labs, Inc. subscription. Please update your billing information to continue your subscription.")
        let signal = try XCTUnwrap(EmailSignalExtractor.extract(failed)?.signal)
        XCTAssertEqual(signal.kind, .paymentFailed)

        let report = analyze(receipts + [failed], now: day(2026, 10, 25))
        XCTAssertEqual(report.subscriptions.first?.evidence.count, 2, "the declined payment is not a receipt")
        XCTAssertNotNil(report.insights.first { $0.kind == .paymentFailed })

        let retried = analyze(receipts + [failed, saasReceipt(10)], now: day(2026, 10, 25))
        XCTAssertNil(retried.insights.first { $0.kind == .paymentFailed }, "paid after all")
    }

    // MARK: Stores selling other companies' subscriptions

    func testPrimeVideoChannel_isTheChannel_notPrime() throws {
        let ended = email(day(2026, 6, 9), from: "Prime Video <no-reply@primevideo.com>", subject: "Your Lumière Subscription Has Ended",
                          text: "Hello, Your subscription to Lumière [https://www.primevideo.com/channel/x] on Prime Video was recently canceled because you opted out of the automatic renewal selection.")
        let signal = try XCTUnwrap(EmailSignalExtractor.extract(ended)?.signal)
        XCTAssertEqual(signal.kind, .cancellation)
        XCTAssertEqual(signal.merchantHint, "Lumière")
        let merchant = MerchantCatalog.builtin.resolve(hint: signal.merchantHint, senderName: signal.senderName,
                                                       senderDomain: signal.senderDomain)
        XCTAssertEqual(merchant?.displayName, "Lumière", "a channel cancellation must not cancel Prime Video or Prime")
    }

    func testChannelTrial_thenOptOut_isNotListed() throws {
        let started = email(day(2026, 6, 2), from: "Prime Video <no-reply@primevideo.com>",
                            subject: "You subscribed to Lumière on Prime Video",
                            text: "You recently started a free trial offer for Lumière on Prime Video. 7-day free trial. Automatically renews for CA$4.99/month. Please review our cancellation policy below.")
        let optedOut = email(day(2026, 6, 2), from: "Prime Video <no-reply@primevideo.com>",
                             subject: "Changes to your Lumière subscription",
                             text: "You have opted out of automatic renewal for your subscription to Lumière [https://www.primevideo.com/x] on Prime Video. Your access to this subscription will end on 9 June 2026.")
        let startSignal = try XCTUnwrap(EmailSignalExtractor.extract(started)?.signal)
        XCTAssertEqual(startSignal.merchantHint, "Lumière")
        XCTAssertEqual(startSignal.kind, .trialStarted)
        XCTAssertEqual(EmailSignalExtractor.extract(optedOut)?.signal.kind, .cancellation)
        XCTAssertTrue(analyze([started, optedOut], now: day(2026, 10, 28)).subscriptions.isEmpty,
                      "a trial cancelled before it ended is not a subscription, and never Prime Video's")
    }

    func testPrimeVideoRental_isOneTime_andNotPrime() throws {
        let rental = email(day(2026, 10, 28), from: "Amazon Prime Video <no-reply@primevideo.com>",
                           subject: "Amazon Prime Video order of Sample Film",
                           text: "Find all of your previous purchases and unexpired rentals in Purchases. Order #D01-0000000 Sample Film, $4.51 Total: $4.51. Purchase details: When you rent a video, you have 30 days to start watching.")
        let signal = try XCTUnwrap(EmailSignalExtractor.extract(rental)?.signal)
        XCTAssertTrue(signal.oneTimeLanguage)
        XCTAssertNotEqual(signal.merchantHint, "Amazon Prime")
        XCTAssertTrue(analyze([rental], now: day(2026, 10, 29)).subscriptions.isEmpty)
    }

    func testAppStoreReceipt_forAnUnknownApp_isNamedAfterTheApp() {
        let merchant = MerchantCatalog.builtin.resolve(hint: "Sleepwell Sounds", senderName: "Google Play",
                                                       senderDomain: "google.com")
        XCTAssertEqual(merchant?.displayName, "Sleepwell Sounds", "not lumped under \"Google\"")
        XCTAssertEqual(MerchantCatalog.builtin.resolve(hint: "Google One", senderName: "Google Play",
                                                       senderDomain: "google.com")?.displayName, "Google One")
    }
}
