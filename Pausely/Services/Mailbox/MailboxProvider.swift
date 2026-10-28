import Foundation

/// A message in a provider's own terms (Gmail id, Graph id, or IMAP folder + UID).
struct MessageRef: Hashable, Codable {
    let id: String
    var folder: String? = nil
}

/// What triage needs to decide whether a message is worth reading in full.
struct MessageSummary {
    let ref: MessageRef
    var from: String
    var subject: String
    var snippet: String = ""
    var labelIds: [String] = []
    var receivedDate: Date?
    var messageID: String?
}

/// One inbox, reached one way (Gmail API, Microsoft Graph or IMAP). Every provider is read-only.
/// The scanner drives it: open → candidates → summaries → rawMessage for the few worth reading → close.
protocol MailboxProvider: AnyObject {
    var account: MailboxAccount { get }
    /// Signs in or refreshes tokens, and for IMAP opens a TLS connection.
    func open() async throws
    /// The messages worth considering: every search pass on a first scan, only mail since `cursor` later.
    func candidates(plan: InboxSearchPlan, cursor: String?) async throws -> (refs: [MessageRef], cursor: String?)
    /// Sender, subject and date, without reading bodies.
    func summaries(_ refs: [MessageRef]) async throws -> [MessageSummary]
    /// The whole message as raw MIME, for `MIMEParser`.
    func rawMessage(_ ref: MessageRef) async throws -> Data?
    func close() async
    /// Signs out at the provider where possible (revokes tokens).
    func revoke() async
}

enum MailboxError: LocalizedError, Equatable {
    case notConfigured(String)
    case authFailed(String)
    case authExpired
    case network(String)
    case server(String)
    case throttled(retryAfter: TimeInterval)
    case insecure(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notConfigured(let detail): return detail
        case .authFailed(let detail): return detail
        case .authExpired: return "Your sign-in expired. Reconnect this inbox."
        case .network(let detail): return "Couldn't reach the mail server. \(detail)"
        case .server(let detail): return "The mail server said: \(detail)"
        case .throttled: return "The mail server asked Pausely to slow down. Try again in a few minutes."
        case .insecure(let detail): return detail
        case .cancelled: return "Stopped."
        }
    }
}

// MARK: - What every scan looks for

/// The search passes every provider runs (see INBOX_PLAN.md, "the strict regimen"), in provider-neutral
/// form. Each provider turns them into its own query language.
struct InboxSearchPlan {
    /// Only mail received on or after this date.
    var since: Date
    /// Senders of known subscriptions (pass 3).
    var billerDomains: [String]
    /// Platforms that bill on behalf of others (pass 4).
    var platformDomains: [String]
    /// Receipt, renewal, trial, price-change, cancellation and failed-payment wording (pass 5).
    var subjectTerms: [String]
    /// Upper bound on messages considered per inbox, newest first.
    var maxCandidates = 1_500

    static let platforms = [
        "apple.com", "email.apple.com", "google.com", "googleplay.com", "paypal.com", "stripe.com", "paddle.com",
        "paddle.net", "chargebee.com", "recurly.com", "shopify.com", "amazon.com", "amazon.ca", "amazon.co.uk",
        "amazon.de", "amazon.fr", "amazon.es", "amazon.co.jp", "microsoft.com", "patreon.com", "substack.com",
        "fastspring.com", "gumroad.com", "lemonsqueezy.com", "2checkout.com", "zuora.com"
    ]

    /// Subject words in English, French, Spanish, German, Japanese, Arabic, Italian and Portuguese.
    static let subjectWords = [
        // English
        "receipt", "invoice", "subscription", "renewal", "renews", "membership", "your plan", "free trial",
        "trial ends", "price change", "price increase", "payment received", "payment failed", "billing",
        "auto-renew", "cancelled", "canceled",
        // French
        "reçu", "facture", "abonnement", "renouvellement", "essai gratuit",
        // Spanish
        "recibo", "factura", "suscripción", "renovación", "prueba gratuita",
        // German
        "Rechnung", "Quittung", "Abonnement", "Verlängerung", "Probeabo", "Kündigung",
        // Japanese
        "領収書", "請求書", "サブスクリプション", "定期購入", "更新", "無料体験",
        // Arabic
        "إيصال", "فاتورة", "اشتراك", "تجديد",
        // Italian
        "ricevuta", "fattura", "abbonamento", "rinnovo",
        // Portuguese
        "assinatura", "renovação", "fatura"
    ]

    static func standard(catalog: MerchantCatalog, since: Date) -> InboxSearchPlan {
        let platformSet = Set(platforms)
        var seen = Set<String>()
        let billers = catalog.profiles.flatMap(\.domains).filter { domain in
            !platformSet.contains(domain) && seen.insert(domain).inserted
        }
        return InboxSearchPlan(since: since, billerDomains: billers, platformDomains: platforms, subjectTerms: subjectWords)
    }

    /// Splits a list into chunks of at most `size`, for providers that limit query length.
    static func batches<T>(_ items: [T], size: Int) -> [[T]] {
        stride(from: 0, to: items.count, by: max(1, size)).map { Array(items[$0..<min($0 + size, items.count)]) }
    }
}
