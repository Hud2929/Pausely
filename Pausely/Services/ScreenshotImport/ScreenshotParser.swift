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
        var paymentMethod: String? = nil
        /// Why the row may not be what it seems; such a row is shown but not ticked.
        var doubt: Doubt? = nil
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
                trialEndsAt: trialEndsAt,
                paymentMethod: paymentMethod
            )
        }
    }

    /// Why a row read from a screenshot is not taken as a subscription without the person's tick.
    enum Doubt: Equatable, Sendable {
        /// Outside a list of subscriptions or recurring payments, a charge with nothing saying it repeats
        /// (a bank's transactions listed Shell, REWE and Amazon as subscriptions, the rating of 2026-11-23).
        case mayNotRepeat
        /// "Every 4 weeks" is thirteen charges a year, which no billing period here holds: kept as monthly.
        case everyFourWeeks
        /// "Every 2 months": no billing period holds it, so half the charge is counted each month.
        case everyTwoMonths
        /// Rent, insurance, energy: a recurring bill, not a subscription, so not ticked for the person
        /// (a recurring-payments list had rent ticked, the rating of 2026-11-23).
        case aBill
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
                      calendar: Calendar = .billing,
                      rates: CurrencyRates = .fallback) -> [DetectedItem] {
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
        // Active subscriptions first (highest yearly cost in default currency first), then inactive/expired below.
        return merged.sorted { lhs, rhs in
            if lhs.isCancelled != rhs.isCancelled { return !lhs.isCancelled }
            let lRaw = (lhs.amount ?? 0) * ProvenSubscription.periodsPerYear(lhs.frequency)
            let rRaw = (rhs.amount ?? 0) * ProvenSubscription.periodsPerYear(rhs.frequency)
            let lCost = rates.convert(lRaw, from: lhs.currency, to: defaultCurrency) ?? 0
            let rCost = rates.convert(rRaw, from: rhs.currency, to: defaultCurrency) ?? 0
            if lCost != rCost { return lCost > rCost }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Convenience helper for parsing plain top-to-bottom OCR lines (useful in tests and fallback paths).
    static func parse(lines: [String],
                      defaultCurrency: String,
                      now: Date = Date(),
                      calendar: Calendar = .billing,
                      rates: CurrencyRates = .fallback) -> [DetectedItem] {
        let count = max(lines.count, 1)
        let step = min(0.042, 0.85 / CGFloat(count))
        let observations = lines.enumerated().map { idx, text in
            let y = 0.92 - CGFloat(idx) * step
            return TextObservation(text: text, boundingBox: CGRect(x: 0.08, y: max(0.02, y), width: 0.84, height: min(0.024, step * 0.65)))
        }
        return parse(pages: [observations], defaultCurrency: defaultCurrency, now: now, calendar: calendar, rates: rates)
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

    private static let appleScreenMarkers: Set<String> = [
        "subscriptions", "share new subscriptions", "renewal receipts", "apple account"
    ]

    private static func parseSinglePage(_ observations: [TextObservation],
                                        catalog: MerchantCatalog,
                                        defaultCurrency: String,
                                        now: Date,
                                        calendar: Calendar) -> [DetectedItem] {
        let lines = clusterLines(observations)
        var section: SectionState = .unknown
        let isAppleSubscriptionsScreen = lines.contains { line in
            let l = line.text.lowercased()
            return appleScreenMarkers.contains(l) || isActiveHeader(l) || isInactiveHeader(l)
        }
        let detectedPaymentMethod: String? = isAppleSubscriptionsScreen ? "Apple" : nil
        // Every row of such a list repeats; elsewhere (a bank's transactions) only what says so does.
        let listRepeats = isAppleSubscriptionsScreen || lines.contains { recurringListHeaders.contains($0.text.lowercased().trimmingCharacters(in: .whitespaces)) }
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
            /// Known to repeat: a subscription service, a list of them, or a line saying how often.
            var repeats: Bool
            var everyFourWeeks = false
            var everyTwoMonths = false
        }

        /// A line of how often and when ("Monthly · next 19 Dec 2026") that heads the row under it, as a bank's
        /// recurring payments are laid out: attached to the row above, every period and date was a row off.
        struct HeadingDetail {
            var frequency: BillingFrequency?
            var date: Date?
            var repeats: Bool
            var everyFourWeeks: Bool
            var everyTwoMonths: Bool
        }
        var heading: HeadingDetail?
        func applyHeading(to card: inout PendingCard) {
            guard let detail = heading else { return }
            heading = nil
            if let frequency = detail.frequency { card.frequency = frequency }
            if card.renewalDate == nil { card.renewalDate = detail.date }
            if detail.repeats { card.repeats = true }
            if detail.everyFourWeeks { card.everyFourWeeks = true }
            if detail.everyTwoMonths { card.everyTwoMonths = true }
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
                // Every 2 months, counted as half each month, so a year comes to what it costs.
                amount: card.everyTwoMonths ? card.amount.map { AmountText.rounded($0 / 2, currency: card.currency) } : card.amount,
                currency: card.currency,
                frequency: card.frequency ?? .monthly,
                renewalDate: card.renewalDate,
                trialEndsAt: card.trialEndsAt,
                isCancelled: card.isCancelled,
                paymentMethod: detectedPaymentMethod,
                doubt: isBill(card.name) ? .aBill
                    : !(card.repeats || card.trialEndsAt != nil) ? .mayNotRepeat
                    : card.everyTwoMonths ? .everyTwoMonths
                    : card.everyFourWeeks ? .everyFourWeeks : nil
            )
            merge(item, into: &items)
        }

        for (index, line) in lines.enumerated() {
            let text = line.text
            let lower = text.lowercased()
            let next = index + 1 < lines.count ? lines[index + 1] : nil

            // Section headers ("ACTIVE", "INACTIVE", "EXPIRED")
            if isActiveHeader(lower) {
                flushCurrent()
                heading = nil
                section = .active
                continue
            }
            if isInactiveHeader(lower) {
                flushCurrent()
                heading = nil
                section = .inactive
                continue
            }
            if isChromeNoise(text, lower: lower) { continue }
            // A row's own label ("Card payment", "Direct debit") is never a name (the rating of 2026-11-23).
            if isRowLabel(lower) { continue }

            let price = extractPrice(in: text, defaultCurrency: defaultCurrency)
            let freq = extractFrequency(in: lower)
            let dateInfo = extractDateInfo(in: text, now: now, calendar: calendar)
            let isExpiredLine = containsExpiryWord(lower)
            let isTrialLine = containsTrialWord(lower)
            let fourWeeks = isEveryFourWeeks(lower)
            let twoMonths = isEveryTwoMonths(lower)

            // Money coming in is never a subscription: a bank list showed "Salary +€3,200.00" as one,
            // ticked (the rating of 2026-11-23).
            if price != nil, isIncomeOrTransfer(lower) {
                flushCurrent()
                heading = nil
                continue
            }

            // 1. Single-line bank/card or compact row containing BOTH a name AND a price (e.g. "Netflix  $19.99/mo").
            // Kept open in `current` and emitted by `flushCurrent()` so a tight following subline
            // ("Renews Dec 15" or "Expired Oct 10, 2026") updates the card before merging.
            if let price, let leftName = extractLeadingName(from: line, priceRange: price.range, catalog: catalog) {
                flushCurrent()
                let resolved = resolveService(leftName, catalog: catalog)
                let cancelled = section == .inactive || isExpiredLine
                var card = PendingCard(
                    name: resolved.name,
                    category: resolved.category,
                    amount: price.amount,
                    currency: price.currency,
                    frequency: freq ?? .monthly,
                    renewalDate: dateInfo.date,
                    trialEndsAt: isTrialLine ? dateInfo.date : nil,
                    isCancelled: cancelled,
                    lastMinY: line.minY,
                    repeats: listRepeats || resolved.isSubscription || freq != nil || fourWeeks || twoMonths || dateInfo.hasKeyword,
                    everyFourWeeks: fourWeeks,
                    everyTwoMonths: twoMonths
                )
                applyHeading(to: &card)
                current = card
                continue
            }

            // 2a. A line of how often and when that sits closer to the row under it than to the row above heads
            // the row under it.
            let isPeriodOrDate = price == nil && (freq != nil || fourWeeks || twoMonths || dateInfo.date != nil)
            if isPeriodOrDate, let next {
                let below = line.minY - next.maxY
                let above = current.map { $0.lastMinY - line.maxY } ?? .greatestFiniteMagnitude
                // Clearly closer: on an evenly spaced list a detail stays with the row it follows.
                if below + 0.006 < above {
                    heading = HeadingDetail(frequency: freq, date: isExpiredLine ? nil : dateInfo.date,
                                            repeats: freq != nil || fourWeeks || twoMonths || dateInfo.hasKeyword,
                                            everyFourWeeks: fourWeeks, everyTwoMonths: twoMonths)
                    continue
                }
            }

            // 2. Detail line (price-only, renewal-date-only, trial-only, or expiry-only) attaches to open card.
            let isDetailOnly = price != nil || dateInfo.hasKeyword || isExpiredLine || isTrialLine || freq != nil || fourWeeks || twoMonths
            if isDetailOnly, var card = current, (card.lastMinY - line.maxY) <= 0.085 {
                if let price, card.amount == nil {
                    card.amount = price.amount
                    card.currency = price.currency
                }
                if let freq { card.frequency = freq; card.repeats = true }
                if fourWeeks { card.everyFourWeeks = true; card.repeats = true }
                if twoMonths { card.everyTwoMonths = true; card.repeats = true }
                if dateInfo.hasKeyword { card.repeats = true }
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
                // "ChatGPT" over "Plus" is ChatGPT Plus where the catalog has it by that name.
                let plan = text.trimmingCharacters(in: .whitespaces)
                if !plan.contains(" "), let entry = CatalogData.entries.first(where: {
                    $0.name.caseInsensitiveCompare("\(card.name) \(plan)") == .orderedSame }) {
                    card.name = entry.name
                }
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
                    var card = PendingCard(
                        name: resolved.name,
                        category: resolved.category,
                        amount: price?.amount,
                        currency: price?.currency ?? defaultCurrency,
                        frequency: freq,
                        renewalDate: dateInfo.date,
                        trialEndsAt: isTrialLine ? dateInfo.date : nil,
                        isCancelled: section == .inactive || isExpiredLine,
                        lastMinY: line.minY,
                        repeats: listRepeats || resolved.isSubscription || freq != nil || fourWeeks || twoMonths || dateInfo.hasKeyword,
                        everyFourWeeks: fourWeeks,
                        everyTwoMonths: twoMonths
                    )
                    applyHeading(to: &card)
                    current = card
                }
            }
        }

        flushCurrent()
        return items
    }

    // MARK: - Merging & Deduplication

    /// Merges one newly scanned batch into existing results without losing user edits or ticks; returns IDs
    /// that were newly added or became eligible for automatic selection (e.g. a second sighting cleared `.mayNotRepeat`).
    static func mergeBatch(_ incoming: [DetectedItem], into list: inout [DetectedItem]) -> Set<String> {
        var addedIDs: Set<String> = []
        for item in incoming {
            let beforeIdx = list.firstIndex { ServiceName.same($0.name, item.name) }
            let wasCancelled = beforeIdx.map { list[$0].isCancelled } ?? false
            let wasMayNotRepeat = beforeIdx.map { list[$0].doubt == .mayNotRepeat } ?? false
            merge(item, into: &list)
            if beforeIdx == nil {
                addedIDs.insert(item.id)
            } else if let idx = beforeIdx {
                if (wasCancelled && !list[idx].isCancelled) || (wasMayNotRepeat && list[idx].doubt != .mayNotRepeat) {
                    addedIDs.insert(list[idx].id)
                }
            }
        }
        return addedIDs
    }

    private static func merge(_ incoming: DetectedItem, into list: inout [DetectedItem]) {
        if let idx = list.firstIndex(where: { ServiceName.same($0.name, incoming.name) }) {
            var existing = list[idx]
            // An older inactive/expired row for the same service (e.g. Apple Subscriptions INACTIVE
            // section) must never mark a currently active row as cancelled.
            if !existing.isCancelled && incoming.isCancelled {
                return
            }
            if existing.isCancelled && !incoming.isCancelled {
                existing.isCancelled = false
                if let amount = incoming.amount {
                    existing.amount = amount
                    existing.currency = incoming.currency
                }
                if let renewal = incoming.renewalDate { existing.renewalDate = renewal }
                if let trial = incoming.trialEndsAt { existing.trialEndsAt = trial }
                if let method = incoming.paymentMethod { existing.paymentMethod = method }
                existing.frequency = incoming.frequency
                list[idx] = existing
                return
            }
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
            if existing.paymentMethod == nil, let method = incoming.paymentMethod {
                existing.paymentMethod = method
            }
            // Seen once where it plainly repeats, it repeats; and the same charge twice at the same price repeats
            // (Spotify twice in a month of transactions was "nothing says it repeats", 2026-11-23).
            if existing.doubt == .mayNotRepeat, incoming.doubt != .mayNotRepeat { existing.doubt = incoming.doubt }
            else if existing.doubt == .mayNotRepeat, incoming.doubt == .mayNotRepeat, existing.amount != nil,
                    existing.amount == incoming.amount { existing.doubt = nil }
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

        // 2. Fallback to per-thread cached NSDataDetector for localized dates (ISO, DD/MM/YYYY, Japanese, German, etc.)
        if let detector = cachedDateDetector() {
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

    /// The service a name stands for. `isSubscription` is false for a known shop that also sells one-off
    /// things (Amazon): its name alone doesn't say a charge repeats.
    private static func resolveService(_ raw: String, catalog: MerchantCatalog)
        -> (name: String, category: String, isKnown: Bool, isSubscription: Bool) {
        if let match = catalog.resolve(hint: raw, senderName: raw, senderDomain: ""), match.isKnown {
            // "ChatGPT" is not "ChatGPT Team": a name the catalog only adds a plan to keeps its own (2026-11-23).
            let name = addsOnlyAPlan(raw, to: match.displayName) ? raw : match.displayName
            return (name, match.category ?? SubscriptionCategory.other.rawValue, true, match.kind != .mixedCommerce)
        }
        if let service = CancelHelp.service(named: raw) {
            let cat = CatalogData.entries.first { $0.name.caseInsensitiveCompare(service.name) == .orderedSame }?.category.rawValue
                ?? SubscriptionCategory.other.rawValue
            return (service.name, cat, true, true)
        }
        if let entry = CatalogData.entries.first(where: { ServiceName.same($0.name, raw) }) {
            return (addsOnlyAPlan(raw, to: entry.name) ? raw : entry.name, entry.category.rawValue, true, true)
        }
        return (raw, SubscriptionCategory.other.rawValue, false, false)
    }


    private static func cleanCandidateServiceName(_ raw: String) -> String? {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip common bank statement prefixes/suffixes ("APPLE.COM/BILL", "SPOTIFY USA", "NETFLIX.COM", "*1234").
        name = name.replacingOccurrences(of: #"\s*\*\d{4}\b"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"\s+(?:USA|US|INC\.?|LLC|LTD\.?|CORP\.?|BILLING|RECURRING|AUTOPAY)$"#,
                                         with: "", options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"\.(?:com|io|tv|app|co|org)$"#, with: "", options: [.regularExpression, .caseInsensitive])
        // A store's number or a payment reference after the name ("TESCO STORES 3321", "SPOTIFY P2A91C"), never the
        // name itself; three digits stay ("Microsoft 365") (the rating of 2026-11-23).
        for _ in 0..<2 {
            name = name.replacingOccurrences(of: #"(?<=\S)\s+(?:#?\d{4,}|(?=[A-Za-z]*\d)(?=\d*[A-Za-z])[A-Za-z0-9]{5,})$"#,
                                             with: "", options: .regularExpression)
        }
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

    private static func isPlausibleTitle(_ name: String) -> Bool {
        let lower = name.lowercased()
        if startsWithDateOrBillingKeyword(lower) { return false }
        // A transaction's own line ("1 Nov 2026 • Transfer") is not a name (the rating of 2026-11-23).
        if name.contains("•") || name.contains(" · ") { return false }
        let months = "jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec"
        if lower.range(of: "^\\d{1,2}\\.?\\s*(\(months))\\b", options: .regularExpression) != nil { return false }
        if lower.range(of: "^(\(months))[a-z]*\\.?\\s+\\d{1,2}\\b", options: .regularExpression) != nil { return false }
        let words = name.split(whereSeparator: \.isWhitespace)
        guard (1...5).contains(words.count) else { return false }
        // Reject full sentences (ending with period or containing 6+ words).
        if name.hasSuffix(".") || name.hasSuffix("?") || name.hasSuffix("!") { return false }
        return true
    }
}
