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
}
