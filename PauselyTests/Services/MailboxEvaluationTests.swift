import XCTest
@testable import Pausely

// MARK: - Synthetic Mailbox

/// Builds a realistic, fully synthetic mailbox: real subscriptions mixed with orders, rides, tickets, promos,
/// bills and header junk. Brand names appear because merchant matching must be exercised, but every email body is
/// original test text. No real mailbox is ever read.
final class MailboxBuilder {
    private(set) var emails: [RawEmail] = []
    private var counter = 0
    let calendar: Calendar

    init() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        calendar = c
    }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func add(_ date: Date, from: String, subject: String, text: String = "", html: String? = nil,
             headers: [String: String] = [:], labels: [String] = []) {
        counter += 1
        emails.append(RawEmail(id: "msg-\(counter)", date: date, from: from, subject: subject, bodyText: text,
                               bodyHTML: html, headers: headers, labelIds: labels))
    }

    func dkim(_ domain: String) -> [String: String] {
        ["authentication-results": "mx.google.com; dkim=pass header.i=@\(domain) header.s=s1; spf=pass smtp.mailfrom=bounce.\(domain)"]
    }

    let unsubscribe = ["list-unsubscribe": "<mailto:unsub@example.com>"]

    func page(_ body: String, ld: Any? = nil) -> String {
        var script = ""
        if let ld, let data = try? JSONSerialization.data(withJSONObject: ld), let json = String(data: data, encoding: .utf8) {
            script = "<script type=\"application/ld+json\">\(json)</script>"
        }
        return "<html><head><style>p{margin:0}</style>\(script)</head><body>\(body)</body></html>"
    }
}

// MARK: - Evaluation

final class MailboxEvaluationTests: XCTestCase {

    private let mailbox = MailboxBuilder()
    private lazy var now: Date = mailbox.date(2026, 10, 7)

    private func buildMailbox() -> [RawEmail] { Self.makeMailbox(mailbox) }

    static func makeMailbox(_ m: MailboxBuilder) -> [RawEmail] {
        let ca = "CATEGORY_PROMOTIONS"

        // ===== REAL SUBSCRIPTIONS (all must be found) =====

        // Netflix: 6 monthly receipts, two carry structured Invoice markup, one refund, three promos.
        let netflixInvoice: [String: Any] = [
            "@context": "http://schema.org", "@type": "Invoice", "provider": ["@type": "Organization", "name": "Netflix"],
            "totalPaymentDue": ["@type": "PriceSpecification", "price": "16.49", "priceCurrency": "CAD"], "billingPeriod": "P1M"
        ]
        for (i, month) in [4, 5, 6, 7, 8, 9].enumerated() {
            let structured = i >= 4
            m.add(m.date(2026, month, 12), from: "Netflix <info@mailer.netflix.com>", subject: "Your Netflix payment receipt",
                  text: structured ? "" : "Thanks for being a Netflix member.\nPlan: Standard\nAmount charged: C$16.49\nYour plan renews monthly.",
                  html: structured ? m.page("<p>Receipt</p><p>Total C$16.49</p>", ld: netflixInvoice) : nil,
                  headers: m.dkim("netflix.com").merging(m.unsubscribe) { a, _ in a })
        }
        m.add(m.date(2026, 8, 20), from: "Netflix <info@mailer.netflix.com>", subject: "Your Netflix refund",
              text: "We've refunded C$16.49 to your original payment method.")
        for day in [3, 17, 28] {
            m.add(m.date(2026, 9, day), from: "Netflix <info@mailer.netflix.com>", subject: "Watch more for less",
                  text: "Plans starting at $5.99/month. Save 20% on annual plans. Shop now.", labels: [ca])
        }

        // Spotify: price rises from 11.99 to 12.99 in September, with the price-change notice in July.
        for (month, amount) in [(6, "11.99"), (7, "11.99"), (8, "11.99"), (9, "12.99")] {
            m.add(m.date(2026, month, 5), from: "Spotify <no-reply@spotify.com>", subject: "Your Spotify Premium receipt",
                  text: "Amount paid: C$\(amount) per month.\nYour subscription renews monthly.")
        }
        m.add(m.date(2026, 7, 20), from: "Spotify <no-reply@spotify.com>", subject: "Your Spotify Premium price is changing",
              text: "Starting with your next bill on September 5, the price will be C$12.99 per month.")
        for day in [2, 24] {
            m.add(m.date(2026, 9, day), from: "Spotify <no-reply@spotify.com>", subject: "Try Premium free",
                  text: "One month free, then C$11.99/month.", labels: [ca])
        }

        // Apple: iCloud+ through an App Store receipt.
        for month in [6, 7, 8, 9] {
            m.add(m.date(2026, month, 3), from: "Apple <no_reply@email.apple.com>", subject: "Your receipt from Apple.",
                  text: "iCloud+ with 200 GB of storage\nRenews monthly\nC$3.99\nOrder ID: MX4F\nTotal C$3.99")
        }

        // Google Play: Google One.
        for month in [7, 8, 9] {
            m.add(m.date(2026, month, 18), from: "Google Play <googleplay-noreply@google.com>",
                  subject: "Your Google One subscription renewed",
                  text: "Google One 200 GB\nC$3.49 per month\nYour subscription will renew automatically.")
        }

        // Unknown SaaS billed by Stripe; two receipts carry recurring Order markup.
        let brightlineOrder: [String: Any] = [
            "@context": "http://schema.org", "@type": "Order", "seller": ["@type": "Organization", "name": "Brightline CRM"],
            "priceCurrency": "USD", "price": "49.00",
            "acceptedOffer": ["@type": "Offer", "priceSpecification": ["@type": "UnitPriceSpecification", "price": "49.00",
                                                                        "priceCurrency": "USD", "unitCode": "MON"]]
        ]
        for (i, date) in [m.date(2026, 7, 1), m.date(2026, 8, 1), m.date(2026, 9, 1), m.date(2026, 10, 1)].enumerated() {
            let structured = i < 2
            m.add(date, from: "Brightline CRM <invoice+statements@stripe.com>", subject: "Your receipt from Brightline CRM #2041-\(i)",
                  text: structured ? "" : "Receipt from Brightline CRM\nAmount paid $49.00 USD\nPro plan, billed monthly",
                  html: structured ? m.page("<p>Amount paid $49.00 USD</p>", ld: brightlineOrder) : nil)
        }

        // PayPal automatic payment.
        for month in [7, 8, 9] {
            m.add(m.date(2026, month, 14), from: "PayPal <service@paypal.com>", subject: "You sent an automatic payment to Cloudvault",
                  text: "Hello,\nYour automatic payment to Cloudvault for $6.00 USD has been sent.\nNext payment: Oct 14, 2026\nTransaction ID: 9X44")
        }

        // Local gym, billed directly.
        for month in [7, 8, 9, 10] {
            m.add(m.date(2026, month, 3), from: "Ironside Fitness <billing@ironsidefitness.ca>", subject: "Membership payment received",
                  text: "Thank you for your monthly membership payment of $34.99.\nYour membership renews on the 3rd of each month.")
        }

        // Adobe: yearly, renewing in under 45 days.
        for year in [2024, 2025] {
            m.add(m.date(year, 10, 20), from: "Adobe <mail@mail.adobe.com>", subject: "Your Adobe subscription receipt",
                  text: "Creative Cloud All Apps\nAmount charged: C$779.88 per year\nYour subscription will renew on October 20.")
        }

        // Amazon Prime membership (not Amazon orders).
        for month in [6, 7, 8, 9] {
            m.add(m.date(2026, month, 9), from: "Amazon.ca <auto-confirm@amazon.ca>", subject: "Your Amazon Prime membership payment",
                  text: "Your Prime membership fee of C$9.99 was charged.\nYour membership renews monthly.")
        }

        // DashPass membership (not DoorDash orders).
        for month in [7, 8, 9] {
            m.add(m.date(2026, month, 2), from: "DoorDash <no-reply@doordash.com>", subject: "Your DashPass receipt",
                  text: "DashPass monthly fee C$9.99\nYour membership renews automatically.")
        }

        // Notion free trial that just started.
        m.add(m.date(2026, 10, 5), from: "Notion <team@notion.so>", subject: "Your free trial has started",
              text: "Enjoy your 14-day free trial of Notion Plus.\nAfter your trial ends you'll be billed $10.00 per month.")

        // Hulu: stopped paying in March.
        for month in [1, 2, 3] {
            m.add(m.date(2026, month, 8), from: "Hulu <hulu@mail.hulu.com>", subject: "Your Hulu receipt",
                  text: "Hulu (No Ads)\nTotal: C$11.99 billed monthly. Your subscription renews each month.")
        }

        // Disney+: cancelled in August.
        for month in [6, 7, 8] {
            m.add(m.date(2026, month, 12), from: "Disney+ <disneyplus@mail.disneyplus.com>", subject: "Your Disney+ receipt",
                  text: "Total C$11.99 per month. Your membership renews monthly.")
        }
        m.add(m.date(2026, 8, 20), from: "Disney+ <disneyplus@mail.disneyplus.com>", subject: "Your Disney+ subscription has been cancelled",
              text: "We're sorry to see you go. Your subscription has been cancelled.")

        // Unknown merchant sending through an ESP: identity revealed only by the DKIM signature.
        for month in [7, 8, 9] {
            m.add(m.date(2026, month, 15), from: "Billing <bounce@mail.sendgrid.net>", subject: "Your Quickfolio payment",
                  text: "Payment of $19.00 received. Your subscription renews monthly.", headers: m.dkim("quickfolio.io"))
        }

        // ===== NOT SUBSCRIPTIONS (none may appear) =====

        // Amazon orders, two with one-time structured markup.
        let amazonOrder: (String) -> [Any] = { price in
            [["@context": "http://schema.org", "@type": "Order", "seller": ["@type": "Organization", "name": "Amazon.ca"],
              "priceCurrency": "CAD", "price": price, "acceptedOffer": ["@type": "Offer", "price": price, "priceCurrency": "CAD"]],
             ["@context": "http://schema.org", "@type": "ParcelDelivery", "provider": ["@type": "Organization", "name": "Amazon.ca"]]]
        }
        let orders: [(Int, Int, String)] = [(6, 3, "42.17"), (7, 14, "18.99"), (7, 22, "126.40"), (8, 9, "33.15"), (9, 1, "64.80"), (9, 28, "21.99")]
        for (i, order) in orders.enumerated() {
            let structured = i % 3 == 0
            m.add(m.date(2026, order.0, order.1), from: "Amazon.ca <shipment-tracking@amazon.ca>",
                  subject: "Your Amazon.ca order #702-\(1000 + i) has shipped",
                  text: structured ? "" : "Thanks for your order.\nOrder #702-\(1000 + i)\nTracking number 1Z99\nOrder Total: C$\(order.2)",
                  html: structured ? m.page("<p>Order Total: C$\(order.2)</p>", ld: amazonOrder(order.2)) : nil)
        }

        // DoorDash food orders (the footer mentions DashPass savings: it must not become a membership charge).
        let food: [(Int, Int, String)] = [(5, 9, "33.83"), (6, 4, "21.50"), (6, 29, "48.04"), (7, 17, "12.90"), (8, 11, "27.30"), (9, 6, "39.25"), (9, 30, "18.40")]
        for (i, order) in food.enumerated() {
            m.add(m.date(2026, order.0, order.1), from: "DoorDash <no-reply@doordash.com>", subject: "Your order from Pizza Palace",
                  text: "Order #55\(i)\nDelivered.\nDashPass savings: C$3.00\nDelivery fee C$0.00\nTotal C$\(order.2)")
        }

        // Rides.
        let rides: [(Int, Int, String)] = [(6, 2, "23.45"), (6, 19, "14.10"), (7, 7, "31.80"), (8, 3, "12.95"), (8, 26, "27.60"), (9, 21, "19.35")]
        for ride in rides {
            m.add(m.date(2026, ride.0, ride.1), from: "Uber Receipts <uber.us@uber.com>", subject: "Your Tuesday evening trip with Uber",
                  text: "Thanks for riding, Alex\nTotal C$\(ride.2)\nDriver: Sam")
        }

        // One-off purchases.
        m.add(m.date(2026, 6, 1), from: "Frontgate Tickets <orders@frontgatetickets.com>", subject: "Your tickets for Summer Fest",
              text: "E-tickets attached. Order #44721. Total: C$394.99")
        m.add(m.date(2026, 9, 14), from: "Nintendo <no-reply@accounts.nintendo.com>", subject: "Thank you for your purchase",
              text: "Your purchase of a digital game. Total C$79.99")

        // Utility bill: steady dates but varying amounts.
        for (month, amount) in [(6, "82.14"), (7, "91.50"), (8, "77.02"), (9, "120.33")] {
            m.add(m.date(2026, month, 28), from: "Toronto Hydro <billing@torontohydro.com>", subject: "Your bill is ready",
                  text: "Amount due: $\(amount). Due date in 14 days.")
        }

        // Header junk and unrelated money emails.
        m.add(m.date(2026, 8, 3), from: "Dec 26 <orders@bounce.sendgrid.net>", subject: "Your order", text: "Thanks for your order. Total $134.99")
        m.add(m.date(2026, 9, 1), from: "Payments <noreply@mailgun.org>", subject: "Payment received for invoice 2231", text: "Payment received: $40.00")
        m.add(m.date(2026, 9, 2), from: "Account <alerts@mcsv.net>", subject: "Your receipt", text: "Receipt total: $59.99")
        for day in [8, 22] {
            m.add(m.date(2026, 9, day), from: "Interac e-Transfer <notify@payments.interac.ca>", subject: "You received money",
                  text: "Sam sent you $60.00 with Interac e-Transfer.")
        }
        m.add(m.date(2026, 7, 30), from: "Air Example <bookings@airexample.com>", subject: "Your itinerary",
              text: "", html: m.page("<p>Booking confirmed</p>", ld: ["@context": "http://schema.org", "@type": "FlightReservation",
                                                                           "reservationFor": ["@type": "Flight", "flightNumber": "AC123"],
                                                                           "totalPrice": "612.40", "priceCurrency": "CAD"]))
        for day in [4, 11, 18] {
            m.add(m.date(2026, 9, day), from: "The Daily Brief <news@dailybrief.example>", subject: "Your weekly newsletter",
                  text: "Top stories this week. Unsubscribe any time.", headers: m.unsubscribe, labels: [ca])
        }

        return m.emails
    }

    // MARK: Expectations

    private let expectedSubscriptions: Set<String> = [
        "Netflix", "Spotify", "iCloud+", "Google One", "Brightline CRM", "Cloudvault", "Ironside Fitness",
        "Adobe Creative Cloud", "Amazon Prime", "DashPass", "Notion", "Hulu", "Disney+", "Quickfolio"
    ]

    private struct Evaluation {
        var report: IntelligenceReport
        var extracted: Int
        var total: Int
        var detected: Set<String>
        var reviewOnly: Set<String>
    }

    private func evaluate() -> Evaluation {
        let emails = buildMailbox()
        let signals = emails.compactMap { EmailSignalExtractor.extract($0)?.signal }
        let report = SubscriptionIntelligenceEngine().analyze(signals: signals, now: now, calendar: mailbox.calendar, defaultCurrency: "CAD")
        let detected = Set(report.subscriptions.filter { $0.tier >= .likely }.map(\.name))
        let reviewOnly = Set(report.subscriptions.filter { $0.tier == .review }.map(\.name))
        return Evaluation(report: report, extracted: signals.count, total: emails.count, detected: detected, reviewOnly: reviewOnly)
    }

    // MARK: Scorecard

    func testScorecard_precisionAndRecall() {
        let result = evaluate()
        let truePositives = result.detected.intersection(expectedSubscriptions)
        let falsePositives = result.detected.subtracting(expectedSubscriptions)
        let missed = expectedSubscriptions.subtracting(result.detected)
        let precision = result.detected.isEmpty ? 0 : Double(truePositives.count) / Double(result.detected.count)
        let recall = Double(truePositives.count) / Double(expectedSubscriptions.count)

        print("""

        ===== MAILBOX SCORECARD =====
        emails: \(result.total) · kept as signals: \(result.extracted)
        expected: \(expectedSubscriptions.count) · detected: \(result.detected.count)
        precision: \(String(format: "%.0f%%", precision * 100)) · recall: \(String(format: "%.0f%%", recall * 100))
        false positives: \(falsePositives.sorted())
        missed: \(missed.sorted())
        review-tier extras: \(result.reviewOnly.sorted())
        =============================

        """)

        // Detailed report for humans (written outside the sandbox so it can be inspected after the run).
        var table = "name | tier | status | freq | amount | score | evidence\n"
        for sub in result.report.subscriptions {
            table += "\(sub.name) | \(sub.tier) | \(sub.status) | \(sub.frequency.rawValue) | \(sub.amount) \(sub.currency) | \(sub.score) | \(sub.evidence.count)\n"
        }
        table += "\nINSIGHTS\n" + result.report.insights.map { "- [\($0.kind)] \($0.title)" }.joined(separator: "\n")
        table += "\n\nignored purchase groups: \(result.report.ignoredPurchaseGroups)\nprecision \(precision) recall \(recall)"
        try? table.write(toFile: "/tmp/pausely_scorecard.txt", atomically: true, encoding: .utf8)

        XCTAssertTrue(falsePositives.isEmpty, "Junk reached the confirmed/likely tiers: \(falsePositives.sorted())")
        XCTAssertTrue(missed.isEmpty, "Real subscriptions were missed: \(missed.sorted())")
        XCTAssertTrue(result.reviewOnly.isEmpty, "Too many 'worth a look' extras: \(result.reviewOnly.sorted())")
    }

    func testNoJunkNamesEverSurface_inAnyTier() {
        let names = Set(evaluate().report.subscriptions.map(\.name))
        for junk in ["Dec 26", "Payments", "Account", "Em", "Frontgate Tickets", "Nintendo", "Toronto Hydro", "Uber", "DoorDash", "Amazon"] {
            XCTAssertFalse(names.contains(junk), "\(junk) should never be listed")
        }
    }

    // MARK: Lifecycle in the full pipeline

    func testLifecycleStatuses_inFullPipeline() {
        let subs = Dictionary(uniqueKeysWithValues: evaluate().report.subscriptions.map { ($0.name, $0) })
        XCTAssertEqual(subs["Spotify"]?.status, .priceIncreased)
        XCTAssertEqual(subs["Notion"]?.status, .trial)
        XCTAssertEqual(subs["Hulu"]?.status, .likelyEnded)
        XCTAssertEqual(subs["Disney+"]?.status, .cancelled)
        XCTAssertEqual(subs["Netflix"]?.status, .active)
        XCTAssertEqual(subs["Netflix"]?.frequency, .monthly)
        XCTAssertEqual(subs["Adobe Creative Cloud"]?.frequency, .yearly)
    }

    func testCurrenciesAreReadCorrectly() {
        let subs = Dictionary(uniqueKeysWithValues: evaluate().report.subscriptions.map { ($0.name, $0) })
        XCTAssertEqual(subs["Brightline CRM"]?.currency, "USD")
        XCTAssertEqual(subs["Brightline CRM"]?.amount, 49)
        XCTAssertEqual(subs["Cloudvault"]?.currency, "USD")
        XCTAssertEqual(subs["Netflix"]?.currency, "CAD")
    }

    func testInsights_surfaceTheMoneyMoments() {
        let kinds = Set(evaluate().report.insights.map(\.kind))
        XCTAssertTrue(kinds.contains(.priceIncrease))
        XCTAssertTrue(kinds.contains(.trialEnding))
        XCTAssertTrue(kinds.contains(.renewalSoon))   // Adobe renews in under 45 days
        XCTAssertTrue(kinds.contains(.likelyEnded))   // Hulu
    }

    // MARK: Each intelligence layer earns its keep

    func testHeaderIntelligence_revealsTheRealSender() {
        let subs = evaluate().report.subscriptions.map(\.name)
        XCTAssertTrue(subs.contains("Quickfolio"), "DKIM domain should unmask the relayed sender")
    }

    func testStructuredMarkup_marksRealSubscriptionsAndOrders() {
        let emails = buildMailbox()
        let netflixStructured = emails.filter { $0.subject == "Your Netflix payment receipt" && $0.bodyHTML != nil }
            .compactMap { EmailSignalExtractor.extract($0)?.signal }
        XCTAssertEqual(netflixStructured.count, 2)
        XCTAssertTrue(netflixStructured.allSatisfy { $0.markup == .subscription && $0.cadenceHint == .monthly })

        let orderMarkup = emails.filter { $0.subject.hasPrefix("Your Amazon.ca order") && $0.bodyHTML != nil }
            .compactMap { EmailSignalExtractor.extract($0)?.signal }
        XCTAssertFalse(orderMarkup.isEmpty)
        XCTAssertTrue(orderMarkup.allSatisfy { $0.oneTimeLanguage && !$0.renewalLanguage })
    }

    func testReservationsAreNeverSubscriptions() {
        let names = evaluate().report.subscriptions.map(\.name)
        XCTAssertFalse(names.contains("Air Example"))
    }

    func testPromotionsNeverCountEvenWhenTheyShowPrices() {
        let netflix = evaluate().report.subscriptions.first { $0.name == "Netflix" }
        XCTAssertEqual(netflix?.evidence.count, 6)
    }
}
