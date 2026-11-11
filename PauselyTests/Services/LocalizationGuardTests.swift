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
        "Text(\"", "Label(\"", "Button(\"", "Toggle(\"", "Picker(\"", "Section(\"", "Link(\"", "Menu(\"",
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
                var values: [String] = []
                if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String { values.append(value) }
                if let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]] {
                    // "one", "two" and "zero" forms may spell the number out ("Einmal", "مرتين").
                    for (category, form) in plural where !["one", "two", "zero"].contains(category) {
                        if let value = (form["stringUnit"] as? [String: Any])?["value"] as? String { values.append(value) }
                    }
                }
                for value in values where specifiers(value) != expected {
                    failures.append("\"\(key)\" [\(language)]: \(value)")
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.sorted().joined(separator: "\n"))
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
        XCTAssertEqual(L10n.string("\(2) receipts"), "إيصالين", "Arabic dual")

        defaults.set("en", forKey: L10n.languageKey)
        XCTAssertEqual(L10n.string("\(1) receipts"), "1 receipt", "English singular")
        XCTAssertEqual(L10n.string("Charged \(4) times, about every month"), "Charged 4 times, about every month")
    }
}
