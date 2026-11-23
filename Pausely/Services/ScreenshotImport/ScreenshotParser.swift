import CoreGraphics
import Foundation

/// On-device parser for screenshots of Apple *Settings › Subscriptions* and bank/card recurring
/// charge lists. Pure value logic over Vision OCR bounding boxes so every edge case is unit tested
/// without needing images or simulators.
enum ScreenshotParser {

    /// One recognized text run from Vision (`VNRecognizedTextObservation`) in normalized image
    /// coordinates: origin at bottom-left (`y = 1.0` at top of screenshot, `y = 0.0` at bottom).
    struct TextObservation: Sendable, Equatable {
        let text: String
        let boundingBox: CGRect

        init(text: String, boundingBox: CGRect) {
            self.text = text
            self.boundingBox = boundingBox
        }
    }

    /// One subscription candidate read from one or more screenshots.
    struct DetectedItem: Identifiable, Equatable, Sendable {
        let id: String
        var name: String
        var category: String
        var amount: Decimal?
        var currency: String
        var frequency: BillingFrequency
        var renewalDate: Date?
        var trialEndsAt: Date?
        var isCancelled: Bool
        /// True when the subscription is explicitly listed in a free trial.
        var isTrial: Bool { trialEndsAt != nil }

        func tallyLine() -> TallyLine? {
            guard let amount, amount > 0 else { return nil }
            return TallyLine(
                name: name,
                category: category,
                amount: amount,
                currency: currency,
                isConfirmed: true,
                frequency: frequency,
                anchor: renewalDate,
                trialEndsAt: trialEndsAt
            )
        }
    }

    /// One horizontal visual line formed by clustering spatially aligned OCR boxes.
    struct VisualLine: Equatable, Sendable {
        let text: String
        let parts: [TextObservation]
        let minY: CGFloat
        let maxY: CGFloat
        let midY: CGFloat
        let height: CGFloat
    }

    // MARK: - Public Entry Points

    /// Parses multiple screenshots (e.g. a scrolled Apple Subscriptions list) and merges duplicates.
    static func parse(pages: [[TextObservation]],
                      defaultCurrency: String,
                      now: Date = Date(),
                      calendar: Calendar = .billing) -> [DetectedItem] {
        let catalog = MerchantCatalog.builtin.extending(with: CatalogData.entries.map {
            ($0.name, $0.category.rawValue, $0.cancellationURL)
        })
        var merged: [DetectedItem] = []
        for page in pages {
            let items = parseSinglePage(page, catalog: catalog, defaultCurrency: defaultCurrency, now: now, calendar: calendar)
            for item in items {
                merge(item, into: &merged)
            }
        }
        // Active subscriptions first (highest yearly cost first), then inactive/expired below.
        return merged.sorted { lhs, rhs in
            if lhs.isCancelled != rhs.isCancelled { return !lhs.isCancelled }
            let lCost = (lhs.amount ?? 0) * ProvenSubscription.periodsPerYear(lhs.frequency)
            let rCost = (rhs.amount ?? 0) * ProvenSubscription.periodsPerYear(rhs.frequency)
            if lCost != rCost { return lCost > rCost }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Convenience helper for parsing plain top-to-bottom OCR lines (useful in tests and fallback paths).
    static func parse(lines: [String],
                      defaultCurrency: String,
                      now: Date = Date(),
                      calendar: Calendar = .billing) -> [DetectedItem] {
        let count = max(lines.count, 1)
        let step = min(0.042, 0.85 / CGFloat(count))
        let observations = lines.enumerated().map { idx, text in
            let y = 0.92 - CGFloat(idx) * step
            return TextObservation(text: text, boundingBox: CGRect(x: 0.08, y: max(0.02, y), width: 0.84, height: min(0.024, step * 0.65)))
        }
        return parse(pages: [observations], defaultCurrency: defaultCurrency, now: now, calendar: calendar)
    }

    // MARK: - Spatial Line Clustering

    static func clusterLines(_ observations: [TextObservation]) -> [VisualLine] {
        let cleaned = observations.compactMap { obs -> TextObservation? in
            let trimmed = ReceiptTextAnalyzer.normalizingDigits(obs.text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return TextObservation(text: trimmed, boundingBox: obs.boundingBox)
        }
        // Top-to-bottom (higher midY first in Vision normalized space), then left-to-right.
        let sorted = cleaned.sorted { lhs, rhs in
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.004 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        var groups: [[TextObservation]] = []
        for obs in sorted {
            if let idx = groups.firstIndex(where: { group in
                let avgY = group.map(\.boundingBox.midY).reduce(0, +) / CGFloat(group.count)
                let maxH = max(group.map(\.boundingBox.height).max() ?? 0.02, obs.boundingBox.height)
                return abs(obs.boundingBox.midY - avgY) <= max(maxH * 0.65, 0.014)
            }) {
                groups[idx].append(obs)
            } else {
                groups.append([obs])
            }
        }

        return groups.map { group in
            let ordered = group.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let minY = ordered.map(\.boundingBox.minY).min() ?? 0
            let maxY = ordered.map(\.boundingBox.maxY).max() ?? 0
            let midY = ordered.map(\.boundingBox.midY).reduce(0, +) / CGFloat(ordered.count)
            let height = max(maxY - minY, 0.01)
            let joined = ordered.map(\.text).joined(separator: "  ")
            return VisualLine(text: joined, parts: ordered, minY: minY, maxY: maxY, midY: midY, height: height)
        }
        .sorted { $0.midY > $1.midY }
    }

    // MARK: - Page Parsing

    private enum SectionState { case unknown, active, inactive }

    private static func parseSinglePage(_ observations: [TextObservation],
                                        catalog: MerchantCatalog,
                                        defaultCurrency: String,
                                        now: Date,
                                        calendar: Calendar) -> [DetectedItem] {
        let lines = clusterLines(observations)
        var section: SectionState = .unknown
        var items: [DetectedItem] = []

        // Accumulator for multi-line Apple Settings subscription cards.
        struct PendingCard {
            var name: String
            var category: String
            var amount: Decimal?
            var currency: String
            var frequency: BillingFrequency?
            var renewalDate: Date?
            var trialEndsAt: Date?
            var isCancelled: Bool
            var lastMinY: CGFloat
        }

        var current: PendingCard?

        func flushCurrent() {
            guard let card = current else { return }
            current = nil
            // Require at least a price OR a renewal/trial/expiry date OR a known subscription service
            // inside an explicit Active/Inactive subscriptions list.
            guard card.amount != nil || card.renewalDate != nil || card.trialEndsAt != nil || card.isCancelled else { return }
            let item = DetectedItem(
                id: card.name.lowercased(),
                name: card.name,
                category: card.category,
                amount: card.amount,
                currency: card.currency,
                frequency: card.frequency ?? .monthly,
                renewalDate: card.renewalDate,
                trialEndsAt: card.trialEndsAt,
                isCancelled: card.isCancelled
            )
            merge(item, into: &items)
        }

        for line in lines {
            let text = line.text
            let lower = text.lowercased()

            // Section headers ("ACTIVE", "INACTIVE", "EXPIRED")
            if isActiveHeader(lower) {
                flushCurrent()
                section = .active
                continue
            }
            if isInactiveHeader(lower) {
                flushCurrent()
                section = .inactive
                continue
            }
            if isChromeNoise(text, lower: lower) { continue }

            let price = extractPrice(in: text, defaultCurrency: defaultCurrency)
            let freq = extractFrequency(in: lower)
            let dateInfo = extractDateInfo(in: text, now: now, calendar: calendar)
            let isExpiredLine = containsExpiryWord(lower)
            let isTrialLine = containsTrialWord(lower)

            // 1. Single-line bank/card or compact row containing BOTH a name AND a price (e.g. "Netflix  $19.99/mo").
            if let price, let leftName = extractLeadingName(from: line, priceRange: price.range, catalog: catalog) {
                flushCurrent()
                let resolved = resolveService(leftName, catalog: catalog)
                let cancelled = section == .inactive || isExpiredLine
                let item = DetectedItem(
                    id: resolved.name.lowercased(),
                    name: resolved.name,
                    category: resolved.category,
                    amount: price.amount,
                    currency: price.currency,
                    frequency: freq ?? .monthly,
                    renewalDate: isTrialLine ? nil : dateInfo.date,
                    trialEndsAt: isTrialLine ? dateInfo.date : nil,
                    isCancelled: cancelled
                )
                merge(item, into: &items)
                // Keep a lightweight open card in case the very next tight subline carries "Renews Dec 15".
                current = PendingCard(
                    name: item.name,
                    category: item.category,
                    amount: item.amount,
                    currency: item.currency,
                    frequency: freq,
                    renewalDate: item.renewalDate,
                    trialEndsAt: item.trialEndsAt,
                    isCancelled: item.isCancelled,
                    lastMinY: line.minY
                )
                continue
            }

            // 2. Detail line (price-only, renewal-date-only, trial-only, or expiry-only) attaches to open card.
            let isDetailOnly = price != nil || dateInfo.hasKeyword || isExpiredLine || isTrialLine || freq != nil
            if isDetailOnly, var card = current, (card.lastMinY - line.maxY) <= 0.085 {
                if let price, card.amount == nil {
                    card.amount = price.amount
                    card.currency = price.currency
                }
                if let freq { card.frequency = freq }
                if let date = dateInfo.date {
                    if isTrialLine {
                        card.trialEndsAt = date
                        if card.renewalDate == nil { card.renewalDate = date }
                    } else if !isExpiredLine {
                        card.renewalDate = date
                    }
                }
                if isExpiredLine { card.isCancelled = true }
                card.lastMinY = line.minY
                current = card
                continue
            }

            // 3. Could this line be a plan subtitle for the currently open card (e.g. "Standard Plan", "200 GB")?
            if var card = current,
               (card.lastMinY - line.maxY) <= 0.045,
               card.amount == nil, card.renewalDate == nil,
               isPlanSubtitle(text, forService: card.name, catalog: catalog) {
                if let freq { card.frequency = freq }
                card.lastMinY = line.minY
                current = card
                continue
            }

            // 4. Otherwise, if this line looks like a service name, start a new card.
            if let cleanedName = cleanCandidateServiceName(text) {
                let resolved = resolveService(cleanedName, catalog: catalog)
                // Accept known services anywhere, or plausible names inside a subscription list or before details.
                if resolved.isKnown || isPlausibleTitle(cleanedName) {
                    flushCurrent()
                    current = PendingCard(
                        name: resolved.name,
                        category: resolved.category,
                        amount: price?.amount,
                        currency: price?.currency ?? defaultCurrency,
                        frequency: freq,
                        renewalDate: isTrialLine ? nil : dateInfo.date,
                        trialEndsAt: isTrialLine ? dateInfo.date : nil,
                        isCancelled: section == .inactive || isExpiredLine,
                        lastMinY: line.minY
                    )
                }
            }
        }

        flushCurrent()
        return items
    }

    // MARK: - Merging & Deduplication

    private static func merge(_ incoming: DetectedItem, into list: inout [DetectedItem]) {
        if let idx = list.firstIndex(where: { ServiceName.same($0.name, incoming.name) }) {
            var existing = list[idx]
            if existing.amount == nil, let amount = incoming.amount {
                existing.amount = amount
                existing.currency = incoming.currency
            }
            if existing.renewalDate == nil, let renewal = incoming.renewalDate {
                existing.renewalDate = renewal
            }
            if existing.trialEndsAt == nil, let trial = incoming.trialEndsAt {
                existing.trialEndsAt = trial
            }
            if incoming.isCancelled {
                existing.isCancelled = true
            }
            if existing.category == SubscriptionCategory.other.rawValue,
               incoming.category != SubscriptionCategory.other.rawValue {
                existing.category = incoming.category
            }
            if existing.frequency == .monthly, incoming.frequency != .monthly {
                existing.frequency = incoming.frequency
            }
            list[idx] = existing
        } else {
            list.append(incoming)
        }
    }

    // MARK: - Extraction Helpers

    private struct PriceMatch {
        let amount: Decimal
        let currency: String
        let range: NSRange
    }

    private static func extractPrice(in text: String, defaultCurrency: String) -> PriceMatch? {
        let figures = ReceiptTextAnalyzer.moneyFigures(in: text)
        for fig in figures {
            let currency = fig.money.currency ?? defaultCurrency
            let maxCap: Decimal = ReceiptTextAnalyzer.wholeUnitCurrencies.contains(currency) ? 2_000_000 : 5_000
            if fig.money.amount > 0, fig.money.amount < maxCap {
                return PriceMatch(amount: fig.money.amount, currency: currency, range: fig.range)
            }
        }
        return nil
    }

    private static func extractLeadingName(from line: VisualLine, priceRange: NSRange, catalog: MerchantCatalog) -> String? {
        let ns = line.text as NSString
        guard priceRange.location > 1 else { return nil }
        let prefix = ns.substring(to: priceRange.location)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—·•|:")))
        guard let cleaned = cleanCandidateServiceName(prefix) else { return nil }
        let lower = cleaned.lowercased()
        // Reject lines that are pure billing labels ("Renews Dec 14", "Total", "Next charge").
        if startsWithDateOrBillingKeyword(lower) { return nil }
        let resolved = resolveService(cleaned, catalog: catalog)
        return (resolved.isKnown || isPlausibleTitle(cleaned)) ? cleaned : nil
    }

    static func extractFrequency(in lower: String) -> BillingFrequency? {
        if lower.contains("/wk") || lower.contains("/week") || lower.contains("per week") || lower.contains("weekly")
            || lower.contains("pro woche") || lower.contains("par semaine") || lower.contains("semanal") || lower.contains("週額") || lower.contains("أسبوعي") {
            return .weekly
        }
        if lower.contains("/2wk") || lower.contains("every 2 weeks") || lower.contains("biweekly") || lower.contains("bi-weekly") {
            return .biweekly
        }
        if lower.contains("/3mo") || lower.contains("every 3 months") || lower.contains("quarterly") || lower.contains("3 months") {
            return .quarterly
        }
        if lower.contains("/6mo") || lower.contains("every 6 months") || lower.contains("semiannual") || lower.contains("6 months") {
            return .semiannual
        }
        if lower.contains("/yr") || lower.contains("/year") || lower.contains("per year") || lower.contains("yearly")
            || lower.contains("annual") || lower.contains("pro jahr") || lower.contains("par an") || lower.contains("anual")
            || lower.contains("年額") || lower.contains("سنوي") {
            return .yearly
        }
        if lower.contains("/mo") || lower.contains("/month") || lower.contains("per month") || lower.contains("monthly")
            || lower.contains("1 month") || lower.contains("pro monat") || lower.contains("par mois") || lower.contains("mensual")
            || lower.contains("月額") || lower.contains("شهري") {
            return .monthly
        }
        return nil
    }

    private struct DateMatch {
        let date: Date?
        let hasKeyword: Bool
    }

    private static let dateKeywords = [
        "renews", "renew", "next bill", "next charge", "next payment", "billing date", "due ",
        "trial ends", "free trial", "expires", "expired", "ends ", "cancels ",
        "se renouvelle", "renouvellement", "verlängert", "läuft ab", "se renueva", "vence",
        "更新日", "次回請求", "期限", "يتجدد", "ينتهي"
    ]

    private static func extractDateInfo(in text: String, now: Date, calendar: Calendar) -> DateMatch {
        let lower = text.lowercased()
        let hasKeyword = dateKeywords.contains { lower.contains($0) }

        // 1. Explicit month-day pattern (e.g. "Dec 14", "Dec 14, 2026", "14 Dec 2026", "November 3")
        if let explicit = parseMonthDay(in: text, now: now, calendar: calendar) {
            return DateMatch(date: calendar.noon(of: explicit), hasKeyword: hasKeyword)
        }

        // 2. Fallback to NSDataDetector for localized dates (ISO, DD/MM/YYYY, Japanese, German, etc.)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(location: 0, length: (text as NSString).length)
            if let match = detector.firstMatch(in: text, options: [], range: range),
               let detected = match.date {
                // Reject improbable dates more than 3 years away (e.g. OCR reading a 4-digit card suffix as a year).
                let days = abs(calendar.calendarDays(from: now, to: detected))
                if days <= 1_100 {
                    return DateMatch(date: calendar.noon(of: detected), hasKeyword: hasKeyword)
                }
            }
        }
        return DateMatch(date: nil, hasKeyword: hasKeyword)
    }

    private static let monthMap: [String: Int] = [
        "jan": 1, "january": 1, "januar": 1, "janvier": 1, "enero": 1,
        "feb": 2, "february": 2, "februar": 2, "février": 2, "febrero": 2,
        "mar": 3, "march": 3, "märz": 3, "mars": 3, "marzo": 3,
        "apr": 4, "april": 4, "avril": 4, "abril": 4,
        "may": 5, "mai": 5, "mayo": 5,
        "jun": 6, "june": 6, "juni": 6, "juin": 6, "junio": 6,
        "jul": 7, "july": 7, "juli": 7, "juillet": 7, "julio": 7,
        "aug": 8, "august": 8, "août": 8, "agosto": 8,
        "sep": 9, "sept": 9, "september": 9, "septembre": 9, "septiembre": 9,
        "oct": 10, "october": 10, "oktober": 10, "octobre": 10, "octubre": 10,
        "nov": 11, "november": 11, "novembre": 11, "noviembre": 11,
        "dec": 12, "december": 12, "dezember": 12, "décembre": 12, "diciembre": 12,
    ]

    private static let monthFirstRegex = try? NSRegularExpression(
        pattern: #"\b([A-Za-zÀ-ÿ]{3,10})\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?\b"#,
        options: [.caseInsensitive]
    )

    private static let dayFirstRegex = try? NSRegularExpression(
        pattern: #"\b(\d{1,2})\.?\s+([A-Za-zÀ-ÿ]{3,10})\.?(?:,?\s+(\d{4}))?\b"#,
        options: [.caseInsensitive]
    )

    private static func parseMonthDay(in text: String, now: Date, calendar: Calendar) -> Date? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        func build(monthToken: String, dayToken: String, yearToken: String?) -> Date? {
            guard let month = monthMap[monthToken.lowercased()],
                  let day = Int(dayToken), (1...31).contains(day) else { return nil }
            if let yearToken, let year = Int(yearToken), (2020...2035).contains(year) {
                return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            }
            // No year given ("Renews Dec 14"): use current year, or next year if more than 30 days in the past.
            let currentYear = calendar.component(.year, from: now)
            guard let candidate = calendar.date(from: DateComponents(year: currentYear, month: month, day: day, hour: 12)) else { return nil }
            if calendar.calendarDays(from: now, to: candidate) < -30 {
                return calendar.date(from: DateComponents(year: currentYear + 1, month: month, day: day, hour: 12))
            }
            return candidate
        }

        if let match = monthFirstRegex?.firstMatch(in: text, range: full) {
            let monthToken = ns.substring(with: match.range(at: 1))
            let dayToken = ns.substring(with: match.range(at: 2))
            let yearToken = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)) : nil
            if let date = build(monthToken: monthToken, dayToken: dayToken, yearToken: yearToken) { return date }
        }
        if let match = dayFirstRegex?.firstMatch(in: text, range: full) {
            let dayToken = ns.substring(with: match.range(at: 1))
            let monthToken = ns.substring(with: match.range(at: 2))
            let yearToken = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)) : nil
            if let date = build(monthToken: monthToken, dayToken: dayToken, yearToken: yearToken) { return date }
        }
        return nil
    }

    // MARK: - Service Name Cleaning & Classification

    private static func resolveService(_ raw: String, catalog: MerchantCatalog) -> (name: String, category: String, isKnown: Bool) {
        if let match = catalog.resolve(hint: raw, senderName: raw, senderDomain: ""), match.isKnown {
            return (match.displayName, match.category ?? SubscriptionCategory.other.rawValue, true)
        }
        if let service = CancelHelp.service(named: raw) {
            let cat = CatalogData.entries.first { $0.name.caseInsensitiveCompare(service.name) == .orderedSame }?.category.rawValue
                ?? SubscriptionCategory.other.rawValue
            return (service.name, cat, true)
        }
        if let entry = CatalogData.entries.first(where: { ServiceName.same($0.name, raw) }) {
            return (entry.name, entry.category.rawValue, true)
        }
        return (raw, SubscriptionCategory.other.rawValue, false)
    }

    private static func cleanCandidateServiceName(_ raw: String) -> String? {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip common bank statement prefixes/suffixes ("APPLE.COM/BILL", "SPOTIFY USA", "NETFLIX.COM", "*1234").
        name = name.replacingOccurrences(of: #"\s*\*\d{4}\b"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s+(?:USA|US|INC\.?|LLC|LTD\.?|CORP\.?|BILLING|RECURRING|AUTOPAY)$"#,
                                         with: "", options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"\.(?:com|io|tv|app|co|org)$"#, with: "", options: [.regularExpression, .caseInsensitive])
        name = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ">›•·")))
        guard name.count >= 2, name.count <= 48 else { return nil }
        guard name.contains(where: \.isLetter) else { return nil }
        // Convert ALL-CAPS bank statement descriptors ("NETFLIX", "SPOTIFY") to readable casing.
        if name == name.uppercased(), name.count > 4 {
            name = name.capitalized
        }
        return name
    }

    private static func isPlanSubtitle(_ text: String, forService serviceName: String, catalog: MerchantCatalog) -> Bool {
        // If this line itself matches a DIFFERENT known service, it's a new card, not a subtitle.
        if let cleaned = cleanCandidateServiceName(text) {
            let resolved = resolveService(cleaned, catalog: catalog)
            if resolved.isKnown, !ServiceName.same(resolved.name, serviceName) { return false }
        }
        let lower = text.lowercased()
        let planIndicators = [
            "plan", "tier", "individual", "family", "duo", "student", "personal", "standard", "basic",
            "premium", "pro", "plus", "ultra", "max", "monthly", "annual", "yearly", "gb", "tb",
            "with ads", "ad-free", "bundle", "membership", "subscription", "storage"
        ]
        if planIndicators.contains(where: { lower.contains($0) }) { return true }
        // e.g. "Super Duolingo" right under "Duolingo"
        if ServiceName.same(text, serviceName) { return true }
        return false
    }

    private static func isActiveHeader(_ lower: String) -> Bool {
        ["active", "active subscriptions", "actifs", "aktiv", "activas", "有効", "نشطة"].contains(lower.trimmingCharacters(in: .whitespaces))
    }

    private static func isInactiveHeader(_ lower: String) -> Bool {
        ["inactive", "expired", "inactive subscriptions", "cancelled", "canceled",
         "inactifs", "abgelaufen", "inactivas", "期限切れ", "منتهية"].contains(lower.trimmingCharacters(in: .whitespaces))
    }

    private static func containsExpiryWord(_ lower: String) -> Bool {
        ["expired", "expires", "cancelled", "canceled", "ended", "abgelaufen", "expiré", "venció", "期限切れ", "منتهي"].contains { lower.contains($0) }
    }

    private static func containsTrialWord(_ lower: String) -> Bool {
        ["free trial", "trial ends", "essai gratuit", "kostenlose testphase", "prueba gratis", "無料トライアル", "تجربة مجانية"].contains { lower.contains($0) }
    }

    private static func startsWithDateOrBillingKeyword(_ lower: String) -> Bool {
        let prefixes = ["renews", "renew", "expires", "expired", "trial", "free trial", "total", "subtotal", "tax",
                        "next ", "billed ", "charged ", "due ", "upcoming", "monthly total", "yearly total"]
        return prefixes.contains { lower.hasPrefix($0) }
    }

    private static func isChromeNoise(_ raw: String, lower: String) -> Bool {
        // Time in iOS status bar ("9:41", "10:25 AM")
        if raw.range(of: #"^\d{1,2}:\d{2}(?:\s?[AP]M)?$"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // Battery % or carrier indicator
        if raw.range(of: #"^\d{1,3}%$"#, options: .regularExpression) != nil { return true }
        if ["5g", "4g", "lte", "wi-fi", "wifi", "sos", "carrier"].contains(lower) { return true }
        let chrome = [
            "subscriptions", "settings", "apple account", "apple id", "back", "done", "edit", "search", "cancel",
            "share with family", "share new subscriptions", "renewal receipts", "a receipt will be sent",
            "recurring", "recurring payments", "recurring charges", "upcoming bills", "bills & subscriptions",
            "manage", "see all", "view all", "filter", "sort", "today", "yesterday", "this month", "next month"
        ]
        if chrome.contains(lower) { return true }
        if lower.hasPrefix("a receipt will be sent") || lower.hasPrefix("subscriptions you share") || lower.hasPrefix("automatically share") { return true }
        return false
    }

    private static func isPlausibleTitle(_ name: String) -> Bool {
        let lower = name.lowercased()
        if startsWithDateOrBillingKeyword(lower) { return false }
        let words = name.split(whereSeparator: \.isWhitespace)
        guard (1...5).contains(words.count) else { return false }
        // Reject full sentences (ending with period or containing 6+ words).
        if name.hasSuffix(".") || name.hasSuffix("?") || name.hasSuffix("!") { return false }
        return true
    }
}
