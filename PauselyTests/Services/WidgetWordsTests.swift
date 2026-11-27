import XCTest
@testable import Pausely

/// The widgets' words. Days ("today", "in 3 days") come from the system in every language, with its
/// plural forms; the few sentences the widgets do carry are in their own catalog, in all five
/// languages. Before, every widget string was English, with plurals built by hand.
final class WidgetWordsTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - Days

    func testTheWeekAheadIsSaidInWordsAndLaterDaysAsDates() {
        let english = Locale(identifier: "en_US")
        XCTAssertEqual(DayText.relative(daysAway: 0, locale: english), "today")
        XCTAssertEqual(DayText.relative(daysAway: 1, locale: english), "tomorrow")
        XCTAssertEqual(DayText.relative(daysAway: 3, locale: english), "in 3 days")

        let day = Calendar.billing.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 12))!
        XCTAssertEqual(DayText.text(daysAway: 7, day: day, locale: english), "in 7 days")
        XCTAssertEqual(DayText.text(daysAway: 8, day: day, locale: english), "Nov 28")
    }

    func testDaysAreSaidInEachOfTheAppsLanguages() {
        let english = DayText.relative(daysAway: 3, locale: Locale(identifier: "en"))
        for code in ["ar", "de", "es", "fr", "ja"] {
            let locale = Locale(identifier: code)
            let tomorrow = DayText.relative(daysAway: 1, locale: locale)
            let later = DayText.relative(daysAway: 3, locale: locale)
            XCTAssertFalse(tomorrow.isEmpty)
            XCTAssertNotEqual(tomorrow, "tomorrow", code)
            XCTAssertNotEqual(later, english, code)
        }
        XCTAssertEqual(DayText.relative(daysAway: 1, locale: Locale(identifier: "de")), "morgen")
        XCTAssertEqual(DayText.relative(daysAway: 1, locale: Locale(identifier: "fr")), "demain")
    }

    // MARK: - The widgets' own sentences

    /// Every sentence a widget shows (`Text("…")`, a configuration name or description, a
    /// `String(localized:)`) is in the widgets' catalog, in Arabic, German, Spanish, French and Japanese.
    func testEveryWidgetSentenceIsTranslated() throws {
        let folder = root.appendingPathComponent("PauselyWidget")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: folder.path), "Sources aren't readable from this test run")

        let catalogData = try Data(contentsOf: folder.appendingPathComponent("Localizable.xcstrings"))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])

        // Literals that reach the screen through a localized initialiser.
        let patterns = [#"Text\("((?:[^"\\]|\\.)+)"\)"#,
                        #"configurationDisplayName\("((?:[^"\\]|\\.)+)"\)"#,
                        #"\.description\("((?:[^"\\]|\\.)+)"\)"#,
                        #"String\(localized: "((?:[^"\\]|\\.)+)"\)"#,
                        #"return "((?:[^"\\]|\\.)+)""#,                 // a LocalizedStringKey chosen in code
                        #"\? "((?:[^"\\]|\\.)+)" : "((?:[^"\\]|\\.)+)"\)"#]  // Text(condition ? "a" : "b")
            .map { try! NSRegularExpression(pattern: $0) }

        var shown: Set<String> = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for pattern in patterns {
                for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    for group in 1..<match.numberOfRanges {
                        guard let range = Range(match.range(at: group), in: text) else { continue }
                        // "Then \(amount)" is the catalog key "Then %@".
                        let key = String(text[range]).replacingOccurrences(of: #"\\\([^)]*\)"#, with: "%@", options: .regularExpression)
                        shown.insert(key)
                    }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(shown.count, 10, "The scan found too few sentences to be reading the widgets")

        var missing: [String] = []
        for key in shown.sorted() {
            let localizations = strings[key]?["localizations"] as? [String: Any] ?? [:]
            for language in ["ar", "de", "es", "fr", "ja"] {
                let unit = (localizations[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                if (unit?["value"] as? String ?? "").isEmpty { missing.append("\(key) [\(language)]") }
            }
        }
        XCTAssertEqual(missing, [], "Shown by a widget and not translated")
        let pausePlan = strings["Pause Plan"]?["localizations"] as? [String: Any] ?? [:]
        for language in ["ar", "de", "es", "fr", "ja"] {
            let value = ((pausePlan[language] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String ?? ""
            XCTAssertFalse(value.contains("Pause Plan"), "Widget 'Pause Plan' must be translated in \(language)")
        }
    }

    /// Nothing a widget shows is built by gluing English words together.
    func testNoWidgetTextIsHandBuiltEnglish() throws {
        let folder = root.appendingPathComponent("PauselyWidget")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: folder.path), "Sources aren't readable from this test run")
        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            for (index, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated() {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }   // a comment may quote them
                let handBuilt = ["== 1 ? \"\" : \"s\"", "\"today\"", "\"tomorrow\"", " days\"", "\"subs\""]
                if handBuilt.contains(where: line.contains) { offenders.append("\(file.lastPathComponent):\(index + 1)") }
            }
        }
        XCTAssertEqual(offenders, [])
    }
}
