import Foundation

/// Pure factual detector for overlapping active subscriptions in the same everyday category
/// (video streaming, music, AI assistants, cloud storage). Never guesses or recommends alternatives;
/// only states what you are paying simultaneously and what those overlapping services add up to.
enum OverlapDetector {

    enum Cluster: String, CaseIterable, Identifiable, Equatable {
        case videoStreaming
        case musicStreaming
        case aiAssistants
        case cloudStorage
        case fitness
        case newsReading
        case securityVPN

        var id: String { rawValue }

        var title: String {
            switch self {
            case .videoStreaming: return L10n.string("Video streaming")
            case .musicStreaming: return L10n.string("Music streaming")
            case .aiAssistants: return L10n.string("AI tools")
            case .cloudStorage: return L10n.string("Cloud storage")
            case .fitness: return L10n.string("Fitness & wellness")
            case .newsReading: return L10n.string("News & reading")
            case .securityVPN: return L10n.string("VPN & security")
            }
        }
    }

    struct Group: Identifiable, Equatable {
        let cluster: Cluster
        let subscriptions: [Subscription]
        let monthlyTotal: Decimal
        let annualTotal: Decimal
        let isConverted: Bool
        var unconvertibleCount: Int = 0

        var id: String { cluster.id }
    }

    private static let videoNames: [String] = [
        "netflix", "hbo max", "hbomax", "disney", "hulu", "prime video", "apple tv", "paramount", "peacock",
        "crunchyroll", "espn", "discovery+", "discovery plus", "starz", "showtime", "mubi", "fubo",
        "sling", "youtube tv", "youtube premium", "britbox", "acorn tv", "shudder", "crave", "dazn", "amc+",
        "criterion", "philo", "hidive", "viki", "curiositystream"
    ]
    private static let exactVideoNames: Set<String> = ["max", "hbo"]

    private static let musicNames: [String] = [
        "spotify", "apple music", "youtube music", "tidal", "deezer", "amazon music",
        "soundcloud", "qobuz", "pandora", "napster"
    ]

    private static let aiNames: [String] = [
        "chatgpt", "openai", "claude", "perplexity", "gemini", "poe", "midjourney",
        "copilot", "cursor", "grok", "supergrok", "notion ai", "runwayml", "runway ml", "runway gen"
    ]
    private static let exactAINames: Set<String> = ["runway"]

    private static let cloudNames: [String] = [
        "icloud", "google one", "dropbox", "onedrive", "proton drive", "box.com", "box cloud", "box storage",
        "backblaze", "pcloud", "sync.com", "mega"
    ]
    private static let exactCloudNames: Set<String> = ["box"]

    private static let fitnessNames: [String] = [
        "peloton", "apple fitness", "strava", "calm", "headspace", "myfitnesspal",
        "fitbod", "centr", "freeletics", "whoop", "oura", "planet fitness", "equinox", "classpass"
    ]

    private static let newsNames: [String] = [
        "new york times", "nytimes", "washington post", "wall street journal", "wsj", "the economist",
        "the atlantic", "new yorker", "the guardian", "bloomberg", "substack", "apple news", "wired"
    ]
    private static let exactNewsNames: Set<String> = ["medium", "medium membership"]

    private static let securityNames: [String] = [
        "1password", "bitwarden", "dashlane", "lastpass", "nordvpn", "expressvpn",
        "surfshark", "proton vpn", "protonvpn", "mullvad", "norton", "malwarebytes", "mcafee"
    ]

    /// Classifies an active subscription into an overlap cluster, or nil if it doesn't belong to one.
    static func cluster(for subscription: Subscription) -> Cluster? {
        guard !subscription.isPausely else { return nil }
        let lower = subscription.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let words = lower.split { !$0.isLetter && !$0.isNumber && $0 != "+" }.map(String.init)

        func matches(_ list: [String], exact: Set<String> = []) -> Bool {
            if exact.contains(lower) { return true }
            return list.contains { known in
                if known.contains(" ") || known.count >= 6 { return lower.contains(known) }
                return words.contains { $0 == known || $0 == known + "+" }
            }
        }

        if matches(musicNames) { return .musicStreaming }
        if matches(aiNames, exact: exactAINames) { return .aiAssistants }
        if matches(cloudNames, exact: exactCloudNames) { return .cloudStorage }
        if matches(videoNames, exact: exactVideoNames) || PausePlanSchedule.isStreamingService(named: subscription.name) { return .videoStreaming }
        if matches(securityNames) { return .securityVPN }
        if matches(newsNames, exact: exactNewsNames) { return .newsReading }
        if matches(fitnessNames) { return .fitness }

        switch SubscriptionCategory.matching(subscription.category) {
        case .music: return .musicStreaming
        case .aiTools: return .aiAssistants
        case .cloudStorage: return .cloudStorage
        case .healthFitness, .gym: return .fitness
        case .news: return .newsReading
        case .security: return .securityVPN
        default: return nil
        }
    }

    /// Returns every cluster where 2 or more active subscriptions are currently charging, sorted by
    /// highest combined monthly cost first (deterministic tie-break by cluster identifier).
    static func groups(in subscriptions: [Subscription],
                       currency: String,
                       rates: CurrencyRates) -> [Group] {
        var buckets: [Cluster: [Subscription]] = [:]
        for sub in subscriptions.charging {
            guard let kind = cluster(for: sub) else { continue }
            buckets[kind, default: []].append(sub)
        }

        let display = MoneyFormat.normalizedCode(currency)
        return buckets.compactMap { cluster, members -> Group? in
            guard members.count >= 2 else { return nil }
            let ordered = members.sorted { lhs, rhs in
                let l = rates.convert(lhs.monthlyCost, from: lhs.currency, to: currency) ?? 0
                let r = rates.convert(rhs.monthlyCost, from: rhs.currency, to: currency) ?? 0
                if l != r { return l > r }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            let monthly = ordered.monthlyTotal(in: currency, rates: rates)
            let yearly = ordered.annualTotal(in: currency, rates: rates)
            let isConverted = ordered.contains {
                MoneyFormat.normalizedCode($0.currency) != display
                    && rates.convert($0.monthlyCost, from: $0.currency, to: currency) != nil
            }
            let unconvertible = ordered.filter { rates.convert($0.monthlyCost, from: $0.currency, to: currency) == nil }.count
            return Group(
                cluster: cluster,
                subscriptions: ordered,
                monthlyTotal: monthly,
                annualTotal: yearly,
                isConverted: isConverted,
                unconvertibleCount: unconvertible
            )
        }
        .sorted {
            if $0.monthlyTotal != $1.monthlyTotal { return $0.monthlyTotal > $1.monthlyTotal }
            return $0.cluster.rawValue < $1.cluster.rawValue
        }
    }
}
