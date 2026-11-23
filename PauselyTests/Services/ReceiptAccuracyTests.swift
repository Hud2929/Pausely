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
        ReceiptTextAnalyzer.chargeCandidate(subject: subject, body: body)?.money
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

    // MARK: Which figure on a receipt is the charge (shapes from real receipts, details made up)

    func testTaxIsNotThePrice_whenLabelsComeBeforeFigures() {
        let body = """
        You've successfully subscribed to Brightdesk Plus.
        Your subscription will automatically renew monthly.
        Order number: sub_0000 Order date: Sep 03, 2025 Plan
           Amount
              Brightdesk Plus Subscription $20.00 Tax: $2.60
        Total: $22.60 Payment method Visa-0000 By subscribing, you authorize us to charge you the subscription cost.
        """
        XCTAssertEqual(money("Brightdesk - Your new plan", body), .init(amount: Decimal(string: "22.60")!, currency: nil))
    }

    func testTotalChargedIsRead_whenFiguresComeBeforeLabels() {
        let body = "| CA$59.99 Studywell Plus annual plan CA$7.80 GST/HST CA$67.79 Total charged |\n| Your annual subscription renews automatically each year. |"
        XCTAssertEqual(money("Your Studywell Plus receipt", body), .init(amount: Decimal(string: "67.79")!, currency: "CAD"))
    }

    func testStoreReceiptTotalIncludesTax() {
        let body = """
        You've made a subscription purchase on the store. You will be automatically charged $134.99 for 1 year, then $269.99/year starting Dec 26, 2026, unless canceled.
        Item Price
        Cloud Plan 2 TB (by Example LLC) $134.99
        Auto-renewing subscription
        Tax: $17.55
        Total: $152.54
        """
        XCTAssertEqual(money("Your Order Receipt from Dec 26, 2025", body), .init(amount: Decimal(string: "152.54")!, currency: nil))
        let prices = ReceiptTextAnalyzer.introductoryPrices(in: body)
        XCTAssertEqual(prices?.intro, Decimal(string: "134.99"))
        XCTAssertEqual(prices?.next, Decimal(string: "269.99"))
    }

    func testAQuantityNextToAPriceIsNotAFigure() {
        XCTAssertEqual(money("Receipt", "Pro plan\nQty 1 $12.00\nAmount paid $12.00"), .init(amount: 12, currency: nil))
    }

    func testMembershipFeeIsACharge_serviceFeeIsNot() {
        XCTAssertEqual(money("Your DashPass receipt", "Your membership fee of C$9.99 was charged."),
                       .init(amount: Decimal(string: "9.99")!, currency: "CAD"))
        XCTAssertEqual(money("Your order", "Service fee $2.99\nTotal $31.40"), .init(amount: Decimal(string: "31.40")!, currency: nil))
    }

    // MARK: Offers are not trials (a real "90 days free" offer was reported as a trial that had started)

    func testAnInvitationToStartATrialIsNotATrial() {
        let offer = email(day(2026, 8, 27), from: "Tunewave <no-reply@tunewave.example>", subject: "Activate 90 days FREE of Tunewave Unlimited",
                          text: "You're eligible for a complimentary 90 day free trial of Tunewave Unlimited. To activate your trial, tap below.\nSubscribe Now - 90 Days Free\nAuto-renews at $12.99/month after until cancelled. New subscribers only. Limited time offer. Terms apply.")
        let signal = EmailSignalExtractor.extract(offer)?.signal
        XCTAssertNotEqual(signal?.kind, .trialStarted)
        XCTAssertNotEqual(signal?.kind, .trialEnding)
        XCTAssertTrue(signal == nil || signal?.promotional == true, "an offer is a promotion, whatever price it quotes")
        XCTAssertTrue(analyze([signal].compactMap { $0 }, now: day(2026, 9, 1)).isEmpty)
    }

    func testATrialThatHasBegunIsATrial() {
        let welcome = email(day(2026, 5, 12), from: "Amazon.ca <prime@amazon.ca>", subject: "Welcome to Prime!",
                            text: "* Plan name: - Prime\n* Plan type: - 30-day Free Trial\n* Renewal date: - June 10, 2026\nAfter your trial, your membership renews at $9.99 plus tax per month. You won't be charged if you cancel your membership before the renewal date.")
        let signal = EmailSignalExtractor.extract(welcome)?.signal
        XCTAssertEqual(signal?.kind, .trialStarted)
        XCTAssertEqual(signal?.promotional, false)
    }

    // MARK: Stores (shapes from real mail and from the reference notes)

    func testAChannelBoughtInAVideoStore_withNoReceiptsSince_isWorthALook() {
        let started = email(day(2026, 5, 21), from: "Prime Video <no-reply@primevideo.com>", subject: "You subscribed to Crunchyroll Fan on Prime Video",
                            text: "You recently started a promotional offer for Crunchyroll Fan on Prime Video.\nCrunchyroll Fan\n3-month promotional period\nStarted on 21 May 2026\nPromotional price\nCA$2.99/month\nFor 3 months\nStandard subscription price\nCA$10.99/month\nAfter that\nYour subscription automatically renews.")
        let found = analyze(EmailSignalExtractor.extractAll(started).map(\.signal), now: day(2026, 11, 10))
        let channel = found.first
        XCTAssertEqual(channel?.name, "Crunchyroll", "in a store, what follows the brand is its plan")
        XCTAssertEqual(channel?.amount, Decimal(string: "10.99"))
        XCTAssertEqual(channel?.status, .active, "the store sends no renewal receipts, so silence is not an ending")
        XCTAssertEqual(channel?.tier, .review, "one sign-up notice is worth a look, not a claim")
        XCTAssertEqual(channel?.doubt, "This store doesn't email a receipt for each renewal", "the row says why it is only worth a look")

        // With the store's cancellation notice, it is not offered as running.
        let ended = email(day(2026, 6, 2), from: "Prime Video <no-reply@primevideo.com>", subject: "Your Crunchyroll Fan Subscription Has Ended",
                          text: "Your subscription to Crunchyroll Fan on Prime Video has ended. You won't be charged again.")
        let after = analyze((EmailSignalExtractor.extractAll(started) + EmailSignalExtractor.extractAll(ended)).map(\.signal), now: day(2026, 11, 10))
        XCTAssertFalse(after.contains { $0.status == .active })
    }

    func testAnAppStoreReceiptYieldsEachSubscriptionAndNoOneOffPurchase() {
        let text = """
        Receipt
        APPLE ACCOUNT tester@example.com
        DATE Sep 18, 2026
        ORDER ID MNJ0000000
        DOCUMENT NO. 780000000000
        Duolingo - Language Lessons
        Super Duolingo (Monthly)
        Renews Oct 18, 2026  $12.99
        Castle Siege
        Sack of Gems
        In-App Purchase  $4.99
        iCloud+
        iCloud+ with 200 GB of Storage (Monthly)
        Renews Oct 18, 2026  $2.99
        Subtotal  $20.97
        Tax  $1.73
        TOTAL  $22.70
        """
        let receipt = email(day(2026, 9, 18), from: "Apple <no_reply@email.apple.com>", subject: "Your receipt from Apple.", text: text)
        let signals = EmailSignalExtractor.extractAll(receipt).map(\.signal)
        XCTAssertEqual(signals.map(\.amount), [Decimal(string: "12.99"), Decimal(string: "2.99")], "each item's own price, never the total")
        XCTAssertEqual(signals.map(\.merchantHint), ["Duolingo - Language Lessons", "iCloud+"])
        XCTAssertEqual(signals.map(\.cadenceHint), [.monthly, .monthly])
        XCTAssertEqual(Set(signals.map(\.id)).count, 2, "two facts from one email keep separate identities")
        let names = analyze(signals, now: day(2026, 9, 20)).map(\.name)
        XCTAssertEqual(Set(names), ["Duolingo", "iCloud+"])
    }

    func testAnAppStoreReceiptOfOneOffPurchasesIsNotASubscription() {
        let text = "Receipt\nAPPLE ACCOUNT tester@example.com\nDuolingo - Language Lessons\n1,200 Gems\nIn-App Purchase  $9.99\nSubtotal  $9.99\nTax  $0.00\nTOTAL  $9.99"
        let receipt = email(day(2026, 9, 18), from: "Apple <no_reply@email.apple.com>", subject: "Your receipt from Apple.", text: text)
        XCTAssertTrue(EmailSignalExtractor.extractAll(receipt).isEmpty, "a one-off purchase inside a subscription app is not that app's subscription")
    }

    func testAFamilyMembersCopyIsNotABill() {
        let text = "Your Apple ID was used to purchase Super Duolingo (Monthly).\nDuolingo - Language Lessons\nSuper Duolingo (Monthly)\nRenews Oct 18, 2026  $12.99\nTOTAL  $12.99\nThis is not a receipt. The original receipt for this purchase has been sent to the Family Organizer."
        let notice = email(day(2026, 9, 18), from: "Apple <no_reply@email.apple.com>", subject: "Your recent purchase with your Apple Account.", text: text)
        XCTAssertTrue(EmailSignalExtractor.extractAll(notice).isEmpty)
    }

    func testAnAppStoreSubscriptionNobodyHasHeardOfIsStillFound() {
        let text = "Receipt\nAPPLE ACCOUNT tester@example.com\nMoonlit Journal: Daily Diary\nPremium (Annual)\nRenews Sep 18, 2027  $39.99\nSubtotal  $39.99\nTax  $0.00\nTOTAL  $39.99"
        let receipt = email(day(2026, 9, 18), from: "Apple <no_reply@email.apple.com>", subject: "Your receipt from Apple.", text: text)
        let found = analyze(EmailSignalExtractor.extractAll(receipt).map(\.signal), now: day(2026, 10, 1)).first
        XCTAssertEqual(found?.name, "Moonlit Journal")
        XCTAssertEqual(found?.frequency, .yearly)
        XCTAssertEqual(found?.amount, Decimal(string: "39.99"))
        XCTAssertGreaterThanOrEqual(found?.tier ?? .hidden, .likely)
    }

    func testStripeSubjectNamesTheMerchant() {
        XCTAssertEqual(PlatformHints.merchantFromSubject("Your Acme Tools receipt [#1217-3050]"), "Acme Tools")
        XCTAssertEqual(PlatformHints.merchantFromSubject("Your receipt from Notion #2041-0001"), "Notion")
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

    // MARK: The newest charge, and charges that are not charges (a real inbox, 2026-11-22)

    /// Months of a plan at one price, then one charge at a much higher amount for the same plan. Dropped,
    /// the row said "$31.64, last charged Oct 20" a fortnight after a $148.41 charge on Nov 10; made the
    /// price, it would have called a likely prorated upgrade the monthly price. Now the newest charge is
    /// the last charge, the plan keeps its price, and the charge is a dated note until it happens twice.
    func testOneNewerChargeAtAnotherAmountIsALastChargeAndANoteNotAPrice() {
        var signals = (1...10).map { charge("anthropic.com", day(2026, $0, 20), "31.64", cadence: .monthly) }
        signals.append(charge("anthropic.com", day(2026, 11, 10), "148.41", cadence: .monthly))
        let found = analyze(signals, now: day(2026, 11, 22))
        XCTAssertEqual(found.count, 1, "one plan, not two")
        let plan = found.first
        XCTAssertEqual(plan?.lastChargeDate, day(2026, 11, 10))
        XCTAssertEqual(plan?.amount, Decimal(string: "31.64"), "one charge doesn't set a new price")
        XCTAssertEqual(plan?.unusualCharge?.amount, Decimal(string: "148.41"))
        XCTAssertNotEqual(plan?.status, .priceIncreased)
        XCTAssertEqual(plan?.nextBillingDate, day(2026, 12, 10), "the next charge follows the newest one")
        XCTAssertTrue(plan?.reasons.contains { $0.contains("more than the usual") } == true, "\(plan?.reasons ?? [])")
        XCTAssertFalse(plan?.reasons.contains { $0.contains("varies a lot") } == true, "a plan with one odd charge is not a run of orders")
        let insight = SubscriptionInsights.all(for: found, groups: [:], now: day(2026, 11, 22), calendar: utc)
            .first { $0.subscriptionId == plan?.id }
        XCTAssertEqual(insight?.title.hasSuffix("charged more than usual"), true, insight?.title ?? "none")
        XCTAssertTrue(insight?.detail.contains("A new plan or an extra charge") == true)
    }

    /// Two charges at the new amount settle it: that is the price now, said as a change the app can't
    /// explain ("a new plan or a higher price"), never "raised its price".
    func testTwoChargesAtANewAmountSettleTheNewPrice() {
        var signals = (1...10).map { charge("anthropic.com", day(2026, $0, 20), "31.64", cadence: .monthly) }
        signals.append(charge("anthropic.com", day(2026, 11, 10), "158.20", cadence: .monthly))
        signals.append(charge("anthropic.com", day(2026, 12, 10), "158.20", cadence: .monthly))
        let found = analyze(signals, now: day(2026, 12, 15))
        let plan = found.first
        XCTAssertEqual(plan?.amount, Decimal(string: "158.20"))
        XCTAssertEqual(plan?.previousAmount, Decimal(string: "31.64"))
        XCTAssertEqual(plan?.status, .priceIncreased)
        XCTAssertNil(plan?.unusualCharge)
        XCTAssertTrue(plan?.reasons.contains { $0.contains("a new plan or a higher price") } == true, "\(plan?.reasons ?? [])")
        let insight = SubscriptionInsights.all(for: found, groups: [:], now: day(2026, 12, 15), calendar: utc)
            .first { $0.kind == .priceIncrease }
        XCTAssertFalse(insight?.title.contains("raised its price") == true)
    }

    /// Adding a subscription once makes later scans trust it, but trust never puts it under "Confirmed:
    /// your receipts show these renew": a Prime Video sign-up with no receipt was shown there.
    func testTrustNeverLiftsARowIntoConfirmed() {
        counter += 1
        let signUp = ReceiptSignal(id: "t\(counter)", date: day(2026, 5, 20), senderDomain: "primevideo.com", senderName: "Prime Video",
                                   merchantHint: "Crunchyroll", platform: "direct", kind: .charge, amount: Decimal(string: "10.99"),
                                   currency: "USD", cadenceHint: .monthly, trialDays: nil, renewalLanguage: true,
                                   oneTimeLanguage: false, promotional: false)
        let engine = SubscriptionIntelligenceEngine()
        let first = engine.analyze(signals: [signUp], now: day(2026, 11, 22), calendar: utc, defaultCurrency: "USD").subscriptions.first
        let key = try? XCTUnwrap(first?.merchantKey)
        let trusted = engine.analyze(signals: [signUp], now: day(2026, 11, 22), calendar: utc, defaultCurrency: "USD",
                                     corrections: [key ?? "": .trusted]).subscriptions.first
        XCTAssertEqual(trusted?.tier, .likely, "worth a look, never confirmed by a tap")
        XCTAssertGreaterThan(trusted?.score ?? 0, first?.score ?? 0)
        XCTAssertEqual(trusted?.reasons.first, "You added it to your list before")
    }

    /// A trial's end is worked out from the email's date, never read from it: it is said as "around", the
    /// note sends the person to the email for the exact day, and the estimate errs early. "Trial ends
    /// Nov 28" and "Cancel before Nov 28" were stated as fact from the email date plus three days.
    func testATrialsWorkedOutEndIsSaidAsAroundAndErrsEarly() {
        counter += 1
        let ending = ReceiptSignal(id: "e\(counter)", date: day(2026, 11, 20), senderDomain: "spotify.com", senderName: "Spotify",
                                   merchantHint: nil, platform: "direct", kind: .trialEnding, amount: Decimal(string: "10.99"),
                                   currency: "USD", cadenceHint: .monthly, trialDays: nil, renewalLanguage: true,
                                   oneTimeLanguage: false, promotional: false)
        let found = analyze([ending], now: day(2026, 11, 20))
        let trial = found.first { $0.status == .trial }
        XCTAssertEqual(trial?.trialEndsOn, day(2026, 11, 21), "the earliest likely day, one after the email")
        if let trial {
            XCTAssertTrue(FoundRow.evidence(for: trial, now: day(2026, 11, 20)).hasPrefix("Trial ends around"))
        }
        let note = SubscriptionInsights.all(for: found, groups: [:], now: day(2026, 11, 20), calendar: utc).first { $0.kind == .trialEnding }
        XCTAssertTrue(note?.title.contains("around") == true, note?.title ?? "none")
        XCTAssertTrue(note?.detail.hasPrefix("Check the exact day in the email") == true, note?.detail ?? "none")
    }

    /// A small rise is still a price rise, said as one.
    func testASmallRiseIsStillAPriceRise() {
        var signals = (1...6).map { charge("spotify.com", day(2026, $0, 5), "10.99", cadence: .monthly) }
        signals.append(charge("spotify.com", day(2026, 7, 5), "11.99", cadence: .monthly))
        let plan = analyze(signals, now: day(2026, 7, 20)).first { $0.name == "Spotify" }
        XCTAssertEqual(plan?.status, .priceIncreased)
        XCTAssertEqual(plan?.lastChargeDate, day(2026, 7, 5))
        XCTAssertTrue(plan?.reasons.contains { $0.hasPrefix("Up from") } == true, "\(plan?.reasons ?? [])")
    }

    /// A later one-off from the same seller (its receipt says nothing about renewing) never moves the plan.
    func testALaterOneOffDoesNotMoveThePlan() {
        var signals = (1...6).map { charge("anthropic.com", day(2026, $0, 20), "31.64", cadence: .monthly) }
        signals.append(charge("anthropic.com", day(2026, 6, 28), "84.75", renewal: false))
        let plan = analyze(signals, now: day(2026, 7, 1)).first
        XCTAssertEqual(plan?.lastChargeDate, day(2026, 6, 20))
        XCTAssertEqual(plan?.amount, Decimal(string: "31.64"))
        XCTAssertNotEqual(plan?.status, .priceIncreased)
    }

    /// A Prime Video channel emails when someone subscribes and never again. That email is the sign-up,
    /// not "the last charge": the row said "Last charged May 20" six months of charges later.
    func testAChannelSignUpIsNotALastCharge() {
        counter += 1
        let signUp = ReceiptSignal(id: "s\(counter)", date: day(2026, 5, 20), senderDomain: "primevideo.com", senderName: "Prime Video",
                                   merchantHint: "Crunchyroll", platform: "direct", kind: .charge, amount: Decimal(string: "10.99"),
                                   currency: "USD", cadenceHint: .monthly, trialDays: nil, renewalLanguage: true,
                                   oneTimeLanguage: false, promotional: false)
        let plan = analyze([signUp], now: day(2026, 11, 22)).first
        XCTAssertNotNil(plan, "still listed: it probably runs on")
        XCTAssertNil(plan?.lastChargeDate, "a sign-up is not a charge")
        XCTAssertEqual(plan?.subscribedOn, day(2026, 5, 20))
        XCTAssertEqual(plan?.tier, .review, "worth a look, never confirmed on a sign-up alone")
        if let plan {
            XCTAssertEqual(FoundRow.evidence(for: plan, now: day(2026, 11, 22)), "Subscribed on May\u{00A0}20")
        }
    }

    /// A yearly plan on an introductory price that ends at the coming renewal: one note, which says the
    /// coming charge with tax. Two notes said "expect $152.54" (the old price with tax) and "goes up to
    /// $269.99" (the new price without) about the same charge (a real inbox, 2026-11-22).
    func testAnIntroductoryPriceEndingIsOneNoteWithTheChargeWithTax() {
        counter += 1
        var receipt = ReceiptSignal(id: "g\(counter)", date: day(2025, 12, 26), senderDomain: "google.com", senderName: "Google Play",
                                    merchantHint: "Google One", platform: "googleplay", kind: .charge, amount: Decimal(string: "152.54"),
                                    currency: "CAD", cadenceHint: .yearly, trialDays: nil, renewalLanguage: true,
                                    oneTimeLanguage: false, promotional: false)
        receipt.introAmount = Decimal(string: "134.99")
        receipt.nextAmount = Decimal(string: "269.99")
        let engine = SubscriptionIntelligenceEngine()
        let report = engine.analyze(signals: [receipt], now: day(2026, 11, 22), calendar: utc, defaultCurrency: "CAD")
        let about = report.insights.filter { $0.subscriptionId == report.subscriptions.first?.id }
        XCTAssertEqual(about.count, 1, "\(about.map(\.title))")
        XCTAssertEqual(about.first?.kind, .priceChangeNotice)
        XCTAssertTrue(about.first?.detail.contains("305.09") == true, about.first?.detail ?? "")
        XCTAssertTrue(about.first?.detail.contains("with tax") == true)

        // Added to the list at what the next renewal charges, so its reminder is about that charge (T12).
        let google = try? XCTUnwrap(report.subscriptions.first)
        XCTAssertEqual(google?.amount, Decimal(string: "152.54"), "the row still shows what was charged")
        XCTAssertEqual(google?.comingAmount, Decimal(string: "305.09"))
        XCTAssertEqual(google.map { FoundSubscription(proven: $0).line.amount }, Decimal(string: "305.09"))
    }

    /// "Most likely renewed after the trial" is said only of a store that emails no receipt per renewal:
    /// from a seller that does, months without a receipt say the trial did not go on.
    func testATrialAtASellerThatEmailsReceiptsIsNotAssumedToHaveRenewed() {
        func trialStart(_ domain: String, _ name: String) -> ReceiptSignal {
            counter += 1
            return ReceiptSignal(id: "ts\(counter)", date: day(2026, 5, 12), senderDomain: domain, senderName: name, merchantHint: name,
                                 platform: "direct", kind: .trialStarted, amount: Decimal(string: "9.99"), currency: "CAD",
                                 cadenceHint: .monthly, trialDays: 30, renewalLanguage: true, oneTimeLanguage: false, promotional: false)
        }
        let prime = analyze([trialStart("amazon.ca", "Amazon Prime")], now: day(2026, 11, 22)).first
        XCTAssertNotNil(prime, "Amazon emails no receipt per renewal: probably still running")
        XCTAssertTrue(prime?.startedWithTrial == true)
        XCTAssertEqual(prime?.doubt, "This store doesn't email a receipt for each renewal", "its row says why it is only worth a look")
        if let prime {
            XCTAssertEqual(FoundRow.evidence(for: prime, now: day(2026, 11, 22)), "Trial started on May\u{00A0}12")
        }
        XCTAssertNil(analyze([trialStart("spotify.com", "Spotify")], now: day(2026, 11, 22)).first { $0.status == .active },
                     "Spotify emails a receipt each month; none since the trial means it didn't go on")
    }

    /// A row that may have ended, if added anyway, lands with no date: its old charge would have made Home
    /// promise a next one.
    func testAnEndedRowIsAddedWithoutADate() {
        let ended = ProvenSubscription(id: "x", name: "ChatGPT Plus", merchantKey: "chatgpt plus", category: nil, cancelURL: nil,
                                       amount: Decimal(string: "22.60")!, currency: "CAD", frequency: .monthly,
                                       lastChargeDate: day(2025, 9, 3), nextBillingDate: nil, status: .likelyEnded, score: 56,
                                       tier: .likely, evidence: [], reasons: [], previousAmount: nil, trialEndsOn: nil)
        XCTAssertNil(FoundSubscription(proven: ended).line.anchor)
    }

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

    /// A row under "Worth a look" says what keeps it from certain: the heading's "Check these before adding
    /// them" didn't say what to check (the rating of 2026-11-22).
    func testAWorthALookRowSaysWhatKeepsItFromCertain() {
        let two = analyze([charge("fathomnotes.example", day(2026, 6, 15), "12.00"),
                           charge("fathomnotes.example", day(2026, 7, 15), "12.00")], now: day(2026, 7, 20)).first
        XCTAssertEqual(two?.tier, .review, "an unknown sender's two charges are worth a look")
        XCTAssertEqual(two?.doubt, "Two charges so far; a third would confirm it")
    }

    /// A receipt that says only "$" takes the dollar the email or its sender names, and otherwise a dollar:
    /// US receipts showed as Canadian dollars in Canada and as riyals in Saudi Arabia (2026-11-22).
    func testABareDollarIsNeverAnotherCurrencyAndIsSaidWhenAssumed() {
        XCTAssertEqual(DollarHint.currency(text: "Total: $15.49 USD", senderDomain: "netflix.com"), "USD")
        XCTAssertEqual(DollarHint.currency(text: "Amount: US$9.99", senderDomain: "example.com"), "USD")
        XCTAssertEqual(DollarHint.currency(text: "Total $16.49", senderDomain: "mail.cineplex.ca"), "CAD")
        XCTAssertNil(DollarHint.currency(text: "Total $16.49", senderDomain: "netflix.com"), "nothing says which")
        XCTAssertNil(DollarHint.currency(text: "$5 USD or $7 CAD", senderDomain: "shop.com"), "two named: no guess")
        XCTAssertEqual(DollarHint.assumed(readerCurrency: "CAD"), "CAD")
        XCTAssertEqual(DollarHint.assumed(readerCurrency: "SAR"), "USD", "a dollar never becomes riyals")
        XCTAssertEqual(DollarHint.assumed(readerCurrency: "EUR"), "USD")

        let charges = [6, 7, 8].map { month -> ReceiptSignal in
            var bare = charge("fathomnotes.example", day(2026, month, 15), "12.00", cadence: .monthly)
            bare.currency = nil   // "$12.00" and nothing to say which dollar
            return bare
        }
        let plan = analyze(charges, now: day(2026, 8, 20)).first
        XCTAssertEqual(plan?.currencyAssumed, true)
        XCTAssertEqual(DollarNote.sentence(code: "USD", locale: Locale(identifier: "en_US")),
                       "Receipts that say only “$” are counted as US Dollar.", "said once, above the rows, with a way to change it")
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
