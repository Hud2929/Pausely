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
        XCTAssertEqual(lines[0], "Name,Category,Amount,Currency,Billing cycle,Status,Each month,Each year,Next renewal,Tracking since")
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

    /// The full file (JSON): the list, the history and the Pause Plan, in a form another tool can
    /// read back exactly. The privacy policy names it as one of the two machine-readable copies.
    @MainActor
    func testTheFullFileReadsBackAsTheSameListAndHistory() throws {
        let renews = day(2026, 11, 30)
        let netflix = Subscription(name: "Netflix", category: "entertainment", amount: Decimal(string: "15.49")!, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: renews, createdAt: day(2026, 1, 3))
        let dazn = Subscription(name: "DAZN \"Total\"", category: "sports", amount: Decimal(string: "44.99")!, currency: "EUR",
                                billingFrequency: .yearly, status: .cancelled, createdAt: day(2025, 8, 1))
        let cancelled = LifecycleEvent(kind: .cancelled, subscription: dazn, date: day(2026, 10, 2))

        let data = try SubscriptionExporter.json(for: [netflix, dazn], history: [cancelled], pausePlan: nil)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("\"amount\" : 15.49"), "the price as it was entered, not a rounding of it: \(text)")
        XCTAssertTrue(text.contains("\"amount\" : 44.99"))
        XCTAssertTrue(text.contains("\"currency\" : \"EUR\""))

        struct File: Decodable { let subscriptions: [Subscription]; let history: [LifecycleEvent]; let pausePlan: PausePlan? }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(File.self, from: data)
        XCTAssertEqual(file.subscriptions.map(\.name), ["Netflix", "DAZN \"Total\""])
        XCTAssertEqual(file.subscriptions.map(\.amount), [netflix.amount, dazn.amount])
        XCTAssertEqual(file.subscriptions.map(\.status), [.active, .cancelled])
        XCTAssertEqual(file.subscriptions[0].nextBillingDate, netflix.nextBillingDate)
        XCTAssertEqual(file.history, [cancelled])
        XCTAssertNil(file.pausePlan)

        XCTAssertEqual(try SubscriptionExporter.json(for: [netflix, dazn], history: [cancelled], pausePlan: nil), data,
                       "the same data makes the same file")
    }

    /// Each choice on the export screen makes the file it names, with only what was asked for.
    @MainActor
    func testEachFormatWritesItsOwnFile() throws {
        XCTAssertEqual(ExportFormat.allCases, [.csv, .pdf, .json])
        let list = [Subscription(name: "Netflix", category: "entertainment", amount: 10, currency: "USD", billingFrequency: .monthly),
                    Subscription(name: "DAZN", category: "sports", amount: 20, currency: "EUR", billingFrequency: .monthly, status: .cancelled)]
        func file(_ format: ExportFormat, cancelled: Bool) throws -> URL {
            let url = try XCTUnwrap(SubscriptionExporter.shared.export(subscriptions: list,
                                                                       options: ExportOptions(includeCancelled: cancelled, format: format)))
            addTeardownBlock { try? FileManager.default.removeItem(at: url) }
            return url
        }

        let spreadsheet = try file(.csv, cancelled: false)
        XCTAssertEqual(spreadsheet.pathExtension, "csv")
        let rows = try String(contentsOf: spreadsheet, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(rows.count, 2, "the headings and the one subscription still charging")

        let page = try file(.pdf, cancelled: true)
        XCTAssertEqual(page.pathExtension, "pdf")
        XCTAssertEqual(try Data(contentsOf: page).prefix(5), Data("%PDF-".utf8))

        let full = try file(.json, cancelled: true)
        XCTAssertEqual(full.pathExtension, "json")
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: full)) as? [String: Any])
        XCTAssertEqual((parsed["subscriptions"] as? [[String: Any]])?.compactMap { $0["name"] as? String }, ["Netflix", "DAZN"])
        XCTAssertNotNil(parsed["history"] as? [Any], "the history is in the file even when it is empty")

        let withoutCancelled = try file(.json, cancelled: false)
        let fewer = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: withoutCancelled)) as? [String: Any])
        XCTAssertEqual((fewer["subscriptions"] as? [[String: Any]])?.count, 1)
    }
}
