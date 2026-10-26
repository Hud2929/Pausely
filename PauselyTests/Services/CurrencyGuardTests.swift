import XCTest
@testable import Pausely

/// Keeps money handling in one place, forever. Scans the app's and the widget's Swift sources and
/// fails with file:line for anything that bypasses Core/Money:
///
/// 1. a currency formatter of its own (all money text goes through `MoneyFormat`)
/// 2. a currency symbol table or symbol glued to a number (`currencySymbol`)
/// 3. a currency symbol written into user-facing text ("$9.99", "$\(amount)", "12 €")
/// 4. a sum over subscription money without converting (`reduce` over `.monthlyCost` and friends)
/// 5. a subscription's own-currency amount labelled with the display currency
/// 6. a conversion that silently falls back to the unconverted number (`try? convert ... ??`)
/// 7. a new `= "USD"` default parameter
///
/// A line that is a deliberate exception carries `// money-guard: <why>`. Whole files that hold
/// US list prices or sample text are allow-listed below, each with its reason.
/// The rules and how to fix each one: `.claude/skills/pausely-currency/SKILL.md`.
final class CurrencyGuardTests: XCTestCase {

    private struct Rule {
        let name: String
        let fix: String
        let matches: (_ line: String) -> Bool
        var allowedPaths: [String] = []
    }

    private static let moneyEngine = "Pausely/Core/Money/"

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern)
    }

    private static func has(_ pattern: NSRegularExpression, _ text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static let ownFormatter = regex(#"numberStyle\s*=\s*\.currency|\.currency\(code:|formatter\.currency(Code|Symbol)\s*="#)
    private static let symbolIdentifier = regex(#"\bcurrencySymbol\b"#)
    private static let symbolNextToAmount = regex(#"[$€£¥₹]\s?(⟨⟩|\d)|\d\s?[€£¥₹]|^\s*[$€£¥₹]\s*$"#)
    private static let rawSum = regex(#"reduce\([^\n]*\.(monthlyCost|annualCost|lifetimeSpend|amount)\b"#)
    private static let rawFormat = regex(#"\.format\(\s*[\w.]*\.(amount|monthlyCost|annualCost|lifetimeSpend)\s*\)"#)
    private static let silentFallback = regex(#"try\?[^\n]*\.convert\([^\n]*\?\?"#)
    private static let usdDefault = regex(#":\s*String\s*=\s*"USD""#)
    private static let amountWithCurrency = regex(
        #"(?:MoneyFormat\.string|\.format)\(\s*(\w+)\.(amount|monthlyCost|annualCost|lifetimeSpend|savedSoFar|amountPerCharge)\s*,\s*(?:currencyCode:\s*)?([\w.]+)"#)

    /// True when `subscription.amount` (or another own-currency amount) is formatted with a currency
    /// other than `subscription.currency`.
    static func formatsWithAnotherCurrency(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return amountWithCurrency.matches(in: line, range: range).contains { match in
            guard let owner = Range(match.range(at: 1), in: line), let code = Range(match.range(at: 3), in: line) else { return false }
            return line[code] != "\(line[owner]).currency"
        }
    }

    private let rules: [Rule] = [
        Rule(name: "own currency formatter",
             fix: "Use MoneyFormat.string(amount, currency).",
             matches: { CurrencyGuardTests.has(CurrencyGuardTests.ownFormatter, $0) }),
        Rule(name: "currency symbol handled by hand",
             fix: "Use MoneyFormat.string(...) for amounts, or MoneyFormat.symbol(for:) for an input prefix.",
             matches: { CurrencyGuardTests.has(CurrencyGuardTests.symbolIdentifier, $0) },
             allowedPaths: [
                "Pausely/Services/SupabaseManager.swift",          // CurrencyManager.currencySymbol(for:) itself
                "Pausely/Views/TierSelectionSheet.swift",           // prefix of the price input field
                "Pausely/Views/Subscriptions/AmountStepView.swift", // prefix of the amount input field
                "Pausely/Views/AddSubscription/LuxuryAddSubscriptionView.swift" // prefix of the amount input field
             ]),
        Rule(name: "currency symbol written into text",
             fix: "Format the amount with MoneyFormat and interpolate it; sample amounts use OnboardingSample.money.",
             matches: { line in CurrencyGuardTests.literalTexts(line).contains { CurrencyGuardTests.has(CurrencyGuardTests.symbolNextToAmount, $0) } },
             allowedPaths: [
                "Pausely/Services/AlternativeDatabase.swift", // US offers quoted as published ("$300 credit")
                "Pausely/Services/CatalogData.swift",         // US plan names and descriptions ("ChatGPT Pro ($200)")
                "Pausely/Services/Intelligence/ReceiptTextAnalyzer.swift",   // reads symbols out of receipts
                "Pausely/Services/Intelligence/EmailSignalExtractor.swift"   // decodes &euro; and friends in emails
             ]),
        Rule(name: "sum over subscription money without converting",
             fix: "Use subscriptions.monthlyTotal(in:) / annualTotal(in:) or MoneyMath.total.",
             matches: { CurrencyGuardTests.has(CurrencyGuardTests.rawSum, $0) && !$0.contains("convert") }),
        Rule(name: "own-currency amount labelled with the display currency",
             fix: "Use MoneyFormat.string(amount, subscription.currency), or convert first.",
             matches: { CurrencyGuardTests.has(CurrencyGuardTests.rawFormat, $0) }),
        Rule(name: "amount labelled with another currency",
             fix: "Format x.amount with x.currency; convert first to show it in another currency.",
             matches: { CurrencyGuardTests.formatsWithAnotherCurrency($0) }),
        Rule(name: "conversion that silently falls back",
             fix: "Use CurrencyManager.shared.rates.convert(...) and handle nil explicitly.",
             matches: { CurrencyGuardTests.has(CurrencyGuardTests.silentFallback, $0) }),
        Rule(name: "US dollars as a default currency",
             fix: "Default to CurrencyManager.shared.selectedCurrency, or require the currency.",
             matches: { CurrencyGuardTests.has(CurrencyGuardTests.usdDefault, $0) },
             allowedPaths: [
                "Pausely/Services/SupabaseManager.swift",       // formatCatalogPrice: the catalog's prices are in USD
                "Pausely/Services/AlternativeDatabase.swift",   // parsed catalog patterns carry US list prices
                "Pausely/Services/WidgetDataStore.swift",       // empty widget summary before the first publish
                "Pausely/Services/Intelligence/SubscriptionIntelligenceEngine.swift", // mailbox fallback, tested in USD
                "PauselyWidget/"                                 // sample data for widget previews
             ])
    ]

    // MARK: - The scan

    func testMoneyIsOnlyHandledByTheMoneyEngine() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path),
                          "Sources aren't readable from this test run")

        var violations: [String] = []
        for folder in ["Pausely", "PauselyWidget"] {
            let base = root.appendingPathComponent(folder)
            guard let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in files where file.pathExtension == "swift" {
                let relative = String(file.path.dropFirst(root.path.count + 1))
                if relative.hasPrefix(Self.moneyEngine) { continue }
                let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
                for (index, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || line.contains("money-guard:") { continue }
                    for rule in rules where !rule.allowedPaths.contains(where: { relative.hasPrefix($0) }) {
                        if rule.matches(line) {
                            violations.append("\(relative):\(index + 1): \(rule.name). \(rule.fix)\n    \(trimmed)")
                        }
                    }
                }
            }
        }
        XCTAssertTrue(violations.isEmpty, "Money handled outside Core/Money:\n" + violations.joined(separator: "\n"))
    }

    // MARK: - The guard's own parsing

    /// The text of each string literal on a line, with every interpolation replaced by "⟨⟩", so
    /// `"$\(amount)"` reads as "$⟨⟩" and closure arguments like `$0` (which live in code) are ignored.
    static func literalTexts(_ line: String) -> [String] {
        enum Context { case code(parens: Int), string(String) }
        var stack: [Context] = [.code(parens: 0)]
        var texts: [String] = []
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            switch stack[stack.count - 1] {
            case .code(let parens):
                if c == "/" && next == "/" && stack.count == 1 { return texts }  // a trailing comment
                if c == "\"" {
                    stack.append(.string(""))
                } else if c == "(" {
                    stack[stack.count - 1] = .code(parens: parens + 1)
                } else if c == ")" {
                    if parens == 0, stack.count > 1, case .string(let text) = stack[stack.count - 2] {
                        stack.removeLast()  // end of an interpolation
                        stack[stack.count - 1] = .string(text + "⟨⟩")
                    } else {
                        stack[stack.count - 1] = .code(parens: max(0, parens - 1))
                    }
                }
            case .string(let text):
                if c == "\\" && next == "(" {
                    stack.append(.code(parens: 0))
                    i += 1
                } else if c == "\\", let escaped = next {
                    stack[stack.count - 1] = .string(text + String(escaped))
                    i += 1
                } else if c == "\"" {
                    stack.removeLast()
                    texts.append(text)
                } else {
                    stack[stack.count - 1] = .string(text + String(c))
                }
            }
            i += 1
        }
        for case .string(let text) in stack { texts.append(text) }  // a literal that continues
        return texts
    }

    func testLiteralParsingSeesTextButNotCode() {
        XCTAssertEqual(Self.literalTexts(#"Text("$\(amount) a month")"#), ["$⟨⟩ a month"])
        XCTAssertEqual(Self.literalTexts(#"let x = items.map { "\($0.name)" } // "$5""#), ["⟨⟩"])
        XCTAssertEqual(Self.literalTexts(#"Text(flag ? "On" : "Off")"#), ["On", "Off"])
        XCTAssertEqual(Self.literalTexts(#""\(a ? "x" : "y") costs $9""#), ["x", "y", "⟨⟩ costs $9"])
    }

    func testEachRuleCatchesWhatItShould() {
        func caught(_ line: String) -> [String] { rules.filter { $0.matches(line) }.map(\.name) }
        XCTAssertFalse(caught(#"formatter.numberStyle = .currency"#).isEmpty)
        XCTAssertFalse(caught(#"Text(entry.currencySymbol)"#).isEmpty)
        XCTAssertFalse(caught(#"Text("Total: $\(total)")"#).isEmpty)
        XCTAssertFalse(caught(#"Text("Only $9.99 a month")"#).isEmpty)
        XCTAssertFalse(caught(#"Text("12,99 €")"#).isEmpty)
        XCTAssertFalse(caught(#"let total = subs.reduce(0) { $0 + $1.monthlyCost }"#).isEmpty)
        XCTAssertFalse(caught(#"Text(manager.format(sub.amount))"#).isEmpty)
        XCTAssertFalse(caught(#"let x = (try? m.convert(a, from: c, to: d)) ?? a"#).isEmpty)
        XCTAssertFalse(caught(#"init(currency: String = "USD")"#).isEmpty)
        XCTAssertFalse(caught(#"let a = MoneyFormat.string(sub.monthlyCost, currencyCode)"#).isEmpty)
        XCTAssertFalse(caught(#"Text(cm.format(best.amount, currencyCode: cm.selectedCurrency))"#).isEmpty)
        XCTAssertTrue(caught(#"let a = MoneyFormat.string(sub.monthlyCost, sub.currency)"#).isEmpty)

        XCTAssertTrue(caught(#"Text(MoneyFormat.string(sub.amount, sub.currency))"#).isEmpty)
        XCTAssertTrue(caught(#"let names = subs.map { "\($0.name)" }.joined()"#).isEmpty)
        XCTAssertTrue(caught(#"let total = subs.monthlyTotal(in: currency)"#).isEmpty)
        XCTAssertTrue(caught(#"Text("Renews in \($0) days")"#).isEmpty)
    }
}
