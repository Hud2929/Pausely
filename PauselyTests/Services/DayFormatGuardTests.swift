import XCTest
@testable import Pausely

/// A day is written one way everywhere, and a day that isn't in this year carries its year. On
/// 2026-11-22 a real scan said "Last charged Dec 26" and "Last charged Sep 3" about December and
/// September 2025: read in November 2026, both looked recent, and one looked like it hadn't happened.
final class DayFormatGuardTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testADayOutsideThisYearCarriesItsYear() {
        let now = day(2026, 11, 22)
        XCTAssertEqual(DayText.date(day(2026, 11, 10), locale: english, now: now, calendar: utc), "Nov 10")
        XCTAssertEqual(DayText.date(day(2025, 12, 26), locale: english, now: now, calendar: utc), "Dec 26, 2025")
        XCTAssertEqual(DayText.date(day(2025, 9, 3), locale: english, now: now, calendar: utc), "Sep 3, 2025")
        XCTAssertEqual(DayText.date(day(2027, 1, 5), locale: english, now: now, calendar: utc), "Jan 5, 2027",
                       "a coming day next year says so too")
        XCTAssertEqual(DayText.date(day(2026, 11, 26), locale: english, now: now, calendar: utc, weekday: true), "Thu, Nov 26")
    }

    func testFoundRowsSayTheYearOfAnOldCharge() {
        let now = day(2026, 11, 22)
        func found(last: Date?, subscribed: Date? = nil) -> ProvenSubscription {
            ProvenSubscription(id: "x", name: "Google One", merchantKey: "google one", category: nil, cancelURL: nil,
                               amount: 152.54, currency: "CAD", frequency: .yearly, lastChargeDate: last, nextBillingDate: nil,
                               status: .active, score: 70, tier: .likely, evidence: [], reasons: [], previousAmount: nil,
                               trialEndsOn: nil, subscribedOn: subscribed)
        }
        let lastYear = FoundRow.evidence(for: found(last: day(2025, 12, 26)), now: now)
        XCTAssertTrue(lastYear.contains("2025"), lastYear)
        XCTAssertTrue(lastYear.hasPrefix("Last charged"), lastYear)
        let thisYear = FoundRow.evidence(for: found(last: day(2026, 10, 20)), now: now)
        XCTAssertFalse(thisYear.contains("2026"), thisYear)
        XCTAssertEqual(FoundRow.evidence(for: found(last: nil, subscribed: day(2026, 5, 20)), now: now), "Subscribed on May\u{00A0}20")
    }

    /// No screen, widget or service formats a day itself: every one goes through `DayText.date`
    /// (`L10n.day` in the app). A month and day without a year is how the bug was written, in
    /// twenty-five places. Formats that always carry the year are allowed.
    func testNoDayIsFormattedByHand() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folders = ["Pausely", "Shared", "PauselyWidget"].map { root.appendingPathComponent($0) }
        try XCTSkipUnless(FileManager.default.fileExists(atPath: folders[0].path), "Sources aren't readable from this test run")
        let handMade = try NSRegularExpression(pattern: #"\.month\(\.(abbreviated|wide)\)\.day\(\)(?!\.year\(\))"#)
        var offenders: [String] = []
        for folder in folders {
            let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
            for file in files where file.lastPathComponent != "DayText.swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                let range = NSRange(text.startIndex..., in: text)
                if handMade.firstMatch(in: text, range: range) != nil { offenders.append(file.lastPathComponent) }
            }
        }
        XCTAssertEqual(offenders, [], "use L10n.day or DayText.date, which add the year when it isn't this year")
    }
}
