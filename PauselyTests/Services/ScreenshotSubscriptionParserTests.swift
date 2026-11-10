import XCTest
@testable import Pausely

/// Screenshot Import's parser, on text laid out the way the two kinds of screens lay it out.
/// These shapes are written from memory of the screens, not from real screenshots: see
/// REDESIGN_PLAN.md. Real screenshots must be run through it before the feature ships.
final class ScreenshotSubscriptionParserTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 9))! }

    private func line(_ text: String, x: CGFloat = 0.2, y: CGFloat, width: CGFloat = 0.4, height: CGFloat = 0.02) -> ScreenshotTextLine {
        ScreenshotTextLine(text: text, box: CGRect(x: x, y: y, width: width, height: height))
    }
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    private func parse(_ lines: [ScreenshotTextLine]) -> [ScreenshotSubscriptionParser.Candidate] {
        ScreenshotSubscriptionParser.candidates(from: lines, now: now, calendar: calendar)
    }

    // MARK: A list of subscriptions (name, plan, "Renews …"; no prices)

    func testSubscriptionListGivesNameDateAndFrequencyButNoPrice() {
        let found = parse([
            line("Subscriptions", x: 0.35, y: 0.06),
            line("Active", x: 0.05, y: 0.12),
            line("Netflix", y: 0.18), line("Standard (Monthly)", y: 0.205), line("Renews 27 Nov", y: 0.23),
            line("Duolingo", y: 0.30), line("Super Duolingo (1 Year)", y: 0.325), line("Renews 3 Mar", y: 0.35),
        ])
        XCTAssertEqual(found.map(\.name), ["Netflix", "Duolingo"])
        XCTAssertEqual(found[0].nextCharge, day(2026, 11, 27))
        XCTAssertEqual(found[0].frequency, .monthly)
        XCTAssertNil(found[0].amount, "this screen shows no price; none may be invented")
        XCTAssertEqual(found[1].nextCharge, day(2027, 3, 3), "a date without a year is the next one, here next year")
        XCTAssertEqual(found[1].frequency, .yearly)
    }

    func testUnknownAppInASubscriptionListIsKeptUnderItsOwnName() {
        let found = parse([
            line("Tidepool Journal", y: 0.18), line("Premium (Monthly)", y: 0.205), line("Renews 2 Dec", y: 0.23),
        ])
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].name, "Tidepool Journal")
        XCTAssertFalse(found[0].isKnownService)
        XCTAssertEqual(found[0].nextCharge, day(2026, 12, 2))
    }

    func testExpiredRowsAreLeftOut() {
        let found = parse([
            line("Netflix", y: 0.18), line("Standard (Monthly)", y: 0.205), line("Renews 27 Nov", y: 0.23),
            line("Inactive", x: 0.05, y: 0.30),
            line("Spotify", y: 0.36), line("Premium (Monthly)", y: 0.385), line("Expired 4 Aug", y: 0.41),
        ])
        XCTAssertEqual(found.map(\.name), ["Netflix"])
    }

    // MARK: A list of charges (merchant and amount on one row)

    func testChargeListGivesNameAndAmount() {
        let found = parse([
            line("Latest Transactions", x: 0.05, y: 0.10),
            line("Spotify", x: 0.18, y: 0.20), line("-$12.99", x: 0.78, y: 0.20, width: 0.15),
            line("Nov 4", x: 0.18, y: 0.225),
            line("Netflix", x: 0.18, y: 0.30), line("CA$16.49", x: 0.76, y: 0.30, width: 0.17),
            line("Oct 28", x: 0.18, y: 0.325),
        ])
        XCTAssertEqual(found.map(\.name), ["Spotify", "Netflix"])
        XCTAssertEqual(found[0].amount, Decimal(string: "12.99"))
        XCTAssertNil(found[0].currency, "a bare $ doesn't say which dollar")
        XCTAssertEqual(found[1].amount, Decimal(string: "16.49"))
        XCTAssertEqual(found[1].currency, "CAD")
        XCTAssertNil(found[0].nextCharge, "the date of a past charge is not a renewal date")
    }

    func testTheSameServiceTwiceBecomesOneCandidate() {
        let found = parse([
            line("Spotify", x: 0.18, y: 0.20), line("$12.99", x: 0.78, y: 0.20, width: 0.15),
            line("Spotify", x: 0.18, y: 0.30), line("$12.99", x: 0.78, y: 0.30, width: 0.15),
        ])
        XCTAssertEqual(found.count, 1)
    }

    func testANameWithNothingBesideItIsNotASubscription() {
        XCTAssertEqual(parse([line("Netflix", y: 0.2), line("Watch anywhere. Cancel anytime, no commitment today.", y: 0.5, width: 0.7)]), [])
    }

    func testAnEmptyScreenshotFindsNothing() {
        XCTAssertEqual(parse([]), [])
    }

    // MARK: Pieces

    func testAmountNeedsACurrencyAndTwoDecimals() {
        XCTAssertNil(ScreenshotSubscriptionParser.amount(in: "Renews 27 Nov"))
        XCTAssertNil(ScreenshotSubscriptionParser.amount(in: "4 of 12"))
        XCTAssertEqual(ScreenshotSubscriptionParser.amount(in: "12,99 €")?.amount, Decimal(string: "12.99"))
        XCTAssertEqual(ScreenshotSubscriptionParser.amount(in: "12,99 €")?.currency, "EUR")
        XCTAssertEqual(ScreenshotSubscriptionParser.amount(in: "$1,299.00")?.amount, Decimal(string: "1299.00"))
        XCTAssertEqual(ScreenshotSubscriptionParser.amount(in: "£7.99/month")?.currency, "GBP")
    }

    func testRenewalDateShapes() {
        XCTAssertEqual(ScreenshotSubscriptionParser.renewalDate(in: "Next billing date: December 3, 2027", now: now, calendar: calendar), day(2027, 12, 3))
        XCTAssertEqual(ScreenshotSubscriptionParser.renewalDate(in: "Renews Nov 10", now: now, calendar: calendar), day(2026, 11, 10), "today counts")
        XCTAssertEqual(ScreenshotSubscriptionParser.renewalDate(in: "Renews Nov 9", now: now, calendar: calendar), day(2027, 11, 9))
        XCTAssertNil(ScreenshotSubscriptionParser.renewalDate(in: "Nov 4", now: now, calendar: calendar), "no renewal wording")
        XCTAssertNil(ScreenshotSubscriptionParser.renewalDate(in: "Renews Feb 30", now: now, calendar: calendar))
    }
}
