import SwiftUI
import UIKit

// MARK: - Service Logo View
//
// Shows the service's own icon: its apple-touch-icon first, then Google's favicon service, cached
// on disk for 30 days. Only the service's domain is sent, never anything about the customer.
// Falls back to a category-coloured initial when there's no domain or no usable icon.

struct ServiceLogoView: View {
    let name: String
    let category: String?
    let size: CGFloat

    @State private var image: UIImage?

    init(name: String, category: String? = nil, size: CGFloat = 48) {
        self.name = name
        self.category = category
        self.size = size
    }

    private var domain: String? { ServiceDomains.domain(for: name) }

    /// The service's own icon in an app-icon shape. Without one, the first letter on a quiet tile:
    /// no category colours, no gradients, so a list of logos doesn't turn into confetti.
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        ZStack {
            shape.fill(Color.inkLifted)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .transition(.opacity)
            } else {
                initialView
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.stroke(Color.line, lineWidth: 1))
        .accessibilityHidden(true)
        .task(id: domain) {
            guard let domain else { image = nil; return }
            if let cached = LogoStore.shared.cachedImage(for: domain) {
                image = cached
                return
            }
            let loaded = await LogoStore.shared.image(for: domain)
            withAnimation(Motion.fade) { image = loaded }
        }
    }

    /// The letter on the tile: the first letter or digit of the name. A name can begin with something
    /// that is neither (a direction mark in front of "Gmail" in Arabic left the tile blank).
    static func initial(of name: String) -> String {
        let first = name.first { $0.isLetter || $0.isNumber } ?? name.first
        return first.map { String($0).uppercased() } ?? ""
    }

    /// The letter is drawn, not set as text: it stands in for a logo and is sized to its tile like
    /// one, so it is a picture. (As text it was reported by Apple's audit as text that cannot grow.)
    private var initialView: some View {
        let letter = Text(verbatim: Self.initial(of: name))
            .font(.total(size * 0.44, weight: .semibold))
            .foregroundStyle(Color.inkText)
        return Canvas { context, area in
            context.draw(letter, at: CGPoint(x: area.width / 2, y: area.height / 2))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Logo Store

/// Loads and caches service icons. One request per domain at a time; failures are remembered for
/// the session so a missing icon isn't fetched again on every scroll.
@MainActor
final class LogoStore {
    static let shared = LogoStore()

    private var memory: [String: UIImage] = [:]
    private var missing: Set<String> = []
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func cachedImage(for domain: String) -> UIImage? {
        if let image = memory[domain] { return image }
        if let image = Self.readDisk(domain) {
            memory[domain] = image
            return image
        }
        return nil
    }

    func image(for domain: String) async -> UIImage? {
        if let image = cachedImage(for: domain) { return image }
        if missing.contains(domain) { return nil }
        if let task = inFlight[domain] { return await task.value }
        let task = Task.detached(priority: .utility) { await Self.download(domain) }
        inFlight[domain] = task
        let image = await task.value
        inFlight[domain] = nil
        if let image { memory[domain] = image } else { missing.insert(domain) }
        return image
    }

    // MARK: Network

    /// The service's own icon, asked of the service's own site and nobody else: its touch icon
    /// (180px, made for home screens), then its favicon. A lookup service was used as a last resort
    /// before; it was told the address of every service whose own icon was missing, which is a list
    /// of what someone subscribes to. Where a site has no usable icon the initial is shown instead.
    ///
    /// A few of the best-known services keep their icon at none of those three addresses. For
    /// them the address on their own site is known (`ServiceDomains.iconAddresses`) and asked first.
    nonisolated static func sources(for domain: String) -> [URL] {
        let host = domain.hasPrefix("www.") ? String(domain.dropFirst(4)) : domain
        return ([ServiceDomains.iconAddresses[host]].compactMap { $0 } + [
            "https://\(host)/apple-touch-icon.png",
            "https://www.\(host)/apple-touch-icon.png",
            "https://\(host)/favicon.ico"
        ]).compactMap(URL.init(string:))
    }

    nonisolated private static func download(_ domain: String) async -> UIImage? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.httpCookieStorage = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        for url in sources(for: domain) {
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = UIImage(data: data),
                  min(image.size.width * image.scale, image.size.height * image.scale) >= 48 else { continue }
            writeDisk(data, domain)
            return image
        }
        return nil
    }

    // MARK: Disk cache

    nonisolated private static let maxAge: TimeInterval = 30 * 24 * 3600

    nonisolated private static func fileURL(_ domain: String) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let safe = domain.replacingOccurrences(of: "/", with: "_")
        return caches.appendingPathComponent("ServiceLogos", isDirectory: true).appendingPathComponent(safe + ".img")
    }

    nonisolated private static func readDisk(_ domain: String) -> UIImage? {
        guard let url = fileURL(domain),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < maxAge,
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    nonisolated private static func writeDisk(_ data: Data, _ domain: String) {
        guard let url = fileURL(domain) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// The logos kept on the iPhone say which services its last owner paid for: they go with the rest.
    static func removeSavedLogos() {
        shared.memory = [:]
        shared.missing = []
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        try? FileManager.default.removeItem(at: caches.appendingPathComponent("ServiceLogos", isDirectory: true))
    }
}

// MARK: - Service Domain Lookup

enum ServiceDomains {
    /// Where a service keeps its icon when it is at none of the three usual addresses. Each is on
    /// the service's own site, and each was asked for and answered with an image of 128 pixels or
    /// more on 2026-11-17. Without them a new install showed a letter for YouTube Premium, Google
    /// One and PlayStation Plus on the first screen that shows logos (seen on a simulator that had
    /// never run the app; the ones the tours use had their icons from weeks before).
    nonisolated static let iconAddresses: [String: String] = [
        "youtube.com": "https://www.youtube.com/img/favicon_144.png",
        "google.com": "https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png",
        "playstation.com": "https://gmedia.playstation.com/is/image/SIEPDC/ps-logo-favicon?$icon-196-196--t$",
        "discord.com": "https://discord.com/assets/favicon.ico",
        "notion.com": "https://www.notion.com/front-static/logo-ios.png",
        "duolingo.com": "https://d35aaqx5ub95lt.cloudfront.net/images/duolingo-touch-icon2.png",
    ]

    /// Hosts that are not on a service's domain and still its own: the address the service's own
    /// front page names as its touch icon (read on 2026-11-17). Anything else in the table above
    /// must be on the service's domain; the test holds both.
    nonisolated static let assetHosts: [String: String] = [
        "duolingo.com": "d35aaqx5ub95lt.cloudfront.net",
    ]

    // Keyed by lowercase service name → canonical domain
    private static let domains: [String: String] = [
        // ── Streaming: Video ──────────────────────────────────────────────
        "netflix": "netflix.com",
        "gmail": "gmail.com", "gmail (app password)": "gmail.com", "icloud mail": "icloud.com",
        "yahoo mail": "yahoo.com", "aol mail": "aol.com", "outlook": "outlook.com",
        "hulu": "hulu.com",
        "disney+": "disneyplus.com",
        "disney plus": "disneyplus.com",
        "hbo max": "max.com",
        "max": "max.com",
        "apple tv+": "apple.com",
        "apple tv": "apple.com",
        "amazon prime": "amazon.com",
        "amazon prime video": "amazon.com",
        "prime video": "amazon.com",
        "peacock": "peacocktv.com",
        "paramount+": "paramountplus.com",
        "paramount plus": "paramountplus.com",
        "espn+": "espn.com",
        "espn plus": "espn.com",
        "youtube premium": "youtube.com",
        "youtube tv": "youtube.com",
        "crunchyroll": "crunchyroll.com",
        "discovery+": "discoveryplus.com",
        "discovery plus": "discoveryplus.com",
        "fubo": "fubo.tv",
        "fubotv": "fubo.tv",
        "sling": "sling.com",
        "sling tv": "sling.com",
        "philo": "philo.com",
        "shudder": "shudder.com",
        "mubi": "mubi.com",
        "curiositystream": "curiositystream.com",
        "nebula": "nebula.tv",
        "britbox": "britbox.com",
        "acorn tv": "acorn.tv",
        // ── Streaming: Music & Audio ──────────────────────────────────────
        "spotify": "spotify.com",
        "apple music": "apple.com",
        "tidal": "tidal.com",
        "deezer": "deezer.com",
        "pandora": "pandora.com",
        "siriusxm": "siriusxm.com",
        "sirius xm": "siriusxm.com",
        "soundcloud": "soundcloud.com",
        "audible": "audible.com",
        "amazon music": "music.amazon.com",
        // ── Cloud Storage ─────────────────────────────────────────────────
        "icloud": "icloud.com",
        "icloud+": "icloud.com",
        // one.google.com serves no touch icon and only a 32-pixel favicon; google.com serves the full mark.
        "google one": "google.com",
        // chatgpt.com serves no touch icon and a 48-pixel favicon; openai.com serves the same mark at full size.
        "chatgpt": "openai.com",
        "chatgpt plus": "openai.com",
        "dropbox": "dropbox.com",
        "onedrive": "microsoft.com",
        "pcloud": "pcloud.com",
        "backblaze": "backblaze.com",
        "box": "box.com",
        // ── Productivity & Collaboration ──────────────────────────────────
        "microsoft 365": "microsoft.com",
        "office 365": "microsoft.com",
        "microsoft office": "microsoft.com",
        "notion": "notion.com",
        "slack": "slack.com",
        "zoom": "zoom.us",
        "google workspace": "workspace.google.com",
        "monday": "monday.com",
        "monday.com": "monday.com",
        "asana": "asana.com",
        "clickup": "clickup.com",
        "airtable": "airtable.com",
        "todoist": "todoist.com",
        "trello": "trello.com",
        "linear": "linear.app",
        "coda": "coda.io",
        "basecamp": "basecamp.com",
        // ── Design & Creative ─────────────────────────────────────────────
        "figma": "figma.com",
        "canva": "canva.com",
        "adobe creative cloud": "adobe.com",
        "adobe cc": "adobe.com",
        "adobe": "adobe.com",
        "sketch": "sketch.com",
        "procreate": "procreate.art",
        // ── Apple Services ────────────────────────────────────────────────
        "apple one": "apple.com",
        "apple arcade": "apple.com",
        "apple news+": "apple.com",
        "apple news plus": "apple.com",
        "apple fitness+": "apple.com",
        "apple fitness plus": "apple.com",
        // ── Developer Tools ───────────────────────────────────────────────
        "github": "github.com",
        "github copilot": "github.com",
        "jetbrains": "jetbrains.com",
        "vercel": "vercel.com",
        "netlify": "netlify.com",
        "datadog": "datadoghq.com",
        "sentry": "sentry.io",
        "postman": "postman.com",
        // ── Security & VPN ────────────────────────────────────────────────
        "nordvpn": "nordvpn.com",
        "expressvpn": "expressvpn.com",
        "surfshark": "surfshark.com",
        "protonvpn": "protonvpn.com",
        "mullvad": "mullvad.net",
        // ── Password Managers ─────────────────────────────────────────────
        "1password": "1password.com",
        "lastpass": "lastpass.com",
        "bitwarden": "bitwarden.com",
        "dashlane": "dashlane.com",
        "keeper": "keepersecurity.com",
        "nordpass": "nordpass.com",
        // ── Health & Fitness ─────────────────────────────────────────────
        "peloton": "onepeloton.com",
        "strava": "strava.com",
        "headspace": "headspace.com",
        "calm": "calm.com",
        "noom": "noom.com",
        "myfitnesspal": "myfitnesspal.com",
        "my fitness pal": "myfitnesspal.com",
        "whoop": "whoop.com",
        "oura": "ouraring.com",
        "ten percent happier": "tenpercent.com",
        "waking up": "wakingup.com",
        "weight watchers": "weightwatchers.com",
        "ww": "weightwatchers.com",
        // ── Finance ───────────────────────────────────────────────────────
        "robinhood": "robinhood.com",
        "ynab": "youneedabudget.com",
        "you need a budget": "youneedabudget.com",
        "quicken": "quicken.com",
        "acorns": "acorns.com",
        "betterment": "betterment.com",
        // ── Education ─────────────────────────────────────────────────────
        "duolingo": "duolingo.com",
        "coursera": "coursera.org",
        "skillshare": "skillshare.com",
        "masterclass": "masterclass.com",
        "brilliant": "brilliant.org",
        "babbel": "babbel.com",
        "rosetta stone": "rosettastone.com",
        "linkedin premium": "linkedin.com",
        "linkedin learning": "linkedin.com",
        "udemy": "udemy.com",
        "khan academy": "khanacademy.org",
        // ── Gaming ────────────────────────────────────────────────────────
        "xbox game pass": "xbox.com",
        "xbox": "xbox.com",
        "playstation plus": "playstation.com",
        "ps plus": "playstation.com",
        "nintendo switch online": "nintendo.com",
        "nintendo": "nintendo.com",
        "ea play": "ea.com",
        "discord nitro": "discord.com",
        "discord": "discord.com",
        "twitch": "twitch.tv",
        // ── News & Reading ────────────────────────────────────────────────
        "new york times": "nytimes.com",
        "nyt": "nytimes.com",
        "wall street journal": "wsj.com",
        "wsj": "wsj.com",
        "the economist": "economist.com",
        "economist": "economist.com",
        "bloomberg": "bloomberg.com",
        "washington post": "washingtonpost.com",
        "medium": "medium.com",
        "wired": "wired.com",
        "the atlantic": "theatlantic.com",
        "new yorker": "newyorker.com",
        "kindle unlimited": "amazon.com",
        "scribd": "scribd.com",
        // ── Food & Delivery ───────────────────────────────────────────────
        "amazon": "amazon.com",
        "walmart+": "walmart.com",
        "walmart plus": "walmart.com",
        "instacart": "instacart.com",
        "doordash": "doordash.com",
        "grubhub": "grubhub.com",
        "uber eats": "ubereats.com",
        "hellofresh": "hellofresh.com",
        "blue apron": "blueapron.com",
        // ── Social ───────────────────────────────────────────────────────
        "twitter": "twitter.com",
        "x": "x.com",
        "reddit": "reddit.com",
        "reddit premium": "reddit.com",
        "tinder": "tinder.com",
        "bumble": "bumble.com",
        "hinge": "hinge.co",
        "match": "match.com",
        // ── Smart Home ────────────────────────────────────────────────────
        "ring": "ring.com",
        "nest": "nest.com",
        "arlo": "arlo.com",
        "simplisafe": "simplisafe.com",
        "wyze": "wyze.com",
        // ── E-commerce & Business ─────────────────────────────────────────
        "shopify": "shopify.com",
        "squarespace": "squarespace.com",
        "wix": "wix.com",
        "webflow": "webflow.com",
        "mailchimp": "mailchimp.com",
        "hubspot": "hubspot.com",
        "salesforce": "salesforce.com",
        "zendesk": "zendesk.com",
    ]

    /// The known domain for a service: the list above, then the site of the catalog's link for it
    /// (a real address that was requested and answered). Never a guess: the catalog used to invent a
    /// website from the name with ".com" on the end, and whoever owned that address supplied the logo.
    @MainActor
    static func domain(for serviceName: String) -> String? {
        let key = serviceName.trimmingCharacters(in: .whitespaces).lowercased()
        if let known = domains[key] { return known }
        guard let link = SubscriptionCatalogService.shared.entry(named: key)?.cancellationURL else { return nil }
        return siteDomain(ofLink: link)
    }

    /// "account.adobe.com" is adobe.com's. Apple's subscriptions page stands for no service in
    /// particular (anything billed through the App Store is cancelled there), so it gives no logo.
    static func siteDomain(ofLink link: String) -> String? {
        guard let host = URL(string: link)?.host?.lowercased(), host != "apps.apple.com" else { return nil }
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return nil }
        // Two-part endings such as "co.uk" and "com.au" keep three labels.
        let secondLevel: Set<String> = ["co", "com", "org", "net", "ac", "gov", "edu"]
        let keep = labels.count >= 3 && labels[labels.count - 1].count == 2 && secondLevel.contains(labels[labels.count - 2]) ? 3 : 2
        return labels.suffix(keep).joined(separator: ".")
    }
}
