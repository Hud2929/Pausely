import Foundation

// MARK: - Receipt Text Analyzer
/// Pure, on-device text analysis for a single email. No network, no storage, no UI.
/// It answers: "what was charged, and does the language say recurring subscription or one-time order?"
enum ReceiptTextAnalyzer {

    // MARK: Types

    struct Money: Equatable {
        let amount: Decimal
        /// ISO code when the email states it explicitly (C$, CAD, €, …). nil for a bare "$".
        let currency: String?
    }

    struct LanguageFlags: Equatable {
        var renewal = false
        var oneTime = false
        var trialStart = false
        var trialEnding = false
        var priceChange = false
        var cancelled = false
        var marketing = false
        var refund = false
    }

    struct Analysis: Equatable {
        var money: Money?
        var flags: LanguageFlags
        var frequency: BillingFrequency?
        var trialDays: Int?
        var productHint: String?
        var kind: EmailKind
    }

    // MARK: Entry point

    static func analyze(subject: String, body: String, promotional: Bool = false) -> Analysis {
        let cappedBody = String(body.prefix(24_000))
        let flags = languageFlags(subject: subject, body: cappedBody, promotional: promotional)
        let money = extractChargeAmount(subject: subject, body: cappedBody)
        let frequency = explicitFrequency(subject: subject, body: cappedBody)
        let trialDays = extractTrialDays(subject + " " + cappedBody)
        let product = productHint(subject: subject, body: cappedBody)
        let kind = classify(flags: flags, hasAmount: money != nil)
        return Analysis(money: money, flags: flags, frequency: frequency,
                        trialDays: trialDays, productHint: product, kind: kind)
    }

    // MARK: Classification

    static func classify(flags: LanguageFlags, hasAmount: Bool) -> EmailKind {
        if flags.cancelled { return .cancellation }
        if flags.trialEnding { return .trialEnding }
        if flags.priceChange && !flags.refund { return .priceChange }
        if flags.trialStart && !hasAmount { return .trialStarted }
        if flags.trialStart && flags.renewal && !flags.oneTime { return .trialStarted }
        if hasAmount && !flags.refund { return .charge }
        if flags.renewal && hasAmount { return .renewalNotice }
        return .other
    }

    // MARK: Language flags

    static func languageFlags(subject: String, body: String, promotional: Bool) -> LanguageFlags {
        let subjectLower = subject.lowercased()
        let text = (subjectLower + "\n" + body.lowercased())
        var flags = LanguageFlags()

        flags.renewal = containsAny(text, [
            "auto-renew", "auto renew", "autorenew", "automatically renew", "will renew", "renews on", "renews automatically",
            "renewal date", "next billing date", "next payment", "next charge", "your next bill", "billing period",
            "your subscription", "your membership", "recurring", "billed monthly", "billed annually", "billed yearly",
            "subscription receipt", "membership fee", "subscription renewal", "plan renews", "per month", "/month", "/mo ",
            "per year", "/year", "monthly plan", "annual plan", "monthly subscription", "annual subscription"
        ])

        flags.oneTime = containsAny(text, [
            "order #", "order number", "order no", "your order", "order confirmation", "shipped", "shipping", "tracking number",
            "out for delivery", "has been delivered", "was delivered", "thanks for your order", "thank you for your order",
            "pickup", "pick-up", "item(s)", "qty", "quantity", "e-ticket", "your tickets", "ticket order", "reservation",
            "booking confirmation", "itinerary", "boarding", "check-in", "gift card", "donation", "tip for", "your tip",
            "your ride", "trip receipt", "your trip", "delivery fee", "driver", "your parking", "parking session",
            "your delivery", "order from"
        ])

        flags.trialEnding = containsAny(text, [
            "trial ends", "trial is ending", "trial will end", "trial expires", "trial ending", "last day of your trial",
            "before your trial", "your free trial ends", "free trial is ending", "trial is almost over"
        ])

        flags.trialStart = flags.trialEnding || containsAny(text, [
            "free trial", "trial has started", "your trial", "trial begins", "start your trial", "trial period",
            "welcome to your trial", "trial started", "days free"
        ])

        flags.priceChange = containsAny(text, [
            "price change", "price increase", "price is changing", "price will change", "new price", "increase in price",
            "adjusting our prices", "pricing update", "updating our prices", "price adjustment", "prices are changing",
            "increase the price", "increasing the price", "rate increase"
        ])

        flags.cancelled = containsAny(text, [
            "subscription has been cancelled", "subscription has been canceled", "subscription was cancelled",
            "subscription was canceled", "we've cancelled your", "we've canceled your", "cancellation confirmation",
            "you've cancelled", "you've canceled", "your cancellation", "membership has ended", "subscription has ended",
            "subscription expired", "won't be charged again", "will not be charged again", "membership has been cancelled",
            "membership has been canceled", "your plan has been cancelled", "your plan has been canceled",
            "sorry to see you go", "we're sorry to see you go"
        ])

        flags.refund = containsAny(text, ["refund", "refunded", "credit issued", "chargeback", "reversal"])

        flags.marketing = promotional || containsAny(subjectLower, [
            "% off", "sale", "limited time", "special offer", "exclusive offer", "newsletter", "deal of", "save up to",
            "shop now", "last chance", "don't miss", "flash sale", "black friday", "cyber monday", "new arrivals"
        ])

        return flags
    }

    // MARK: Amount extraction

    private static let currencyTokens: [(String, String?)] = [
        ("c$", "CAD"), ("ca$", "CAD"), ("cad", "CAD"), ("us$", "USD"), ("usd", "USD"), ("au$", "AUD"), ("aud", "AUD"),
        ("nz$", "NZD"), ("nzd", "NZD"), ("£", "GBP"), ("gbp", "GBP"), ("€", "EUR"), ("eur", "EUR"), ("¥", "JPY"),
        ("jpy", "JPY"), ("₹", "INR"), ("inr", "INR"), ("chf", "CHF"), ("mxn", "MXN"), ("brl", "BRL"), ("sek", "SEK"),
        ("nok", "NOK"), ("dkk", "DKK"), ("$", nil)
    ]

    private static let amountRegex: NSRegularExpression? = {
        let symbols = "(?:C\\$|CA\\$|US\\$|AU\\$|NZ\\$|CAD|USD|AUD|NZD|GBP|EUR|JPY|INR|CHF|MXN|BRL|SEK|NOK|DKK|£|€|¥|₹|\\$)"
        let number = "(\\d{1,3}(?:,\\d{3})+(?:\\.\\d{2})|\\d+(?:\\.\\d{2}))"
        let pattern = "(?i)(?:(\(symbols))\\s?\(number)|\(number)\\s?(CAD|USD|AUD|NZD|GBP|EUR|CHF)\\b)"
        return try? NSRegularExpression(pattern: pattern)
    }()

    private static let euroCommaRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: "(\\d{1,3}(?:\\.\\d{3})*,\\d{2})\\s?(€|EUR)", options: [.caseInsensitive])

    private static let positiveContext: [(String, Int)] = [
        ("amount charged", 4), ("amount paid", 4), ("amount due", 3), ("you paid", 4), ("you were charged", 4),
        ("you've been charged", 4), ("we charged", 4), ("charged", 3), ("billed", 3), ("payment of", 3), ("your payment", 2),
        ("total", 2), ("price", 1), ("per month", 2), ("/month", 2), ("/mo", 2), ("per year", 2), ("/year", 2),
        ("monthly", 1), ("annual", 1), ("subscription", 1), ("plan", 1), ("renew", 1), ("membership", 1)
    ]

    private static let negativeContext: [(String, Int)] = [
        ("subtotal", 3), ("save", 4), (" off", 3), ("discount", 3), ("coupon", 3), ("was ", 3), ("regularly", 3),
        ("list price", 3), ("gift card", 3), ("credit", 2), ("points", 3), ("tax", 3), ("shipping", 3), ("refund", 5),
        ("up to", 3), ("starting at", 3), ("starts at", 3), ("from $", 3), ("limit", 2), ("fee", 1), ("tip", 2),
        ("balance", 2), ("rewards", 3), ("cashback", 3), ("minimum", 2), ("spend $", 4), ("spend", 2), ("over $", 3)
    ]

    /// Picks the amount that was actually charged, not the first dollar figure in the email.
    static func extractChargeAmount(subject: String, body: String) -> Money? {
        let text = subject + "\n" + body
        let ns = text as NSString
        var candidates: [(money: Money, score: Int, position: Int)] = []

        func consider(amountString: String, currency: String?, range: NSRange, decimalComma: Bool = false) {
            var cleaned = amountString
            if decimalComma {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
            guard let value = Decimal(string: cleaned), value > 0, value < 10_000 else { return }

            let beforeStart = max(0, range.location - 70)
            let before = ns.substring(with: NSRange(location: beforeStart, length: range.location - beforeStart)).lowercased()
            let afterEnd = min(ns.length, range.location + range.length + 40)
            let after = ns.substring(with: NSRange(location: range.location + range.length, length: afterEnd - (range.location + range.length))).lowercased()
            let context = before + "|" + after

            var score = 0
            for (word, weight) in positiveContext where context.contains(word) { score += weight }
            for (word, weight) in negativeContext where context.contains(word) { score -= weight }
            // "total" inside "subtotal" must not count as positive
            if context.contains("subtotal") { score -= 2 }

            candidates.append((Money(amount: value, currency: currency), score, range.location))
        }

        let full = NSRange(location: 0, length: ns.length)

        amountRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match else { return }
            if match.range(at: 1).location != NSNotFound, match.range(at: 2).location != NSNotFound {
                let symbol = ns.substring(with: match.range(at: 1))
                let number = ns.substring(with: match.range(at: 2))
                consider(amountString: number, currency: currencyCode(forToken: symbol), range: match.range)
            } else if match.range(at: 3).location != NSNotFound, match.range(at: 4).location != NSNotFound {
                let number = ns.substring(with: match.range(at: 3))
                let code = ns.substring(with: match.range(at: 4)).uppercased()
                consider(amountString: number, currency: code, range: match.range)
            }
        }

        euroCommaRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match, match.range(at: 1).location != NSNotFound else { return }
            consider(amountString: ns.substring(with: match.range(at: 1)), currency: "EUR", range: match.range, decimalComma: true)
        }

        guard !candidates.isEmpty else { return nil }
        // Highest score wins; on ties prefer the later one ("Total" sits at the bottom of receipts).
        let best = candidates.max { lhs, rhs in
            lhs.score == rhs.score ? lhs.position < rhs.position : lhs.score < rhs.score
        }
        guard let best, best.score >= 0 else { return nil }
        return best.money
    }

    static func currencyCode(forToken token: String) -> String? {
        let lower = token.lowercased()
        return currencyTokens.first { $0.0 == lower }?.1 ?? nil
    }

    // MARK: Frequency

    /// Only returns a frequency when the email states one clearly. The engine prefers real charge dates over this.
    static func explicitFrequency(subject: String, body: String) -> BillingFrequency? {
        let text = (subject + " " + body.prefix(8_000)).lowercased()
        var found: [BillingFrequency] = []
        if containsAny(text, ["billed monthly", "per month", "/month", "/mo ", "every month", "monthly plan", "monthly subscription", "monthly membership"]) { found.append(.monthly) }
        if containsAny(text, ["billed annually", "billed yearly", "per year", "/year", "every year", "annual plan", "yearly plan", "annual subscription", "annual membership", "yearly subscription"]) { found.append(.yearly) }
        if containsAny(text, ["per week", "/week", "every week", "weekly subscription", "billed weekly"]) { found.append(.weekly) }
        if containsAny(text, ["quarterly", "every 3 months", "every three months"]) { found.append(.quarterly) }
        if containsAny(text, ["every 6 months", "every six months", "semi-annual", "semiannual"]) { found.append(.semiannual) }
        return found.count == 1 ? found.first : nil
    }

    // MARK: Trial

    static func extractTrialDays(_ text: String) -> Int? {
        let pattern = "(\\d{1,3})[- ]day(?:s)?(?: free)? trial|trial (?:of|for) (\\d{1,3}) days|(\\d{1,3}) days free"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        for i in 1...3 where match.range(at: i).location != NSNotFound {
            if let days = Int(ns.substring(with: match.range(at: i))), (1...365).contains(days) { return days }
        }
        return nil
    }

    // MARK: Product hints
    /// Resolves product-level names that live under big, mixed-commerce brands
    /// (an Amazon *Prime* receipt is a subscription; an Amazon *order* is not).
    private static let productNeedles: [(String, String)] = [
        ("amazon prime", "Amazon Prime"), ("prime membership", "Amazon Prime"), ("prime video", "Prime Video"),
        ("amazon music unlimited", "Amazon Music Unlimited"), ("kindle unlimited", "Kindle Unlimited"), ("audible", "Audible"),
        ("dashpass", "DashPass"), ("uber one", "Uber One"), ("walmart+", "Walmart+"), ("walmart plus", "Walmart+"),
        ("instacart+", "Instacart+"), ("instacart plus", "Instacart+"), ("switch online", "Nintendo Switch Online"),
        ("playstation plus", "PlayStation Plus"), ("ps plus", "PlayStation Plus"), ("game pass", "Xbox Game Pass"),
        ("microsoft 365", "Microsoft 365"), ("office 365", "Microsoft 365"), ("google one", "Google One"),
        ("google workspace", "Google Workspace"), ("youtube premium", "YouTube Premium"), ("youtube music", "YouTube Music"),
        ("youtube tv", "YouTube TV"), ("apple one", "Apple One"), ("icloud+", "iCloud+"), ("icloud storage", "iCloud+"),
        ("apple music", "Apple Music"), ("apple tv+", "Apple TV+"), ("apple arcade", "Apple Arcade"),
        ("chatgpt plus", "ChatGPT Plus"), ("chatgpt pro", "ChatGPT Pro"), ("chatgpt team", "ChatGPT Team"),
        ("claude pro", "Claude Pro"), ("claude max", "Claude Max"), ("github copilot", "GitHub Copilot"),
        ("disney+", "Disney+"), ("disney plus", "Disney+"), ("paramount+", "Paramount+"), ("peacock", "Peacock"),
        ("discord nitro", "Discord Nitro"), ("nitro", "Discord Nitro"), ("lyft pink", "Lyft Pink"), ("grubhub+", "Grubhub+")
    ]

    static func productHint(subject: String, body: String) -> String? {
        let text = (subject + " " + body.prefix(6_000)).lowercased()
        // Prefer products named in the subject
        let subjectLower = subject.lowercased()
        if let hit = productNeedles.first(where: { subjectLower.contains($0.0) }) { return hit.1 }
        if let hit = productNeedles.first(where: { text.contains($0.0) && $0.0 != "nitro" && $0.0 != "audible" && $0.0 != "peacock" }) { return hit.1 }
        return nil
    }

    // MARK: Helpers

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

// MARK: - Email Kind

enum EmailKind: String, Codable, Equatable {
    case charge
    case renewalNotice
    case trialStarted
    case trialEnding
    case priceChange
    case cancellation
    case other
}
