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
}
