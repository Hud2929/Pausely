import Foundation

// MARK: - The money on a receipt

/// The part of `ReceiptTextAnalyzer` that reads money: the figures a receipt holds, the currency each
/// is in, and which of them is the charge (a total, and not a part of the sum, a saving or an offer).
extension ReceiptTextAnalyzer {

    /// Symbols and local abbreviations that name a currency. A bare "$" names none: it's the reader's own dollar.
    static let currencySymbols: [(token: String, code: String?)] = [
        ("CA$", "CAD"), ("C$", "CAD"), ("US$", "USD"), ("AU$", "AUD"), ("A$", "AUD"), ("NZ$", "NZD"), ("HK$", "HKD"),
        ("NT$", "TWD"), ("S$", "SGD"), ("R$", "BRL"), ("MX$", "MXN"),
        ("Fr.", "CHF"), ("Rp", "IDR"), ("RM", "MYR"),
        ("£", "GBP"), ("€", "EUR"), ("¥", "JPY"), ("￥", "JPY"), ("₹", "INR"), ("₩", "KRW"), ("₪", "ILS"), ("₺", "TRY"),
        ("₽", "RUB"), ("₴", "UAH"), ("฿", "THB"), ("₱", "PHP"), ("₫", "VND"), ("₦", "NGN"), ("zł", "PLN"), ("Kč", "CZK"),
        ("円", "JPY"), ("원", "KRW"),
        ("ر.س.", "SAR"), ("ر.س", "SAR"), ("ريال سعودي", "SAR"), ("د.إ.", "AED"), ("د.إ", "AED"), ("درهم إماراتي", "AED"),
        ("ج.م.", "EGP"), ("ج.م", "EGP"), ("د.ك.", "KWD"), ("د.ك", "KWD"), ("ر.ق.", "QAR"), ("ر.ق", "QAR"),
        ("د.ب.", "BHD"), ("د.ب", "BHD"), ("ر.ع.", "OMR"), ("ر.ع", "OMR"),
        ("$", nil)
    ]

    /// ISO codes read next to an amount, in capitals only ("TRY 30 days free" is not thirty lira).
    static let currencyCodes: [String] = [
        "USD", "CAD", "AUD", "NZD", "GBP", "EUR", "JPY", "INR", "CHF", "MXN", "BRL", "SEK", "NOK", "DKK", "SAR", "AED",
        "EGP", "KWD", "QAR", "BHD", "OMR", "ILS", "TRY", "PLN", "CZK", "HUF", "RON", "HKD", "SGD", "TWD", "KRW", "THB",
        "IDR", "MYR", "PHP", "VND", "ZAR", "NGN", "ARS", "CLP", "COP", "PEN", "RUB", "UAH", "CNY"
    ]

    /// Currencies whose prices are whole numbers ("¥990", "9,900원").
    static let wholeUnitCurrencies: Set<String> = ["JPY", "KRW", "VND", "IDR", "CLP", "HUF", "COP", "TWD"]
    /// Currencies written with three decimals ("1.250 KWD").
    static let threeDecimalCurrencies: Set<String> = ["KWD", "BHD", "OMR"]

    private static let numberPattern = "\\d{1,3}(?:[.,\u{202F}]\\d{3})+(?:[.,]\\d{1,3})?|\\d+(?:[.,]\\d{1,3})?"

    private static let symbolAlternation: String = currencySymbols
        .map { entry in
            let escaped = NSRegularExpression.escapedPattern(for: entry.token)
            let startsWithAsciiLetter = entry.token.first.map { $0.isASCII && $0.isLetter } ?? false
            return startsWithAsciiLetter ? "\\b\(escaped)" : escaped
        }
        .joined(separator: "|")

    /// "$15.49", "C$ 16.49", "USD 20", "SAR 29.99".
    private static let prefixRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(\(symbolAlternation)|\\b(?:\(currencyCodes.joined(separator: "|")))\\b)[ \u{00A0}\u{202F}]{0,2}(\(numberPattern))")

    /// "10,99 €", "49.00 USD", "990円", "29.99 ر.س", "129 kr".
    private static let suffixRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(\(numberPattern))[ \u{00A0}\u{202F}]{0,2}(\(symbolAlternation)|(?:\(currencyCodes.joined(separator: "|")))\\b|kr\\b)")

    /// Trailing ISO code immediately after a bare symbol figure ("$15.49 CAD", "$19.99 USD").
    private static let trailingDollarCodeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "^[ \u{00A0}\u{202F}]{1,2}(USD|CAD|AUD|NZD|HKD|SGD|MXN|TWD|BRL|GBP|EUR|CHF)\\b")

    private static let positiveContext: [(String, Int)] = [
        ("amount charged", 4), ("amount paid", 4), ("amount due", 3), ("you paid", 4), ("you were charged", 4),
        ("you've been charged", 4), ("we charged", 4), ("charged", 3), ("billed", 3), ("payment of", 3), ("your payment", 2),
        ("total", 2), ("price", 1), ("per month", 2), ("/month", 2), ("/mo", 2), ("per year", 2), ("/year", 2),
        ("monthly", 1), ("annual", 1), ("subscription", 1), ("plan", 1), ("renew", 1), ("membership", 1),
        ("montant", 3), ("facturé", 3), ("payé", 3), ("abonnement", 1), ("importe", 3), ("cobrado", 3), ("pagado", 3),
        ("suscripción", 1), ("betrag", 3), ("gesamt", 2), ("abgerechnet", 3), ("bezahlt", 3), ("abonnement", 1),
        ("importo", 3), ("totale", 2), ("pagato", 3), ("valor", 2), ("pago", 2),
        ("請求額", 4), ("ご請求", 4), ("お支払い", 3), ("支払金額", 4), ("合計", 2), ("月額", 2), ("年額", 2),
        ("결제 금액", 4), ("결제금액", 4), ("합계", 2),
        ("المبلغ المدفوع", 4), ("المبلغ", 3), ("الإجمالي", 2), ("المجموع", 2), ("تم خصم", 4), ("تم تحصيل", 4), ("اشتراك", 1)
    ]

    private static let negativeContext: [(String, Int)] = [
        ("subtotal", 3), ("save", 4), (" off", 3), ("discount", 3), ("coupon", 3), ("was ", 3), ("regularly", 3),
        ("list price", 3), ("gift card", 3), ("credit", 2), ("points", 3), ("tax", 3), ("shipping", 3), ("refund", 5),
        ("up to", 3), ("starting at", 3), ("starts at", 3), ("start at", 3), ("from $", 3), ("limit", 2), ("delivery fee", 2), ("service fee", 2), ("booking fee", 2), ("processing fee", 2), ("tip", 2),
        ("balance", 2), ("rewards", 3), ("cashback", 3), ("minimum", 2), ("spend $", 4), ("spend", 2), ("over $", 3),
        ("rabais", 3), ("économ", 3), ("livraison", 2), ("descuento", 3), ("ahorra", 3), ("rabatt", 3), ("sparen", 3),
        ("割引", 3), ("ポイント", 3), ("送料", 2), ("値引", 3), ("할인", 3), ("포인트", 3), ("خصم بقيمة", 3), ("وفّر", 3)
    ]

    /// Words that come straight before an offered price: what a plan costs, would cost, or will cost later,
    /// never what was just charged ("Plans from $7.99", "then $269.99/year", "danach 10,99 €").
    private static let offerLead: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?:\\b(?:from|starting at|starts at|start at|as low as|only|just|then|after that|thereafter|afterwards|"
            + "danach|anschließend|ab|puis|ensuite|à partir de|luego|después|desde|a partir de|poi|depois)|その後|以降は?|ثم)"
            + "\\W{0,3}$",
        options: [.caseInsensitive])

    /// Western digits for Arabic-Indic, Persian and full-width ones, and their separators, so "٢٩٫٩٩" and
    /// "９９０" read like "29.99" and "990".
    static func normalizingDigits(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { (0x0660...0x066C).contains($0.value) || (0x06F0...0x06F9).contains($0.value)
            || (0xFF10...0xFF19).contains($0.value) || $0.value == 0xFF0E || $0.value == 0xFF0C }) else { return text }
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0660...0x0669: out.append(Unicode.Scalar(scalar.value - 0x0660 + 0x30)!)
            case 0x06F0...0x06F9: out.append(Unicode.Scalar(scalar.value - 0x06F0 + 0x30)!)
            case 0xFF10...0xFF19: out.append(Unicode.Scalar(scalar.value - 0xFF10 + 0x30)!)
            case 0x066B, 0xFF0E: out.append(".")
            case 0x066C, 0xFF0C: out.append(",")
            default: out.append(scalar)
            }
        }
        return String(out)
    }

    /// Reads "1,234.56", "1.234,56", "12,99", "990", "1.250" (three-decimal currencies) as a number.
    /// Returns whether the text had a decimal part.
    static func parseAmount(_ text: String, currency: String?) -> (value: Decimal, hasDecimals: Bool)? {
        let lastDot = text.lastIndex(of: ".")
        let lastComma = text.lastIndex(of: ",")
        var decimalSeparator: Character?
        if let lastDot, let lastComma {
            decimalSeparator = lastDot > lastComma ? "." : ","
        } else if let only = lastDot ?? lastComma {
            let digitsAfter = text.distance(from: only, to: text.endIndex) - 1
            let separator = text[only]
            let groups: [Substring] = text.split(whereSeparator: { $0 == separator })
            let groupsOfThree = groups.dropFirst().allSatisfy { $0.count == 3 }
            if digitsAfter == 3 && groupsOfThree {
                // "1,250" is twelve hundred and fifty, except in dinars and rials written to three places.
                if let currency, threeDecimalCurrencies.contains(currency), separator == ".",
                   text.filter({ $0 == "." }).count == 1 { decimalSeparator = "." }
            } else {
                decimalSeparator = separator
            }
        }
        var whole = ""
        var fraction = ""
        var inFraction = false
        for (index, character) in zip(text.indices, text) {
            if character.isNumber {
                if inFraction { fraction.append(character) } else { whole.append(character) }
            } else if character == decimalSeparator, index == (character == "." ? lastDot : lastComma) {
                inFraction = true
            }
        }
        guard let value = Decimal(string: fraction.isEmpty ? whole : whole + "." + fraction) else { return nil }
        return (value, !fraction.isEmpty)
    }

    /// Every money figure in a text, in reading order: the building block for receipts that list several
    /// charges, where each figure belongs to the lines just above it.
    static func moneyFigures(in text: String) -> [(money: Money, range: NSRange)] {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var found: [(money: Money, range: NSRange)] = []
        func add(_ amount: String, _ token: String, _ range: NSRange) {
            var currency = currencyCode(forToken: token)
            var finalRange = range
            // "$15.49 CAD" or "$19.99 USD": resolve the trailing code onto the bare "$" figure.
            if currency == nil, token == "$" {
                let end = range.location + range.length
                let tailLen = min(6, ns.length - end)
                if tailLen >= 4 {
                    let tail = ns.substring(with: NSRange(location: end, length: tailLen))
                    if let m = trailingDollarCodeRegex?.firstMatch(in: tail, range: NSRange(location: 0, length: (tail as NSString).length)) {
                        currency = (tail as NSString).substring(with: m.range(at: 1))
                        finalRange = NSRange(location: range.location, length: range.length + m.range.length)
                    }
                }
            }
            // Zero figures are kept ("Tax $0.00"): they still separate one label from the next.
            guard let parsed = parseAmount(amount, currency: currency) else { return }
            found.append((Money(amount: parsed.value, currency: currency), finalRange))
        }
        prefixRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match else { return }
            add(ns.substring(with: match.range(at: 2)), ns.substring(with: match.range(at: 1)), match.range)
        }
        suffixRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match, !found.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) else { return }
            add(ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2)), match.range)
        }
        return found.sorted { $0.range.location < $1.range.location }
    }

    /// True when the words nearest a figure call it a subtotal, a tax, shipping or a discount.
    static func isPartOfASum(label: String) -> Bool {
        let nearest = String(label.suffix(22))
        return partLabel?.firstMatch(in: nearest, range: NSRange(location: 0, length: (nearest as NSString).length)) != nil
    }

    /// True when the words nearest a figure call it the total.
    static func isTotal(label: String) -> Bool {
        let range = NSRange(location: 0, length: (label as NSString).length)
        let cleaned = (subtotalWord?.stringByReplacingMatches(in: label, range: range, withTemplate: " ") ?? label).lowercased()
        let nearest = String(cleaned.suffix(26))
        return totalLabels.contains(where: nearest.contains)
    }

    /// Labels that say "this figure is what was charged" when they stand right before it.
    private static let totalLabels = [
        "total", "amount paid", "amount charged", "amount due", "you paid", "total paid", "total charged", "grand total",
        "montant total", "montant payé", "montant facturé", "importe total", "importe cobrado", "total pagado",
        "gesamtbetrag", "gesamt", "gesamtsumme", "betrag", "totale", "importo", "valor total",
        "合計", "請求額", "ご請求額", "支払金額", "お支払い金額", "합계", "결제 금액", "결제금액",
        "المبلغ المدفوع", "الإجمالي", "المجموع"
    ]

    /// Labels that say "this figure is part of the sum, not the sum": a subtotal, a tax, shipping, a discount.
    /// Whole words only: "vat" is inside "activate" and "iva" inside "private".
    private static let partLabel: NSRegularExpression? = try? NSRegularExpression(
        pattern: "\\b(?:sub[- ]?total|sous-total|zwischensumme|tax|taxes|vat|gst|hst|pst|qst|tva|mwst|ust|iva|shipping|"
            + "delivery|livraison|versand|envío|discount|rabatt|remise|descuento)\\b|小計|소계|المجموع الفرعي|税|세금|ضريبة|送料",
        options: [.caseInsensitive])

    /// "Subtotal" must not read as "total".
    private static let subtotalWord: NSRegularExpression? = try? NSRegularExpression(
        pattern: "sub[- ]?total|sous-total|zwischensumme|小計|소계|المجموع الفرعي", options: [.caseInsensitive])

    /// The charged amount, and whether the words around it say a charge happened ("amount paid", "total",
    /// "we charged") rather than only naming a plan's price.
    ///
    /// A receipt is a column of labelled figures ("Plan $20.00 · Tax: $2.60 · Total: $22.60"). Each figure is
    /// judged first by its own label, the words between the figure before it and itself; words elsewhere
    /// count for less and can't veto it. "Tax:" disqualifies the 2.60 it labels, not the 20.00 before it.
    static func chargeCandidate(subject: String, body: String) -> (money: Money, evidence: Bool)? {
        let text = normalizingDigits(subject + "\n" + body)
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        struct Figure {
            var amount: String
            var currency: String?
            var range: NSRange
            var numberRange: NSRange
        }
        var figures: [Figure] = []
        prefixRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match else { return }
            figures.append(Figure(amount: ns.substring(with: match.range(at: 2)),
                                  currency: currencyCode(forToken: ns.substring(with: match.range(at: 1))),
                                  range: match.range, numberRange: match.range(at: 2)))
        }
        suffixRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match else { return }
            // "$49.00 USD" was already read with its symbol; the code after it only names the currency.
            // (And "Qty 1 $12.00" is not one dollar: a figure never shares characters with another.)
            if figures.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) { return }
            figures.append(Figure(amount: ns.substring(with: match.range(at: 1)),
                                  currency: currencyCode(forToken: ns.substring(with: match.range(at: 2))),
                                  range: match.range, numberRange: match.range(at: 1)))
        }
        figures.sort { $0.range.location < $1.range.location }

        var candidates: [(money: Money, score: Int, position: Int, evidence: Bool)] = []
        for (index, figure) in figures.enumerated() {
            let range = figure.range
            // "1 299,00 €" could be a quantity and a price, or a price over a thousand: too unsure to use.
            if figure.numberRange.location >= 2 {
                let lead = ns.substring(with: NSRange(location: figure.numberRange.location - 2, length: 2))
                if lead.range(of: "^\\d[ \\x{00A0}\\x{202F}]$", options: .regularExpression) != nil { continue }
            }
            // A longer run of digits (an order number, a date) is not an amount.
            if figure.numberRange.location >= 1, range.location == figure.numberRange.location {
                let previous = ns.substring(with: NSRange(location: figure.numberRange.location - 1, length: 1))
                if previous.range(of: "[\\d.,]", options: .regularExpression) != nil { continue }
            }
            guard let parsed = parseAmount(figure.amount, currency: figure.currency) else { continue }
            let wholeUnits = figure.currency.map(wholeUnitCurrencies.contains) ?? false
            guard parsed.value > 0, parsed.value < (wholeUnits ? 2_000_000 : 10_000) else { continue }

            let end = range.location + range.length
            let previousEnd = index > 0 ? figures[index - 1].range.location + figures[index - 1].range.length : 0
            let nextStart = index + 1 < figures.count ? figures[index + 1].range.location : ns.length

            // Which way does this line read? Most receipts put the label first ("Total: $22.60"). Some put the
            // figure first ("CA$67.79 Total charged"): a line whose first figure has nothing before it and
            // whose last figure has words after it.
            let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
            let onLine = figures.filter { NSLocationInRange($0.range.location, lineRange) }
            var labelFollows = false
            if let first = onLine.first, let last = onLine.last {
                let lead = ns.substring(with: NSRange(location: lineRange.location, length: first.range.location - lineRange.location))
                let lastEnd = last.range.location + last.range.length
                let tail = ns.substring(with: NSRange(location: lastEnd, length: max(0, lineRange.location + lineRange.length - lastEnd)))
                labelFollows = !lead.contains(where: \.isLetter) && tail.contains(where: \.isLetter)
            }

            let own: String      // the words that label this figure
            let nearest: String  // the part of that label touching the figure
            let wider: String    // the lead-in before the label
            let after: String    // what follows the figure, up to the next one
            if labelFollows {
                let labelEnd = max(end, min(nextStart, end + 60, lineRange.location + lineRange.length))
                own = ns.substring(with: NSRange(location: end, length: labelEnd - end)).lowercased()
                nearest = String(own.prefix(26))
                wider = ""
                after = ""
            } else {
                // Back to the figure before it, at most 60 characters.
                let ownStart = min(range.location, max(previousEnd, range.location - 60, 0))
                own = ns.substring(with: NSRange(location: ownStart, length: range.location - ownStart)).lowercased()
                nearest = String(own.suffix(26))
                let widerStart = max(0, range.location - 70)
                wider = widerStart < ownStart
                    ? ns.substring(with: NSRange(location: widerStart, length: ownStart - widerStart)).lowercased() : ""
                let afterEnd = max(end, min(nextStart, end + 40, ns.length))
                after = ns.substring(with: NSRange(location: end, length: afterEnd - end)).lowercased()
            }
            // Words after a figure label the next figure when one follows closely ("$20.00  Tax: $2.60").
            let labelsNext = nextStart >= end && nextStart - end <= 28

            var score = 0
            var evidence = false
            func withoutSubtotal(_ text: String) -> String {
                subtotalWord?.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length),
                                                       withTemplate: " ") ?? text
            }
            let ownWithoutParts = withoutSubtotal(own)
            for (word, weight) in positiveContext where ownWithoutParts.contains(word) {
                score += weight * 2
                if weight >= 3 || totalLabels.contains(word) { evidence = true }
            }
            // Only the label nearest the figure can make it a part of the sum ("Tax: $2.60").
            let partRange = NSRange(location: 0, length: (nearest as NSString).length)
            if partLabel?.firstMatch(in: nearest, range: partRange) != nil {
                score -= 8
                evidence = false
            }
            for (word, weight) in negativeContext where own.contains(word) { score -= weight * 2 }
            // The label right against the figure decides most receipts: "Total: $22.60", "Amount paid $12.00".
            let direct = withoutSubtotal(nearest)
            if totalLabels.contains(where: direct.contains) { score += 6; evidence = true }

            for (word, weight) in positiveContext where wider.contains(word) { score += weight }
            let close = String(after.prefix(14))
            for (word, weight) in positiveContext where close.contains(word) { score += weight }
            if !labelsNext {
                for (word, weight) in negativeContext where after.contains(word) { score -= weight }
            } else {
                // "$5 off", "$10.00 discount": said of this figure even when another follows.
                for word in [" off", "discount", "rabatt", "remise", "descuento"] where close.contains(word) { score -= 6 }
            }
            if !labelFollows, offerLead?.firstMatch(in: own, range: NSRange(location: 0, length: (own as NSString).length)) != nil {
                score -= 8
                evidence = false
            }
            // A price without cents ("$8") is how offers and thresholds are written too ("$5 off", "over $50"):
            // it counts only when the words around it say it was charged.
            if !parsed.hasDecimals && !wholeUnits && score < 3 { continue }

            var currency = figure.currency
            if currency == nil {
                let trailing = after.trimmingCharacters(in: .whitespaces).prefix(4).uppercased()
                for code in ["USD", "CAD", "AUD", "GBP", "EUR", "NZD", "CHF"] where trailing.hasPrefix(code) { currency = code }
            }
            candidates.append((Money(amount: parsed.value, currency: currency), score, range.location, evidence))
        }

        guard !candidates.isEmpty else { return nil }
        // Highest score wins; on ties prefer the later one ("Total" sits at the bottom of receipts).
        let best = candidates.max { lhs, rhs in
            lhs.score == rhs.score ? lhs.position < rhs.position : lhs.score < rhs.score
        }
        guard let best, best.score >= 0 else { return nil }
        return (best.money, best.evidence)
    }

    static func currencyCode(forToken token: String) -> String? {
        if let symbol = currencySymbols.first(where: { $0.token.caseInsensitiveCompare(token) == .orderedSame }) { return symbol.code }
        let upper = token.uppercased()
        return currencyCodes.contains(upper) ? upper : nil
    }
}
