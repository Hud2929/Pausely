import Foundation

// MARK: - Raw Email
/// What the scanner hands over for ONE email. It lives in memory only for the duration of extraction.
struct RawEmail {
    var id: String
    var date: Date
    var from: String
    var subject: String
    var bodyText: String
    var bodyHTML: String?
    /// Lower-cased header name → value (first occurrence).
    var headers: [String: String]
    var labelIds: [String]
}

// MARK: - Ambiguity (on-device classifier hook)

enum ReceiptVerdict: Equatable {
    case recurring(BillingFrequency?)
    case oneTime
    case unsure
}

/// Optional on-device classifier for receipts the rules cannot decide (e.g. Apple's on-device language model).
protocol AmbiguousReceiptClassifier {
    func classify(merchantGuess: String?, subject: String, excerpt: String) async -> ReceiptVerdict
}

struct ExtractionResult {
    var signal: ReceiptSignal
    /// Present only when the rules could not tell recurring from one-time. Trimmed text for the on-device classifier.
    var ambiguousExcerpt: String?
    var merchantGuess: String?
    var subject: String = ""
}

extension ReceiptSignal {
    func applying(_ verdict: ReceiptVerdict) -> ReceiptSignal {
        var copy = self
        switch verdict {
        case .recurring(let frequency):
            copy.renewalLanguage = true
            copy.oneTimeLanguage = false
            if let frequency { copy.cadenceHint = frequency }
        case .oneTime:
            copy.oneTimeLanguage = true
        case .unsure:
            break
        }
        return copy
    }
}

// MARK: - Header Intelligence

struct HeaderIntel: Equatable {
    var hasUnsubscribe: Bool
    var bulk: Bool
    /// Domain that DKIM-signed the message. Reveals the real sender behind relay/ESP "From" addresses.
    var authenticatedDomain: String?

    static func analyze(headers: [String: String]) -> HeaderIntel {
        let unsubscribe = headers["list-unsubscribe"] != nil
        let precedence = (headers["precedence"] ?? "").lowercased()
        let bulk = precedence == "bulk" || precedence == "list" || precedence == "junk" || headers["list-id"] != nil

        var domain: String?
        if let results = headers["authentication-results"] {
            domain = firstMatch(in: results, pattern: "dkim=pass[^;]*?header\\.(?:d|i)=@?([A-Za-z0-9.\\-]+)")
        }
        if domain == nil, let signature = headers["dkim-signature"] {
            domain = firstMatch(in: signature, pattern: "(?:^|[;\\s])d=([A-Za-z0-9.\\-]+)")
        }
        return HeaderIntel(hasUnsubscribe: unsubscribe, bulk: bulk,
                           authenticatedDomain: domain.map { MerchantCatalog.registrableDomain($0) })
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: match.range(at: 1)).lowercased()
    }

    /// The domain to resolve the merchant from: the DKIM-authenticated one when the From domain is only a relay.
    static func effectiveDomain(from: String, authenticated: String?) -> String {
        guard let authenticated else { return from }
        let fromRegistrable = MerchantCatalog.registrableDomain(from)
        let isRelay = MerchantCatalog.relayDomains.contains(fromRegistrable) || MerchantCatalog.freeMailDomains.contains(fromRegistrable)
        let authIsRelay = MerchantCatalog.relayDomains.contains(authenticated) || MerchantCatalog.freeMailDomains.contains(authenticated)
        if isRelay && !authIsRelay { return authenticated }
        return from
    }
}

// MARK: - Platform Hints

enum PlatformHints {
    struct Hint: Equatable {
        var platform: String
        var merchant: String?
    }

    static func detect(fromDomain: String, subject: String, body: String) -> Hint? {
        let registrable = MerchantCatalog.registrableDomain(fromDomain)
        let subjectLower = subject.lowercased()
        let bodyLower = body.prefix(8_000).lowercased()

        if registrable == "stripe.com" || subjectLower.contains("receipt from") || subjectLower.contains("invoice from") {
            return Hint(platform: "stripe", merchant: merchantFromSubject(subject))
        }
        if registrable == "apple.com" || fromDomain.hasSuffix("apple.com") {
            guard subjectLower.contains("receipt") || subjectLower.contains("subscription") || subjectLower.contains("invoice") else { return nil }
            return Hint(platform: "apple", merchant: appleItemName(from: body))
        }
        if registrable == "google.com" || registrable == "googleplay.com" {
            let isPlay = subjectLower.contains("subscription") || subjectLower.contains("google play") || subjectLower.contains("google one") || bodyLower.contains("google play")
            guard isPlay else { return nil }
            var name: String?
            if let match = subject.range(of: #"Your (.+?) subscription"#, options: .regularExpression) {
                name = String(subject[match]).replacingOccurrences(of: "Your ", with: "").replacingOccurrences(of: " subscription", with: "")
            } else if subjectLower.contains("google one") { name = "Google One" }
            return Hint(platform: "googleplay", merchant: name)
        }
        if registrable.hasPrefix("paypal.") {
            guard subjectLower.contains("subscription") || subjectLower.contains("recurring") || subjectLower.contains("automatic payment") else { return nil }
            return Hint(platform: "paypal", merchant: merchantFromSubject(subject) ?? paypalMerchant(from: body))
        }
        if registrable == "paddle.com" || registrable == "paddle.net" || bodyLower.contains("paddle.com") {
            return Hint(platform: "paddle", merchant: merchantFromSubject(subject))
        }
        return nil
    }

    /// "Your receipt from Notion" → "Notion". "Invoice from Brightline CRM #1234" → "Brightline CRM".
    static func merchantFromSubject(_ subject: String) -> String? {
        let patterns = [
            #"(?:receipt|invoice|statement)\s+from\s+([A-Za-z0-9][A-Za-z0-9\s\-\.&']*?)(?:\s+#|\s+\(|\.\s|\.$|,|$)"#,
            #"(?:payment|automatic payment|payment sent)\s+to\s+([A-Za-z0-9][A-Za-z0-9\s\-\.&']*?)(?:\s+#|\s+\(|\.\s|\.$|,|$)"#,
            #"^([A-Za-z0-9][A-Za-z0-9\s]{1,30}?)[\s\-–:]+(?:subscription|invoice|receipt|billing|renewal)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: subject, range: NSRange(subject.startIndex..., in: subject)),
                  let range = Range(match.range(at: 1), in: subject) else { continue }
            let name = String(subject[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.count >= 2 { return name }
        }
        return nil
    }

    static func appleItemName(from body: String) -> String? {
        let pattern = #"([A-Za-z][A-Za-z0-9\s\-\+\.]{2,40})\s*\n\s*[A-Z]{0,2}[\$€£]\s?[\d.,]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              let range = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func paypalMerchant(from body: String) -> String? {
        let pattern = #"(?:automatic payment to|subscription to|payment to)\s+([A-Za-z0-9][A-Za-z0-9\s\-\.]{1,40}?)(?:\s+has been|\s+was|\s+for|\.|\n)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              let range = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Triage (metadata first)

/// Decides from cheap metadata (headers, snippet, labels) whether an email deserves a full read.
/// Deliberately permissive: skipping a real receipt is worse than reading an extra email.
enum EmailTriage {
    private static let billingWords = [
        "receipt", "invoice", "payment", "paid", "billed", "billing", "charged", "charge", "renew", "subscription",
        "membership", "trial", "price", "cancel", "order", "statement", "your plan", "confirmation", "total",
        "amount", "due", "refund", "thanks for", "thank you for", "welcome to", "plan", "upgrade", "expires"
    ]

    static func shouldReadBody(from: String, subject: String, snippet: String, labelIds: [String],
                               catalog: MerchantCatalog = .builtin) -> Bool {
        let text = (subject + " " + snippet).lowercased()
        let hasBillingWords = billingWords.contains { text.contains($0) }
        if hasBillingWords { return true }
        if labelIds.contains("CATEGORY_PURCHASES") { return true }
        let sender = EmailSignalExtractor.parseSender(from)
        if catalog.isKnownDomain(sender.domain) && !labelIds.contains("CATEGORY_PROMOTIONS") { return true }
        return false
    }
}

// MARK: - HTML → text

enum HTMLText {
    /// Converts HTML to readable plain text, keeping line structure so line-oriented patterns still work.
    static func plain(_ html: String) -> String {
        var text = html
        for tag in ["script", "style", "head"] {
            text = text.replacingOccurrences(of: "<\(tag)[^>]*>.*?</\(tag)>", with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</(p|div|tr|li|h[1-6]|table|section)>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</t[dh]>", with: "  ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodeEntities(text)
        let lines = text.components(separatedBy: .newlines).map {
            $0.replacingOccurrences(of: "[ \\t\\x{00A0}]+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func decodeEntities(_ string: String) -> String {
        var s = string
        let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
                     "&euro;": "€", "&pound;": "£", "&yen;": "¥", "&cent;": "¢", "&ndash;": "–", "&mdash;": "—"]
        for (entity, value) in named { s = s.replacingOccurrences(of: entity, with: value) }
        // Numeric entities: &#8364; and &#x20AC;
        if let regex = try? NSRegularExpression(pattern: "&#(x?[0-9A-Fa-f]+);") {
            let ns = s as NSString
            var result = ""
            var last = 0
            for match in regex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
                let code = ns.substring(with: match.range(at: 1))
                let value = code.lowercased().hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
                if let value, let scalar = Unicode.Scalar(value) { result.unicodeScalars.append(scalar) }
                last = match.range.location + match.range.length
            }
            result += ns.substring(from: last)
            s = result
        }
        return s
    }
}

// MARK: - Extractor

/// Reduces ONE email to a compact `ReceiptSignal`. Pure and deterministic: the same input always gives the same output,
/// which is what makes the whole detection pipeline testable without touching a real mailbox.
enum EmailSignalExtractor {

    static func extract(_ email: RawEmail, catalog: MerchantCatalog = .builtin) -> ExtractionResult? {
        let sender = parseSender(email.from)
        let intel = HeaderIntel.analyze(headers: email.headers)
        let domain = HeaderIntel.effectiveDomain(from: sender.domain, authenticated: intel.authenticatedDomain)
        let labelPromo = email.labelIds.contains("CATEGORY_PROMOTIONS")

        let text = email.bodyText.isEmpty ? HTMLText.plain(email.bodyHTML ?? "") : email.bodyText
        let analysis = ReceiptTextAnalyzer.analyze(subject: email.subject, body: text, promotional: labelPromo)
        let markup = email.bodyHTML.flatMap { StructuredReceiptParser.parse(html: $0) }
        let platform = PlatformHints.detect(fromDomain: sender.domain, subject: email.subject, body: text)

        // Merge evidence. Product names (Amazon *Prime*, *DashPass*) beat generic seller names.
        let hint = analysis.productHint ?? markup?.merchant ?? platform?.merchant
        let amount = markup?.amount ?? analysis.money?.amount
        let currency = markup?.currency ?? analysis.money?.currency
        let cadence = markup?.cadence ?? analysis.frequency

        var flags = analysis.flags
        if let markup {
            if markup.kind == .subscription {
                flags.renewal = true
                flags.oneTime = false
            } else if markup.kind.isOneTime && analysis.productHint == nil {
                flags.oneTime = true
                flags.renewal = false
            }
        }

        // A receipt wrongly filed under Promotions must not be discarded when the markup proves it is a receipt.
        let markupProvesReceipt = markup != nil && markup?.kind != .parcel
        let promotional = (labelPromo && !markupProvesReceipt) || (flags.marketing && !markupProvesReceipt)

        var kind = ReceiptTextAnalyzer.classify(flags: flags, hasAmount: amount != nil)
        if markupProvesReceipt, amount != nil, !flags.cancelled, !flags.refund { kind = .charge }

        // Keep only emails that say something useful: a charge or a lifecycle event.
        let lifecycle: Set<EmailKind> = [.trialStarted, .trialEnding, .priceChange, .cancellation]
        guard amount != nil || lifecycle.contains(kind) else { return nil }

        let signal = ReceiptSignal(
            id: email.id, date: email.date, senderDomain: domain, senderName: sender.name, merchantHint: hint,
            platform: platform?.platform ?? "direct", kind: kind, amount: amount, currency: currency,
            cadenceHint: cadence, trialDays: analysis.trialDays, renewalLanguage: flags.renewal,
            oneTimeLanguage: flags.oneTime, promotional: promotional,
            markup: markup?.kind, hasUnsubscribe: intel.hasUnsubscribe, bulkMail: intel.bulk)

        // Ambiguous: a charge from a merchant we do not know, with no recurring or one-time language at all.
        var excerpt: String?
        let knownMerchant = hint != nil || catalog.isKnownDomain(domain)
        if kind == .charge, !flags.renewal, !flags.oneTime, !promotional, markup == nil, !knownMerchant, amount != nil {
            excerpt = String(text.prefix(1_400))
        }
        return ExtractionResult(signal: signal, ambiguousExcerpt: excerpt, merchantGuess: hint ?? sender.name, subject: email.subject)
    }

    // MARK: Sender parsing

    static func parseSender(_ header: String) -> (name: String, domain: String) {
        var name = header
        var address = header
        if let open = header.firstIndex(of: "<"), let close = header.firstIndex(of: ">"), open < close {
            name = String(header[..<open]).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            address = String(header[header.index(after: open)..<close])
        } else if header.contains("@") {
            name = ""
        }
        let domain = address.split(separator: "@").last.map { String($0).lowercased().trimmingCharacters(in: .whitespaces) } ?? ""
        return (name, domain)
    }
}
