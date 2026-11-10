import Foundation
import CoreGraphics

/// One line of text read from a screenshot. `box` is in unit coordinates with the origin at the
/// top left (x and y from 0 to 1, y growing downwards).
struct ScreenshotTextLine: Equatable {
    let text: String
    let box: CGRect
}

/// Turns the text of a screenshot into subscriptions to confirm. Pure: no Vision, no clock.
///
/// Two shapes are understood, because they are what people have on their phones:
/// 1. A list of subscriptions (Settings › Apple Account › Subscriptions, Google Play): a name, a plan
///    line and "Renews 27 Nov". These lists usually show no price.
/// 2. A list of charges (a bank or card app, Apple Card): a merchant, an amount on the same row
///    and sometimes a date.
///
/// Nothing found here is saved without the user confirming it: a screenshot proves less than a
/// receipt, so every candidate says what was read and what was not.
enum ScreenshotSubscriptionParser {

    struct Candidate: Equatable, Identifiable {
        var id: String { key }
        /// Normalized name; one candidate per key.
        let key: String
        let name: String
        let category: String?
        /// nil when the screenshot showed no price for this row.
        let amount: Decimal?
        /// nil when the amount had a bare symbol ("$") or there was no amount.
        let currency: String?
        let frequency: BillingFrequency?
        let nextCharge: Date?
        /// The name matched a service Pausely knows.
        let isKnownService: Bool
    }

    static func candidates(from lines: [ScreenshotTextLine], now: Date, calendar: Calendar = .current,
                           catalog: MerchantCatalog = .builtin) -> [Candidate] {
        let sorted = lines
            .map { ScreenshotTextLine(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), box: $0.box) }
            .filter { !$0.text.isEmpty }
            .sorted { ($0.box.minY, $0.box.minX) < ($1.box.minY, $1.box.minX) }
        guard !sorted.isEmpty else { return [] }

        // 1. Anchors: lines that name a service, or the title above a "Renews …" line.
        var anchors: [(index: Int, merchant: ResolvedMerchant)] = []
        var claimed = Set<Int>()
        for (index, line) in sorted.enumerated() where isNameLike(line.text) {
            if let merchant = catalog.resolve(hint: line.text, senderName: "", senderDomain: ""), merchant.isKnown {
                anchors.append((index, merchant))
                claimed.insert(index)
            }
        }
        for (index, line) in sorted.enumerated() where renewalDate(in: line.text, now: now, calendar: calendar) != nil {
            // Already inside a known service's block?
            if let owner = anchors.last(where: { $0.index < index }), isSameBlock(sorted[owner.index], line) { continue }
            guard let titleIndex = titleIndex(above: index, in: sorted), !claimed.contains(titleIndex),
                  let merchant = catalog.resolve(hint: sorted[titleIndex].text, senderName: "", senderDomain: "") else { continue }
            anchors.append((titleIndex, merchant))
            claimed.insert(titleIndex)
        }
        anchors.sort { $0.index < $1.index }

        // 2. Each anchor owns the lines on its row and below it, up to the next anchor.
        var result: [Candidate] = []
        var seen = Set<String>()
        for (position, anchor) in anchors.enumerated() {
            let title = sorted[anchor.index]
            let nextAnchorY = position + 1 < anchors.count ? sorted[anchors[position + 1].index].box.minY : 2
            let block = sorted.enumerated().filter { index, line in
                guard index != anchor.index else { return false }
                let sameRow = abs(line.box.midY - title.box.midY) < title.box.height * 0.6
                let below = line.box.minY > title.box.minY && line.box.minY < nextAnchorY - title.box.height * 0.3
                    && isSameBlock(title, line)
                return sameRow || below
            }.map(\.element)

            let texts = block.map(\.text)
            let rowText = texts.joined(separator: "\n")
            if texts.contains(where: isEnded) { continue }   // "Expired", "Expires 5 Dec": already cancelled

            let money = block.lazy.compactMap { amount(in: $0.text) }.first
            let date = texts.lazy.compactMap { renewalDate(in: $0, now: now, calendar: calendar) }.first
            let frequency = frequency(in: title.text + "\n" + rowText)

            // A bare name with nothing else on its row is a heading or a logo label, not a subscription.
            guard money != nil || date != nil || frequency != nil else { continue }
            guard seen.insert(anchor.merchant.key).inserted else { continue }
            result.append(Candidate(key: anchor.merchant.key, name: anchor.merchant.displayName,
                                    category: anchor.merchant.category, amount: money?.amount, currency: money?.currency,
                                    frequency: frequency, nextCharge: date, isKnownService: anchor.merchant.isKnown))
        }
        return result
    }

    // MARK: - Rows

    /// Lines belong to one list row when they sit within a few line heights of its title.
    private static func isSameBlock(_ title: ScreenshotTextLine, _ line: ScreenshotTextLine) -> Bool {
        line.box.minY - title.box.minY < max(title.box.height * 4.5, 0.02)
    }

    /// The title of the row a "Renews …" line belongs to: the highest of the lines stacked directly
    /// above it with the same left edge.
    private static func titleIndex(above index: Int, in lines: [ScreenshotTextLine]) -> Int? {
        let renew = lines[index]
        var best: Int?
        var lastY = renew.box.minY
        var i = index - 1
        while i >= 0 {
            let line = lines[i]
            let aligned = abs(line.box.minX - renew.box.minX) < 0.04
            let close = lastY - line.box.minY < max(line.box.height, renew.box.height) * 2.2
            if aligned && close {
                best = i
                lastY = line.box.minY
            } else if lastY - line.box.minY > renew.box.height * 3 {
                break
            }
            i -= 1
        }
        guard let best, isNameLike(lines[best].text) else { return nil }
        return best
    }

    /// Short text that could be a name: has letters, isn't a sentence, an amount or a date line.
    private static func isNameLike(_ text: String) -> Bool {
        guard text.count >= 2, text.count <= 40, text.rangeOfCharacter(from: .letters) != nil else { return false }
        if amount(in: text) != nil { return false }
        let lower = text.lowercased()
        let notNames = ["renews", "renewal", "next billing", "billing date", "expires", "expired", "subscriptions",
                        "active", "inactive", "settings", "see all", "today", "yesterday", "pending", "balance"]
        return !notNames.contains { lower.hasPrefix($0) }
    }

    private static func isEnded(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("expires") || lower.hasPrefix("expired") || lower.hasPrefix("cancelled")
            || lower.hasPrefix("canceled") || lower.hasPrefix("ends ")
    }

    // MARK: - Amount, frequency, date

    /// A price on a row: needs a currency symbol or code and two decimals, so "27 Nov" or "4 of 12"
    /// never count. A leading minus (a debit in a bank list) is ignored.
    static func amount(in text: String) -> ReceiptTextAnalyzer.Money? {
        let pattern = #"(?:(US\$|CA\$|C\$|A\$|AU\$|NZ\$|\$|€|£|¥|USD|CAD|EUR|GBP|AUD)\s?)(\d{1,5}(?:,\d{3})*[.,]\d{2})(?!\d)|(?<!\d)(\d{1,5}(?:[.,]\d{2}))\s?(€|USD|CAD|EUR|GBP|AUD)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        func group(_ i: Int) -> String? {
            guard let range = Range(match.range(at: i), in: text) else { return nil }
            return String(text[range])
        }
        let token = group(1) ?? group(4) ?? ""
        guard var number = group(2) ?? group(3) else { return nil }
        // "1,299.00" or "12,99": the last separator is the decimal point.
        if let last = number.lastIndex(where: { $0 == "." || $0 == "," }) {
            let whole = number[..<last].replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
            number = whole + "." + number[number.index(after: last)...]
        }
        guard let value = Decimal(string: number), value > 0 else { return nil }
        return ReceiptTextAnalyzer.Money(amount: value, currency: ReceiptTextAnalyzer.currencyCode(forToken: token))
    }

    static func frequency(in text: String) -> BillingFrequency? {
        let lower = text.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { lower.contains($0) } }
        if has(["yearly", "annual", "/yr", "/year", "per year", "a year", "12 months", "1 year"]) { return .yearly }
        if has(["6 months", "semiannual", "semi-annual"]) { return .semiannual }
        if has(["quarterly", "3 months"]) { return .quarterly }
        if has(["weekly", "/wk", "/week", "per week", "1 week"]) { return .weekly }
        if has(["monthly", "/mo", "/month", "per month", "a month", "1 month"]) { return .monthly }
        return nil
    }

    private static let months: [String: Int] = {
        var map: [String: Int] = [:]
        let names = ["january", "february", "march", "april", "may", "june", "july", "august", "september",
                     "october", "november", "december"]
        for (i, name) in names.enumerated() {
            map[name] = i + 1
            map[String(name.prefix(3))] = i + 1
        }
        map["sept"] = 9
        return map
    }()

    /// The date on a "Renews 27 Nov" / "Next billing date: December 3, 2026" line, at local noon.
    /// Without a year it is the next such day on or after `now`. English month names only for now.
    static func renewalDate(in text: String, now: Date, calendar: Calendar = .current) -> Date? {
        let lower = text.lowercased()
        guard ["renews", "next billing", "billing date", "next payment", "next charge", "renewal date"]
            .contains(where: { lower.contains($0) }) else { return nil }
        // Only real month names, so "renews 27" is never read as a month and a day.
        let month = months.keys.sorted { $0.count > $1.count }.joined(separator: "|")
        let pattern = "(?:(\\d{1,2})(?:st|nd|rd|th)?\\s+(\(month))\\b\\.?|\\b(\(month))\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?)(?:,?\\s+(\\d{4}))?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for match in regex.matches(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
            func group(_ i: Int) -> String? {
                guard let range = Range(match.range(at: i), in: lower) else { return nil }
                return String(lower[range])
            }
            guard let monthName = group(2) ?? group(3), let month = months[monthName],
                  let day = Int(group(1) ?? group(4) ?? ""), (1...31).contains(day) else { continue }
            var components = DateComponents(month: month, day: day, hour: 12)
            if let yearText = group(5), let year = Int(yearText) {
                components.year = year
                if let date = calendar.date(from: components), calendar.component(.day, from: date) == day { return date }
                continue
            }
            let today = calendar.startOfDay(for: now)
            let thisYear = calendar.component(.year, from: now)
            for year in [thisYear, thisYear + 1] {
                components.year = year
                if let date = calendar.date(from: components), calendar.component(.day, from: date) == day, date >= today {
                    return date
                }
            }
        }
        return nil
    }
}
