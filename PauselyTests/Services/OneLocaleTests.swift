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

    // MARK: - Counts

    /// A count takes the form its number needs in each language: one or many in English, six forms in
    /// Arabic, none in Japanese. Before, every language had one form, so English said "1 subscriptions"
    /// and Arabic used the 3-to-10 form for every number.
    func testCountsTakeTheFormTheirNumberNeeds() {
        func subscriptions(_ count: Int) -> String { L10n.string("\(count) subscriptions") }

        UserDefaults.standard.set("en", forKey: L10n.languageKey)
        XCTAssertEqual(subscriptions(1), "1 subscription")
        XCTAssertEqual(subscriptions(2), "2 subscriptions")
        XCTAssertEqual(subscriptions(0), "0 subscriptions")
        XCTAssertEqual(L10n.string("\(1) subscriptions have no renewal date"), "1 subscription has no renewal date")
        XCTAssertEqual(L10n.string("Save \(1) dates"), "Save 1 date")

        UserDefaults.standard.set("ar", forKey: L10n.languageKey)
        let arabic = [0, 1, 2, 5, 11, 100].map(subscriptions)
        XCTAssertEqual(Set(arabic).count, 6, "\(arabic)")
        XCTAssertEqual(subscriptions(2), "اشتراكان")
        XCTAssertEqual(subscriptions(1), "اشتراك واحد")

        UserDefaults.standard.set("fr", forKey: L10n.languageKey)
        XCTAssertEqual(subscriptions(1), "1 abonnement")
        XCTAssertEqual(subscriptions(0), "0 abonnement", "French counts none as one")
        XCTAssertEqual(subscriptions(2), "2 abonnements")

        UserDefaults.standard.set("de", forKey: L10n.languageKey)
        XCTAssertEqual(subscriptions(1), "1 Abo")
        XCTAssertEqual(subscriptions(7), "7 Abos")

        UserDefaults.standard.set("ja", forKey: L10n.languageKey)
        XCTAssertEqual(subscriptions(3), "3件のサブスク")
    }

    /// German addresses the reader one way throughout: formally. It used to say "du" on some screens and
    /// "Sie" on others, sometimes in the same flow.
    func testGermanAddressesTheReaderOneWay() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var informal: [String] = []
        for path in ["Pausely/Localizable.xcstrings", "PauselyWidget/Localizable.xcstrings", "Pausely/AppShortcuts.xcstrings"] {
            let url = root.appendingPathComponent(path)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
            let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])
            for (_, entry) in strings {
                guard let german = (entry["localizations"] as? [String: Any])?["de"] as? [String: Any] else { continue }
                var texts: [String] = []
                if let unit = german["stringUnit"] as? [String: Any], let value = unit["value"] as? String { texts.append(value) }
                if let forms = (german["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]] {
                    texts += forms.values.compactMap { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
                }
                informal += texts.filter {
                    $0.range(of: #"\b(du|dich|dir|dein|deine|deinen|deiner|deinem|deines)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
                }
                // A command needs no pronoun to be informal ("Tippe auf …"). These are the forms a
                // translator reaches for; the formal ones end in "-en Sie".
                informal += texts.filter { text in
                    text.components(separatedBy: CharacterSet(charactersIn: ".!?:\n")).contains { sentence in
                        sentence.trimmingCharacters(in: .whitespaces)
                            .range(of: Self.informalGermanCommand, options: .regularExpression) != nil
                    }
                }
            }
        }
        XCTAssertEqual(informal.sorted(), [])
        // The rule itself: it must catch the informal command and let the formal one through.
        XCTAssertNotNil("Tippe auf %@".range(of: Self.informalGermanCommand, options: .regularExpression))
        XCTAssertNil("Tippen Sie auf %@".range(of: Self.informalGermanCommand, options: .regularExpression))
        XCTAssertNil("Suche läuft".range(of: Self.informalGermanCommand, options: .regularExpression), "a noun, not a command")
    }

    /// A subscription has one word in each language. German says "Abo" and Japanese "サブスク"; the long
    /// forms appear only where a sentence names Apple's own Settings menu. And the first tab is the
    /// start of the app, not a house ("Zuhause", "Hogar" and "Maison" all shipped).
    func testASubscriptionAndTheFirstTabHaveOneWordInEachLanguage() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Pausely/Localizable.xcstrings")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])
        func value(_ key: String, _ language: String) -> String? {
            let unit = ((strings[key]?["localizations"] as? [String: Any])?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
            return unit?["value"] as? String
        }
        var strays: [String] = []
        for key in strings.keys {
            if let german = value(key, "de"), german.contains("Abonnement"),
               !german.contains("Einstellungen"), !german.contains("„Abonnements“") { strays.append(german) }
            if let japanese = value(key, "ja") {
                let outsideQuotes = japanese.replacingOccurrences(of: "「[^」]*」", with: "", options: .regularExpression)
                if outsideQuotes.contains("サブスクリプション") { strays.append(japanese) }
            }
        }
        XCTAssertEqual(strays.sorted(), [])
        XCTAssertEqual(value("Home", "de"), "Start")
        XCTAssertEqual(value("Home", "es"), "Inicio")
        XCTAssertEqual(value("Home", "fr"), "Accueil")
    }

    /// A sentence that opens with the "du" form of a command, not followed by "Sie". Words that are also
    /// nouns ("Suche", "Teile", "Stelle") are left out: a heading may open with them.
    private static let informalGermanCommand = "^(Tippe|Füge|Wähle|Gib|Öffne|Prüfe|Kündige|Behalte|Schau|Schaue|Sieh|Lies|Melde|Erstelle"
        + "|Verbinde|Aktiviere|Lass|Versuch|Versuche|Geh|Gehe|Nimm|Trag|Trage|Starte|Entscheide|Bestätige|Ändere|Setze"
        + "|Zeig|Zeige|Lösche|Entferne|Schalte|Erlaube|Warte|Hol|Hole|Schreib|Schreibe|Sende|Fordere|Nutze"
        + "|Verwende|Mach|Mache|Lege|Finde|Halte|Scrolle|Ziehe|Wische|Drücke|Klicke) (?!Sie\\b)"

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
