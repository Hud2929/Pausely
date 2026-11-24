import SwiftUI
import UIKit

// MARK: - Service Logo View
//
// Shows the service's own icon, asked of the service's own site and nobody else: its touch icon, its
// favicon, then the icon its front page names. Cached on disk for 30 days. Nothing about the
// customer is sent. Falls back to the name's first letter when there's no site or no usable icon.

struct ServiceLogoView: View {
    let name: String
    let category: String?
    let size: CGFloat

    @State private var image: UIImage?
    /// The icon is a dark glyph on a clear background: drawn on white, as iOS draws such icons. On the
    /// app's ink it was all but invisible (1Password, the rating of 2026-11-22).
    @State private var onWhite = false

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
            shape.fill(onWhite ? Color.paper : Color.inkLifted)

            if let image {
                if onWhite {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(size * 0.16)
                        .frame(width: size, height: size)
                        .transition(.opacity)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .transition(.opacity)
                }
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
                onWhite = Self.isDarkGlyphOnClear(cached)
                image = cached
                return
            }
            let loaded = await LogoStore.shared.image(for: domain)
            onWhite = loaded.map(Self.isDarkGlyphOnClear) ?? false
            withAnimation(Motion.fade) { image = loaded }
        }
    }

    /// Whether an icon is a glyph on a clear background (most of its corners see-through) whose own colour
    /// is dark: such a glyph needs a white tile. A light glyph on clear stays on ink, where it shows.
    nonisolated static func isDarkGlyphOnClear(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let side = 8
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return false }
        let corners = [0, side - 1, (side - 1) * side, side * side - 1]
        guard corners.filter({ pixels[$0 * 4 + 3] < 128 }).count >= 3 else { return false }
        var light = 0.0, counted = 0.0
        for index in 0..<(side * side) where pixels[index * 4 + 3] >= 128 {
            let alpha = Double(pixels[index * 4 + 3]) / 255
            let red = Double(pixels[index * 4]) / 255 / alpha, green = Double(pixels[index * 4 + 1]) / 255 / alpha
            let blue = Double(pixels[index * 4 + 2]) / 255 / alpha
            light += 0.2126 * red + 0.7152 * green + 0.0722 * blue
            counted += 1
        }
        return counted > 0 && light / counted < 0.6
    }

    /// The letter on the tile: the first letter or digit of the name. A name can begin with something
    /// that is neither (a direction mark in front of "Gmail" in Arabic left the tile blank).
    static func initial(of name: String) -> String {
        // A leading "The" is not the name: "The Economist" was a "T" (the rating of 2026-11-23).
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let name = trimmed.lowercased().hasPrefix("the ") && trimmed.count > 4 ? String(trimmed.dropFirst(4)) : name
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

/// Loads and caches service icons. One request per domain at a time. A site that has no usable icon
/// is remembered for a week, and one that could not be reached for the session, so a missing icon
/// isn't fetched again on every scroll.
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
        if missing.contains(domain) || Self.isKnownMiss(domain) { return nil }
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
        // A known address is asked only if it is on the service's own site: a slip in the table
        // must never send one service's name to another's server.
        let known = [ServiceDomains.iconAddresses[host]].compactMap { $0 }.compactMap(URL.init(string:))
            .filter { ServiceDomains.isOwnSite($0, of: host) }
        return known + [
            "https://\(host)/apple-touch-icon.png",
            "https://www.\(host)/apple-touch-icon.png",
            "https://\(host)/favicon.ico"
        ].compactMap(URL.init(string:))
    }

    /// The front page of a service's site, asked when it keeps no icon at the usual addresses.
    nonisolated static func frontPages(of domain: String) -> [URL] {
        let host = domain.hasPrefix("www.") ? String(domain.dropFirst(4)) : domain
        return ["https://www.\(host)/", "https://\(host)/"].compactMap(URL.init(string:))
    }

    /// The icons a front page names that may be asked for: the three largest on the service's own
    /// site. None when the page that answered is somewhere else (a service not offered in a country
    /// sends its visitors to another company's page, and that page's icon is not the service's), and
    /// none on another host: an icon is asked of the service's own site and nobody else.
    nonisolated static func icons(namedIn html: String, at page: URL, for domain: String) -> [URL] {
        let host = domain.hasPrefix("www.") ? String(domain.dropFirst(4)) : domain
        guard ServiceDomains.isOwnSite(page, of: host) else { return [] }
        return Array(PageIcons.named(in: html, at: page).filter { ServiceDomains.isOwnSite($0, of: host) }.prefix(3))
    }

    nonisolated private static func download(_ domain: String) async -> UIImage? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.httpCookieStorage = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        func icon(at url: URL) async -> UIImage? {
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = UIImage(data: data),
                  min(image.size.width * image.scale, image.size.height * image.scale) >= 48 else { return nil }
            writeDisk(data, domain)
            return image
        }

        for url in sources(for: domain) {
            if let image = await icon(at: url) { return image }
        }
        // None at the usual addresses: the site's own front page says where it keeps one.
        var settled = false
        for page in frontPages(of: domain) {
            guard let (bytes, response) = try? await session.bytes(from: page),
                  let answer = response as? HTTPURLResponse, let landed = answer.url else { continue }
            settled = settled || settles(status: answer.statusCode)
            guard answer.statusCode == 200 else { continue }
            var head = Data()
            do {
                // The page is read as far as the end of its head and no further: a front page can be
                // megabytes, and all that is wanted from it is one address.
                for try await byte in bytes {
                    head.append(byte)
                    if head.count % 4_096 == 0, PageIcons.hasReadEnough(head) { break }
                }
            } catch { continue }
            for url in icons(namedIn: String(decoding: head, as: UTF8.self), at: landed, for: domain) {
                if let image = await icon(at: url) { return image }
            }
            break
        }
        // The site was reached and has no icon that can be used: it is not asked again for a week.
        if settled { markMiss(domain) }
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

    // MARK: Sites with no icon

    /// How long a site that answered with no usable icon is left alone. Finding that out costs its
    /// front page, and a catalog scrolled on every launch would fetch a few hundred of them. Only a
    /// site that answered is marked: with no connection nothing is, and the next launch asks again.
    nonisolated static let missLife: TimeInterval = 7 * 24 * 3600

    /// Whether a front page's answer settles that the site has no icon to give: a page that was
    /// read, or a refusal that will not change by tomorrow. A server in trouble, or one asking for
    /// patience, settles nothing.
    nonisolated static func settles(status: Int) -> Bool {
        status == 200 || ((400..<500).contains(status) && status != 408 && status != 429)
    }

    nonisolated static func missIsFresh(markedAt: Date, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(markedAt)
        return age >= 0 && age < missLife
    }

    nonisolated private static func missURL(_ domain: String) -> URL? {
        fileURL(domain)?.deletingPathExtension().appendingPathExtension("none")
    }

    nonisolated private static func isKnownMiss(_ domain: String) -> Bool {
        guard let url = missURL(domain),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let marked = attributes[.modificationDate] as? Date else { return false }
        return missIsFresh(markedAt: marked)
    }

    nonisolated private static func markMiss(_ domain: String) {
        guard let url = missURL(domain) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data().write(to: url, options: .atomic)
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
        // Deezer's front page names its 72-point icon there (read on 2026-11-22); its own favicon is 16.
        "deezer.com": "cdn-files.dzcdn.net",
    ]

    /// Whether an address is on a service's own site: its domain, a name under it, or the one
    /// host listed for it above. Over https only.
    nonisolated static func isOwnSite(_ url: URL, of domain: String) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return host == domain || host.hasSuffix("." + domain) || assetHosts[domain] == host
    }

    // Keyed by lowercase service name → canonical domain
    private static let domains: [String: String] = [
        // ── Streaming: Video ──────────────────────────────────────────────
        "netflix": "netflix.com",
        // Gmail's own site is mail.google.com: gmail.com has no icon of its own (2026-11-22).
        "gmail": "mail.google.com", "gmail (app password)": "mail.google.com", "icloud mail": "icloud.com",
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
        "uber eats": "ubereats.com", "uber one": "uber.com",
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
