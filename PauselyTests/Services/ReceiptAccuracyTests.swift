import XCTest
@testable import Pausely

/// Mistakes the engine made on the end-to-end test mailbox (`scripts/mailtest/make_test_mailbox.py`),
/// each pinned at the level where it went wrong so it can't come back.
final class ReceiptAccuracyTests: XCTestCase {

    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private var counter = 0

    private func email(_ date: Date, from: String, subject: String, text: String, headers: [String: String] = [:]) -> RawEmail {
        counter += 1
        return RawEmail(id: "accuracy-\(counter)", date: date, from: from, subject: subject, bodyText: text,
                        bodyHTML: nil, headers: headers, labelIds: [])
    }

    private func money(_ subject: String, _ body: String) -> ReceiptTextAnalyzer.Money? {
        ReceiptTextAnalyzer.extractChargeAmount(subject: subject, body: body)
    }

    private let bulk = ["list-unsubscribe": "<mailto:unsubscribe@example.com>", "precedence": "bulk"]

    // MARK: Amounts

    func testWholeDollarPriceIsReadWhenTheWordsSayItWasCharged() {
        XCTAssertEqual(money("Your Fathom Notes invoice", "Fathom Notes Pro\n$8 per month\nTotal: $8\nYour plan renews monthly."),
                       .init(amount: 8, currency: nil))
        XCTAssertEqual(money("Receipt", "Amount paid: €10"), .init(amount: 10, currency: "EUR"))
    }

    func testWholeDollarFiguresInOffersAreNotAmounts() {
        XCTAssertNil(money("This week", "Take $5 off your next order."))
        XCTAssertNil(money("Members", "Plans start at $5 a month for members."))
        XCTAssertNil(money("Rewards", "Spend $50 and get a $10 gift card."))
        XCTAssertNil(money("Hello", "Try 30 days free."), "TRY is a currency code only in capitals next to a price")
    }

    func testOfferedPricesAreNeverTheCharge() {
        XCTAssertNil(money("New this week", "Thinking about a different plan? Plans from $7.99/month."))
        XCTAssertNil(money("3 Monate Premium für 0,00 €", "Nur für kurze Zeit: 3 Monate Premium für 0,00 €, danach 10,99 € pro Monat."))
        XCTAssertNil(money("Offre", "Votre abonnement à partir de 4,99 € par mois."))
        // The charge stays the charge when an offer follows it.
        XCTAssertEqual(money("Your receipt", "Amount charged: $134.99 for 1 year, then $269.99/year."),
                       .init(amount: Decimal(string: "134.99")!, currency: nil))
    }

    func testRiyalsDirhamsAndArabicDigits() {
        XCTAssertEqual(money("إيصال اشتراكك", "المبلغ المدفوع: 29.99 ر.س\nيتجدد اشتراكك تلقائيًا كل شهر."),
                       .init(amount: Decimal(string: "29.99")!, currency: "SAR"))
        XCTAssertEqual(money("إيصال", "المبلغ المدفوع: ٢٩٫٩٩ ر.س"), .init(amount: Decimal(string: "29.99")!, currency: "SAR"))
        XCTAssertEqual(money("Receipt", "Amount paid: AED 39.00"), .init(amount: 39, currency: "AED"))
        XCTAssertEqual(money("Receipt", "Total 1.250 KWD"), .init(amount: Decimal(string: "1.25")!, currency: "KWD"),
                       "dinars are written to three places")
    }

    func testNumberFormats() {
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("1,234.56", currency: "USD")?.value, Decimal(string: "1234.56"))
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("1.234,56", currency: "EUR")?.value, Decimal(string: "1234.56"))
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("12,99", currency: "EUR")?.value, Decimal(string: "12.99"))
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("1,250", currency: "USD")?.value, 1250)
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("1.250", currency: "EUR")?.value, 1250)
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("990", currency: "JPY")?.value, 990)
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("9,900", currency: "KRW")?.value, 9900)
        XCTAssertEqual(ReceiptTextAnalyzer.parseAmount("12.5", currency: nil)?.value, Decimal(string: "12.5"))
    }

    func testAQuantityBeforeAPriceIsNotPartOfIt() {
        // "1 299,00 €" is unreadable without knowing which it is, so nothing is taken from it; the total is.
        XCTAssertEqual(money("Reçu", "Qté 1 299,00 €\nMontant facturé : 299,00 €"), .init(amount: 299, currency: "EUR"))
    }

    func testFullWidthYen() {
        XCTAssertEqual(money("ご利用料金のお知らせ", "ご請求額: ￥９９０"), .init(amount: 990, currency: "JPY"))
    }

    // MARK: Promotions without a "Promotions" label (every inbox except Gmail's own)

    func testBulkOfferFromARealBillerIsNotACharge() {
        let promo = email(day(2026, 10, 1), from: "Netflix <info@members.netflix.com>", subject: "New this week, picked for you",
                          text: "Tonight's picks are in.\nThinking about a different plan? Plans from $7.99/month.", headers: bulk)
        XCTAssertNil(EmailSignalExtractor.extract(promo), "an offered price is not a receipt")

        let stated = email(day(2026, 10, 1), from: "Netflix <info@members.netflix.com>", subject: "Picked for you",
                           text: "Premium is $22.99 per month. See what's included.", headers: bulk)
        XCTAssertEqual(EmailSignalExtractor.extract(stated)?.signal.promotional, true,
                       "bulk mail that neither calls itself a receipt nor says anything was charged")
    }

    func testAReceiptSentAsBulkMailIsStillAReceipt() {
        let receipt = email(day(2026, 10, 1), from: "Netflix <info@account.netflix.com>", subject: "Your Netflix receipt",
                            text: "Amount charged: $15.49\nYour membership renews monthly.", headers: bulk)
        let signal = EmailSignalExtractor.extract(receipt)?.signal
        XCTAssertEqual(signal?.promotional, false)
        XCTAssertEqual(signal?.kind, .charge)
        XCTAssertEqual(signal?.amount, Decimal(string: "15.49"))
    }

    // MARK: Wording

    func testPriceChangeNoticeIsNotACharge() {
        let notice = email(day(2026, 8, 2), from: "Crunchyroll <no-reply@crunchyroll.com>", subject: "An update to your membership price",
                           text: "Starting with your next bill, the price of Crunchyroll Fan will change to $9.99 per month.")
        XCTAssertEqual(EmailSignalExtractor.extract(notice)?.signal.kind, .priceChange)
    }

    func testBillingPeriodIsReadInEveryAppLanguage() {
        let cases: [(String, BillingFrequency)] = [
            ("Dein Abonnement verlängert sich automatisch jeden Monat.", .monthly),
            ("Votre abonnement mensuel se renouvelle automatiquement.", .monthly),
            ("Tu suscripción se renovará cada mes.", .monthly),
            ("サブスクリプションは毎月自動更新されます。", .monthly),
            ("يتجدد اشتراكك تلقائيًا كل شهر.", .monthly),
            ("Ihr Abo wird jährlich abgerechnet.", .yearly),
            ("Facturé une fois par an.", .yearly),
            ("年額プランです。", .yearly),
            ("Billed every 3 months.", .quarterly)
        ]
        for (text, expected) in cases {
            XCTAssertEqual(ReceiptTextAnalyzer.explicitFrequency(subject: "", body: text), expected, text)
        }
    }

    // MARK: Merchant names

    func testAKnownBrandInsideAnotherBusinessNameIsNotThatBrand() {
        let catalog = MerchantCatalog.builtin
        XCTAssertEqual(catalog.resolve(hint: "Linear Orbit", senderName: "Linear Orbit", senderDomain: "stripe.com")?.displayName, "Linear Orbit")
        XCTAssertEqual(catalog.resolve(hint: "Calm Waters Spa", senderName: "", senderDomain: "stripe.com")?.displayName, "Calm Waters Spa")
        XCTAssertEqual(catalog.resolve(hint: nil, senderName: "Notion Press", senderDomain: "notionpress.example")?.displayName, "Notion Press")
    }

    func testABrandWithPlanWordsOrATaglineIsStillThatBrand() {
        let catalog = MerchantCatalog.builtin
        XCTAssertEqual(catalog.resolve(hint: "Netflix International", senderName: "", senderDomain: "stripe.com")?.displayName, "Netflix")
        XCTAssertEqual(catalog.resolve(hint: "Spotify Premium Family", senderName: "", senderDomain: "paypal.com")?.displayName, "Spotify")
        XCTAssertEqual(catalog.resolve(hint: "Amazon Prime Membership", senderName: "", senderDomain: "amazon.com")?.displayName, "Amazon Prime")
        XCTAssertEqual(catalog.resolve(hint: "Duolingo - Language Lessons", senderName: "Apple", senderDomain: "email.apple.com")?.displayName, "Duolingo")
        XCTAssertEqual(catalog.resolve(hint: "Google One 200 GB", senderName: "", senderDomain: "google.com")?.displayName, "Google One")
        XCTAssertEqual(catalog.resolve(hint: "Amazon Prime Video", senderName: "", senderDomain: "amazon.com")?.displayName, "Prime Video",
                       "the video service is not the Prime membership with a word added")
    }

    // MARK: Schedules and price changes

    private func charge(_ domain: String, _ date: Date, _ amount: String, cadence: BillingFrequency? = nil, renewal: Bool = true) -> ReceiptSignal {
        counter += 1
        return ReceiptSignal(id: "c\(counter)", date: date, senderDomain: domain, senderName: "", merchantHint: nil, platform: "direct",
                             kind: .charge, amount: Decimal(string: amount), currency: "USD", cadenceHint: cadence, trialDays: nil,
                             renewalLanguage: renewal, oneTimeLanguage: false, promotional: false)
    }

    private func analyze(_ signals: [ReceiptSignal], now: Date) -> [ProvenSubscription] {
        SubscriptionIntelligenceEngine().analyze(signals: signals, now: now, calendar: utc, defaultCurrency: "USD").subscriptions
    }

    func testAStrayChargeBetweenReceiptsDoesNotChangeTheSchedule() {
        // Five monthly receipts and one extra charge a week before the last (a one-off from the same company).
        var signals = [6, 7, 8, 9, 10].map { charge("spotify.com", day(2026, $0, 5), "10.99") }
        signals.append(charge("spotify.com", day(2026, 9, 29), "10.99"))
        let spotify = analyze(signals, now: day(2026, 10, 20)).first { $0.name == "Spotify" }
        XCTAssertEqual(spotify?.frequency, .monthly)
        XCTAssertEqual(spotify?.status, .active)
        XCTAssertEqual(spotify?.evidence.count, 5, "the stray charge is left out of the schedule, not counted in it")
    }

    func testAPlanThatMovedFromMonthlyToYearlyIsYearlyNow() {
        var signals = (1...8).map { charge("dropbox.com", day(2024, $0, 3), "11.99") }
        signals.append(charge("dropbox.com", day(2024, 12, 3), "119.88"))
        signals.append(charge("dropbox.com", day(2025, 12, 3), "119.88"))
        let dropbox = analyze(signals, now: day(2026, 6, 1)).first { $0.name == "Dropbox" }
        XCTAssertEqual(dropbox?.frequency, .yearly)
        XCTAssertEqual(dropbox?.amount, Decimal(string: "119.88"))
        XCTAssertEqual(dropbox?.status, .active)
    }

    func testAPriceRiseTwoChargesAgoIsStillAPriceRise() {
        let amounts = ["7.99", "7.99", "7.99", "9.99", "9.99"]
        let signals = zip([6, 7, 8, 9, 10], amounts).map { charge("crunchyroll.com", day(2026, $0.0, 25), $0.1) }
        let crunchyroll = analyze(signals, now: day(2026, 11, 10)).first { $0.name == "Crunchyroll" }
        XCTAssertEqual(crunchyroll?.status, .priceIncreased)
        XCTAssertEqual(crunchyroll?.previousAmount, Decimal(string: "7.99"))
        XCTAssertEqual(crunchyroll?.amount, Decimal(string: "9.99"))
    }

    func testAnOldPriceRiseIsNoLongerNews() {
        // 7.99 two years ago, 9.99 ever since: nothing to report today.
        var signals = [charge("crunchyroll.com", day(2024, 9, 25), "7.99")]
        signals += (0..<14).map { charge("crunchyroll.com", utc.date(byAdding: .month, value: $0, to: day(2024, 10, 25))!, "9.99") }
        let crunchyroll = analyze(signals, now: day(2025, 12, 1)).first { $0.name == "Crunchyroll" }
        XCTAssertEqual(crunchyroll?.status, .active)
        XCTAssertNil(crunchyroll?.previousAmount)
    }

    func testAnUnknownMerchantWhosePriceSteppedOnceIsStillOnePlan() {
        let amounts = ["12.00", "12.00", "12.00", "15.00", "15.00"]
        let signals = zip([6, 7, 8, 9, 10], amounts).map { charge("fathomnotes.example", day(2026, $0.0, 15), $0.1) }
        let plan = analyze(signals, now: day(2026, 10, 20)).first
        XCTAssertEqual(plan?.amount, 15)
        XCTAssertGreaterThanOrEqual(plan?.tier ?? .hidden, .likely)
    }

    func testAnUnknownMerchantWithDifferentAmountsEveryTimeIsNotAPlan() {
        let amounts = ["12.00", "31.50", "18.20", "44.10", "9.75"]
        let signals = zip([6, 7, 8, 9, 10], amounts).map { charge("cornershop.example", day(2026, $0.0, 15), $0.1, renewal: false) }
        XCTAssertFalse(analyze(signals, now: day(2026, 10, 20)).contains { $0.tier >= .likely })
    }
}
