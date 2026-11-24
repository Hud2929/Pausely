import Foundation

/// An amount as a person types it and as an edit field shows it.
///
/// People write numbers the way their language does: "9,99" in Paris, "٩٫٩٩" on an Arabic keyboard,
/// "1'299.00" in Zurich, "１５００" from a Japanese keyboard. And currencies differ: yen has no
/// decimals, dinars have three, a normal price in rupiah has six digits. Every field that takes an
/// amount reads it and shows it through here, so all of them agree.
enum AmountText {

    /// What was typed, as an amount in `currency`. Nil when it isn't a positive amount or is larger
    /// than Pausely tracks (`ceiling(for:)`).
    static func parse(_ raw: String, currency: String, locale: Locale = L10n.locale) -> Decimal? {
        guard let typed = number(in: raw, locale: locale, decimals: MoneyFormat.fractionDigits(for: currency)) else { return nil }
        let value = rounded(typed, currency: currency)
        guard value > 0, value <= ceiling(for: currency) else { return nil }
        return value
    }

    /// True when what was typed is a number, and more than Pausely tracks in this currency.
    static func isTooLarge(_ raw: String, currency: String, locale: Locale = L10n.locale) -> Bool {
        guard let value = number(in: raw, locale: locale, decimals: MoneyFormat.fractionDigits(for: currency)) else { return false }
        return value > ceiling(for: currency)
    }

    /// The amount as an edit field shows it: the currency's own decimals ("1500" yen, "1.500" dinars),
    /// the reader's decimal mark, no grouping, and digits a keyboard can type back.
    static func text(for amount: Decimal, currency: String, locale: Locale = L10n.locale) -> String {
        let digits = MoneyFormat.fractionDigits(for: currency)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.roundingMode = .halfUp
        return formatter.string(from: amount as NSDecimalNumber) ?? MoneyFormat.plainNumber(amount, currency)
    }

    /// The amount rounded to the currency's own decimals: what is compared when asking "did it change?".
    static func rounded(_ amount: Decimal, currency: String) -> Decimal {
        var input = amount
        var output = Decimal()
        NSDecimalRound(&output, &input, MoneyFormat.fractionDigits(for: currency), .plain)
        return output
    }

    /// The largest amount a field accepts: what 100,000 US dollars come to in the currency, by the
    /// built-in rates, and never less than 100,000. It is there to catch a slip of the finger, not to
    /// judge a price: Rp 186,000 a month is an ordinary subscription.
    static func ceiling(for currency: String, rates: CurrencyRates = .fallback) -> Decimal {
        let floor: Decimal = 100_000
        guard let converted = rates.convert(floor, from: "USD", to: MoneyFormat.normalizedCode(currency)) else { return floor }
        return max(floor, converted)
    }

    // MARK: - Reading a number

    /// The number in `raw`, whatever digits and marks it was typed with. Nil when there is none, or
    /// when it is negative. `decimals` is how many the currency has: yen has none, so "1,500" yen is
    /// fifteen hundred in every language.
    static func number(in raw: String, locale: Locale, decimals: Int = 2) -> Decimal? {
        if raw.contains(where: { minusSigns.contains($0) }) { return nil }

        // Digits of any script become 0-9; the decimal and grouping marks of any script become "." and ",".
        var text = ""
        for character in raw {
            if let digit = character.wholeNumberValue, character.unicodeScalars.count == 1,
               character.unicodeScalars.first?.properties.generalCategory == .decimalNumber {
                text.append(String(digit))
            } else if decimalMarks.contains(character) {
                text.append(".")
            } else if groupingMarks.contains(character) {
                text.append(",")
            } else if character == "." || character == "," {
                text.append(character)
            }
            // Everything else (currency signs, letters, spaces and apostrophes used for grouping) is dropped.
        }
        guard text.contains(where: \.isNumber) else { return nil }

        let dots = text.filter { $0 == "." }.count
        let commas = text.filter { $0 == "," }.count
        switch (dots, commas) {
        case (0, 0):
            break
        case (_, _) where dots > 0 && commas > 0:
            // Both marks: whichever comes last is the decimal mark, the other groups thousands.
            if text.lastIndex(of: ".")! > text.lastIndex(of: ",")! {
                text = text.replacingOccurrences(of: ",", with: "")
            } else {
                text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
        default:
            // One kind of mark. Several of it can only be grouping ("1,299,000"). A single one is read
            // the way the reader's own language writes numbers: as grouping when that is its grouping
            // mark and the digits sit in groups of three ("1.299" in German), otherwise as the decimal mark.
            let mark: Character = dots > 0 ? "." : ","
            let count = max(dots, commas)
            let parts = text.split(separator: mark, omittingEmptySubsequences: false)
            let groupsOfThree = parts.count >= 2 && !parts[0].isEmpty && parts[0].count <= 3
                && parts.dropFirst().allSatisfy { $0.count == 3 }
            let isGrouping = count > 1 || (groupsOfThree && (decimals == 0 || groupingMark(of: locale) == mark))
            if isGrouping {
                guard groupsOfThree else { return nil }
                text = text.replacingOccurrences(of: String(mark), with: "")
            } else if mark == "," {
                text = text.replacingOccurrences(of: ",", with: ".")
            }
        }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// "." or ",": how the locale groups thousands. A space or an apostrophe counts as neither.
    private static func groupingMark(of locale: Locale) -> Character? {
        switch locale.groupingSeparator {
        case ".": return "."
        case ",", "٬": return ","
        default: return nil
        }
    }

    /// U+066B Arabic decimal separator, U+FF0E fullwidth full stop, U+3002 is a sentence mark and is not here.
    private static let decimalMarks: Set<Character> = ["\u{066B}", "\u{FF0E}"]
    /// U+066C Arabic thousands separator, U+FF0C fullwidth comma, U+060C Arabic comma.
    private static let groupingMarks: Set<Character> = ["\u{066C}", "\u{FF0C}", "\u{060C}"]
    /// Hyphen-minus, minus sign, en dash, fullwidth hyphen-minus.
    private static let minusSigns: Set<Character> = ["-", "\u{2212}", "\u{2013}", "\u{FF0D}"]
}
