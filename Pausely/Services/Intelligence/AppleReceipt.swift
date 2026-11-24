import Foundation

/// Reads an App Store receipt ("Your receipt from Apple."). One receipt can list several purchases, each
/// with its own lines and price:
///
///     Duolingo - Language Lessons
///     Super Duolingo (Monthly)
///     Renews Nov 12, 2026                    $12.99
///
/// followed by Subtotal, Tax and TOTAL. The total is the sum of everything on the receipt plus tax, so it
/// is never one subscription's price; each item's own price is. An item that renews is a subscription; an
/// item without a renewal line (an in-app purchase, a paid app) is a one-off.
enum AppleReceipt {
    struct Item: Equatable {
        var title: String
        var plan: String?
        var amount: Decimal
        var currency: String?
        var renews: Bool
        var frequency: BillingFrequency?
    }

    /// Apple calls it a receipt in some countries and an invoice in others, in every language.
    private static let subjectWords = [
        "receipt", "invoice", "reçu", "facture", "beleg", "rechnung", "recibo", "factura", "ricevuta", "fattura",
        "領収書", "請求書", "إيصال", "فاتورة"
    ]

    static func isApple(_ domain: String) -> Bool {
        let registrable = MerchantCatalog.registrableDomain(domain)
        return registrable == "apple.com" || registrable == "itunes.com"
    }

    static func isAppleBilling(fromDomain: String, subject: String) -> Bool {
        guard isApple(fromDomain) else { return false }
        let lower = subject.lowercased()
        return subjectWords.contains { lower.contains($0) }
    }

    /// "This is not a receipt. The original receipt for this purchase has been sent to the Family Organizer."
    static func isFamilyNotice(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("this is not a receipt") || lower.contains("sent to the family organizer")
    }

    private static let renewsWords = [
        "renews", "renouvellement", "se renouvelle", "verlängert sich", "verlängerung am", "se renueva", "renovación",
        "si rinnova", "renova em", "更新日", "に更新", "يتجدد", "التجديد في"
    ]

    /// Lines that belong to the receipt's header or footer, never to an item.
    private static let headerWords = [
        "apple account", "apple id", "order id", "document no", "billed to", "date:", "receipt", "invoice",
        "report a problem", "write a review"
    ]

    /// The purchases on the receipt, or nil when the text isn't laid out the way this reader expects
    /// (no figure that is labelled as the total).
    static func items(in text: String) -> [Item]? {
        let normalized = ReceiptTextAnalyzer.normalizingDigits(text)
        let ns = normalized as NSString
        let figures = ReceiptTextAnalyzer.moneyFigures(in: normalized)
        guard !figures.isEmpty else { return nil }

        var items: [Item] = []
        var sawTotal = false
        var previousEnd = 0
        for figure in figures {
            let label = ns.substring(with: NSRange(location: previousEnd, length: max(0, figure.range.location - previousEnd)))
            previousEnd = figure.range.location + figure.range.length
            if ReceiptTextAnalyzer.isPartOfASum(label: label) { continue }
            if ReceiptTextAnalyzer.isTotal(label: label) { sawTotal = true; continue }
            guard figure.money.amount > 0 else { continue }

            // The item's own lines stand just above its price.
            let lines = label.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { line in !line.isEmpty && !headerWords.contains { line.lowercased().hasPrefix($0) } }
            let own = Array(lines.suffix(5))
            guard !own.isEmpty else { continue }
            let renewsIndex = own.lastIndex { line in renewsWords.contains { line.lowercased().contains($0) } }
            let planIndex = renewsIndex.map { $0 - 1 } ?? own.lastIndex { frequency(inPlan: $0) != nil }
            let plan = planIndex.flatMap { $0 >= 0 ? own[$0] : nil }
            let titleIndex = (planIndex ?? own.count - 1) - 1
            let title = titleIndex >= 0 ? own[titleIndex] : (plan ?? own[own.count - 1])
            let period = plan.flatMap(frequency(inPlan:))
            items.append(Item(title: title, plan: plan, amount: figure.money.amount, currency: figure.money.currency,
                              renews: renewsIndex != nil || period != nil, frequency: period))
        }
        return sawTotal ? items : nil
    }

    /// "Super Duolingo (Monthly)", "iCloud+ with 200 GB (1 Month)", "Pro (Annual)".
    static func frequency(inPlan plan: String) -> BillingFrequency? {
        let lower = plan.lowercased()
        guard let open = lower.lastIndex(of: "("), let close = lower.lastIndex(of: ")"), open < close else { return nil }
        let period = lower[lower.index(after: open)..<close]
        if period.contains("week") { return .weekly }
        if period.contains("3 month") || period.contains("quarter") { return .quarterly }
        if period.contains("6 month") { return .semiannual }
        if period.contains("month") || period.contains("mensuel") || period.contains("monat") || period.contains("mensual") { return .monthly }
        if period.contains("year") || period.contains("annual") || period.contains("annuel") || period.contains("jahr") || period.contains("anual") { return .yearly }
        return nil
    }
}
