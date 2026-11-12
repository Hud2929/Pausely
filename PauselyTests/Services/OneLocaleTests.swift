import XCTest
@testable import Pausely

/// Everything the code builds (sentences, money, dates, day wording) is in one locale: the language
/// chosen in the app, with the iPhone's own region. Before, a chosen language had no region (so a
/// Canadian reading English saw "CA$" on their own currency), and about seventy money and date texts
/// ignored the choice altogether, which could put "Nov 12" in a Japanese sentence.
final class OneLocaleTests: XCTestCase {

    private var savedLanguage: Any?

    override func setUp() {
        super.setUp()
        savedLanguage = UserDefaults.standard.object(forKey: L10n.languageKey)
    }

    override func tearDown() {
        UserDefaults.standard.set(savedLanguage, forKey: L10n.languageKey)
        super.tearDown()
    }

    private let price = Decimal(string: "15.49")!

    func testAChosenLanguageKeepsTheIPhonesRegion() {
        let canada = Locale(identifier: "en_CA")
        let chosen = L10n.locale(language: "en", onDevice: canada)
        XCTAssertEqual(MoneyFormat.string(price, "CAD", locale: chosen), "$15.49")
        XCTAssertEqual(MoneyFormat.string(price, "USD", locale: chosen), "US$15.49")
        // What it used to be: a language with no region.
        XCTAssertEqual(MoneyFormat.string(price, "CAD", locale: Locale(identifier: "en")), "CA$15.49")

        let arabic = L10n.locale(language: "ar", onDevice: canada)
        XCTAssertEqual(arabic.language.languageCode?.identifier, "ar")
        XCTAssertEqual(arabic.region?.identifier, "CA")
    }

    func testEnglishChosenOnAnArabicIPhoneIsWrittenWithLatinDigits() {
        let chosen = L10n.locale(language: "en", onDevice: Locale(identifier: "ar_SA"))
        XCTAssertTrue(MoneyFormat.string(price, "SAR", locale: chosen).contains("15.49"))
        XCTAssertEqual(chosen.region?.identifier, "SA")
    }

    func testMoneyDatesAndDaysAllFollowTheChosenLanguage() {
        UserDefaults.standard.set("de", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.locale.language.languageCode?.identifier, "de")
        // German words, this iPhone's region: what an iPhone set to German in the same region shows.
        let region = Locale.current.region?.identifier ?? "US"
        XCTAssertEqual(MoneyFormat.string(price, "EUR"), MoneyFormat.string(price, "EUR", locale: Locale(identifier: "de_\(region)")))
        XCTAssertEqual(MoneyFormat.string(price, "EUR", locale: L10n.locale(language: "de", onDevice: Locale(identifier: "en_DE"))), "15,49\u{00A0}€")
        XCTAssertEqual(L10n.relativeDay(1), "morgen")
        XCTAssertEqual(L10n.relativeDay(0, capitalized: true), "Heute")
        XCTAssertEqual(L10n.relativeDay(-3), "vor 3 Tagen")
        let november = Calendar.billing.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12))!
        XCTAssertEqual(november.formatted(.dateTime.month(.wide).locale(L10n.locale)), "November")

        UserDefaults.standard.set("ja", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.relativeDay(1), "明日")
        XCTAssertEqual(november.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale)), "11月12日")

        UserDefaults.standard.set("system", forKey: L10n.languageKey)
        XCTAssertNil(L10n.chosenLocale)
        XCTAssertEqual(L10n.locale.identifier, Locale.current.identifier)
    }

    func testDirectionFollowsTheChosenLanguage() {
        UserDefaults.standard.set("ar", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.isRightToLeft, true)
        UserDefaults.standard.set("en", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.isRightToLeft, false)
        UserDefaults.standard.set("system", forKey: L10n.languageKey)
        XCTAssertNil(L10n.isRightToLeft, "the iPhone decides")
    }

    /// No date, duration or number is formatted without saying in which locale, no language is turned
    /// into a locale by its code alone, and no day phrase is put together by hand.
    func testNothingIsFormattedInAnotherLocale() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path), "Sources aren't readable from this test run")
        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let name = String(file.path.dropFirst(root.path.count + 1))
            for (index, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated() {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }
                let formatsWithoutLocale = (line.contains(".formatted(.dateTime") || line.contains(".formatted(.units(")
                                            || line.contains(".formatted(.number")) && !line.contains("locale")
                let bareLanguage = line.contains("Locale(identifier: appLanguage)") || line.contains("Locale(identifier: code)")
                let handBuiltDay = line.contains("L10n.string(\"today\")") || line.contains("L10n.string(\"tomorrow\")")
                    || line.contains("L10n.string(\"Tomorrow\")")
                if formatsWithoutLocale || bareLanguage || handBuiltDay { offenders.append("\(name):\(index + 1)") }
            }
        }
        XCTAssertEqual(offenders, [])
    }
}
