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
        /// Outside a list of subscriptions or recurring payments, a charge with nothing saying it repeats.
        case mayNotRepeat
        /// "Every 4 weeks" is thirteen charges a year, which no billing period here holds: kept as monthly.
        case everyFourWeeks
        /// "Every 2 months": no billing period holds it, so half the charge is counted each month.
        case everyTwoMonths
        /// Rent, insurance, energy: a recurring bill, not a subscription, so not ticked for the person.
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
            ($0.name, $0.category.displayName, $0.cancellationURL)
        })
        var merged: [DetectedItem] = []
        for page in pages {
            let items = parseSinglePage(page, catalog: catalog, defaultCurrency: defaultCurrency, now: now, calendar: calendar)
            for item in items {
                merge(item, into: &merged)
            }
        }
        return sortedItems(merged, defaultCurrency: defaultCurrency, rates: rates)
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

    static func sortedItems(_ items: [DetectedItem], defaultCurrency: String, rates: CurrencyRates = .fallback) -> [DetectedItem] {
        items.sorted { lhs, rhs in
            if lhs.isCancelled != rhs.isCancelled { return !lhs.isCancelled }
            let lRaw = (lhs.amount ?? 0) * ProvenSubscription.periodsPerYear(lhs.frequency)
            let rRaw = (rhs.amount ?? 0) * ProvenSubscription.periodsPerYear(rhs.frequency)
            let lCost = rates.convert(lRaw, from: lhs.currency, to: defaultCurrency) ?? 0
            let rCost = rates.convert(rRaw, from: rhs.currency, to: defaultCurrency) ?? 0
            if lCost != rCost { return lCost > rCost }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
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
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.003 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        var groups: [[TextObservation]] = []
        for obs in sorted {
            if let idx = groups.firstIndex(where: { belongsToSameVisualLine(obs, group: $0) }) {
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
            let height = max(maxY - minY, 0.004)
            let joined = ordered.map(\.text).joined(separator: "  ")
            return VisualLine(text: joined, parts: ordered, minY: minY, maxY: maxY, midY: midY, height: height)
        }
        .sorted { $0.midY > $1.midY }
    }

    /// Two OCR boxes share a visual line when they sit on the same horizontal band. Vertically stacked
    /// boxes in the same column (overlapping horizontally) are kept separate even on tall scrolling captures.
    private static func belongsToSameVisualLine(_ obs: TextObservation, group: [TextObservation]) -> Bool {
        let avgY = group.map(\.boundingBox.midY).reduce(0, +) / CGFloat(group.count)
        let maxH = max(group.map(\.boundingBox.height).max() ?? 0.015, obs.boundingBox.height)
        let dy = abs(obs.boundingBox.midY - avgY)

        for member in group {
            let overlapX = min(obs.boundingBox.maxX, member.boundingBox.maxX) - max(obs.boundingBox.minX, member.boundingBox.minX)
            let minW = max(min(obs.boundingBox.width, member.boundingBox.width), 0.001)
            if overlapX > minW * 0.35 {
                let minH = min(obs.boundingBox.height, member.boundingBox.height)
                if abs(obs.boundingBox.midY - member.boundingBox.midY) > minH * 0.45 {
                    return false
                }
            }
        }
        return dy <= max(maxH * 0.68, min(maxH * 1.15, 0.012))
    }

    // MARK: - Page Parsing

    private enum SectionState { case unknown, active, inactive }

    private static func detectPageContext(lines: [VisualLine]) -> (isApple: Bool, listRepeats: Bool, paymentMethod: String?) {
        let lowered = lines.map { $0.text.lowercased().trimmingCharacters(in: .whitespaces) }
        let hasNonApple = lowered.contains { text in
            nonAppleSourceMarkers.contains { text.contains($0) }
        }
        let hasGooglePlay = lowered.contains { $0.contains("google play") || $0.contains("play store") }
        let hasExplicitApple = lowered.contains { appleExplicitMarkers.contains($0) }
        let hasSubHeader = lowered.contains {
            ["subscriptions", "abos", "abonnements", "suscripciones", "サブスクリプション", "الاشتراكات"].contains($0)
        }
        let hasActiveOrInactive = lowered.contains { isActiveHeader($0) || isInactiveHeader($0) }
        let isApple = !hasNonApple && (hasExplicitApple || (hasSubHeader && hasActiveOrInactive) || hasSubHeader)
        let listRepeats = isApple || hasGooglePlay || hasActiveOrInactive
            || lowered.contains { recurringListHeaders.contains($0) }
        let method: String? = hasGooglePlay ? "Google Play" : (isApple ? "Apple" : nil)
        return (isApple, listRepeats, method)
    }

    private static func parseSinglePage(_ observations: [TextObservation],
                                        catalog: MerchantCatalog,
                                        defaultCurrency: String,
                                        now: Date,
                                        calendar: Calendar) -> [DetectedItem] {
        let lines = clusterLines(observations)
        var section: SectionState = .unknown
        let context = detectPageContext(lines: lines)
        let isSingleSubScreen = isSingleSubscriptionScreen(lines)
        var items: [DetectedItem] = []

        struct PendingCard {
            var name: String
            var category: String
            var amount: Decimal?
            var currency: String
            var frequency: BillingFrequency?
            var renewalDate: Date?
            var trialEndsAt: Date?
            var sawTrial: Bool = false
            var isCancelled: Bool
            var paymentMethod: String?
            var lastMinY: CGFloat
            /// Known to repeat: a subscription service, a list of them, or a line saying how often.
            var repeats: Bool
            var everyFourWeeks = false
            var everyTwoMonths = false
        }

        /// A line of how often and when ("Monthly · next 19 Dec 2026") that heads the row under it.
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
            if card.frequency == nil, let frequency = detail.frequency { card.frequency = frequency }
            if card.renewalDate == nil { card.renewalDate = detail.date }
            if detail.repeats { card.repeats = true }
            if detail.everyFourWeeks { card.everyFourWeeks = true }
            if detail.everyTwoMonths { card.everyTwoMonths = true }
        }

        var current: PendingCard?

        func flushCurrent() {
            guard let card = current else { return }
            current = nil
            guard card.amount != nil || card.renewalDate != nil || card.trialEndsAt != nil || card.isCancelled else { return }
            let normalizedCat = SubscriptionCategory.matching(card.category).displayName
            let item = DetectedItem(
                id: card.name.lowercased(),
                name: card.name,
                category: normalizedCat,
                amount: card.everyTwoMonths ? card.amount.map { AmountText.rounded($0 / 2, currency: card.currency) } : card.amount,
                currency: card.currency,
                frequency: card.frequency ?? .monthly,
                renewalDate: card.renewalDate,
                trialEndsAt: card.trialEndsAt,
                isCancelled: card.isCancelled,
                paymentMethod: card.paymentMethod ?? context.paymentMethod,
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

            // Stop before alternative plan options / cancel footer on an Edit Subscription screen.
            if isSingleSubScreen, isEditScreenCutoff(lower) {
                flushCurrent()
                break
            }

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
            if isRowLabel(lower) { continue }

            let priceAndFreq = extractPriceAndFrequency(in: text, defaultCurrency: defaultCurrency)
            let price = priceAndFreq.price
            let freq = priceAndFreq.frequency ?? extractFrequency(in: lower)
            let dateInfo = extractDateInfo(in: text, now: now, calendar: calendar)
            let isExpiredLine = containsExpiryWord(lower)
            let isTrialLine = containsTrialWord(lower)
            let fourWeeks = isEveryFourWeeks(lower)
            let twoMonths = isEveryTwoMonths(lower)

            if price != nil, isIncomeOrTransfer(lower, inAppleSubscriptions: context.isApple) {
                flushCurrent()
                heading = nil
                continue
            }

            // 1. Single-line bank/card, RTL, or compact row containing BOTH a name AND a price.
            if let price, let row = extractRowNameAndDate(from: line, price: price, catalog: catalog, now: now, calendar: calendar) {
                flushCurrent()
                let resolved = resolveService(row.name, catalog: catalog)
                let cancelled = section == .inactive || isExpiredLine
                let rowDate = row.date ?? dateInfo.date
                var card = PendingCard(
                    name: resolved.name,
                    category: resolved.category,
                    amount: price.amount,
                    currency: price.currency,
                    frequency: freq,
                    renewalDate: rowDate,
                    trialEndsAt: isTrialLine ? rowDate : nil,
                    sawTrial: isTrialLine,
                    isCancelled: cancelled,
                    paymentMethod: row.paymentMethod ?? context.paymentMethod,
                    lastMinY: line.minY,
                    repeats: context.listRepeats || resolved.isSubscription || freq != nil || fourWeeks || twoMonths || dateInfo.hasKeyword,
                    everyFourWeeks: fourWeeks,
                    everyTwoMonths: twoMonths
                )
                applyHeading(to: &card)
                current = card
                continue
            }

            // 2a. A line of how often and when that sits closer to the row under it than to the row above heads
            // the row under it. Never steal an Apple card's trailing "Renews…"/"Expires…"/"Free Trial" line.
            let isPeriodOrDate = price == nil && (freq != nil || fourWeeks || twoMonths || dateInfo.date != nil)
            let isTrailingCardDetail = context.isApple && (dateInfo.hasKeyword || isExpiredLine || isTrialLine)
            if isPeriodOrDate, !isTrailingCardDetail, let next {
                let below = line.minY - next.maxY
                let above = current.map { $0.lastMinY - line.maxY } ?? .greatestFiniteMagnitude
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
                if isTrialLine { card.sawTrial = true }
                if let date = dateInfo.date {
                    if isTrialLine || (card.sawTrial && card.trialEndsAt == nil && !isExpiredLine) {
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

            // 3. Plan subtitle for the currently open card (e.g. "Standard Plan", "200 GB", "All-Access", "Forfait Essentiel").
            if var card = current,
               (card.lastMinY - line.maxY) <= 0.048,
               card.amount == nil, card.renewalDate == nil,
               isPlanSubtitle(text, forService: card.name, nextLine: next, defaultCurrency: defaultCurrency,
                              inSubscriptionList: context.listRepeats, now: now, calendar: calendar, catalog: catalog) {
                if let freq { card.frequency = freq }
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
            if let cleaned = cleanCandidateServiceName(text) {
                let resolved = resolveService(cleaned.name, catalog: catalog)
                if resolved.isKnown || isPlausibleTitle(cleaned.name) {
                    flushCurrent()
                    var card = PendingCard(
                        name: resolved.name,
                        category: resolved.category,
                        amount: price?.amount,
                        currency: price?.currency ?? defaultCurrency,
                        frequency: freq,
                        renewalDate: dateInfo.date,
                        trialEndsAt: isTrialLine ? dateInfo.date : nil,
                        sawTrial: isTrialLine,
                        isCancelled: section == .inactive || isExpiredLine,
                        paymentMethod: cleaned.paymentMethod ?? context.paymentMethod,
                        lastMinY: line.minY,
                        repeats: context.listRepeats || resolved.isSubscription || freq != nil || fourWeeks || twoMonths || dateInfo.hasKeyword,
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
    /// that were newly added or became eligible for automatic selection (newly active, price-filled, date-filled,
    /// or second sighting clearing `.mayNotRepeat`).
    static func mergeBatch(_ incoming: [DetectedItem],
                           into list: inout [DetectedItem],
                           defaultCurrency: String? = nil,
                           rates: CurrencyRates = .fallback) -> Set<String> {
        var addedIDs: Set<String> = []
        for item in incoming {
            let beforeIdx = list.firstIndex { ServiceName.same($0.name, item.name) }
            let wasCancelled = beforeIdx.map { list[$0].isCancelled } ?? false
            let wasMayNotRepeat = beforeIdx.map { list[$0].doubt == .mayNotRepeat } ?? false
            let hadNoAmount = beforeIdx.map { list[$0].amount == nil } ?? false
            let hadNoDate = beforeIdx.map { list[$0].renewalDate == nil } ?? false
            merge(item, into: &list)
            if beforeIdx == nil {
                addedIDs.insert(item.id)
            } else if let idx = beforeIdx {
                let nowEligible = (wasCancelled && !list[idx].isCancelled)
                    || (wasMayNotRepeat && list[idx].doubt != .mayNotRepeat)
                    || (hadNoAmount && list[idx].amount != nil)
                    || (hadNoDate && list[idx].renewalDate != nil)
                if nowEligible {
                    addedIDs.insert(list[idx].id)
                }
            }
        }
        if let sortCurrency = defaultCurrency ?? list.first?.currency ?? incoming.first?.currency {
            list = sortedItems(list, defaultCurrency: sortCurrency, rates: rates)
        }
        return addedIDs
    }

    private static func merge(_ incoming: DetectedItem, into list: inout [DetectedItem]) {
        if let idx = list.firstIndex(where: { ServiceName.same($0.name, incoming.name) }) {
            var existing = list[idx]
            if !existing.isCancelled && incoming.isCancelled { return }
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
                existing.doubt = incoming.doubt
                list[idx] = existing
                return
            }
            if existing.amount == nil, let amount = incoming.amount {
                existing.amount = amount
                existing.currency = incoming.currency
            }
            if existing.renewalDate == nil, let renewal = incoming.renewalDate { existing.renewalDate = renewal }
            if existing.trialEndsAt == nil, let trial = incoming.trialEndsAt { existing.trialEndsAt = trial }
            if existing.paymentMethod == nil, let method = incoming.paymentMethod { existing.paymentMethod = method }
            if existing.doubt == .mayNotRepeat, incoming.doubt != .mayNotRepeat { existing.doubt = incoming.doubt }
            else if existing.doubt == .mayNotRepeat, incoming.doubt == .mayNotRepeat, existing.amount != nil,
                    existing.amount == incoming.amount { existing.doubt = nil }
            if SubscriptionCategory.matching(existing.category) == .other,
               SubscriptionCategory.matching(incoming.category) != .other {
                existing.category = SubscriptionCategory.matching(incoming.category).displayName
            }
            if existing.frequency == .monthly, incoming.frequency != .monthly {
                existing.frequency = incoming.frequency
            }
            list[idx] = existing
        } else {
            list.append(incoming)
        }
    }
}
