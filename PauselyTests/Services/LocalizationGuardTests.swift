import XCTest
@testable import Pausely

/// Keeps translations complete. Fails with file:line when:
/// 1. a string built in code (`L10n.string("…")`, anywhere in the app) has no entry in all five languages;
/// 2. a literal on any screen (`Text`, `Label`, `Button`, titles, field labels, accessibility, the app's
///    own labelled parts) is missing a language, or an English sentence is shown with `Text(verbatim:)`;
/// 3. any translation in the catalog has different format specifiers from its key (a missing `%@` shows
///    the wrong text; an extra one can crash).
final class LocalizationGuardTests: XCTestCase {

    private static let languages = ["ar", "de", "es", "fr", "ja"]
    /// Everything that draws a screen. The DEBUG-only gallery of design parts is not a screen people see.
    private static let screenFiles = ["Pausely/Views", "Pausely/DesignSystem", "Pausely/ContentView.swift"]
    private static let notScreens = ["DesignGalleryView.swift"]
    /// Every way a literal reaches the screen: SwiftUI's own calls, and the labelled arguments of the app's
    /// own parts (`SettingsPage(title:)`, `SettingsSection(footer:)`, `FormHeader(detail:)` and the like).
    private static let screenCalls = [
        "Text(\"", "Label(\"", "Button(\"", "LeaveButton(\"", "Toggle(\"", "Picker(\"", "Section(\"", "Link(\"", "Menu(\"",
        ".navigationTitle(\"", ".accessibilityLabel(\"", ".accessibilityHint(\"", ".accessibilityValue(\"",
        "TextField(\"", "SecureField(\"", ".alert(\"", ".confirmationDialog(\"",
        "title: \"", "detail: \"", "footer: \"", "subtitle: \"", "label: \"", "header: \"", "message: \"", "prompt: \""
    ]

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func catalog() throws -> [String: [String: Any]] {
        let url = root.appendingPathComponent("Pausely/Localizable.xcstrings")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "source tree not available")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return json?["strings"] as? [String: [String: Any]] ?? [:]
    }

    // MARK: Source scanning

    private struct Found { let file: String; let line: Int; let literal: String }

    /// The string literal starting at `start` (just after the opening quote), with interpolations kept as
    /// `\(…)`. Handles nested literals inside interpolations.
    private static func literal(in chars: [Character], from start: Int) -> String? {
        var i = start
        var out = ""
        while i < chars.count {
            let c = chars[i]
            if c == "\"" { return out }
            if c == "\\", i + 1 < chars.count, chars[i + 1] == "(" {
                // Skip the interpolation, tracking parentheses and nested strings.
                var depth = 0
                var j = i + 1
                var inString = false
                while j < chars.count {
                    let d = chars[j]
                    if inString {
                        if d == "\\" { j += 2; continue }
                        if d == "\"" { inString = false }
                    } else {
                        if d == "\"" { inString = true }
                        if d == "(" { depth += 1 }
                        if d == ")" { depth -= 1; if depth == 0 { break } }
                    }
                    j += 1
                }
                out += "\\(…)"
                i = j + 1
                continue
            }
            if c == "\\", i + 1 < chars.count { out.append(chars[i + 1]); i += 2; continue }
            if c == "\n" { return nil }
            out.append(c)
            i += 1
        }
        return nil
    }

    private func scan(_ paths: [String], calls: [String]) throws -> [Found] {
        var found: [Found] = []
        for path in paths {
            let base = root.appendingPathComponent(path)
            var files: [URL] = []
            if path.hasSuffix(".swift") { files = [base] } else if let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) {
                files = e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
            }
            for file in files {
                let text = try String(contentsOf: file, encoding: .utf8)
                let chars = Array(text)
                let source = String(chars)
                for call in calls {
                    var searchStart = source.startIndex
                    while let range = source.range(of: call, range: searchStart..<source.endIndex) {
                        let offset = source.distance(from: source.startIndex, to: range.upperBound)
                        if let literal = Self.literal(in: chars, from: offset), literal.contains(where: \.isLetter) {
                            let line = source[..<range.lowerBound].filter { $0 == "\n" }.count + 1
                            found.append(Found(file: file.path.replacingOccurrences(of: root.path + "/", with: ""), line: line, literal: literal))
                        }
                        searchStart = range.upperBound
                    }
                }
            }
        }
        return found
    }

    /// Catalog key for a source literal: each interpolation becomes a format specifier.
    private static func matchingKey(_ literal: String, in keys: [String]) -> String? {
        if !literal.contains("\\(…)") { return keys.contains(literal) ? literal : nil }
        // A literal "%" in source is "%%" in the catalog key.
        let pattern = "^" + literal.components(separatedBy: "\\(…)")
            .map { NSRegularExpression.escapedPattern(for: $0.replacingOccurrences(of: "%", with: "%%")) }
            .joined(separator: "%(?:lld|ld|d|@|lf|f|\\.\\d+f)") + "$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return keys.first { regex.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
    }

    private static func missingLanguages(_ entry: [String: Any]?) -> [String] {
        let localizations = entry?["localizations"] as? [String: Any] ?? [:]
        return languages.filter { localizations[$0] == nil }
    }

    // MARK: Tests

    func testEveryCodeBuiltStringIsTranslated() throws {
        let strings = try catalog()
        let keys = Array(strings.keys)
        let found = try scan(["Pausely"], calls: ["L10n.string(\""])
        XCTAssertGreaterThan(found.count, 100, "the scan should see the app's code-built strings")
        var failures: [String] = []
        for item in found {
            guard let key = Self.matchingKey(item.literal, in: keys) else {
                failures.append("\(item.file):\(item.line) no catalog entry for \"\(item.literal)\""); continue
            }
            let missing = Self.missingLanguages(strings[key])
            if !missing.isEmpty { failures.append("\(item.file):\(item.line) \"\(key)\" missing \(missing)") }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    /// Errors are shown to people as they are: a bare literal inside a MailboxError would stay in English.
    func testMailboxErrorsAreNeverBareEnglish() throws {
        let calls = ["notConfigured", "authFailed", "network", "server", "insecure"].map { ".\($0)(\"" }
        let found = try scan(["Pausely/Services/Mailbox"], calls: calls)
            .filter { !$0.literal.hasPrefix("HTTP ") }   // a status code, the same in every language
        XCTAssertTrue(found.isEmpty, found.map { "\($0.file):\($0.line) wrap in L10n.string: \"\($0.literal)\"" }.joined(separator: "\n"))
    }

    /// Every literal on every screen exists in all five languages. Until 2026-11-11 this looked only at the
    /// mail screens, and the settings screens shipped in English in every language.
    func testEveryScreenIsTranslated() throws {
        let strings = try catalog()
        let keys = Array(strings.keys)
        let found = try scan(Self.screenFiles, calls: Self.screenCalls)
            .filter { item in !Self.notScreens.contains { item.file.hasSuffix($0) } }
        XCTAssertGreaterThan(found.count, 300, "the scan should see the app's screens")
        var failures: [String] = []
        for item in found {
            guard let key = Self.matchingKey(item.literal, in: keys) else {
                failures.append("\(item.file):\(item.line) no catalog entry for \"\(item.literal)\""); continue
            }
            let missing = Self.missingLanguages(strings[key])
            if !missing.isEmpty { failures.append("\(item.file):\(item.line) \"\(key)\" missing \(missing)") }
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count) untranslated:\n" + failures.joined(separator: "\n"))
    }

    /// A translation is only used when the words reach a `LocalizedStringKey` or `L10n.string`. Handed
    /// to a parameter typed `String` they stay English in every language, and the test above is content
    /// because the catalog has them. The edit screen's four rows did this from the day it was built
    /// ("Billing cycle", "Next renewal", "Category", "Remind me"), and so did "Sign out" on the age check.
    func testNoTranslatedWordsAreHandedToAPlainStringParameter() throws {
        let keys = Array(try catalog().keys)
        func names(_ pattern: String, in text: String) throws -> [String] {
            let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            }
        }
        var files: [URL] = []
        for path in Self.screenFiles {
            let base = root.appendingPathComponent(path)
            files += path.hasSuffix(".swift") ? [base]
                : (FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? [])
        }
        files = files.filter { $0.pathExtension == "swift" && !Self.notScreens.contains($0.lastPathComponent) }
        XCTAssertGreaterThan(files.count, 40, "the scan should see the app's screens")

        // Read from the declarations. A helper whose first argument is a plain String is checked in its
        // own file (they are private, and two files may each have a `row`). An argument or property
        // typed String is checked everywhere by its name, unless the same name is declared as a
        // localised key somewhere: those can't be told apart by name, and are left to the Arabic
        // screen tour (`scripts/tour_untranslated.py`), which reads what the screens really show.
        var plain: Set<String> = [], keyed: Set<String> = []
        var found: [Found] = []
        var helpersSeen: Set<String> = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let helpers = Set(try names(#"func (\w+)(?:<[^>]*>)?\(_ \w+: String\b"#, in: text))
            helpersSeen.formUnion(helpers)
            plain.formUnion(try names(#"\b(\w+): String\??(?: =|,|\)|$)"#, in: text))
            keyed.formUnion(try names(#"\b(\w+): (?:LocalizedStringKey|LocalizedStringResource|Text)\b"#, in: text))
            let path = file.path.replacingOccurrences(of: root.path + "/", with: "")
            found += try scan([path], calls: helpers.map { "\($0)(\"" })
        }
        XCTAssertTrue(helpersSeen.contains("valueLabel"), "the scan should see the edit screen's helpers")
        XCTAssertTrue(keyed.contains("cancelTitle"), "the age check's button takes a localised key")
        // A category is stored under its English name and shown through `localizedLabel`.
        let storedValues: Set = ["category"]
        found += try scan(Self.screenFiles, calls: plain.subtracting(keyed).subtracting(storedValues).map { "\($0): \"" })
            .filter { item in !Self.notScreens.contains { item.file.hasSuffix($0) } }
        let stayEnglish = found.filter { Self.matchingKey($0.literal, in: keys) != nil }
        XCTAssertEqual(stayEnglish.map { "\($0.file):\($0.line) \"\($0.literal)\" is in the catalog but stays English here" }, [])
    }

    /// A sentence that is assigned, returned or picked by a condition as plain text never meets the
    /// catalog. Two were found on 2026-11-12, both English in every language: the age check's
    /// "You can try again in about 3 hours." (built by hand, with an "s" added for the plural) and
    /// the mail server's fallbacks ("The server refused the request." chosen when the server says
    /// nothing), which the test for mail errors could not see behind their `?`.
    func testNoEnglishSentenceIsAssignedReturnedOrChosenAsPlainText() throws {
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path), "source tree not available")
        var found: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" && !Self.demoFiles.contains(file.lastPathComponent) {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where Self.holdsABareSentence(line) {
                found.append("\(file.lastPathComponent):\(index + 1) \(line.trimmingCharacters(in: .whitespaces).prefix(100))")
            }
        }
        XCTAssertEqual(found, [])
        // The rule sees the two it was written for, and lets their repairs through.
        XCTAssertTrue(Self.holdsABareSentence(#"lockoutText = "You can try again in about \(hours) hour\(hours == 1 ? "" : "s").""#))
        XCTAssertTrue(Self.holdsABareSentence(#"throw MailboxError.server(text.isEmpty ? "The server refused the request." : text)"#))
        XCTAssertFalse(Self.holdsABareSentence(#"throw MailboxError.server(text.isEmpty ? L10n.string("The server refused the request.") : text)"#))
        XCTAssertFalse(Self.holdsABareSentence(#"Text(isRemoving ? "Removing…" : "Remove from Pausely")"#), "a choice inside Text is a key")
        XCTAssertFalse(Self.holdsABareSentence(#"let key = "saved_list_is_demo""#))
    }

    /// DEBUG-only sample data and the gallery of design parts: made-up sentences nobody ships.
    private static let demoFiles: Set<String> = ["DesignGalleryView.swift", "DemoSubscriptions.swift", "DemoSavings.swift", "DemoTally.swift"]

    /// True when the line assigns, returns or picks (`? "…"`, `"…" : "…"`) a literal of three or more
    /// words and nothing on the line gives it to the catalog.
    private static func holdsABareSentence(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("//") else { return false }
        let translated = ["L10n.string(", "Text(", "LocalizedStringKey", "LocalizedStringResource", ".accessibilityHint(",
                          ".accessibilityLabel(", ".accessibilityValue(", "Button(", "Label(", "NSRegularExpression", "pattern",
                          "os_log", "PauselyLogger", "print(", "#Preview"]
        guard !translated.contains(where: line.contains) else { return false }
        guard let literal = try? NSRegularExpression(pattern: #"(?:(?:=|return|\?)\s+|"\s+:\s+)"((?:[^"\\]|\\.)*)""#) else { return false }
        for match in literal.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            guard let range = Range(match.range(at: 1), in: line) else { continue }
            let text = String(line[range])
            if text.contains("\\\\") || text.contains("(?:") { continue }   // a pattern, not a sentence
            let plain = text.replacingOccurrences(of: #"\\\((?:[^()]|\([^()]*\))*\)"#, with: "", options: .regularExpression)
            let words = plain.split(whereSeparator: { !$0.isLetter && $0 != "'" }).filter { $0.count > 1 }
            if words.count >= 3, plain.range(of: "[a-z] [a-z]", options: .regularExpression) != nil { return true }
        }
        return false
    }

    /// `Text(verbatim:)` is for names, numbers and addresses. An English sentence in it stays English.
    func testNoEnglishSentenceIsShownVerbatim() throws {
        let found = try scan(Self.screenFiles, calls: ["Text(verbatim: \""])
            .filter { item in !Self.notScreens.contains { item.file.hasSuffix($0) } }
            .filter { item in
                // Two or more plain words in a row read as a sentence; brand names and addresses don't.
                let words = item.literal.split(separator: " ").filter { word in word.allSatisfy(\.isLetter) && word.count > 1 }
                return words.count >= 2 && !item.literal.contains("\\(…)") && !Self.properNames.contains(item.literal)
            }
        XCTAssertTrue(found.isEmpty, found.map { "\($0.file):\($0.line) translate: \"\($0.literal)\"" }.joined(separator: "\n"))
    }

    /// Names that are the same in every language, and the one line only a debug build shows.
    private static let properNames: Set<String> = ["Outlook, Hotmail, Live, MSN", "Pausely Pro",
                                                   "Test without an account (debug build)"]

    func testTranslationsKeepTheirFormatSpecifiers() throws {
        let strings = try catalog()
        let specifier = try NSRegularExpression(pattern: "%(?:\\d+\\$)?(lld|ld|d|@|lf|f|\\.\\d+f)")
        func specifiers(_ text: String) -> [String] {
            specifier.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            }.sorted()
        }
        var failures: [String] = []
        for (key, entry) in strings {
            let expected = specifiers(key)
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            for (language, localization) in localizations {
                // "one", "two" and "zero" forms may spell the number out ("Einmal", "مرتين").
                let values = CatalogTexts.all(in: localization, skipping: ["one", "two", "zero"])
                for value in values where specifiers(value) != expected {
                    failures.append("\"\(key)\" [\(language)]: \(value)")
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.sorted().joined(separator: "\n"))
    }

    /// Two counts beside a noun need a plural pair in every language, and this line had none: the
    /// Savings Receipt read "1 prélèvements évités sur 12" in French (seen on the French tour of
    /// 2026-11-16), and for a yearly plan it read "1 of 1 charges" in English. The line names
    /// what is counted and then gives the count, which no language has to bend.
    func testTheReceiptsCountIsALabelThenANumber() throws {
        let catalog = try catalog()
        XCTAssertNil(catalog["Cancelled %@ · %lld of %lld charges avoided so far"])
        let key = "Charges avoided so far: %lld of %lld"
        let entry = try XCTUnwrap(catalog[key], "the receipt's line is not in the catalog")
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]])
        var sentences = ["en": key]
        for language in ["ar", "de", "es", "fr", "ja"] {
            sentences[language] = try XCTUnwrap((localizations[language]?["stringUnit"] as? [String: Any])?["value"] as? String, language)
        }
        for (language, sentence) in sentences {
            let parts = sentence.components(separatedBy: CharacterSet(charactersIn: ":："))
            let count = try XCTUnwrap(parts.last)
            let label = parts.dropLast().joined()
            XCTAssertEqual(count.components(separatedBy: "lld").count - 1, 2, "\(language): both figures come after the colon")
            XCTAssertFalse(label.contains("lld"), "\(language): a figure stands before the noun it counts")
        }
        let receipt = try String(contentsOf: root.appendingPathComponent("Pausely/Views/Verdict/SavingsReceiptView.swift"), encoding: .utf8)
        XCTAssertTrue(receipt.contains("L10n.string(\"Charges avoided so far: \\(line.avoidedSoFar.count) of \\(line.avoidedCharges.count)\")"))
    }

    /// The app runs on iPad, and there it says "iPad". Eighteen sentences said "iPhone" or "phone" on
    /// both ("Same as iPhone" for the language, "Saved on this iPhone", "Your email never leaves your
    /// iPhone"). Each now has its own wording for the iPad, in every language.
    func testOnAnIPadTheAppSaysIPad() throws {
        let strings = try catalog()
        var wrong: [String] = []
        var varied = 0
        for (key, entry) in strings {
            var localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            // With no English entry the key itself is what an English reader sees, on every device.
            if localizations["en"] == nil { localizations["en"] = ["stringUnit": ["value": key]] }
            for (language, localization) in localizations {
                guard CatalogTexts.all(in: localization).contains(where: { $0.contains("iPhone") }) else { continue }
                let devices = (localization["variations"] as? [String: Any])?["device"] as? [String: [String: Any]] ?? [:]
                let onIPad = devices["ipad"].map { CatalogTexts.all(in: $0) } ?? []
                let elsewhere = devices["other"].map { CatalogTexts.all(in: $0) } ?? []
                let right = !onIPad.isEmpty && onIPad.allSatisfy { $0.contains("iPad") && !$0.contains("iPhone") }
                    && !elsewhere.isEmpty && elsewhere.allSatisfy { !$0.contains("iPad") }
                if right { varied += 1 } else { wrong.append("\(key) [\(language)]") }
            }
        }
        XCTAssertEqual(wrong.sorted(), [])
        XCTAssertGreaterThanOrEqual(varied, 16 * 6, "sixteen sentences in six languages")

        func wording(_ key: String, _ language: String, on device: String) -> String? {
            let localization = (strings[key]?["localizations"] as? [String: [String: Any]])?[language]
            let devices = (localization?["variations"] as? [String: Any])?["device"] as? [String: [String: Any]]
            return devices?[device].flatMap { CatalogTexts.all(in: $0).first }
        }
        XCTAssertEqual(wording("Same as iPhone", "en", on: "ipad"), "Same as iPad")
        XCTAssertEqual(wording("Same as iPhone", "en", on: "other"), "Same as iPhone")
        XCTAssertEqual(wording("Same as iPhone", "fr", on: "ipad")?.contains("iPad"), true)
        XCTAssertEqual(wording("Your list is saved to your account, so it's still there if you change phones.", "en", on: "ipad"),
                       "Your list is saved to your account, so it's still there on a new device.")
    }

    // MARK: The app language reaches code-built text

    func testCodeBuiltTextFollowsTheAppLanguage() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: L10n.languageKey)
        defer { defaults.set(saved, forKey: L10n.languageKey) }

        defaults.set("de", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.string("Stopped."), "Gestoppt.")
        XCTAssertEqual(L10n.string("\(3) emails"), "3 E-Mails")
        XCTAssertEqual(L10n.string("\(1) emails"), "1 E-Mail", "German singular")

        defaults.set("ar", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.string("\(2) emails"), "رسالتين", "Arabic dual")

        defaults.set("en", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.string("\(1) emails"), "1 email", "English singular")
        XCTAssertEqual(L10n.string("Charged \(4) times, about every month"), "Charged 4 times, about every month")
    }
}
