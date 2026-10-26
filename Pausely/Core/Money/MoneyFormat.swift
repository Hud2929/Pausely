import Foundation

/// The only place Pausely turns an amount and an ISO 4217 currency code into text.
///
/// - The reader's locale picks the symbol and separators, so nobody sees a bare "$" for a currency
///   that isn't theirs: in Canada CAD is "$12.99" and USD is "US$12.99"; in the US, USD is "$12.99"
///   and CAD is "CA$12.99"; in Germany EUR is "12,99 €".
/// - Decimals follow the currency: ¥1,500, $12.99, KWD 1.250.
/// - Never build money text by hand (`"$" + amount`, `String(format: "%.2f")`, a NumberFormatter of
///   your own). The guard test in `CurrencyGuardTests` fails the build's tests if anything does.
///
/// See `.claude/skills/pausely-currency/SKILL.md` for the full rules.
enum MoneyFormat {
    /// `amount` in `currency`, for example "$12.99", "US$12.99" or "12,99 €".
    /// - Parameter wholeUnits: drop the decimals, for large headline numbers ("$1,480").
    static func string(_ amount: Decimal, _ currency: String,
                       locale: Locale = .autoupdatingCurrent, wholeUnits: Bool = false) -> String {
        let code = normalizedCode(currency)
        guard isWellFormed(code) else {
            return "\(currency) \(NSDecimalNumber(decimal: amount).stringValue)"
        }
        let formatter = cachedFormatter(code: code, locale: locale, wholeUnits: wholeUnits)
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(code) \(amount)"
    }

    static func string(_ amount: Double, _ currency: String,
                       locale: Locale = .autoupdatingCurrent, wholeUnits: Bool = false) -> String {
        string(decimal(amount), currency, locale: locale, wholeUnits: wholeUnits)
    }

    /// A plain number for files such as CSV: no symbol, no grouping, "." as the decimal point, and the
    /// currency's own decimals ("15.49", "1500", "1.250").
    static func plainNumber(_ amount: Decimal, _ currency: String) -> String {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, fractionDigits(for: currency), .plain)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = fractionDigits(for: currency)
        formatter.maximumFractionDigits = fractionDigits(for: currency)
        return formatter.string(from: rounded as NSDecimalNumber) ?? NSDecimalNumber(decimal: rounded).stringValue
    }

    /// The symbol a reader in `locale` sees for `currency`: "$", "US$", "CA$", "€", "¥".
    static func symbol(for currency: String, locale: Locale = .autoupdatingCurrent) -> String {
        let code = normalizedCode(currency)
        guard isWellFormed(code) else { return code }
        return cachedFormatter(code: code, locale: locale, wholeUnits: false).currencySymbol ?? code
    }

    /// How many digits a currency uses after the decimal point (JPY 0, USD 2, KWD 3).
    static func fractionDigits(for currency: String) -> Int {
        let code = normalizedCode(currency)
        guard isWellFormed(code) else { return 2 }
        return cachedFormatter(code: code, locale: Locale(identifier: "en_US_POSIX"), wholeUnits: false)
            .maximumFractionDigits
    }

    /// "cad " → "CAD".
    static func normalizedCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// True for ISO 4217 codes Foundation knows.
    static func isKnown(_ code: String) -> Bool {
        knownCodes.contains(normalizedCode(code))
    }

    /// A `Double` amount as a `Decimal` without binary noise (12.99, not 12.9900000000000002).
    static func decimal(_ amount: Double) -> Decimal {
        guard amount.isFinite else { return 0 }
        return Decimal(string: String(amount)) ?? Decimal(amount)
    }

    // MARK: - Private

    private static let knownCodes = Set(Locale.Currency.isoCurrencies.map(\.identifier))

    private static func isWellFormed(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var formatters: [String: NumberFormatter] = [:]

    /// NumberFormatter is expensive to create and safe to share for formatting, so keep one per
    /// locale, currency and style.
    private static func cachedFormatter(code: String, locale: Locale, wholeUnits: Bool) -> NumberFormatter {
        let key = "\(locale.identifier)|\(code)|\(wholeUnits)"
        lock.lock()
        defer { lock.unlock() }
        if let formatter = formatters[key] { return formatter }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.roundingMode = .halfUp
        if wholeUnits {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        formatters[key] = formatter
        return formatter
    }
}
