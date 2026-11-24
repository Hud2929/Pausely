import CoreGraphics
import XCTest
@testable import Pausely

/// On-device screenshot parsing: Apple Settings › Subscriptions, bank recurring lists,
/// multi-screenshot deduplication, trials, inactive/expired handling, and international currencies.
final class ScreenshotImportTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Toronto")!
        return cal
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testParsesAppleSettingsSubscriptionsWithActiveTrialAndInactiveSections() {
        let now = day(2026, 11, 23)
        let lines = [
            "9:41",
            "Subscriptions",
            "ACTIVE",
            "Netflix",
            "Standard Plan",
            "$19.99/month",
            "Renews Dec 14, 2026",
            "iCloud+",
            "200 GB",
            "$2.99/month",
            "Renews Dec 1",
            "Duolingo",
            "Super Duolingo (Annual)",
            "$83.99/year",
            "Free Trial · Renews Dec 3",
            "INACTIVE",
            "Hulu",
            "Hulu (No Ads)",
            "Expired Oct 10, 2026",
            "$18.99/month",
        ]

        let items = ScreenshotParser.parse(lines: lines, defaultCurrency: "USD", now: now, calendar: calendar)
        XCTAssertEqual(items.count, 4)

        let netflix = items.first { $0.name == "Netflix" }
        XCTAssertEqual(netflix?.amount, Decimal(string: "19.99"))
        XCTAssertEqual(netflix?.frequency, .monthly)
        XCTAssertEqual(netflix?.renewalDate, day(2026, 12, 14))
        XCTAssertEqual(netflix?.isCancelled, false)

        let icloud = items.first { $0.name == "iCloud+" }
        XCTAssertEqual(icloud?.amount, Decimal(string: "2.99"))
        XCTAssertEqual(icloud?.renewalDate, day(2026, 12, 1))
        XCTAssertEqual(icloud?.isCancelled, false)

        let duolingo = items.first { $0.name == "Duolingo" }
        XCTAssertEqual(duolingo?.amount, Decimal(string: "83.99"))
        XCTAssertEqual(duolingo?.frequency, .yearly)
        XCTAssertEqual(duolingo?.trialEndsAt, day(2026, 12, 3))
        XCTAssertEqual(duolingo?.isTrial, true)
        XCTAssertEqual(duolingo?.isCancelled, false)

        let hulu = items.first { $0.name == "Hulu" }
        XCTAssertEqual(hulu?.isCancelled, true, "inactive section items must be marked cancelled")
    }

    func testParsesSpatialBankRecurringChargeRows() {
        let now = day(2026, 11, 23)
        // Left column = merchant name, right column = amount on same visual Y band.
        let observations: [ScreenshotParser.TextObservation] = [
            .init(text: "Recurring Payments", boundingBox: CGRect(x: 0.1, y: 0.90, width: 0.6, height: 0.03)),
            .init(text: "NETFLIX.COM", boundingBox: CGRect(x: 0.08, y: 0.78, width: 0.35, height: 0.025)),
            .init(text: "$19.99", boundingBox: CGRect(x: 0.76, y: 0.782, width: 0.16, height: 0.025)),
            .init(text: "Next charge Dec 5", boundingBox: CGRect(x: 0.08, y: 0.745, width: 0.40, height: 0.020)),

            .init(text: "SPOTIFY USA", boundingBox: CGRect(x: 0.08, y: 0.66, width: 0.35, height: 0.025)),
            .init(text: "$12.99/mo", boundingBox: CGRect(x: 0.74, y: 0.661, width: 0.18, height: 0.025)),

            .init(text: "Equinox Club", boundingBox: CGRect(x: 0.08, y: 0.56, width: 0.35, height: 0.025)),
            .init(text: "$260.00/mo", boundingBox: CGRect(x: 0.72, y: 0.558, width: 0.20, height: 0.025)),
        ]

        let items = ScreenshotParser.parse(pages: [observations], defaultCurrency: "USD", now: now, calendar: calendar)
        XCTAssertEqual(items.map(\.name), ["Equinox Club", "Netflix", "Spotify"])
        XCTAssertEqual(items.first { $0.name == "Netflix" }?.renewalDate, day(2026, 12, 5))
        XCTAssertEqual(items.first { $0.name == "Spotify" }?.amount, Decimal(string: "12.99"))
        XCTAssertEqual(items.first { $0.name == "Equinox Club" }?.amount, Decimal(string: "260.00"))
    }

    func testDeduplicatesOverlappingMultiScreenshotCaptureAndMergesFields() {
        let now = day(2026, 11, 23)
        // Screenshot 1 cuts off Netflix's renewal date at the bottom; Screenshot 2 has Netflix again with the date.
        let page1 = [
            ScreenshotParser.TextObservation(text: "Netflix", boundingBox: CGRect(x: 0.08, y: 0.20, width: 0.4, height: 0.03)),
            ScreenshotParser.TextObservation(text: "$19.99/month", boundingBox: CGRect(x: 0.08, y: 0.15, width: 0.4, height: 0.025)),
        ]
        let page2 = [
            ScreenshotParser.TextObservation(text: "Netflix Standard", boundingBox: CGRect(x: 0.08, y: 0.82, width: 0.5, height: 0.03)),
            ScreenshotParser.TextObservation(text: "Renews Dec 19", boundingBox: CGRect(x: 0.08, y: 0.77, width: 0.4, height: 0.025)),
            ScreenshotParser.TextObservation(text: "Claude Pro", boundingBox: CGRect(x: 0.08, y: 0.60, width: 0.4, height: 0.03)),
            ScreenshotParser.TextObservation(text: "$20.00/month", boundingBox: CGRect(x: 0.08, y: 0.55, width: 0.4, height: 0.025)),
        ]

        let items = ScreenshotParser.parse(pages: [page1, page2], defaultCurrency: "USD", now: now, calendar: calendar)
        XCTAssertEqual(items.count, 2)
        let netflix = items.first { $0.name == "Netflix" }
        XCTAssertEqual(netflix?.amount, Decimal(string: "19.99"))
        XCTAssertEqual(netflix?.renewalDate, day(2026, 12, 19))
    }

    func testHandlesInternationalCurrenciesAndMonthRollover() {
        let now = day(2026, 12, 20)
        let lines = [
            "Spotify",
            "12,99 €/Monat",
            "Verlängert sich am 10 Jan",
            "iCloud+",
            "¥400/月",
            "Renews Jan 5",
        ]
        let items = ScreenshotParser.parse(lines: lines, defaultCurrency: "EUR", now: now, calendar: calendar)
        let spotify = items.first { $0.name == "Spotify" }
        XCTAssertEqual(spotify?.amount, Decimal(string: "12.99"))
        XCTAssertEqual(spotify?.currency, "EUR")
        XCTAssertEqual(spotify?.renewalDate, day(2027, 1, 10), "Jan 10 seen on Dec 20 rolls to next year")

        let icloud = items.first { $0.name == "iCloud+" }
        XCTAssertEqual(icloud?.amount, Decimal(400))
        XCTAssertEqual(icloud?.currency, "JPY")
        XCTAssertEqual(icloud?.renewalDate, day(2027, 1, 5))
    }

    func testIgnoresStatusBarAndSettingsChrome() {
        let lines = [
            "9:41",
            "5G",
            "100%",
            "Settings",
            "Subscriptions",
            "Share New Subscriptions",
            "Renewal Receipts",
            "A receipt will be sent to you for each renewal.",
        ]
        let items = ScreenshotParser.parse(lines: lines, defaultCurrency: "USD", now: day(2026, 11, 23), calendar: calendar)
        XCTAssertTrue(items.isEmpty)
    }

    func testInactiveDuplicateNeverOverwritesActiveSubscriptionAndCrossCurrencySortsByConvertedCost() {
        let now = day(2026, 11, 23)
        let lines = [
            "Subscriptions",
            "ACTIVE",
            "Netflix",
            "$19.99/month",
            "Renews Dec 14, 2026",
            "iCloud+",
            "¥400/月",
            "Renews Dec 10, 2026",
            "INACTIVE",
            "Netflix",
            "Expired Jan 2, 2025",
            "$15.49/month",
        ]
        let items = ScreenshotParser.parse(lines: lines, defaultCurrency: "USD", now: now, calendar: calendar, rates: .fallback)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].name, "Netflix", "$19.99 USD must sort above ¥400 JPY (~$2.60)")
        XCTAssertEqual(items[0].isCancelled, false, "inactive historical entry must never cancel an active row")
        XCTAssertEqual(items[0].paymentMethod, "Apple")
        XCTAssertEqual(items[1].name, "iCloud+")
    }

    func testSingleLinePriceFollowedByExpiredSublineMarksItemCancelled() {
        let now = day(2026, 11, 23)
        let observations: [ScreenshotParser.TextObservation] = [
            .init(text: "Netflix", boundingBox: CGRect(x: 0.08, y: 0.78, width: 0.30, height: 0.025)),
            .init(text: "$19.99/mo", boundingBox: CGRect(x: 0.72, y: 0.781, width: 0.20, height: 0.025)),
            .init(text: "Expired Oct 10, 2026", boundingBox: CGRect(x: 0.08, y: 0.745, width: 0.45, height: 0.020)),
        ]
        let items = ScreenshotParser.parse(pages: [observations], defaultCurrency: "USD", now: now, calendar: calendar)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Netflix")
        XCTAssertEqual(items[0].isCancelled, true, "following Expired subline must mark the single-line card cancelled")
    }

    // MARK: - A bank's transactions (the rating of 2026-11-23)

    /// A bank list mixes income, one-off purchases and subscriptions. Income and a transaction's own line are
    /// never rows; a purchase with nothing saying it repeats is shown but not taken as a subscription; a known
    /// subscription service is; "every 4 weeks" says how it is counted. A "+" in a name is not income.
    func testABankListKeepsOnlyWhatRepeats() {
        let now = day(2026, 11, 23)
        let lines = [
            "Transactions",
            "Salary  +€3,200.00",
            "1 Nov 2026 • Transfer",
            "Netflix  €13.99",
            "Shell  €45.20",
            "REWE  €62.18",
            "Amazon.de  €23.99",
            "Disney+  €109.90",
            "The New York Times  €4.00",
            "Every 4 weeks"
        ]
        let items = ScreenshotParser.parse(lines: lines, defaultCurrency: "EUR", now: now, calendar: calendar)
        let byName = Dictionary(items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        XCTAssertNil(items.first { $0.name.lowercased().contains("salary") }, "income is never a subscription")
        XCTAssertNil(items.first { $0.name.contains("Nov") || $0.name.lowercased().contains("transfer") }, "a transaction line is not a name")
        XCTAssertNil(byName["netflix"]?.doubt, "a known subscription service repeats")
        XCTAssertNotNil(byName["disney+"], "the plus in Disney+ is part of its name")
        XCTAssertNil(byName["disney+"]?.doubt)
        XCTAssertEqual(byName["shell"]?.doubt, .mayNotRepeat)
        XCTAssertEqual(byName["rewe"]?.doubt, .mayNotRepeat)
        XCTAssertEqual(items.first { $0.name.lowercased().hasPrefix("amazon") }?.doubt, .mayNotRepeat, "a shop's name doesn't say it repeats")
        XCTAssertEqual(items.first { $0.name.lowercased().contains("new york times") }?.doubt, .everyFourWeeks)

        XCTAssertTrue(ScreenshotParser.isIncomeOrTransfer("salary  +€3,200.00"))
        XCTAssertTrue(ScreenshotParser.isIncomeOrTransfer("refund from shop  €12.00"))
        XCTAssertFalse(ScreenshotParser.isIncomeOrTransfer("disney+  $159.99"))
        XCTAssertFalse(ScreenshotParser.isIncomeOrTransfer("apple tv+  $9.99"))
    }

    /// Under a header that says every row repeats ("Recurring payments"), an unknown name is still a subscription.
    func testARecurringListTrustsItsRows() {
        let items = ScreenshotParser.parse(lines: ["Recurring payments", "Corner Gym  $40.00", "Next payment Dec 1"],
                                           defaultCurrency: "USD", now: day(2026, 11, 23), calendar: calendar)
        XCTAssertEqual(items.first?.name, "Corner Gym")
        XCTAssertNil(items.first?.doubt)
    }

    // MARK: - Laid out as banks lay them out (the rating of 2026-11-23)

    /// Lines at the heights a screenshot gives them: a row's lines sit close, rows are farther apart.
    private func page(_ rows: [[String]], top: CGFloat = 0.9, line: CGFloat = 0.03, gap: CGFloat = 0.05) -> [ScreenshotParser.TextObservation] {
        var y = top, out: [ScreenshotParser.TextObservation] = []
        for row in rows {
            for text in row {
                out.append(ScreenshotParser.TextObservation(text: text, boundingBox: CGRect(x: 0.05, y: y, width: 0.9, height: 0.02)))
                y -= line
            }
            y -= gap
        }
        return out
    }

    /// A bank's recurring payments put how often and when above each name: each row takes its own, not the one
    /// above's. Labels are not names; rent and insurance are bills, shown unticked; every 2 months is half each month.
    func testARecurringListReadsEachRowsOwnPeriodAndDay() {
        let now = day(2026, 11, 23)
        let rows: [[String]] = [
            ["Recurring payments"],
            ["Monthly · next 19 Dec 2026", "Netflix   €13.99", "Card subscription"],
            ["Monthly · next 1 Dec 2026", "J MURPHY RENT   €1,450.00", "Standing order"],
            ["Every 2 months · next 9 Jan 2027", "ELECTRIC IRELAND   €96.20", "Direct debit · amount varies"],
            ["Yearly · next 4 Mar 2027", "Microsoft 365 Family   €99.00", "Card subscription"]
        ]
        let items = ScreenshotParser.parse(pages: [page(rows)], defaultCurrency: "EUR", now: now, calendar: calendar)
        let by = Dictionary(items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        XCTAssertNil(items.first { ["card subscription", "standing order", "direct debit"].contains($0.name.lowercased()) }, "labels are not names")
        XCTAssertEqual(by["netflix"]?.renewalDate, day(2026, 12, 19))
        XCTAssertEqual(by["netflix"]?.frequency, .monthly)
        let microsoft = items.first { $0.name.lowercased().hasPrefix("microsoft 365") }
        XCTAssertEqual(microsoft?.frequency, .yearly, "its own row's period, not the row above's")
        XCTAssertEqual(microsoft?.amount, Decimal(string: "99.00"))
        XCTAssertEqual(microsoft?.renewalDate, day(2027, 3, 4))
        let rent = items.first { $0.name.lowercased().contains("rent") }
        XCTAssertEqual(rent?.doubt, .aBill, "rent is a bill: shown, not ticked")
        let electric = items.first { $0.name.lowercased().contains("electric") }
        XCTAssertEqual(electric?.doubt, .aBill)
        XCTAssertEqual(electric?.amount, Decimal(string: "48.10"), "every 2 months: half each month")
    }

    /// A bank's transactions: the balance, labels and store numbers are not subscriptions or names; the same
    /// charge twice repeats; a reference code is not part of a name.
    func testATransactionListKeepsNamesClean() {
        let now = day(2026, 11, 23)
        let rows: [[String]] = [
            ["Current Account", "Available balance €3,412.08"],
            ["21 Nov 2026", "ACME SOFTWARE LTD SALARY   +€2,850.00", "Credit transfer"],
            ["19 Nov 2026", "NETFLIX.COM   -€13.99", "Card payment"],
            ["18 Nov 2026", "TESCO STORES 3321   -€84.17", "Card payment"],
            ["17 Nov 2026", "COSMIC CANDLE P2A91C   -€11.99", "Card payment"],
            ["17 Oct 2026", "COSMIC CANDLE P2A91C   -€11.99", "Card payment"]
        ]
        let items = ScreenshotParser.parse(pages: [page(rows)], defaultCurrency: "EUR", now: now, calendar: calendar)
        let names = items.map { $0.name.lowercased() }
        XCTAssertFalse(names.contains { $0.contains("balance") || $0.contains("salary") || $0.contains("card payment") }, "\(names)")
        XCTAssertTrue(names.contains("tesco stores"), "the store number is not part of the name: \(names)")
        let candle = items.first { $0.name.lowercased() == "cosmic candle" }
        XCTAssertNotNil(candle, "the reference is not part of the name: \(names)")
        XCTAssertNil(candle?.doubt, "the same charge twice repeats")
        XCTAssertEqual(items.first { $0.name.lowercased() == "tesco stores" }?.doubt, .mayNotRepeat)
    }

    /// A trial's page: "Then $13.99 per month" is the price after the trial, not a service called "Then".
    func testATrialsThenLineIsItsPrice() {
        let lines = ["Edit Subscription", "YouTube Premium", "Individual (Monthly)", "Free trial ends December 9, 2026", "Then $13.99 per month"]
        let items = ScreenshotParser.parse(lines: lines, defaultCurrency: "USD", now: day(2026, 11, 23), calendar: calendar)
        XCTAssertNil(items.first { $0.name.lowercased() == "then" })
        let youtube = items.first { $0.name.lowercased().contains("youtube") }
        XCTAssertEqual(youtube?.amount, Decimal(string: "13.99"))
        XCTAssertEqual(youtube?.trialEndsAt, day(2026, 12, 9))
    }

    func testExpiryWordsUseWordBoundariesAndCompoundBillsAndHeadersAreRecognized() {
        // "Recommended" and "Extended" contain "ended" as a substring and must NOT mark a subscription cancelled.
        XCTAssertFalse(ScreenshotParser.containsExpiryWord("recommended plan"))
        XCTAssertFalse(ScreenshotParser.containsExpiryWord("extended coverage"))
        XCTAssertTrue(ScreenshotParser.containsExpiryWord("ended nov 12"))
        XCTAssertTrue(ScreenshotParser.containsExpiryWord("cancelled"))

        // German and Japanese compound bill nouns are recognized as bills.
        XCTAssertTrue(ScreenshotParser.isBill("Hausratversicherung"))
        XCTAssertTrue(ScreenshotParser.isBill("Kaltmiete"))
        XCTAssertTrue(ScreenshotParser.isBill("生命保険"))
        XCTAssertFalse(ScreenshotParser.isBill("Netflix"))

        // Localized recurring headers are filtered as chrome, never treated as service names.
        XCTAssertTrue(ScreenshotParser.isChromeNoise("Daueraufträge", lower: "daueraufträge"))
        XCTAssertTrue(ScreenshotParser.isChromeNoise("Abonnements", lower: "abonnements"))
        XCTAssertTrue(ScreenshotParser.isChromeNoise("定期支払い", lower: "定期支払い"))

        // Second sighting across screenshot batches clears .mayNotRepeat and marks eligible for selection.
        var list = [ScreenshotParser.DetectedItem(id: "candle", name: "Cosmic Candle", category: "Other",
                                                  amount: Decimal(string: "11.99"), currency: "EUR",
                                                  frequency: .monthly, renewalDate: nil, trialEndsAt: nil,
                                                  isCancelled: false, doubt: .mayNotRepeat)]
        let batch2 = [ScreenshotParser.DetectedItem(id: "candle", name: "Cosmic Candle", category: "Other",
                                                    amount: Decimal(string: "11.99"), currency: "EUR",
                                                    frequency: .monthly, renewalDate: nil, trialEndsAt: nil,
                                                    isCancelled: false, doubt: .mayNotRepeat)]
        let newlyEligible = ScreenshotParser.mergeBatch(batch2, into: &list)
        XCTAssertNil(list[0].doubt)
        XCTAssertTrue(newlyEligible.contains("candle"))
    }
}
