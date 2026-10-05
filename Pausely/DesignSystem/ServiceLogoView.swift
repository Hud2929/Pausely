import SwiftUI

// MARK: - Service Logo View
//
// Fetches brand logos via Clearbit Logo API for ~120 known services.
// Falls back gracefully to a category-colored initial circle if the
// service is unknown or if the network request fails.

struct ServiceLogoView: View {
    let name: String
    let category: String?
    let size: CGFloat

    init(name: String, category: String? = nil, size: CGFloat = 48) {
        self.name = name
        self.category = category
        self.size = size
    }

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

            if let domain = ServiceDomains.domain(for: name) {
                AsyncImage(url: URL(string: "https://logo.clearbit.com/\(domain)?size=\(Int(size * 3))")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.62, height: size * 0.62)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
                    case .failure:
                        initialView
                    case .empty:
                        // Still loading — pulse placeholder
                        Circle()
                            .fill(categoryColor.opacity(0.12))
                            .frame(width: size * 0.62, height: size * 0.62)
                    @unknown default:
                        initialView
                    }
                }
            } else {
                initialView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
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

    static func domain(for serviceName: String) -> String? {
        domains[serviceName.trimmingCharacters(in: .whitespaces).lowercased()]
    }
}
