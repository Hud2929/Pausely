import Foundation

/// Which company's cancellation help belongs to a subscription, going by its name.
///
/// Showing another company's steps, link and phone number is worse than showing none. So a name
/// matches a service only when it is that service: its name or one of its other names, written any
/// way ("Disney+", "disney plus", "DisneyPlus"), optionally followed by nothing but plan words
/// ("Netflix Premium", "Spotify Family (yearly)", "iCloud+ 200GB"). A name that merely contains or
/// resembles a service's name ("Loom" inside "Bloomberg") matches nothing, and the screen falls
/// back to a plain search.
struct ServiceMatcher {
    /// Every way of writing a service's name, squeezed to letters and digits → the service.
    private let byKey: [String: SubscriptionService]

    init(services: [SubscriptionService]) {
        var byKey: [String: SubscriptionService] = [:]
        // A service's own name always wins over another service's alias for the same words.
        for service in services {
            for name in [service.name, service.id] {
                let key = Self.words(name).joined()
                if !key.isEmpty, byKey[key] == nil { byKey[key] = service }
            }
        }
        for service in services {
            for alias in service.aliases {
                let key = Self.words(alias).joined()
                if !key.isEmpty, byKey[key] == nil { byKey[key] = service }
            }
        }
        self.byKey = byKey
    }

    func service(for name: String) -> SubscriptionService? {
        let words = Self.words(name)
        if let exact = byKey[words.joined()] { return exact }
        // The service's name, then only words that describe a plan. The longest name wins, so
        // "Apple Music Student" is Apple Music and never a shorter "Apple".
        for count in stride(from: words.count - 1, to: 0, by: -1) {
            guard let service = byKey[words.prefix(count).joined()] else { continue }
            if words.dropFirst(count).allSatisfy(Self.describesAPlan) { return service }
        }
        return nil
    }

    /// Lowercased words of letters and digits. "+" reads as "plus" and "&" as "and", accents are
    /// dropped, and everything else separates words.
    static func words(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "+", with: " plus ")
            .replacingOccurrences(of: "&", with: " and ")
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
    }

    /// Words that name a plan, a billing period or a size, never a different product. Words like
    /// "business" and "team" are left out on purpose: those plans are often cancelled somewhere else,
    /// so a service lists them among its other names only when its page covers them.
    static func describesAPlan(_ word: String) -> Bool {
        planWords.contains(word) || word.range(of: #"^\d+(gb|tb|k|p)?$"#, options: .regularExpression) != nil
    }

    static let planWords: Set<String> = [
        "premium", "plus", "pro", "professional", "basic", "standard", "essential", "essentials", "starter",
        "advanced", "lite", "unlimited", "ultimate", "ultra", "max", "extra", "classic", "preferred", "priority",
        "hd", "uhd", "digital",
        "individual", "personal", "family", "families", "duo", "student", "students", "person", "people",
        "monthly", "month", "annual", "annually", "yearly", "year",
        "plan", "subscription", "membership", "member", "tier", "trial",
        "ads", "ad", "with", "without", "no", "free", "supported"
    ]
}

/// What Pausely can offer someone who wants to cancel a subscription.
struct CancelHelp {
    enum Kind: Equatable {
        /// A service Pausely knows: its own cancellation page, with steps.
        case cancellationPage
        /// The service's own site, from the catalog entry of exactly this name. No steps.
        case website
        /// Nothing known: a web search for how to cancel it.
        case search
    }

    let kind: Kind
    let link: URL?
    /// Steps and contacts, when the service is one Pausely knows.
    let service: SubscriptionService?
}
