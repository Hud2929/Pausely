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

    var body: some View {
        ZStack {
            // Background — gradient for depth, always present
            Circle()
                .fill(
                    LinearGradient(
                        colors: [categoryColor.opacity(0.38), categoryColor.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(categoryColor.opacity(0.45), lineWidth: 1))
                .frame(width: size, height: size)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size * 0.66, height: size * 0.66)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.17, style: .continuous))
                    .transition(.opacity)
            } else {
                initialView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: domain) {
            guard let domain else { image = nil; return }
            if let cached = LogoStore.shared.cachedImage(for: domain) {
                image = cached
                return
            }
            let loaded = await LogoStore.shared.image(for: domain)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }

    private var initialView: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }

    private var categoryColor: Color {
        guard let cat = category,
              let sc = ServiceCategory.allCases.first(where: {
                  $0.rawValue.lowercased() == cat.lowercased()
              }) else { return .purple }
        return sc.color
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

    /// The service's own touch icon (180px, made for home screens), then Google's favicon service.
    nonisolated static func sources(for domain: String) -> [URL] {
        let host = domain.hasPrefix("www.") ? String(domain.dropFirst(4)) : domain
        return [
            "https://\(host)/apple-touch-icon.png",
            "https://www.\(host)/apple-touch-icon.png",
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128"
        ].compactMap(URL.init(string:))
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
}

// MARK: - Service Domain Lookup

enum ServiceDomains {
    // Keyed by lowercase service name → canonical domain
    private static let domains: [String: String] = [
        // ── Streaming: Video ──────────────────────────────────────────────
        "netflix": "netflix.com",
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
        "google one": "one.google.com",
        "dropbox": "dropbox.com",
        "onedrive": "microsoft.com",
        "pcloud": "pcloud.com",
        "backblaze": "backblaze.com",
        "box": "box.com",
        // ── Productivity & Collaboration ──────────────────────────────────
        "microsoft 365": "microsoft.com",
        "office 365": "microsoft.com",
        "microsoft office": "microsoft.com",
        "notion": "notion.so",
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

    /// The known domain for a service: the list above, then the website in the subscription catalog.
    @MainActor
    static func domain(for serviceName: String) -> String? {
        let key = serviceName.trimmingCharacters(in: .whitespaces).lowercased()
        if let known = domains[key] { return known }
        guard let website = SubscriptionCatalogService.shared.entry(named: key)?.websiteURL,
              let host = URL(string: website.hasPrefix("http") ? website : "https://\(website)")?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
