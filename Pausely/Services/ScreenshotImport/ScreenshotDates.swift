import Foundation

/// Date extraction for on-device screenshot parsing across English, German, French, Spanish,
/// Japanese, and Arabic formats. Handles missing-year rollover (forward for upcoming renewals,
/// backward for past bank charges/expirations) and rejects relative durations from `NSDataDetector`.
extension ScreenshotParser {

    struct DateMatch {
        let date: Date?
        let hasKeyword: Bool
    }

    private static let futureDateKeywords = [
        "renews", "renew", "next bill", "next charge", "next payment", "next ", "billing date", "due ",
        "trial ends", "free trial", "se renouvelle", "renouvellement", "verlängert", "se renueva",
        "更新日", "更新", "次回請求", "يتجدد"
    ]

    private static let pastDateKeywords = [
        "expired", "ended ", "cancelled", "canceled", "last charged", "charged on", "paid on",
        "abgelaufen", "expiré", "venció", "期限切れ", "منتهي", "انتهى"
    ]

    private static let dateKeywords: [String] = futureDateKeywords + pastDateKeywords + [
        "expires", "ends ", "cancels ", "läuft ab", "vence", "期限", "ينتهي"
    ]

    static func extractDateInfo(in text: String, now: Date, calendar: Calendar) -> DateMatch {
        let normalized = ReceiptTextAnalyzer.normalizingDigits(text)
        let lower = normalized.lowercased()
        let hasFuture = futureDateKeywords.contains { lower.contains($0) }
        let hasPast = pastDateKeywords.contains { lower.contains($0) }
        let hasKeyword = dateKeywords.contains { lower.contains($0) }
        let preferPast = hasPast || !hasFuture

        // 1. Explicit ISO date (2026-12-14), rejecting explicit out-of-range years without falling through.
        switch parseISODate(in: normalized, now: now, calendar: calendar) {
        case .matched(let iso):
            return DateMatch(date: calendar.noon(of: iso), hasKeyword: hasKeyword)
        case .rejected:
            return DateMatch(date: nil, hasKeyword: hasKeyword)
        case .none:
            break
        }

        // 2. Explicit Japanese date (2026年12月14日 or 12月14日)
        if let jp = parseJapaneseDate(in: normalized, now: now, calendar: calendar, preferPast: preferPast) {
            return DateMatch(date: calendar.noon(of: jp), hasKeyword: hasKeyword)
        }

        // 3. Explicit month-day pattern across EN/DE/FR/ES/AR ("Dec 14", "14. Dez. 2026", "14 de dic. de 2026", "14 ديسمبر 2026")
        if let explicit = parseMonthDay(in: normalized, now: now, calendar: calendar, preferPast: preferPast) {
            return DateMatch(date: calendar.noon(of: explicit), hasKeyword: hasKeyword)
        }

        // 4. Explicit numeric dates (MM/DD/YYYY, DD.MM.YYYY, MM/DD), rejecting explicit out-of-range years without falling through.
        switch parseNumericDate(in: normalized, now: now, calendar: calendar, preferPast: preferPast, hasKeyword: hasKeyword) {
        case .matched(let numeric):
            return DateMatch(date: calendar.noon(of: numeric), hasKeyword: hasKeyword)
        case .rejected:
            return DateMatch(date: nil, hasKeyword: hasKeyword)
        case .none:
            break
        }

        // 5. Fallback to per-thread cached NSDataDetector, rejecting durations ("7 days", "1 month"), ratios ("24/7"), and bare weekdays ("Monday.com").
        if let detector = cachedDateDetector() {
            let ns = normalized as NSString
            let range = NSRange(location: 0, length: ns.length)
            for match in detector.matches(in: normalized, options: [], range: range) {
                guard let detected = match.date else { continue }
                let fragment = ns.substring(with: match.range)
                guard isConcreteDateFragment(fragment) else { continue }
                let year = calendar.component(.year, from: detected)
                guard (2020...2035).contains(year) else { continue }
                let days = abs(calendar.calendarDays(from: now, to: detected))
                if days <= 1_100 {
                    return DateMatch(date: calendar.noon(of: detected), hasKeyword: hasKeyword)
                }
            }
        }
        return DateMatch(date: nil, hasKeyword: hasKeyword)
    }

    /// Strips a leading transaction date from a 3-column bank row ("Nov 19  NETFLIX.COM", "11/19  SPOTIFY",
    /// "2026-11-19  Equinox") and returns the remaining text plus the parsed date.
    static func stripLeadingDate(from text: String, now: Date, calendar: Calendar) -> (remainder: String, date: Date?) {
        let normalized = ReceiptTextAnalyzer.normalizingDigits(text)
        let ns = normalized as NSString
        let full = NSRange(location: 0, length: ns.length)
        for regex in leadingDateRegexes {
            guard let regex, let match = regex.firstMatch(in: normalized, range: full) else { continue }
            let prefix = ns.substring(with: match.range)
            let parsed = extractDateInfo(in: prefix, now: now, calendar: calendar).date
            guard parsed != nil else { continue }
            let tail = ns.substring(from: match.range.location + match.range.length)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—−·•|:")))
            if !tail.isEmpty {
                return (tail, parsed)
            }
        }
        return (text, nil)
    }

    // MARK: - Internal Parsers

    private static let leadingDateRegexes: [NSRegularExpression?] = [
        try? NSRegularExpression(pattern: #"^\d{4}[-/]\d{1,2}[-/]\d{1,2}(?:\s+|[·•|\-–—]\s*)"#),
        try? NSRegularExpression(pattern: #"^\d{1,2}[./]\d{1,2}(?:[./]\d{2,4})?\.?(?:\s+|[·•|\-–—]\s*)"#),
        try? NSRegularExpression(pattern: #"^(?:[A-Za-zÀ-ÿ]{3,10})\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?(?:\s+|[·•|\-–—]\s*)"#, options: [.caseInsensitive]),
        try? NSRegularExpression(pattern: #"^\d{1,2}\.?\s+(?:de\s+)?[A-Za-zÀ-ÿ]{3,10}\.?(?:(?:\s+de)?,?\s+\d{4})?(?:\s+|[·•|\-–—]\s*)"#, options: [.caseInsensitive])
    ]

    private enum ExplicitParseResult {
        case matched(Date)
        case rejected
        case none
    }

    private static let isoRegex = try? NSRegularExpression(pattern: #"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#)
    private static let jpRegex = try? NSRegularExpression(pattern: #"(?:(20\d{2})\s*年\s*)?(\d{1,2})\s*月\s*(\d{1,2})\s*日"#)
    private static let dotDateRegex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})?(?!\d)"#)
    private static let slashDateRegex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?(?![\d/])"#)
    private static let nonDateRatioPattern = try? NSRegularExpression(pattern: #"^\s*(?:24/7|7/24)\s*$"#)
    private static let durationPattern = try? NSRegularExpression(
        pattern: #"(?i)\b(?:\d+\s*[-–]?\s*(?:days?|weeks?|wks?|months?|mos?|years?|yrs?|hours?|hrs?|mins?|minutes?|gb|tb)|today|yesterday|tomorrow|every\s+\d+|for\s+\d+)\b"#
    )
    private static let bareTimePattern = try? NSRegularExpression(pattern: #"^\s*\d{1,2}:\d{2}(?:\s?[AP]M)?\s*$"#, options: [.caseInsensitive])

    private static func isConcreteDateFragment(_ fragment: String) -> Bool {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(where: \.isNumber) else { return false }
        let full = NSRange(location: 0, length: (trimmed as NSString).length)
        if bareTimePattern?.firstMatch(in: trimmed, range: full) != nil { return false }
        if nonDateRatioPattern?.firstMatch(in: trimmed, range: full) != nil { return false }
        if durationPattern?.firstMatch(in: trimmed, range: full) != nil { return false }
        return true
    }

    private static func buildDate(month: Int, day: Int, year: Int?, now: Date, calendar: Calendar, preferPast: Bool) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        func exactDate(year y: Int) -> Date? {
            guard let d = calendar.date(from: DateComponents(year: y, month: month, day: day, hour: 12)),
                  calendar.component(.month, from: d) == month,
                  calendar.component(.day, from: d) == day else { return nil }
            return d
        }
        if let year {
            guard (2020...2035).contains(year) else { return nil }
            return exactDate(year: year)
        }
        let currentYear = calendar.component(.year, from: now)
        let candidate = exactDate(year: currentYear)
            ?? (month == 2 && day == 29 ? exactDate(year: preferPast ? currentYear - 1 : currentYear + 1) : nil)
        guard let candidate else { return nil }
        let delta = calendar.calendarDays(from: now, to: candidate)
        if preferPast {
            if delta > 14 {
                return exactDate(year: currentYear - 1) ?? candidate
            }
        } else {
            if delta < -30 {
                return exactDate(year: currentYear + 1) ?? candidate
            }
        }
        return candidate
    }

    private static func parseISODate(in text: String, now: Date, calendar: Calendar) -> ExplicitParseResult {
        let ns = text as NSString
        guard let match = isoRegex?.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let y = Int(ns.substring(with: match.range(at: 1))),
              let m = Int(ns.substring(with: match.range(at: 2))),
              let d = Int(ns.substring(with: match.range(at: 3))) else { return .none }
        if let date = buildDate(month: m, day: d, year: y, now: now, calendar: calendar, preferPast: false) {
            return .matched(date)
        }
        return .rejected
    }

    private static func parseJapaneseDate(in text: String, now: Date, calendar: Calendar, preferPast: Bool) -> Date? {
        let ns = text as NSString
        guard let match = jpRegex?.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let m = Int(ns.substring(with: match.range(at: 2))),
              let d = Int(ns.substring(with: match.range(at: 3))) else { return nil }
        let y = match.range(at: 1).location != NSNotFound ? Int(ns.substring(with: match.range(at: 1))) : nil
        return buildDate(month: m, day: d, year: y, now: now, calendar: calendar, preferPast: preferPast)
    }

    /// True when the reader's locale formats slash dates day-first (DD/MM) rather than month-first (MM/DD).
    private static func prefersDayFirstSlashDates() -> Bool {
        let locale = L10n.locale
        let template = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? "M/d/y"
        guard let dPos = template.firstIndex(of: "d"), let mPos = template.firstIndex(of: "M") else { return false }
        return dPos < mPos
    }

    private static func parseNumericDate(in text: String, now: Date, calendar: Calendar, preferPast: Bool, hasKeyword: Bool = false) -> ExplicitParseResult {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var sawOutOfRangeYear = false
        // European dot format: DD.MM.YYYY or DD.MM.
        if let match = dotDateRegex?.firstMatch(in: text, range: full),
           let d = Int(ns.substring(with: match.range(at: 1))),
           let m = Int(ns.substring(with: match.range(at: 2))),
           (1...12).contains(m), (1...31).contains(d) {
            let y: Int? = match.range(at: 3).location != NSNotFound ? normalizeYear(ns.substring(with: match.range(at: 3))) : nil
            if let date = buildDate(month: m, day: d, year: y, now: now, calendar: calendar, preferPast: preferPast) {
                return .matched(date)
            }
            if let y, !(2020...2035).contains(y) { sawOutOfRangeYear = true }
        }
        // Slash format: MM/DD[/YYYY] or DD/MM[/YYYY]
        for match in slashDateRegex?.matches(in: text, range: full) ?? [] {
            guard let a = Int(ns.substring(with: match.range(at: 1))),
                  let b = Int(ns.substring(with: match.range(at: 2))) else { continue }
            let y: Int? = match.range(at: 3).location != NSNotFound ? normalizeYear(ns.substring(with: match.range(at: 3))) : nil
            // Reject common non-date ratios ("24/7 support", "7/24") and prose fractions ("1/2 off", "2/3").
            if y == nil && ((a == 24 && b == 7) || (a == 7 && b == 24)) { continue }
            if y == nil && !hasKeyword && a < b && b <= 4 && ns.length > match.range.length + 2 { continue }
            if let y, !(2020...2035).contains(y) {
                sawOutOfRangeYear = true
                continue
            }
            if (1...12).contains(a), (1...12).contains(b), prefersDayFirstSlashDates() {
                if let date = buildDate(month: b, day: a, year: y, now: now, calendar: calendar, preferPast: preferPast) {
                    return .matched(date)
                }
            }
            if (1...12).contains(a), (1...31).contains(b) {
                if let date = buildDate(month: a, day: b, year: y, now: now, calendar: calendar, preferPast: preferPast) {
                    return .matched(date)
                }
            }
            if (13...31).contains(a), (1...12).contains(b) {
                if let date = buildDate(month: b, day: a, year: y, now: now, calendar: calendar, preferPast: preferPast) {
                    return .matched(date)
                }
            }
        }
        return sawOutOfRangeYear ? .rejected : .none
    }

    private static func normalizeYear(_ token: String) -> Int? {
        guard let v = Int(token) else { return nil }
        return v < 100 ? 2000 + v : v
    }

    private static func cachedDateDetector() -> NSDataDetector? {
        let slot = "pausely.screenshot.dateDetector"
        if let cached = Thread.current.threadDictionary[slot] as? NSDataDetector {
            return cached
        }
        guard let created = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        Thread.current.threadDictionary[slot] = created
        return created
    }

    private static let monthMap: [String: Int] = [
        "jan": 1, "january": 1, "januar": 1, "janvier": 1, "janv": 1, "enero": 1, "ene": 1, "يناير": 1,
        "feb": 2, "february": 2, "februar": 2, "février": 2, "févr": 2, "fevr": 2, "fevrier": 2, "febrero": 2, "فبراير": 2,
        "mar": 3, "march": 3, "märz": 3, "mär": 3, "marz": 3, "mars": 3, "marzo": 3, "مارس": 3,
        "apr": 4, "april": 4, "avril": 4, "avr": 4, "abril": 4, "abr": 4, "أبريل": 4, "ابريل": 4,
        "may": 5, "mai": 5, "mayo": 5, "مايو": 5,
        "jun": 6, "june": 6, "juni": 6, "juin": 6, "junio": 6, "يونيو": 6,
        "jul": 7, "july": 7, "juli": 7, "juillet": 7, "juil": 7, "julio": 7, "يوليو": 7,
        "aug": 8, "august": 8, "août": 8, "aoû": 8, "aout": 8, "agosto": 8, "ago": 8, "أغسطس": 8, "اغسطس": 8,
        "sep": 9, "sept": 9, "september": 9, "septembre": 9, "septiembre": 9, "سبتمبر": 9,
        "oct": 10, "october": 10, "oktober": 10, "okt": 10, "octobre": 10, "octubre": 10, "أكتوبر": 10, "اكتوبر": 10,
        "nov": 11, "november": 11, "novembre": 11, "noviembre": 11, "نوفمبر": 11,
        "dec": 12, "december": 12, "dezember": 12, "dez": 12, "décembre": 12, "déc": 12, "diciembre": 12, "dic": 12, "ديسمبر": 12
    ]

    private static let monthFirstRegex = try? NSRegularExpression(
        pattern: #"\b([A-Za-zÀ-ÿ\u0600-\u06FF]{3,12})\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?\b"#,
        options: [.caseInsensitive]
    )

    private static let dayFirstRegex = try? NSRegularExpression(
        pattern: #"\b(\d{1,2})\.?\s+(?:de\s+)?([A-Za-zÀ-ÿ\u0600-\u06FF]{3,12})\.?(?:(?:\s+de)?,?\s+(\d{4}))?\b"#,
        options: [.caseInsensitive]
    )

    private static func parseMonthDay(in text: String, now: Date, calendar: Calendar, preferPast: Bool) -> Date? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        func resolved(monthToken: String, dayToken: String, yearToken: String?) -> Date? {
            guard let month = monthMap[monthToken.lowercased()], let day = Int(dayToken) else { return nil }
            let year = yearToken.flatMap(Int.init)
            return buildDate(month: month, day: day, year: year, now: now, calendar: calendar, preferPast: preferPast)
        }

        // Enumerate ALL matches so preceding words+numbers ("for 7 days, renews Dec 14") never hide the date.
        for match in monthFirstRegex?.matches(in: text, range: full) ?? [] {
            let monthToken = ns.substring(with: match.range(at: 1))
            let dayToken = ns.substring(with: match.range(at: 2))
            let yearToken = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)) : nil
            if let date = resolved(monthToken: monthToken, dayToken: dayToken, yearToken: yearToken) { return date }
        }
        for match in dayFirstRegex?.matches(in: text, range: full) ?? [] {
            let dayToken = ns.substring(with: match.range(at: 1))
            let monthToken = ns.substring(with: match.range(at: 2))
            let yearToken = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)) : nil
            if let date = resolved(monthToken: monthToken, dayToken: dayToken, yearToken: yearToken) { return date }
        }
        return nil
    }
}
