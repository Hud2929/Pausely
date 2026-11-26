import CoreGraphics
import Foundation

/// Price/frequency pairing, LTR + RTL row name extraction, bank descriptor cleanup, and plan-subtitle
/// detection for `ScreenshotParser`. Kept separate from page layout orchestration in `ScreenshotParser.swift`.
extension ScreenshotParser {

    struct PriceMatch {
        let amount: Decimal
        let currency: String
        let range: NSRange
        /// Earliest and latest price spans on the line so LTR/RTL name slicing skips all price tokens
        /// (e.g. "Netflix  Was $22.99  Now $15.49/mo" slices before "$22.99", not before "$15.49").
        let earliestRange: NSRange
        let latestRange: NSRange
    }

    struct RowName {
        let name: String
        let date: Date?
        let paymentMethod: String?
    }

    private static let discountedLeadRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(?:was|save|off|discount|rabatt|remise|descuento)\W{0,3}$"#
    )

    /// Extracts the active charge price AND pairs it with its own adjacent frequency when a line
    /// shows multiple prices (e.g. "Was $19.99 Now $14.99/mo" or "$6.99/mo ($83.88/year)").
    static func extractPriceAndFrequency(in text: String, defaultCurrency: String) -> (price: PriceMatch?, frequency: BillingFrequency?) {
        let figures = ReceiptTextAnalyzer.moneyFigures(in: text)
        let ns = text as NSString
        var valid: [(match: PriceMatch, localFreq: BillingFrequency?, isDiscounted: Bool, isBilledTotal: Bool)] = []

        for (i, fig) in figures.enumerated() {
            let currency = fig.money.currency ?? defaultCurrency
            let maxCap: Decimal = ReceiptTextAnalyzer.wholeUnitCurrencies.contains(currency) ? 2_000_000 : 5_000
            guard fig.money.amount > 0, fig.money.amount < maxCap else { continue }

            let leadStart = max(0, fig.range.location - 18)
            let lead = ns.substring(with: NSRange(location: leadStart, length: fig.range.location - leadStart))
            let isDiscounted = discountedLeadRegex?.firstMatch(in: lead, range: NSRange(location: 0, length: (lead as NSString).length)) != nil
            let isBilledTotal = lead.lowercased().contains("billed") || lead.lowercased().contains("charged")

            let afterStart = fig.range.location + fig.range.length
            let nextStart = i + 1 < figures.count ? figures[i + 1].range.location : ns.length
            let afterLen = max(0, min(nextStart - afterStart, 22))
            let after = ns.substring(with: NSRange(location: afterStart, length: afterLen)).lowercased()
            let localFreq = extractFrequency(in: after)

            valid.append((PriceMatch(amount: fig.money.amount, currency: currency, range: fig.range,
                                     earliestRange: fig.range, latestRange: fig.range),
                          localFreq, isDiscounted, isBilledTotal))
        }
        guard !valid.isEmpty else { return (nil, nil) }
        let earliest = valid.first!.match.range
        let latest = valid.last!.match.range
        func wrap(_ picked: (match: PriceMatch, localFreq: BillingFrequency?, isDiscounted: Bool, isBilledTotal: Bool)) -> (PriceMatch, BillingFrequency?) {
            let m = PriceMatch(amount: picked.match.amount, currency: picked.match.currency,
                               range: picked.match.range, earliestRange: earliest, latestRange: latest)
            return (m, picked.localFreq)
        }
        if valid.count == 1 {
            return wrap(valid[0])
        }
        if let billed = valid.first(where: { !$0.isDiscounted && ($0.isBilledTotal || $0.localFreq == .yearly) }) {
            return wrap(billed)
        }
        if let active = valid.last(where: { !$0.isDiscounted }) {
            return wrap(active)
        }
        return wrap(valid[0])
    }

    private static let trailingFrequencyPrefix = try? NSRegularExpression(
        pattern: #"^\s*(?:/\s*(?:month|mo|m|year|yr|y|week|wk|w|2wk|3mo|6mo|monat|jahr|woche|mois|an|année|semaine|mes|año|semana|月|年|週|شهر|سنة|أسبوع)|(?:per|a)\s+(?:month|year|week))\b"#,
        options: [.caseInsensitive]
    )

    static func extractRowNameAndDate(from line: VisualLine,
                                      price: PriceMatch,
                                      catalog: MerchantCatalog,
                                      now: Date,
                                      calendar: Calendar) -> RowName? {
        let ns = line.text as NSString
        let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—−·•|:"))

        // 1. Standard LTR layout: Name (optionally preceded by a bank date) before the earliest price.
        if price.earliestRange.location > 1 {
            var rawPrefix = ns.substring(to: price.earliestRange.location).trimmingCharacters(in: trimSet)
            // Strip trailing promo connector ("Netflix  Was $22.99 Now $15.49" -> "Netflix").
            rawPrefix = rawPrefix.replacingOccurrences(
                of: #"(?<=\S)\s+(?:was|now|from|only|just|starting\s+at)$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            ).trimmingCharacters(in: trimSet)
            let stripped = stripLeadingDate(from: rawPrefix, now: now, calendar: calendar)
            let candidate = stripped.remainder.trimmingCharacters(in: trimSet)
            if let cleaned = cleanCandidateServiceName(candidate) {
                let lower = cleaned.name.lowercased()
                if !startsWithDateOrBillingKeyword(lower) {
                    let resolved = resolveService(cleaned.name, catalog: catalog)
                    if resolved.isKnown || isPlausibleTitle(cleaned.name) {
                        return RowName(name: cleaned.name, date: stripped.date, paymentMethod: cleaned.paymentMethod)
                    }
                }
            }
        }

        // 2. RTL / price-first layout (e.g. Arabic screenshot: "49.99 ر.س./شهر  Netflix").
        let afterLoc = price.latestRange.location + price.latestRange.length
        if price.earliestRange.location <= 2, afterLoc < ns.length {
            var tail = ns.substring(from: afterLoc)
            if let m = trailingFrequencyPrefix?.firstMatch(in: tail, range: NSRange(location: 0, length: (tail as NSString).length)) {
                tail = (tail as NSString).substring(from: m.range.location + m.range.length)
            }
            tail = tail.trimmingCharacters(in: trimSet)
            if let cleaned = cleanCandidateServiceName(tail) {
                let lower = cleaned.name.lowercased()
                if !startsWithDateOrBillingKeyword(lower), !isChromeNoise(cleaned.name, lower: lower), !isRowLabel(lower) {
                    let resolved = resolveService(cleaned.name, catalog: catalog)
                    if resolved.isKnown || isPlausibleTitle(cleaned.name) {
                        return RowName(name: cleaned.name, date: nil, paymentMethod: cleaned.paymentMethod)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Service Name Cleaning & Classification

    static func resolveService(_ raw: String, catalog: MerchantCatalog)
        -> (name: String, category: String, isKnown: Bool, isSubscription: Bool) {
        if let match = catalog.resolve(hint: raw, senderName: raw, senderDomain: ""), match.isKnown {
            let name = addsOnlyAPlan(raw, to: match.displayName) ? raw : match.displayName
            let category = SubscriptionCategory.matching(match.category).displayName
            return (name, category, true, match.kind != .mixedCommerce)
        }
        if let service = CancelHelp.service(named: raw) {
            let cat = CatalogData.entries.first { $0.name.caseInsensitiveCompare(service.name) == .orderedSame }?.category.displayName
                ?? SubscriptionCategory.other.displayName
            return (service.name, cat, true, true)
        }
        if let entry = CatalogData.entries.first(where: { ServiceName.same($0.name, raw) }) {
            return (addsOnlyAPlan(raw, to: entry.name) ? raw : entry.name, entry.category.displayName, true, true)
        }
        // On-device Vision OCR (especially iOS 27 Neural Engine with automatic language detection) can read
        // lowercase "i" in "iCloud+" as Spanish "¡" ("¡Cloud+") or drop a tiny trailing "+" ("iCloud").
        if raw.hasPrefix("¡") {
            let fixedI = "i" + raw.dropFirst()
            let resolvedI = resolveService(fixedI, catalog: catalog)
            if resolvedI.isKnown { return resolvedI }
        }
        if !raw.hasSuffix("+") {
            let withPlus = raw + "+"
            if let match = catalog.resolve(hint: withPlus, senderName: withPlus, senderDomain: ""), match.isKnown {
                let category = SubscriptionCategory.matching(match.category).displayName
                return (match.displayName, category, true, match.kind != .mixedCommerce)
            }
            if let entry = CatalogData.entries.first(where: { $0.name.caseInsensitiveCompare(withPlus) == .orderedSame }) {
                return (entry.name, entry.category.displayName, true, true)
            }
        }
        return (raw, SubscriptionCategory.other.displayName, false, false)
    }

    static func cleanCandidateServiceName(_ raw: String) -> (name: String, paymentMethod: String?)? {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var paymentMethod: String?

        let upper = name.uppercased()
        if upper.hasPrefix("GOOGLE *") || upper.hasPrefix("GOOGLE*") {
            paymentMethod = "Google Play"
            name = name.replacingOccurrences(of: #"^GOOGLE\s*\*\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        } else if upper.hasPrefix("APL*") || upper.contains("APPLE.COM/BILL") {
            paymentMethod = "Apple"
            name = name.replacingOccurrences(of: #"^APL\s*\*\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        } else {
            name = name.replacingOccurrences(of: #"^(?:PAYPAL|SQ|SP|TST|STRIPE|PP)\s*\*\s*"#,
                                             with: "", options: [.regularExpression, .caseInsensitive])
        }

        name = name.replacingOccurrences(of: #"/(?:BILL|US|UK|CA|EU)\b"#, with: "", options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"\s*\*[A-Za-z0-9]{4,}\b"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s+(?:USA|US|UK|CA|EU|IE|INC\.?|LLC|LTD\.?|CORP\.?|GMBH|B\.V\.?|S\.A\.?|AB|PTY|PLC|BILLING|RECURRING|AUTOPAY)$"#,
                                         with: "", options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"\.(?:com|io|tv|app|co|org|net|de|fr|es|uk|ca)$"#,
                                         with: "", options: [.regularExpression, .caseInsensitive])
        for _ in 0..<2 {
            name = name.replacingOccurrences(of: #"(?<=\S)\s+(?:#?\d{4,}|(?=[A-Za-z]*\d)(?=\d*[A-Za-z])[A-Za-z0-9]{5,})$"#,
                                             with: "", options: .regularExpression)
        }
        name = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ">›•·-–—−")))
        guard name.count >= 2, name.count <= 48 else { return nil }
        guard name.contains(where: \.isLetter) else { return nil }
        if name == name.uppercased(), name.count > 4 {
            name = name.capitalized
        }
        return (name, paymentMethod)
    }

    static func isPlanSubtitle(_ text: String,
                               forService serviceName: String,
                               nextLine: VisualLine?,
                               defaultCurrency: String,
                               inSubscriptionList: Bool,
                               now: Date,
                               calendar: Calendar,
                               catalog: MerchantCatalog) -> Bool {
        if let cleaned = cleanCandidateServiceName(text) {
            let resolved = resolveService(cleaned.name, catalog: catalog)
            if resolved.isKnown, !ServiceName.same(resolved.name, serviceName) { return false }
        }
        let lower = text.lowercased()
        let planIndicators = [
            "plan", "tier", "individual", "family", "duo", "student", "personal", "standard", "basic",
            "premium", "pro", "plus", "ultra", "max", "monthly", "annual", "yearly", "gb", "tb",
            "with ads", "ad-free", "bundle", "membership", "subscription", "storage", "all-access", "all access",
            "unlimited", "forfait", "abo", "tarif", "ファミリー", "個人", "ベーシック", "عائلي", "فردي"
        ]
        if planIndicators.contains(where: { lower.contains($0) }) { return true }
        if ServiceName.same(text, serviceName) { return true }
        if inSubscriptionList, let next = nextLine {
            let nextLower = next.text.lowercased()
            let nextHasPrice = extractPriceAndFrequency(in: next.text, defaultCurrency: defaultCurrency).price != nil
            let nextHasDate = extractDateInfo(in: next.text, now: now, calendar: calendar).hasKeyword
            if nextHasPrice || nextHasDate || containsExpiryWord(nextLower) || containsTrialWord(nextLower) {
                return true
            }
        }
        return false
    }

    static func isPlausibleTitle(_ name: String) -> Bool {
        let lower = name.lowercased()
        if startsWithDateOrBillingKeyword(lower) { return false }
        if name.contains("•") || name.contains(" · ") { return false }
        let months = "jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec"
        if lower.range(of: "^\\d{1,2}\\.?\\s*(\(months))\\b", options: .regularExpression) != nil { return false }
        if lower.range(of: "^(\(months))[a-z]*\\.?\\s+\\d{1,2}\\b", options: .regularExpression) != nil { return false }
        let words = name.split(whereSeparator: \.isWhitespace)
        guard (1...5).contains(words.count) else { return false }
        if name.hasSuffix(".") || name.hasSuffix("?") || name.hasSuffix("!") { return false }
        return true
    }
}
