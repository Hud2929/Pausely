import XCTest
@testable import Pausely

/// The text cells of the exported spreadsheet file. A subscription's name can come from a scanned
/// email, so nothing in it may be able to run as a formula when the file is opened.
final class SubscriptionExporterTests: XCTestCase {

    func testOrdinaryNamesAreWrittenAsTheyAre() {
        XCTAssertEqual(SubscriptionExporter.csvCell("Netflix"), "Netflix")
        XCTAssertEqual(SubscriptionExporter.csvCell("Disney+"), "Disney+", "a plus sign after the first character is harmless")
        XCTAssertEqual(SubscriptionExporter.csvCell(""), "")
    }

    func testCommasQuotesAndLineBreaksAreQuoted() {
        XCTAssertEqual(SubscriptionExporter.csvCell("Paramount+, with Showtime"), "\"Paramount+, with Showtime\"")
        XCTAssertEqual(SubscriptionExporter.csvCell("The \"Plus\" plan"), "\"The \"\"Plus\"\" plan\"")
        XCTAssertEqual(SubscriptionExporter.csvCell("Two\nlines"), "\"Two\nlines\"")
        XCTAssertEqual(SubscriptionExporter.csvCell("Old Mac\rline"), "\"Old Mac\rline\"")
    }

    func testACellThatStartsLikeAFormulaIsMadePlainText() {
        XCTAssertEqual(SubscriptionExporter.csvCell("=1+1"), "'=1+1")
        XCTAssertEqual(SubscriptionExporter.csvCell("+1+1"), "'+1+1")
        XCTAssertEqual(SubscriptionExporter.csvCell("-1+1"), "'-1+1")
        XCTAssertEqual(SubscriptionExporter.csvCell("@SUM(A1:A9)"), "'@SUM(A1:A9)")
        XCTAssertEqual(SubscriptionExporter.csvCell("\t=1+1"), "'\t=1+1")
        XCTAssertEqual(SubscriptionExporter.csvCell("=HYPERLINK(\"https://example.net\",\"Renew now\")"),
                       "\"'=HYPERLINK(\"\"https://example.net\"\",\"\"Renew now\"\")\"",
                       "made plain text first, then quoted like any cell with commas and quotes")
    }

    // MARK: - The file as a whole

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.billing.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// The spreadsheet file: headings in the reader's language, plain numbers, days written
    /// year-month-day. The renewal day is the next one, not the day typed in months ago, and something
    /// cancelled has none.
    @MainActor
    func testTheSpreadsheetIsReadableByAnySpreadsheetAndAnyReader() {
        let saved = UserDefaults.standard.object(forKey: L10n.languageKey)
        defer { UserDefaults.standard.set(saved, forKey: L10n.languageKey) }
        UserDefaults.standard.set("en", forKey: L10n.languageKey)

        let netflix = Subscription(name: "Netflix", category: "entertainment", amount: Decimal(string: "15.49")!, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: day(2026, 1, 31), createdAt: day(2026, 1, 3))
        let gone = Subscription(name: "=HYPERLINK(\"x\")", category: "music", amount: 1500, currency: "JPY",
                                billingFrequency: .yearly, nextBillingDate: day(2026, 6, 1), status: .cancelled, createdAt: day(2025, 6, 1))
        let csv = SubscriptionExporter.csv(for: [netflix, gone], now: day(2026, 11, 12))
        let lines = csv.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "Name,Category,Amount,Currency,Billing cycle,Status,Each month,Each year,Next payment,Tracking since")
        XCTAssertEqual(lines[1], "Netflix,Entertainment,15.49,USD,Monthly,Active,15.49,185.88,2026-11-30,2026-01-03")
        XCTAssertEqual(lines[2], "\"'=HYPERLINK(\"\"x\"\")\",Music,1500,JPY,Yearly,Cancelled,125,1500,,2025-06-01")

        UserDefaults.standard.set("fr", forKey: L10n.languageKey)
        let french = SubscriptionExporter.csv(for: [netflix], now: day(2026, 11, 12)).split(separator: "\n").map(String.init)
        XCTAssertNotEqual(french[0], lines[0], "the headings are in the reader's language")
        XCTAssertTrue(french[1].hasSuffix(",2026-11-30,2026-01-03"), "days and numbers are the same in every language")
        XCTAssertTrue(french[1].contains(",15.49,USD,"))
    }

    /// The printed page: every word in the reader's language (it was English throughout), totals in
    /// the display currency and marked when converted.
    @MainActor
    func testThePrintedPageIsInTheReadersLanguage() {
        let saved = UserDefaults.standard.object(forKey: L10n.languageKey)
        defer { UserDefaults.standard.set(saved, forKey: L10n.languageKey) }
        let list = [Subscription(name: "Netflix", category: "entertainment", amount: 10, currency: "USD", billingFrequency: .monthly),
                    Subscription(name: "DAZN", category: "sports", amount: 20, currency: "EUR", billingFrequency: .monthly, status: .cancelled)]

        UserDefaults.standard.set("en", forKey: L10n.languageKey)
        let english = SubscriptionExporter.pageText(for: list, now: day(2026, 11, 12), currency: "USD")
        XCTAssertEqual(english.title, "Your subscriptions")
        XCTAssertEqual(english.headings, ["Name", "Category", "Amount", "Billing cycle", "Status"])
        XCTAssertEqual(english.eachMonth, "Each month: \(MoneyFormat.string(Decimal(10), "USD"))", "only what is charging is counted")
        XCTAssertEqual(SubscriptionExporter.pageRow(for: list[1]).suffix(2), ["Monthly", "Cancelled"])

        UserDefaults.standard.set("de", forKey: L10n.languageKey)
        let german = SubscriptionExporter.pageText(for: list, now: day(2026, 11, 12), currency: "USD")
        XCTAssertEqual(german.title, "Ihre Abos")
        XCTAssertEqual(german.headings.last, "Status")
        XCTAssertTrue(german.madeOn.contains("November"), german.madeOn)
        XCTAssertNotEqual(german.headings, english.headings)
    }
}
