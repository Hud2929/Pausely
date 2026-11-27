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

/// What Pausely can offer someone who wants to cancel a subscription, most exact first.
struct CancelHelp: Equatable {
    enum Kind: Equatable {
        /// Billed by Apple: cancelled in Settings, by the same steps for every Apple subscription.
        case appleSubscription
        /// Billed through Google Play: cancelled in Google Play Payments & subscriptions.
        case googlePlay
        /// Billed through Amazon Prime Video Channels: cancelled in Amazon Channels settings.
        case amazonChannel
        /// A service Pausely knows: its own cancellation page.
        case cancellationPage
        /// The service's own site, from the catalog entry of exactly this name.
        case website
        /// Nothing known: a web search for how to cancel it, said to be one.
        case search
    }

    let kind: Kind
    let link: URL?

    private static let matcher = ServiceMatcher(services: ServiceDatabase.services)

    /// The service a subscription with this name belongs to, or nil. Exact names only (see `ServiceMatcher`).
    static func service(named name: String) -> SubscriptionService? {
        matcher.service(for: name)
    }

    /// Amazon's Prime Video Channels management page and Google Play's subscriptions page.
    static let amazonChannels = URL(string: "https://www.amazon.com/gp/video/settings/channels")
    static let googlePlaySubscriptions = URL(string: "https://play.google.com/store/account/subscriptions")

    private static let appleBillerNames: Set<String> = [
        "apple", "app store", "app store billing", "apple subscriptions",
        "apple billing", "apple id", "itunes", "itunes store"
    ]
    private static let amazonBillerNames: Set<String> = ["amazon", "prime video", "amazon prime video", "amazon channels"]
    private static let amazonFirstPartyIDs: Set<String> = ["amazonprime", "amazonprimevideo", "amazonmusic", "aws"]
    private static let googlePlayBillerNames: Set<String> = ["google play", "googleplay", "google play store"]

    @MainActor
    static func find(for subscription: Subscription) -> CancelHelp {
        // Store-billed subscriptions must be cancelled through the store that bills them (T11),
        // even when the app itself has its own cancellation page.
        if let billedBy = subscription.paymentMethod?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !billedBy.isEmpty {
            if appleBillerNames.contains(billedBy) {
                return CancelHelp(kind: .appleSubscription, link: applesSubscriptions)
            }
            if amazonBillerNames.contains(billedBy) {
                // Amazon's own first-party services (Prime, Prime Video, Amazon Music, Kindle, Audible, AWS)
                // have their own direct management pages and must not be hijacked to Prime Video Channels.
                let matchedID = service(named: subscription.name)?.id
                let lowerName = subscription.name.lowercased()
                let isFirstParty = (matchedID.map { amazonFirstPartyIDs.contains($0) } ?? false)
                    || lowerName.contains("amazon") || lowerName.contains("kindle") || lowerName.contains("audible")
                if !isFirstParty {
                    return CancelHelp(kind: .amazonChannel, link: amazonChannels)
                }
            }
            if googlePlayBillerNames.contains(billedBy) {
                return CancelHelp(kind: .googlePlay, link: googlePlaySubscriptions)
            }
        }
        if let service = service(named: subscription.name), let page = URL(string: service.cancelURL) {
            if service.isBilledByApple { return CancelHelp(kind: .appleSubscription, link: page) }
            if page == googlePlaySubscriptions { return CancelHelp(kind: .googlePlay, link: page) }
            // A link to a site's front page is its website, not its cancellation page: said as that.
            return CancelHelp(kind: isFrontPage(page) ? .website : .cancellationPage, link: page)
        }
        if let listed = SubscriptionCatalogService.shared.entry(named: subscription.name)?.cancellationURL,
           let site = URL(string: listed), site.scheme == "https", site.host != nil {
            return CancelHelp(kind: isApples(listed) ? .appleSubscription : .website, link: isApples(listed) ? applesSubscriptions : site)
        }
        return CancelHelp(kind: .search, link: searchURL(for: subscription.name))
    }

    /// Where to reopen/resubscribe to a paused service: Apple's Subscriptions screen for Apple-billed
    /// plans, the full store subscription screen for Google Play / Amazon Channels, or the service's
    /// clean origin homepage (`https://<host>`) for web services (never a `/cancel*` path or Google search).
    @MainActor
    static func resubscribeLink(for subscription: Subscription) -> (url: URL, openInSystem: Bool)? {
        let help = find(for: subscription)
        switch help.kind {
        case .appleSubscription:
            guard let url = help.link ?? applesSubscriptions else { return nil }
            return (url, true)
        case .googlePlay:
            guard let url = help.link ?? googlePlaySubscriptions else { return nil }
            return (url, false)
        case .amazonChannel:
            guard let url = help.link ?? amazonChannels else { return nil }
            return (url, false)
        case .cancellationPage, .website:
            guard let link = help.link, var components = URLComponents(url: link, resolvingAgainstBaseURL: false),
                  let host = components.host, !host.isEmpty else { return nil }
            components.scheme = "https"
            components.path = ""
            components.query = nil
            components.fragment = nil
            guard let root = components.url else { return nil }
            return (root, false)
        case .search:
            return nil
        }
    }

    /// Apple's own page for a person's subscriptions. iOS opens it in Settings.
    static let applesSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")

    static func isFrontPage(_ url: URL) -> Bool {
        url.path.isEmpty || url.path == "/"
    }

    static func isApples(_ address: String) -> Bool {
        URL(string: address)?.host == "apps.apple.com"
    }

    static func searchURL(for name: String) -> URL? {
        var search = URLComponents(string: "https://www.google.com/search")
        search?.queryItems = [URLQueryItem(name: "q", value: "cancel \(name) subscription")]
        return search?.url
    }
}
