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
                let texts = CatalogTexts.all(in: german)
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

    /// English labels are written the way the rest of the app talks: sentence case ("Try again", never
    /// "Try Again"), with capitals kept for names. And the day a subscription renews has one name,
    /// the renewal date; it used to be the "payment date" on three screens.
    func testEnglishLabelsAreInSentenceCaseAndTheRenewalDateHasOneName() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Pausely/Localizable.xcstrings")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let keys = try XCTUnwrap(catalog["strings"] as? [String: Any]).keys

        XCTAssertEqual(keys.filter { Self.isInTitleCase($0) }.sorted(), [])
        XCTAssertEqual(keys.filter { $0.localizedCaseInsensitiveContains("payment date") }.sorted(), [])
        XCTAssertEqual(keys.filter { $0 == "Custom" || $0 == "Add Custom" }.sorted(), [], "it is \"Add your own\"")

        // The rule itself.
        XCTAssertTrue(Self.isInTitleCase("Try Again"))
        XCTAssertTrue(Self.isInTitleCase("Open Cancellation Page"))
        XCTAssertFalse(Self.isInTitleCase("Try again"))
        XCTAssertFalse(Self.isInTitleCase("See your Savings Receipt"))
        XCTAssertFalse(Self.isInTitleCase("Start Pause Plan with Pro"))
    }

    /// A label (no sentence punctuation) with a capitalised word after its first that isn't a name.
    private static func isInTitleCase(_ key: String) -> Bool {
        // The Shortcuts app titles its actions and their fields in title case; these appear only there.
        let shortcutTitles: Set = ["Add Subscription", "Get Monthly Spend", "Get Upcoming Renewals",
                                   "Get Subscription Detail", "Days Ahead", "Monthly Cost", "Subscription Name"]
        guard !shortcutTitles.contains(key), key.rangeOfCharacter(from: CharacterSet(charactersIn: ".,:")) == nil else { return false }
        var label = key
        for name in ["Pausely Pro", "Pause Plan", "Savings Receipt", "Pausely Promise", "Find in Email", "Privacy Policy",
                     "Terms of Service", "App Store", "Apple Account", "Screen Time"] {
            label = label.replacingOccurrences(of: name, with: " ")
        }
        let names: Set = ["Pausely", "Apple", "Google", "Microsoft", "Gmail", "Outlook", "IMAP", "Pro", "OK", "AI", "GMX",
                          "WEB.DE", "Zoho", "Fastmail", "Netflix", "Spotify", "iPhone", "I", "Home", "Subscriptions", "Settings"]
        let words = label.split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'" || $0 == ".") }).map(String.init)
        return words.dropFirst().contains { word in
            guard let first = word.first else { return false }
            return first.isUppercase && !names.contains(word)
        }
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

    /// A count on screen is written in the reader's digits. Section counts and the first-run slip
    /// showed "5" beside "٧ اشتراكات" in Arabic, because a bare number in a string is always Latin.
    func testACountIsWrittenInTheReadersDigits() throws {
        XCTAssertEqual(L10n.number(5, locale: Locale(identifier: "en_CA")), "5")
        XCTAssertEqual(L10n.number(5, locale: Locale(identifier: "ar_SA")), "٥")
        XCTAssertEqual(L10n.number(1234, locale: Locale(identifier: "de_DE")), "1.234")

        // No view puts a bare count on screen.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let views = root.appendingPathComponent("Pausely/Views")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: views.path), "Sources aren't readable from this test run")
        let bareCount = #""\\\([A-Za-z_.\[\]0-9]*(\.count|Count|index \+ 1)\)""#
        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            for (index, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated()
            where line.range(of: bareCount, options: .regularExpression) != nil && !line.contains("L10n.string(") {
                offenders.append("\(file.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertEqual(offenders, [])
        XCTAssertNotNil(#"Text(verbatim: "\(section.subscriptions.count)")"#.range(of: bareCount, options: .regularExpression))
        XCTAssertNotNil(#"ProofLine(label: label, value: "\(stats.cancelledCount)")"#.range(of: bareCount, options: .regularExpression),
                        "the year's slip said 7 and 3 in Latin digits beside Arabic amounts")
    }

    /// A sentence takes its direction from its first letter. An Arabic one that begins with a name in
    /// Latin letters ("Pausely Pro بسعر …") was laid out left to right, so on two lines it read from
    /// the middle: the name sat at the end of the first line and the full stop at the start of the
    /// second. A right-to-left mark in front of the name keeps the sentence Arabic.
    func testAnArabicSentenceThatBeginsWithANameIsStillReadRightToLeft() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var leftToRight: [String] = []
        var marked = 0
        for path in ["Pausely/Localizable.xcstrings", "PauselyWidget/Localizable.xcstrings", "Pausely/AppShortcuts.xcstrings"] {
            let url = root.appendingPathComponent(path)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
            let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])
            for (_, entry) in strings {
                guard let arabic = (entry["localizations"] as? [String: Any])?["ar"] as? [String: Any] else { continue }
                let texts = CatalogTexts.all(in: arabic)
                leftToRight += texts.filter { Self.beginsLeftToRight($0) }
                marked += texts.filter { $0.hasPrefix("\u{200F}") }.count
            }
        }
        XCTAssertEqual(leftToRight.sorted(), [])
        XCTAssertGreaterThanOrEqual(marked, 11, "the sentences that begin with Pausely, Gmail or GMX")
        XCTAssertTrue(Self.beginsLeftToRight("Pausely Pro بسعر %@ في السنة."))
        XCTAssertFalse(Self.beginsLeftToRight("\u{200F}Pausely Pro بسعر %@ في السنة."))
        XCTAssertFalse(Self.beginsLeftToRight("%@ يتجدد غدًا"), "a name that arrives as an argument is kept apart by the system")
        XCTAssertFalse(Self.beginsLeftToRight("Pausely Pro"), "a name alone is not a sentence")
    }

    /// True for text with Arabic in it whose first letter is not Arabic and has no right-to-left
    /// mark before it. Placeholders are skipped: what fills them is set apart from the sentence.
    private static func beginsLeftToRight(_ text: String) -> Bool {
        let arabic: ClosedRange<UInt32> = 0x0600...0x06FF
        guard text.unicodeScalars.contains(where: { arabic.contains($0.value) }) else { return false }
        let sentence = text.replacingOccurrences(of: #"%(\d+\$)?(lld|ld|d|@)"#, with: "", options: .regularExpression)
        for scalar in sentence.unicodeScalars {
            if scalar.value == 0x200F || arabic.contains(scalar.value) { return false }
            if scalar.properties.isAlphabetic { return true }
        }
        return false
    }

    /// Arabic is written with Arabic-Indic digits in some regions and Latin ones in others, and the
    /// system picks for every number the code formats. A digit typed into a translation cannot follow,
    /// so the receipt read "خلال 12 شهرًا" beside "٤٧٫٩٧": the sentences spell their numbers instead.
    func testArabicSentencesSpellTheirNumbers() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        // Names that are written with a digit everywhere: a protocol and the port it uses.
        let names = ["POP3", "993"]
        var typed: [String] = []
        for path in ["Pausely/Localizable.xcstrings", "PauselyWidget/Localizable.xcstrings", "Pausely/AppShortcuts.xcstrings"] {
            let url = root.appendingPathComponent(path)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
            let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])
            for (_, entry) in strings {
                guard let arabic = (entry["localizations"] as? [String: Any])?["ar"] as? [String: Any] else { continue }
                let texts = CatalogTexts.all(in: arabic)
                typed += texts.filter { Self.hasATypedDigit($0, besides: names) }
            }
        }
        XCTAssertEqual(typed.sorted(), [])
        XCTAssertTrue(Self.hasATypedDigit("المتوقع خلال 12 شهرًا: %@", besides: names))
        XCTAssertFalse(Self.hasATypedDigit("إلغاءاتك في طريقها لتوفير %1$@ خلال اثني عشر شهرًا، أي %2$@× تكلفة Pausely", besides: names))
        XCTAssertFalse(Self.hasATypedDigit("عادةً المنفذ 993", besides: names))
    }

    /// A digit in the text itself: not one inside a placeholder ("%1$@", "%lld") or a name.
    private static func hasATypedDigit(_ text: String, besides names: [String]) -> Bool {
        var rest = text.replacingOccurrences(of: #"%(\d+\$)?(lld|ld|d|@)"#, with: "", options: .regularExpression)
        for name in names { rest = rest.replacingOccurrences(of: name, with: "") }
        return rest.range(of: "[0-9]", options: .regularExpression) != nil
    }

    /// Currencies are named by the system in the reader's language and found by typing in it. They
    /// were English names on every screen, and only English found them.
    func testCurrenciesAreNamedAndFoundInTheReadersLanguage() throws {
        let all = CurrencyManager.shared.allCurrencies
        let dollar = try XCTUnwrap(all.first { $0.code == "USD" })
        let yen = try XCTUnwrap(all.first { $0.code == "JPY" })
        XCTAssertEqual(dollar.localizedName(in: Locale(identifier: "ja_JP")), "米ドル")
        XCTAssertEqual(dollar.localizedName(in: Locale(identifier: "de_DE")), "US-Dollar")
        XCTAssertEqual(dollar.localizedName(in: Locale(identifier: "fr_FR")), "Dollar des États-Unis")
        XCTAssertEqual(dollar.localizedName(in: Locale(identifier: "es_ES")), "Dólar estadounidense")
        XCTAssertEqual(yen.localizedName(in: Locale(identifier: "ar_SA")), "ين ياباني")

        let spanish = Locale(identifier: "es_ES")
        XCTAssertTrue(dollar.matches("dolar", in: spanish), "found without its accent")
        XCTAssertTrue(dollar.matches("usd", in: spanish))
        XCTAssertTrue(dollar.matches("US Dollar", in: spanish), "the English name still finds it")
        XCTAssertFalse(dollar.matches("yen", in: spanish))
        XCTAssertTrue(yen.matches("円", in: Locale(identifier: "ja_JP")))
        XCTAssertTrue(dollar.matches("  ", in: spanish), "an empty search shows everything")

        // Every currency offered has a name in each of the app's languages, never its bare code.
        for language in ["ar", "de", "en", "es", "fr", "ja"] {
            let locale = Locale(identifier: language)
            XCTAssertEqual(all.filter { $0.localizedName(in: locale) == $0.code }.map(\.code), [], language)
        }
    }

    /// A price and its period are one phrase from the catalog, in the order the language wants.
    /// Joined by hand, Japanese read "¥500 月額" and VoiceOver said the period as a stray word.
    func testAPriceAndItsPeriodAreOnePhraseInTheReadersOrder() {
        UserDefaults.standard.set("en", forKey: L10n.languageKey)
        XCTAssertEqual(BillingFrequency.monthly.priced("$4.99"), "$4.99 a month")
        XCTAssertEqual(BillingFrequency.biweekly.priced("$4.99"), "$4.99 every 2 weeks")
        XCTAssertEqual(BillingFrequency.yearly.pricedShort("$29.99"), "$29.99/yr")

        UserDefaults.standard.set("ja", forKey: L10n.languageKey)
        XCTAssertEqual(BillingFrequency.monthly.priced("¥500"), "月¥500")
        XCTAssertEqual(BillingFrequency.yearly.priced("¥5,000"), "年¥5,000")
        XCTAssertEqual(BillingFrequency.quarterly.priced("¥1,500"), "3か月ごとに¥1,500")

        UserDefaults.standard.set("de", forKey: L10n.languageKey)
        XCTAssertEqual(BillingFrequency.weekly.priced("4,99 €"), "4,99 € pro Woche")
    }

    /// Outside the two functions that do it, no line puts a period word after a price with "+" or
    /// drops one into a sentence the catalog never sees.
    func testNoScreenJoinsAPriceToItsPeriodByHand() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path), "Sources aren't readable from this test run")
        let joinedWithPlus = #"\+\s*("\s*"\s*\+\s*)?([A-Za-z_.]+\.(billingPeriodLabel|shortDisplay|period)\b|L10n\.string\("(/|a month|a year|per |every ))"#
        let droppedIntoText = #"\\\([^)]*\.(billingPeriodLabel|shortDisplay)\)"#
        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let name = String(file.path.dropFirst(root.path.count + 1))
            if name == "Pausely/Models/Subscription.swift" { continue }
            for (index, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated() {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") { continue }
                let plus = line.range(of: joinedWithPlus, options: .regularExpression) != nil
                let inText = line.range(of: droppedIntoText, options: .regularExpression) != nil && !line.contains("L10n.string(")
                if plus || inText { offenders.append("\(name):\(index + 1)") }
            }
        }
        XCTAssertEqual(offenders, [])
        // The rule itself.
        XCTAssertNotNil(#"priceText + " " + found.billingFrequency.billingPeriodLabel"#.range(of: joinedWithPlus, options: .regularExpression))
        XCTAssertNotNil(#"format(now) + " " + L10n.string("a month")"#.range(of: joinedWithPlus, options: .regularExpression))
        XCTAssertNotNil(#""\(charge) \(sub.billingFrequency.billingPeriodLabel)""#.range(of: droppedIntoText, options: .regularExpression))
        XCTAssertNil(#"found.billingFrequency.priced(priceText)"#.range(of: joinedWithPlus, options: .regularExpression))
    }
}
