import Foundation

// MARK: - Merchant Profile

struct MerchantProfile: Equatable {
    enum Kind: Equatable {
        /// The brand sells subscriptions (Netflix, Spotify). A receipt from it is a strong signal.
        case pureSubscription
        /// The brand mostly sells one-off things (Amazon, DoorDash, Uber). Needs proof of recurrence.
        case mixedCommerce
    }

    let key: String
    let displayName: String
    let category: String
    let domains: [String]
    let kind: Kind
    var cancelURL: String? = nil
}

// MARK: - Resolved Merchant

struct ResolvedMerchant: Equatable {
    let key: String
    let displayName: String
    let category: String?
    let kind: MerchantProfile.Kind?
    let isKnown: Bool
    let cancelURL: String?
    /// 0–100: how much we trust this is a real merchant name and not a header fragment.
    let nameQuality: Int
}

// MARK: - Catalog

struct MerchantCatalog {
    private(set) var profiles: [MerchantProfile]
    private var domainIndex: [String: Int] = [:]
    private var nameIndex: [String: Int] = [:]

    init(profiles: [MerchantProfile]) {
        self.profiles = profiles
        rebuildIndexes()
    }

    private mutating func rebuildIndexes() {
        domainIndex = [:]
        nameIndex = [:]
        for (i, profile) in profiles.enumerated() {
            for domain in profile.domains { domainIndex[domain] = i }
            nameIndex[MerchantCatalog.normalize(profile.displayName)] = i
            nameIndex[profile.key] = i
        }
    }

    /// Extends the built-in list with the app's larger catalog (names only; adds category and cancel link).
    func extending(with entries: [(name: String, category: String, cancelURL: String?)]) -> MerchantCatalog {
        var merged = self
        for entry in entries {
            let normalized = MerchantCatalog.normalize(entry.name)
            guard normalized.count >= 4, merged.nameIndex[normalized] == nil else { continue }
            merged.profiles.append(MerchantProfile(key: normalized, displayName: entry.name, category: entry.category,
                                                   domains: [], kind: .pureSubscription, cancelURL: entry.cancelURL))
        }
        merged.rebuildIndexes()
        return merged
    }

    // MARK: Resolution

    func resolve(hint: String?, senderName: String, senderDomain: String) -> ResolvedMerchant? {
        let registrable = MerchantCatalog.registrableDomain(senderDomain)

        // 1. Product/merchant hint from a parser (Stripe merchant, Apple app, "Amazon Prime", …)
        if let hint, let profile = profile(forName: hint) { return known(profile) }

        // 2. Sender domain
        if let index = domainIndex[registrable] ?? domainIndex[senderDomain.lowercased()] {
            // Mixed-commerce brands need a product hint to count as a subscription; otherwise stay "mixed".
            return known(profiles[index])
        }

        // 3. Sender display name
        if let profile = profile(forName: senderName) { return known(profile) }

        // 4. Unknown merchant: best plausible name from hint → display name → domain
        let relayDomain = MerchantCatalog.relayDomains.contains(registrable)
        let freeMail = MerchantCatalog.freeMailDomains.contains(registrable)
        var candidates: [(String, Int)] = []
        if let hint { candidates.append((hint, 70)) }
        candidates.append((senderName, 55))
        if !relayDomain && !freeMail {
            let label = registrable.split(separator: ".").first.map(String.init) ?? registrable
            candidates.append((label, 40))
        }

        for (raw, quality) in candidates {
            let cleaned = MerchantCatalog.cleanDisplayName(raw)
            if MerchantCatalog.isPlausibleMerchantName(cleaned) {
                let key = MerchantCatalog.normalize(cleaned)
                guard !key.isEmpty else { continue }
                return ResolvedMerchant(key: key, displayName: MerchantCatalog.prettify(cleaned), category: nil,
                                        kind: nil, isKnown: false, cancelURL: nil, nameQuality: quality)
            }
        }
        return nil
    }

    private func known(_ profile: MerchantProfile) -> ResolvedMerchant {
        ResolvedMerchant(key: profile.key, displayName: profile.displayName, category: profile.category,
                         kind: profile.kind, isKnown: true, cancelURL: profile.cancelURL, nameQuality: 100)
    }

    private func profile(forName raw: String) -> MerchantProfile? {
        let normalized = MerchantCatalog.normalize(raw)
        guard !normalized.isEmpty else { return nil }
        if let i = nameIndex[normalized] { return profiles[i] }
        // Whole-word containment, longest profile name first so "amazon prime" beats "amazon".
        let padded = " \(normalized) "
        var best: (index: Int, length: Int)?
        for (name, index) in nameIndex where name.count >= 4 {
            if padded.contains(" \(name) "), name.count > (best?.length ?? 0) { best = (index, name.count) }
        }
        if let best { return profiles[best.index] }
        // Short brand names (hbo, max, wsj, nyt, ea) only on exact match
        return nil
    }

    // MARK: Name hygiene

    static func normalize(_ raw: String) -> String {
        let stop: Set<String> = [
            "inc", "llc", "ltd", "corp", "corporation", "co", "company", "gmbh", "the", "billing", "receipts", "receipt",
            "payments", "payment", "support", "team", "noreply", "no", "reply", "donotreply", "do", "not", "notifications",
            "notification", "mail", "email", "emails", "news", "info", "service", "services", "customer", "care",
            "orders", "order", "accounts", "account", "via", "from"
        ]
        let lowered = raw.lowercased()
        let scalars = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "+" ? Character($0) : " " }
        let tokens = String(scalars).split(separator: " ").map(String.init).filter { !stop.contains($0) }
        return tokens.joined(separator: " ")
    }

    static func cleanDisplayName(_ raw: String) -> String {
        var s = raw
        if let range = s.range(of: "<") { s = String(s[..<range.lowerBound]) }
        s = s.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip trailing mail-ish suffixes from domain-style names: "lyftmail" → "lyft"
        let lower = s.lowercased()
        for suffix in ["mail", "email", "emails", "notify", "notifications", "billing", "receipts", "payments", "support", "news"] {
            if lower.hasSuffix(suffix), lower.count > suffix.count + 2, !lower.contains(" ") {
                s = String(s.dropLast(suffix.count))
                break
            }
        }
        return s
    }

    static func prettify(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == trimmed.lowercased() || trimmed == trimmed.uppercased() else { return trimmed }
        return trimmed.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
    }

    private static let genericWords: Set<String> = [
        "account", "accounts", "payments", "payment", "billing", "bill", "invoice", "invoices", "receipt", "receipts",
        "order", "orders", "support", "help", "info", "hello", "hi", "team", "notifications", "notification", "alerts",
        "alert", "mail", "email", "em", "noreply", "news", "newsletter", "service", "services", "customer", "admin",
        "system", "store", "shop", "member", "members", "membership", "messages", "message", "update", "updates",
        "security", "confirm", "confirmation", "verify", "reply", "donotreply", "no reply", "do not reply", "sales",
        "accounting", "finance", "subscription", "subscriptions", "renewal", "renewals", "contact", "service team",
        "customer service", "customer support", "account services", "online"
    ]

    private static let monthPattern = try? NSRegularExpression(
        pattern: "^(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\.?\\s*\\d{1,2}(,?\\s*\\d{2,4})?$",
        options: [.caseInsensitive])

    static func isPlausibleMerchantName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 40 else { return false }
        let lowered = trimmed.lowercased()
        if genericWords.contains(lowered) { return false }
        let tokens = lowered.split(separator: " ").map(String.init)
        if tokens.allSatisfy({ genericWords.contains($0) }) { return false }
        // Date-like fragments such as "Dec 26"
        let range = NSRange(location: 0, length: (trimmed as NSString).length)
        if monthPattern?.firstMatch(in: trimmed, range: range) != nil { return false }
        // Mostly digits (order numbers, ids)
        let digits = trimmed.filter(\.isNumber).count
        if Double(digits) / Double(trimmed.count) > 0.4 { return false }
        // Must contain letters
        guard trimmed.contains(where: \.isLetter) else { return false }
        // Looks like an email local-part fragment with random id
        if lowered.contains("@") || lowered.hasPrefix("bounce") || lowered.hasPrefix("reply-") { return false }
        return true
    }

    // MARK: Domains

    static let freeMailDomains: Set<String> = [
        "gmail.com", "googlemail.com", "yahoo.com", "ymail.com", "hotmail.com", "outlook.com", "live.com", "msn.com",
        "icloud.com", "me.com", "mac.com", "aol.com", "proton.me", "protonmail.com", "tutanota.com", "gmx.com", "zoho.com"
    ]

    /// Email-service-provider and relay domains: the real merchant is NOT the sender domain.
    static let relayDomains: Set<String> = [
        "sendgrid.net", "sendgrid.com", "mailchimp.com", "mcsv.net", "mandrillapp.com", "mailgun.org", "mailgun.com",
        "amazonses.com", "postmarkapp.com", "sparkpostmail.com", "customeriomail.com", "intercom-mail.com", "klaviyomail.com",
        "braze.com", "iterable.com", "sailthru.com", "exacttarget.com", "salesforce.com", "hubspotemail.net", "list-manage.com",
        "constantcontact.com", "createsend.com", "rsgsv.net", "cmail19.com", "cmail20.com", "mailjet.com", "sendinblue.com",
        "brevo.com", "mktomail.com", "marketo.com", "e2ma.net", "stripe.com", "paddle.com", "paypal.com", "paypal.ca",
        "shopify.com", "squarespace.com", "substack.com", "typeform.com", "fastspring.com", "chargebee.com", "recurly.com",
        "zuora.com", "gumroad.com", "lemonsqueezy.com", "bounces.google.com", "google.com", "apple.com", "amazon.com"
    ]

    private static let twoLevelTLDs: Set<String> = [
        "co.uk", "org.uk", "ac.uk", "com.au", "net.au", "org.au", "co.nz", "co.jp", "com.br", "com.mx", "co.in", "co.za",
        "com.sg", "com.hk", "com.tr", "co.kr", "com.ar", "com.co"
    ]

    static func registrableDomain(_ host: String) -> String {
        let labels = host.lowercased().split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return host.lowercased() }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        if twoLevelTLDs.contains(lastTwo), labels.count >= 3 { return labels.suffix(3).joined(separator: ".") }
        return lastTwo
    }
}

// MARK: - Built-in Catalog

extension MerchantCatalog {

    private static func pure(_ name: String, _ category: String, _ domains: [String], cancel: String? = nil) -> MerchantProfile {
        MerchantProfile(key: normalize(name), displayName: name, category: category, domains: domains, kind: .pureSubscription, cancelURL: cancel)
    }

    private static func mixed(_ name: String, _ category: String, _ domains: [String]) -> MerchantProfile {
        MerchantProfile(key: normalize(name), displayName: name, category: category, domains: domains, kind: .mixedCommerce)
    }

    static let builtin = MerchantCatalog(profiles: [
        // Streaming & media
        pure("Netflix", "Entertainment", ["netflix.com"], cancel: "https://www.netflix.com/cancelplan"),
        pure("Spotify", "Music", ["spotify.com"], cancel: "https://www.spotify.com/account/subscription/"),
        pure("Hulu", "Entertainment", ["hulu.com"], cancel: "https://secure.hulu.com/account"),
        pure("Disney+", "Entertainment", ["disneyplus.com", "disney.com", "disneyplus.ca"], cancel: "https://www.disneyplus.com/account"),
        pure("Max", "Entertainment", ["max.com", "hbomax.com", "hbo.com"]),
        pure("YouTube Premium", "Entertainment", ["youtube.com"], cancel: "https://www.youtube.com/paid_memberships"),
        pure("YouTube Music", "Music", []),
        pure("YouTube TV", "Entertainment", ["tv.youtube.com"]),
        pure("Paramount+", "Entertainment", ["paramountplus.com"]),
        pure("Peacock", "Entertainment", ["peacocktv.com"]),
        pure("Crunchyroll", "Entertainment", ["crunchyroll.com"]),
        pure("Crave", "Entertainment", ["crave.ca"]),
        pure("Tidal", "Music", ["tidal.com"]),
        pure("Deezer", "Music", ["deezer.com"]),
        pure("SiriusXM", "Music", ["siriusxm.com"]),
        pure("Audible", "Entertainment", ["audible.com", "audible.ca"]),
        pure("Kindle Unlimited", "Entertainment", []),
        pure("Prime Video", "Entertainment", ["primevideo.com"]),
        pure("Amazon Prime", "Shopping", []),
        pure("Amazon Music Unlimited", "Music", []),
        pure("Apple Music", "Music", []),
        pure("Apple TV+", "Entertainment", []),
        pure("Apple One", "Productivity", []),
        pure("Apple Arcade", "Entertainment", []),
        pure("iCloud+", "Cloud Storage", ["icloud.com"]),
        pure("Twitch", "Entertainment", ["twitch.tv"]),
        pure("Patreon", "Entertainment", ["patreon.com"]),
        pure("Substack", "News", ["substack.com"]),
        pure("Medium", "News", ["medium.com"]),
        pure("The New York Times", "News", ["nytimes.com"]),
        pure("The Wall Street Journal", "News", ["wsj.com"]),
        pure("The Washington Post", "News", ["washingtonpost.com"]),
        pure("The Economist", "News", ["economist.com"]),
        pure("The Globe and Mail", "News", ["theglobeandmail.com"]),
        // Gaming
        pure("Xbox Game Pass", "Gaming", ["xbox.com"]),
        pure("PlayStation Plus", "Gaming", []),
        pure("Nintendo Switch Online", "Gaming", []),
        pure("EA Play", "Gaming", ["ea.com"]),
        pure("Discord Nitro", "Entertainment", ["discord.com", "discordapp.com"]),
        // Productivity & software
        pure("Adobe Creative Cloud", "Productivity", ["adobe.com"], cancel: "https://account.adobe.com/plans"),
        pure("Microsoft 365", "Productivity", []),
        pure("Dropbox", "Cloud Storage", ["dropbox.com"]),
        pure("Notion", "Productivity", ["notion.so", "notion.com"]),
        pure("Slack", "Productivity", ["slack.com"]),
        pure("Zoom", "Productivity", ["zoom.us"]),
        pure("Canva", "Design", ["canva.com"]),
        pure("Figma", "Design", ["figma.com"]),
        pure("Evernote", "Productivity", ["evernote.com"]),
        pure("Todoist", "Productivity", ["todoist.com"]),
        pure("Asana", "Productivity", ["asana.com"]),
        pure("Atlassian", "Productivity", ["atlassian.com", "atlassian.net"]),
        pure("Linear", "Productivity", ["linear.app"]),
        pure("Grammarly", "Productivity", ["grammarly.com"]),
        pure("Google One", "Cloud Storage", []),
        pure("Google Workspace", "Productivity", []),
        pure("HubSpot", "Productivity", ["hubspot.com"]),
        pure("QuickBooks", "Productivity", ["intuit.com", "quickbooks.com"]),
        pure("FreshBooks", "Productivity", ["freshbooks.com"]),
        pure("Zapier", "Productivity", ["zapier.com"]),
        pure("Mailchimp", "Productivity", []),
        pure("Squarespace", "Productivity", []),
        pure("Wix", "Productivity", ["wix.com"]),
        pure("GoDaddy", "Productivity", ["godaddy.com"]),
        pure("Namecheap", "Productivity", ["namecheap.com"]),
        // Developer & AI
        pure("ChatGPT Plus", "AI Tools", ["openai.com"], cancel: "https://chatgpt.com/#settings/Subscription"),
        pure("ChatGPT Pro", "AI Tools", []),
        pure("ChatGPT Team", "AI Tools", []),
        pure("Claude Pro", "AI Tools", ["anthropic.com", "claude.ai"], cancel: "https://claude.ai/settings/billing"),
        pure("Claude Max", "AI Tools", []),
        pure("Midjourney", "AI Tools", ["midjourney.com"]),
        pure("Perplexity", "AI Tools", ["perplexity.ai"]),
        pure("Cursor", "AI Tools", ["cursor.com", "cursor.sh"]),
        pure("GitHub Copilot", "AI Tools", []),
        pure("GitHub", "Productivity", ["github.com"]),
        pure("Vercel", "Productivity", ["vercel.com"]),
        pure("Cloudflare", "Productivity", ["cloudflare.com"]),
        pure("Heroku", "Productivity", ["heroku.com"]),
        pure("Replit", "Productivity", ["replit.com"]),
        // Security & utilities
        pure("NordVPN", "Utilities", ["nordvpn.com", "nordaccount.com"]),
        pure("ExpressVPN", "Utilities", ["expressvpn.com"]),
        pure("Surfshark", "Utilities", ["surfshark.com"]),
        pure("1Password", "Utilities", ["1password.com"]),
        pure("LastPass", "Utilities", ["lastpass.com"]),
        pure("Dashlane", "Utilities", ["dashlane.com"]),
        pure("Bitwarden", "Utilities", ["bitwarden.com"]),
        // Health, fitness & learning
        pure("Headspace", "Health & Fitness", ["headspace.com"]),
        pure("Calm", "Health & Fitness", ["calm.com"]),
        pure("Peloton", "Health & Fitness", ["onepeloton.com", "peloton.com"]),
        pure("Strava", "Health & Fitness", ["strava.com"]),
        pure("MyFitnessPal", "Health & Fitness", ["myfitnesspal.com"]),
        pure("Noom", "Health & Fitness", ["noom.com"]),
        pure("WW", "Health & Fitness", ["weightwatchers.com", "ww.com"]),
        pure("Planet Fitness", "Health & Fitness", ["planetfitness.com"]),
        pure("Duolingo", "Education", ["duolingo.com"]),
        pure("MasterClass", "Education", ["masterclass.com"]),
        pure("Skillshare", "Education", ["skillshare.com"]),
        pure("Coursera", "Education", ["coursera.org"]),
        pure("Udemy", "Education", ["udemy.com"]),
        pure("LinkedIn Premium", "Productivity", ["linkedin.com"]),
        // Membership products inside mixed-commerce brands (matched via product hints)
        pure("DashPass", "Food & Delivery", []),
        pure("Uber One", "Transportation", []),
        pure("Walmart+", "Shopping", []),
        pure("Instacart+", "Food & Delivery", []),
        pure("Lyft Pink", "Transportation", []),
        pure("Grubhub+", "Food & Delivery", []),
        // Mixed-commerce brands: a receipt alone proves nothing
        mixed("Amazon", "Shopping", ["amazon.com", "amazon.ca", "amazon.co.uk"]),
        mixed("DoorDash", "Food & Delivery", ["doordash.com"]),
        mixed("Uber", "Transportation", ["uber.com"]),
        mixed("Lyft", "Transportation", ["lyft.com", "lyftmail.com"]),
        mixed("Instacart", "Food & Delivery", ["instacart.com"]),
        mixed("Walmart", "Shopping", ["walmart.com", "walmart.ca"]),
        mixed("Target", "Shopping", ["target.com"]),
        mixed("eBay", "Shopping", ["ebay.com"]),
        mixed("Apple", "Productivity", ["apple.com", "email.apple.com", "itunes.com"]),
        mixed("Google", "Productivity", ["google.com", "googleplay.com"]),
        mixed("Microsoft", "Productivity", ["microsoft.com", "microsoftonline.com"]),
        mixed("Nintendo", "Gaming", ["nintendo.com", "nintendo.net"]),
        mixed("PlayStation", "Gaming", ["playstation.com", "sony.com"]),
        mixed("Steam", "Gaming", ["steampowered.com", "steamgames.com"]),
        mixed("Grubhub", "Food & Delivery", ["grubhub.com"]),
        mixed("Skip The Dishes", "Food & Delivery", ["skipthedishes.com"]),
        mixed("Ticketmaster", "Entertainment", ["ticketmaster.com", "ticketmaster.ca"]),
        mixed("Eventbrite", "Entertainment", ["eventbrite.com"]),
    ])
}
