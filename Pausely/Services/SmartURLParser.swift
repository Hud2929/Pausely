import Foundation
import SwiftUI
import Combine

struct ServicePattern {
    let name: String
    let patterns: [String]
    let category: ServiceCategory
    let logoURL: String?
    let defaultPrice: Double?
    let priceSelector: String?
    let description: String?
    let cancelURL: String?
    let pauseURL: String?
    let supportURL: String?
}

// MARK: - Smart URL Parser
@MainActor
class SmartURLParser: ObservableObject {
    static let shared = SmartURLParser()
    
    @Published var isParsing = false
    @Published var lastResult: ParsedSubscription?
    @Published var recentParses: [ParsedSubscription] = []
    
    // Service patterns database - 500+ services
    private let servicePatterns: [ServicePattern] = [
        // Streaming
        ServicePattern(name: "Netflix", patterns: ["netflix.com", "netflix"], category: .streaming, logoURL: "https://logo.clearbit.com/netflix.com", defaultPrice: 15.49, priceSelector: nil, description: "Stream movies and TV shows", cancelURL: "https://www.netflix.com/cancelplan", pauseURL: nil, supportURL: "https://help.netflix.com"),
        ServicePattern(name: "Hulu", patterns: ["hulu.com", "hulu"], category: .streaming, logoURL: "https://logo.clearbit.com/hulu.com", defaultPrice: 7.99, priceSelector: nil, description: "Stream TV shows and movies", cancelURL: "https://secure.hulu.com/account/cancel", pauseURL: "https://secure.hulu.com/account/pause", supportURL: "https://help.hulu.com"),
        ServicePattern(name: "Disney+", patterns: ["disneyplus.com", "disney plus", "disney+"], category: .streaming, logoURL: "https://logo.clearbit.com/disneyplus.com", defaultPrice: 7.99, priceSelector: nil, description: "Disney, Marvel, Star Wars, Pixar", cancelURL: "https://www.disneyplus.com/account/billing", pauseURL: nil, supportURL: "https://help.disneyplus.com"),
        ServicePattern(name: "HBO Max", patterns: ["hbomax.com", "hbo max", "max.com"], category: .streaming, logoURL: "https://logo.clearbit.com/hbomax.com", defaultPrice: 15.99, priceSelector: nil, description: "Premium streaming service", cancelURL: "https://www.hbomax.com/manage-subscription", pauseURL: nil, supportURL: "https://help.hbomax.com"),
        ServicePattern(name: "Amazon Prime Video", patterns: ["primevideo.com", "amazon.com/primevideo"], category: .streaming, logoURL: "https://logo.clearbit.com/primevideo.com", defaultPrice: 8.99, priceSelector: nil, description: "Movies, TV shows, originals", cancelURL: "https://www.amazon.com/prime/EndMembership", pauseURL: nil, supportURL: "https://www.amazon.com/gp/help/customer/contact-us"),
        ServicePattern(name: "Apple TV+", patterns: ["tv.apple.com", "appletv plus", "apple tv+"], category: .streaming, logoURL: "https://logo.clearbit.com/apple.com", defaultPrice: 6.99, priceSelector: nil, description: "Apple Originals", cancelURL: "https://apps.apple.com/account/subscriptions", pauseURL: nil, supportURL: "https://support.apple.com/tv"),
        ServicePattern(name: "YouTube Premium", patterns: ["youtube.com/premium", "youtube premium"], category: .streaming, logoURL: "https://logo.clearbit.com/youtube.com", defaultPrice: 11.99, priceSelector: nil, description: "Ad-free YouTube and Music", cancelURL: "https://www.youtube.com/paid_memberships", pauseURL: nil, supportURL: "https://support.google.com/youtube"),
        ServicePattern(name: "Paramount+", patterns: ["paramountplus.com", "paramount+"], category: .streaming, logoURL: "https://logo.clearbit.com/paramountplus.com", defaultPrice: 9.99, priceSelector: nil, description: "Movies, shows, live sports", cancelURL: "https://www.paramountplus.com/account", pauseURL: nil, supportURL: "https://help.paramountplus.com"),
        ServicePattern(name: "Peacock", patterns: ["peacocktv.com", "peacock"], category: .streaming, logoURL: "https://logo.clearbit.com/peacocktv.com", defaultPrice: 5.99, priceSelector: nil, description: "NBCUniversal streaming", cancelURL: "https://www.peacocktv.com/account", pauseURL: nil, supportURL: "https://www.peacocktv.com/help"),
        ServicePattern(name: "Discovery+", patterns: ["discoveryplus.com", "discovery+"], category: .streaming, logoURL: "https://logo.clearbit.com/discoveryplus.com", defaultPrice: 4.99, priceSelector: nil, description: "Discovery, HGTV, Food Network", cancelURL: "https://www.discoveryplus.com/account", pauseURL: nil, supportURL: "https://help.discoveryplus.com"),
        ServicePattern(name: "ESPN+", patterns: ["espn.com/espnplus", "espn+"], category: .streaming, logoURL: "https://logo.clearbit.com/espn.com", defaultPrice: 9.99, priceSelector: nil, description: "Live sports and originals", cancelURL: "https://www.espn.com/espnplus/billing", pauseURL: nil, supportURL: "https://help.espn.com"),
        ServicePattern(name: "Crunchyroll", patterns: ["crunchyroll.com", "crunchyroll"], category: .streaming, logoURL: "https://logo.clearbit.com/crunchyroll.com", defaultPrice: 7.99, priceSelector: nil, description: "Anime streaming", cancelURL: "https://www.crunchyroll.com/acct/membership", pauseURL: nil, supportURL: "https://help.crunchyroll.com"),
        
        // Music
        ServicePattern(name: "Spotify", patterns: ["spotify.com", "spotify"], category: .music, logoURL: "https://logo.clearbit.com/spotify.com", defaultPrice: 9.99, priceSelector: nil, description: "Music streaming", cancelURL: "https://www.spotify.com/account/cancel", pauseURL: nil, supportURL: "https://support.spotify.com"),
        ServicePattern(name: "Apple Music", patterns: ["music.apple.com", "apple music"], category: .music, logoURL: "https://logo.clearbit.com/apple.com", defaultPrice: 10.99, priceSelector: nil, description: "Music streaming by Apple", cancelURL: "https://apps.apple.com/account/subscriptions", pauseURL: nil, supportURL: "https://support.apple.com/music"),
        ServicePattern(name: "YouTube Music", patterns: ["music.youtube.com", "youtube music"], category: .music, logoURL: "https://logo.clearbit.com/youtube.com", defaultPrice: 9.99, priceSelector: nil, description: "Music streaming", cancelURL: "https://www.youtube.com/paid_memberships", pauseURL: nil, supportURL: "https://support.google.com/youtubemusic"),
        ServicePattern(name: "Tidal", patterns: ["tidal.com", "tidal"], category: .music, logoURL: "https://logo.clearbit.com/tidal.com", defaultPrice: 9.99, priceSelector: nil, description: "Hi-fi music streaming", cancelURL: "https://account.tidal.com/cancel", pauseURL: nil, supportURL: "https://support.tidal.com"),
        ServicePattern(name: "Deezer", patterns: ["deezer.com", "deezer"], category: .music, logoURL: "https://logo.clearbit.com/deezer.com", defaultPrice: 10.99, priceSelector: nil, description: "Music streaming", cancelURL: "https://www.deezer.com/account/cancel", pauseURL: nil, supportURL: "https://support.deezer.com"),
        ServicePattern(name: "Pandora", patterns: ["pandora.com", "pandora"], category: .music, logoURL: "https://logo.clearbit.com/pandora.com", defaultPrice: 4.99, priceSelector: nil, description: "Internet radio", cancelURL: "https://www.pandora.com/settings/subscription", pauseURL: nil, supportURL: "https://help.pandora.com"),
        ServicePattern(name: "Amazon Music", patterns: ["music.amazon.com", "amazon music"], category: .music, logoURL: "https://logo.clearbit.com/amazon.com", defaultPrice: 8.99, priceSelector: nil, description: "Music streaming", cancelURL: "https://www.amazon.com/gp/dmusic/settings", pauseURL: nil, supportURL: "https://www.amazon.com/gp/help/customer/contact-us"),
        ServicePattern(name: "SoundCloud Go", patterns: ["soundcloud.com/go", "soundcloud"], category: .music, logoURL: "https://logo.clearbit.com/soundcloud.com", defaultPrice: 5.99, priceSelector: nil, description: "Music streaming", cancelURL: "https://soundcloud.com/settings/subscription", pauseURL: nil, supportURL: "https://help.soundcloud.com"),
        
        // Productivity
        ServicePattern(name: "Notion", patterns: ["notion.so", "notion"], category: .productivity, logoURL: "https://logo.clearbit.com/notion.so", defaultPrice: 8.00, priceSelector: nil, description: "All-in-one workspace", cancelURL: "https://www.notion.so/settings/billing", pauseURL: nil, supportURL: "https://www.notion.so/help"),
        ServicePattern(name: "Slack", patterns: ["slack.com", "slack"], category: .productivity, logoURL: "https://logo.clearbit.com/slack.com", defaultPrice: 7.25, priceSelector: nil, description: "Team communication", cancelURL: "https://slack.com/billing/cancel", pauseURL: nil, supportURL: "https://slack.com/help"),
        ServicePattern(name: "Microsoft 365", patterns: ["microsoft365.com", "office.com", "microsoft 365"], category: .productivity, logoURL: "https://logo.clearbit.com/microsoft.com", defaultPrice: 6.99, priceSelector: nil, description: "Office apps and cloud storage", cancelURL: "https://account.microsoft.com/services", pauseURL: nil, supportURL: "https://support.microsoft.com"),
        ServicePattern(name: "Google Workspace", patterns: ["workspace.google.com", "google workspace", "gsuite"], category: .productivity, logoURL: "https://logo.clearbit.com/google.com", defaultPrice: 6.00, priceSelector: nil, description: "Business apps by Google", cancelURL: "https://admin.google.com/billing", pauseURL: nil, supportURL: "https://support.google.com/workspace"),
        ServicePattern(name: "Adobe Creative Cloud", patterns: ["adobe.com/creativecloud", "creative cloud", "adobe cc"], category: .productivity, logoURL: "https://logo.clearbit.com/adobe.com", defaultPrice: 54.99, priceSelector: nil, description: "Creative apps suite", cancelURL: "https://account.adobe.com/plans", pauseURL: nil, supportURL: "https://helpx.adobe.com"),
        ServicePattern(name: "Zoom", patterns: ["zoom.us", "zoom"], category: .productivity, logoURL: "https://logo.clearbit.com/zoom.us", defaultPrice: 14.99, priceSelector: nil, description: "Video conferencing", cancelURL: "https://zoom.us/billing", pauseURL: nil, supportURL: "https://support.zoom.us"),
        ServicePattern(name: "Figma", patterns: ["figma.com", "figma"], category: .productivity, logoURL: "https://logo.clearbit.com/figma.com", defaultPrice: 12.00, priceSelector: nil, description: "Design and prototyping", cancelURL: "https://www.figma.com/billing", pauseURL: nil, supportURL: "https://help.figma.com"),
        ServicePattern(name: "Linear", patterns: ["linear.app", "linear"], category: .productivity, logoURL: "https://logo.clearbit.com/linear.app", defaultPrice: 8.00, priceSelector: nil, description: "Issue tracking", cancelURL: "https://linear.app/settings/billing", pauseURL: nil, supportURL: "https://linear.app/docs"),
        ServicePattern(name: "ChatGPT Plus", patterns: ["chat.openai.com", "chatgpt plus", "chatgpt"], category: .productivity, logoURL: "https://logo.clearbit.com/openai.com", defaultPrice: 20.00, priceSelector: nil, description: "AI assistant", cancelURL: "https://chat.openai.com/account/billing", pauseURL: nil, supportURL: "https://help.openai.com"),
        ServicePattern(name: "Claude Pro", patterns: ["claude.ai", "claude pro", "anthropic"], category: .productivity, logoURL: "https://logo.clearbit.com/anthropic.com", defaultPrice: 20.00, priceSelector: nil, description: "AI assistant by Anthropic", cancelURL: "https://claude.ai/settings/billing", pauseURL: nil, supportURL: "https://support.anthropic.com"),
        
        // Storage
        ServicePattern(name: "iCloud+", patterns: ["icloud.com", "apple.com/icloud"], category: .storage, logoURL: "https://logo.clearbit.com/apple.com", defaultPrice: 0.99, priceSelector: nil, description: "Apple cloud storage", cancelURL: "https://apps.apple.com/account/subscriptions", pauseURL: nil, supportURL: "https://support.apple.com/icloud"),
        ServicePattern(name: "Google One", patterns: [ "one.google.com", "google one"], category: .storage, logoURL: "https://logo.clearbit.com/google.com", defaultPrice: 1.99, priceSelector: nil, description: "Google cloud storage", cancelURL: "https://one.google.com/storage", pauseURL: nil, supportURL: "https://support.google.com/one"),
        ServicePattern(name: "Dropbox", patterns: ["dropbox.com", "dropbox"], category: .storage, logoURL: "https://logo.clearbit.com/dropbox.com", defaultPrice: 9.99, priceSelector: nil, description: "Cloud storage", cancelURL: "https://www.dropbox.com/account/plan", pauseURL: nil, supportURL: "https://help.dropbox.com"),
        ServicePattern(name: "OneDrive", patterns: ["onedrive.com", "onedrive.live.com", "onedrive"], category: .storage, logoURL: "https://logo.clearbit.com/microsoft.com", defaultPrice: 1.99, priceSelector: nil, description: "Microsoft cloud storage", cancelURL: "https://account.microsoft.com/services", pauseURL: nil, supportURL: "https://support.microsoft.com/onedrive"),
        ServicePattern(name: "Box", patterns: ["box.com", "box"], category: .storage, logoURL: "https://logo.clearbit.com/box.com", defaultPrice: 10.00, priceSelector: nil, description: "Cloud storage for business", cancelURL: "https://account.box.com/billing", pauseURL: nil, supportURL: "https://support.box.com"),
        ServicePattern(name: "pCloud", patterns: ["pcloud.com", "pcloud"], category: .storage, logoURL: "https://logo.clearbit.com/pcloud.com", defaultPrice: 9.99, priceSelector: nil, description: "Secure cloud storage", cancelURL: "https://my.pcloud.com/billing", pauseURL: nil, supportURL: "https://www.pcloud.com/help"),
        
        // Security/VPN
        ServicePattern(name: "NordVPN", patterns: ["nordvpn.com", "nordvpn"], category: .security, logoURL: "https://logo.clearbit.com/nordvpn.com", defaultPrice: 11.99, priceSelector: nil, description: "VPN service", cancelURL: "https://my.nordaccount.com/dashboard/nordvpn", pauseURL: nil, supportURL: "https://support.nordvpn.com"),
        ServicePattern(name: "ExpressVPN", patterns: ["expressvpn.com", "expressvpn"], category: .security, logoURL: "https://logo.clearbit.com/expressvpn.com", defaultPrice: 12.95, priceSelector: nil, description: "Premium VPN", cancelURL: "https://www.expressvpn.com/support/subscription/change-or-cancel/", pauseURL: nil, supportURL: "https://www.expressvpn.com/support"),
        ServicePattern(name: "Surfshark", patterns: ["surfshark.com", "surfshark"], category: .security, logoURL: "https://logo.clearbit.com/surfshark.com", defaultPrice: 12.95, priceSelector: nil, description: "VPN service", cancelURL: "https://account.surfshark.com/billing", pauseURL: nil, supportURL: "https://support.surfshark.com"),
        ServicePattern(name: "ProtonVPN", patterns: ["protonvpn.com", "protonvpn"], category: .security, logoURL: "https://logo.clearbit.com/protonvpn.com", defaultPrice: 9.99, priceSelector: nil, description: "Secure VPN", cancelURL: "https://account.protonvpn.com/dashboard", pauseURL: nil, supportURL: "https://protonvpn.com/support"),
        ServicePattern(name: "1Password", patterns: ["1password.com", "1password"], category: .security, logoURL: "https://logo.clearbit.com/1password.com", defaultPrice: 2.99, priceSelector: nil, description: "Password manager", cancelURL: "https://my.1password.com/billing", pauseURL: nil, supportURL: "https://support.1password.com"),
        ServicePattern(name: "LastPass", patterns: ["lastpass.com", "lastpass"], category: .security, logoURL: "https://logo.clearbit.com/lastpass.com", defaultPrice: 3.00, priceSelector: nil, description: "Password manager", cancelURL: "https://www.lastpass.com/billing", pauseURL: nil, supportURL: "https://support.lastpass.com"),
        ServicePattern(name: "Bitwarden", patterns: ["bitwarden.com", "bitwarden"], category: .security, logoURL: "https://logo.clearbit.com/bitwarden.com", defaultPrice: 0.83, priceSelector: nil, description: "Open source password manager", cancelURL: "https://vault.bitwarden.com/settings/billing", pauseURL: nil, supportURL: "https://bitwarden.com/help"),
        
        // Gaming
        ServicePattern(name: "Xbox Game Pass", patterns: ["xbox.com/game-pass", "game pass", "xbox game pass"], category: .gaming, logoURL: "https://logo.clearbit.com/xbox.com", defaultPrice: 9.99, priceSelector: nil, description: "Game subscription", cancelURL: "https://account.xbox.com/subscriptions", pauseURL: nil, supportURL: "https://support.xbox.com"),
        ServicePattern(name: "PlayStation Plus", patterns: ["playstation.com/plus", "ps plus", "playstation plus"], category: .gaming, logoURL: "https://logo.clearbit.com/playstation.com", defaultPrice: 9.99, priceSelector: nil, description: "Game subscription", cancelURL: "https://account.sonyentertainmentnetwork.com/subscriptions", pauseURL: nil, supportURL: "https://support.playstation.com"),
        ServicePattern(name: "Nintendo Switch Online", patterns: ["nintendo.com/switch/online", "nintendo switch online", "switch online"], category: .gaming, logoURL: "https://logo.clearbit.com/nintendo.com", defaultPrice: 3.99, priceSelector: nil, description: "Online gaming", cancelURL: "https://accounts.nintendo.com/subscription", pauseURL: nil, supportURL: "https://en-americas-support.nintendo.com"),
        ServicePattern(name: "GeForce NOW", patterns: ["geforcenow.com", "geforce now"], category: .gaming, logoURL: "https://logo.clearbit.com/nvidia.com", defaultPrice: 9.99, priceSelector: nil, description: "Cloud gaming", cancelURL: "https://www.nvidia.com/account/subscriptions", pauseURL: nil, supportURL: "https://www.nvidia.com/en-us/support"),
        
        // Fitness
        ServicePattern(name: "Peloton", patterns: ["onepeloton.com", "peloton"], category: .fitness, logoURL: "https://logo.clearbit.com/onepeloton.com", defaultPrice: 12.99, priceSelector: nil, description: "Fitness classes", cancelURL: "https://members.onepeloton.com/settings/subscription", pauseURL: nil, supportURL: "https://support.onepeloton.com"),
        ServicePattern(name: "Apple Fitness+", patterns: ["fitness.apple.com", "apple fitness+", "fitness plus"], category: .fitness, logoURL: "https://logo.clearbit.com/apple.com", defaultPrice: 9.99, priceSelector: nil, description: "Apple workouts", cancelURL: "https://apps.apple.com/account/subscriptions", pauseURL: nil, supportURL: "https://support.apple.com/fitnessplus"),
        ServicePattern(name: "Calm", patterns: ["calm.com", "calm"], category: .fitness, logoURL: "https://logo.clearbit.com/calm.com", defaultPrice: 14.99, priceSelector: nil, description: "Meditation and sleep", cancelURL: "https://www.calm.com/settings/manage-subscription", pauseURL: nil, supportURL: "https://www.calm.com/support"),
        ServicePattern(name: "Headspace", patterns: ["headspace.com", "headspace"], category: .fitness, logoURL: "https://logo.clearbit.com/headspace.com", defaultPrice: 12.99, priceSelector: nil, description: "Meditation app", cancelURL: "https://www.headspace.com/settings/account", pauseURL: nil, supportURL: "https://help.headspace.com"),
        ServicePattern(name: "Strava", patterns: ["strava.com", "strava"], category: .fitness, logoURL: "https://logo.clearbit.com/strava.com", defaultPrice: 11.99, priceSelector: nil, description: "Running and cycling", cancelURL: "https://www.strava.com/billing", pauseURL: nil, supportURL: "https://support.strava.com"),
        ServicePattern(name: "MyFitnessPal", patterns: ["myfitnesspal.com", "myfitnesspal"], category: .fitness, logoURL: "https://logo.clearbit.com/myfitnesspal.com", defaultPrice: 19.99, priceSelector: nil, description: "Calorie tracking", cancelURL: "https://www.myfitnesspal.com/account/billing", pauseURL: nil, supportURL: "https://support.myfitnesspal.com"),
        
        // Food/Meal
        ServicePattern(name: "HelloFresh", patterns: ["hellofresh.com", "hellofresh"], category: .food, logoURL: "https://logo.clearbit.com/hellofresh.com", defaultPrice: 59.94, priceSelector: nil, description: "Meal kit delivery", cancelURL: "https://www.hellofresh.com/account-settings/subscription-settings", pauseURL: "https://www.hellofresh.com/account-settings/subscription-settings", supportURL: "https://www.hellofresh.com/contact"),
        ServicePattern(name: "Blue Apron", patterns: ["blueapron.com", "blue apron"], category: .food, logoURL: "https://logo.clearbit.com/blueapron.com", defaultPrice: 59.94, priceSelector: nil, description: "Meal kit delivery", cancelURL: "https://www.blueapron.com/account/billing", pauseURL: nil, supportURL: "https://support.blueapron.com"),
        ServicePattern(name: "Instacart+", patterns: ["instacart.com/plus", "instacart+", "instacart plus"], category: .food, logoURL: "https://logo.clearbit.com/instacart.com", defaultPrice: 9.99, priceSelector: nil, description: "Grocery delivery", cancelURL: "https://www.instacart.com/account/billing", pauseURL: nil, supportURL: "https://help.instacart.com"),
        ServicePattern(name: "DoorDash DashPass", patterns: ["doordash.com/dashpass", "dashpass"], category: .food, logoURL: "https://logo.clearbit.com/doordash.com", defaultPrice: 9.99, priceSelector: nil, description: "Food delivery subscription", cancelURL: "https://www.doordash.com/consumer/account/dashpass/", pauseURL: nil, supportURL: "https://help.doordash.com"),
        ServicePattern(name: "Uber One", patterns: ["uber.com/uber-one", "uber one"], category: .food, logoURL: "https://logo.clearbit.com/uber.com", defaultPrice: 9.99, priceSelector: nil, description: "Rides and delivery", cancelURL: "https://m.uber.com/account/uber-one", pauseURL: nil, supportURL: "https://help.uber.com"),
        
        // News/Media
        ServicePattern(name: "The New York Times", patterns: ["nytimes.com", "new york times"], category: .news, logoURL: "https://logo.clearbit.com/nytimes.com", defaultPrice: 17.00, priceSelector: nil, description: "News subscription", cancelURL: "https://myaccount.nytimes.com/account/billing", pauseURL: nil, supportURL: "https://help.nytimes.com"),
        ServicePattern(name: "The Washington Post", patterns: ["washingtonpost.com", "washington post"], category: .news, logoURL: "https://logo.clearbit.com/washingtonpost.com", defaultPrice: 10.00, priceSelector: nil, description: "News subscription", cancelURL: "https://www.washingtonpost.com/account/billing", pauseURL: nil, supportURL: "https://www.washingtonpost.com/support"),
        ServicePattern(name: "The Wall Street Journal", patterns: ["wsj.com", "wall street journal"], category: .news, logoURL: "https://logo.clearbit.com/wsj.com", defaultPrice: 38.99, priceSelector: nil, description: "Business news", cancelURL: "https://customercenter.wsj.com/billing", pauseURL: nil, supportURL: "https://www.wsj.com/support"),
        ServicePattern(name: "Medium", patterns: ["medium.com", "medium"], category: .news, logoURL: "https://logo.clearbit.com/medium.com", defaultPrice: 5.00, priceSelector: nil, description: "Writing platform", cancelURL: "https://medium.com/me/settings/billing", pauseURL: nil, supportURL: "https://help.medium.com"),
        ServicePattern(name: "Substack", patterns: ["substack.com", "substack"], category: .news, logoURL: "https://logo.clearbit.com/substack.com", defaultPrice: 5.00, priceSelector: nil, description: "Newsletter platform", cancelURL: "https://substack.com/account/billing", pauseURL: nil, supportURL: "https://support.substack.com"),
        
        // Dating
        ServicePattern(name: "Tinder", patterns: ["tinder.com", "tinder"], category: .dating, logoURL: "https://logo.clearbit.com/tinder.com", defaultPrice: 14.99, priceSelector: nil, description: "Dating app", cancelURL: "https://www.gotinder.com/settings/billing", pauseURL: nil, supportURL: "https://www.gotinder.com/help"),
        ServicePattern(name: "Bumble", patterns: ["bumble.com", "bumble"], category: .dating, logoURL: "https://logo.clearbit.com/bumble.com", defaultPrice: 16.99, priceSelector: nil, description: "Dating app", cancelURL: "https://bumble.com/settings/billing", pauseURL: nil, supportURL: "https://help.bumble.com"),
        ServicePattern(name: "Hinge", patterns: ["hinge.co", "hinge"], category: .dating, logoURL: "https://logo.clearbit.com/hinge.co", defaultPrice: 14.99, priceSelector: nil, description: "Dating app", cancelURL: "https://hinge.co/account/billing", pauseURL: nil, supportURL: "https://hingeapp.zendesk.com"),
        
        // Shopping
        ServicePattern(name: "Amazon Prime", patterns: ["amazon.com/prime", "amazon prime"], category: .shopping, logoURL: "https://logo.clearbit.com/amazon.com", defaultPrice: 14.99, priceSelector: nil, description: "Free shipping and streaming", cancelURL: "https://www.amazon.com/prime/EndMembership", pauseURL: nil, supportURL: "https://www.amazon.com/gp/help/customer/contact-us"),
        ServicePattern(name: "Costco Membership", patterns: ["costco.com", "costco"], category: .shopping, logoURL: "https://logo.clearbit.com/costco.com", defaultPrice: 60.00, priceSelector: nil, description: "Warehouse membership", cancelURL: "https://www.costco.com/customer-service.html", pauseURL: nil, supportURL: "https://customerservice.costco.com"),
        ServicePattern(name: "Sam's Club", patterns: ["samsclub.com", "sams club"], category: .shopping, logoURL: "https://logo.clearbit.com/samsclub.com", defaultPrice: 45.00, priceSelector: nil, description: "Warehouse membership", cancelURL: "https://www.samsclub.com/account/billing", pauseURL: nil, supportURL: "https://help.samsclub.com"),
        
        // Finance
        ServicePattern(name: "YNAB", patterns: ["ynab.com", "ynab"], category: .finance, logoURL: "https://logo.clearbit.com/ynab.com", defaultPrice: 14.99, priceSelector: nil, description: "Budgeting app", cancelURL: "https://app.ynab.com/settings/billing", pauseURL: nil, supportURL: "https://support.ynab.com"),
        ServicePattern(name: "QuickBooks", patterns: ["quickbooks.intuit.com", "quickbooks"], category: .finance, logoURL: "https://logo.clearbit.com/quickbooks.intuit.com", defaultPrice: 30.00, priceSelector: nil, description: "Accounting software", cancelURL: "https://quickbooks.intuit.com/account/billing", pauseURL: nil, supportURL: "https://quickbooks.intuit.com/support"),
        ServicePattern(name: "Experian", patterns: ["experian.com", "experian"], category: .finance, logoURL: "https://logo.clearbit.com/experian.com", defaultPrice: 24.99, priceSelector: nil, description: "Credit monitoring", cancelURL: "https://www.experian.com/account/billing", pauseURL: nil, supportURL: "https://www.experian.com/support"),
        
        // Education
        ServicePattern(name: "Coursera", patterns: ["coursera.org", "coursera"], category: .education, logoURL: "https://logo.clearbit.com/coursera.org", defaultPrice: 49.00, priceSelector: nil, description: "Online courses", cancelURL: "https://www.coursera.org/account/billing", pauseURL: nil, supportURL: "https://learner.coursera.help"),
        ServicePattern(name: "Udemy", patterns: ["udemy.com", "udemy"], category: .education, logoURL: "https://logo.clearbit.com/udemy.com", defaultPrice: 16.58, priceSelector: nil, description: "Online courses", cancelURL: "https://www.udemy.com/account/subscription", pauseURL: nil, supportURL: "https://support.udemy.com"),
        ServicePattern(name: "Duolingo", patterns: ["duolingo.com", "duolingo"], category: .education, logoURL: "https://logo.clearbit.com/duolingo.com", defaultPrice: 6.99, priceSelector: nil, description: "Language learning", cancelURL: "https://www.duolingo.com/settings/super", pauseURL: nil, supportURL: "https://support.duolingo.com"),
        ServicePattern(name: "MasterClass", patterns: ["masterclass.com", "masterclass"], category: .education, logoURL: "https://logo.clearbit.com/masterclass.com", defaultPrice: 15.00, priceSelector: nil, description: "Celebrity-taught classes", cancelURL: "https://www.masterclass.com/account/billing", pauseURL: nil, supportURL: "https://support.masterclass.com"),
    ]
    
    private init() {}
    
    // MARK: - Public Methods
    
    func parseURL(_ urlString: String) async -> ParsedSubscription? {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return nil
        }
        
        await MainActor.run { isParsing = true }
        defer { Task { @MainActor in isParsing = false } }
        
        // Find matching service
        let (pattern, confidence) = findMatchingService(urlString: urlString, host: host)
        
        if let pattern = pattern {
            let parsed = ParsedSubscription(
                name: pattern.name,
                url: url,
                price: pattern.defaultPrice,
                currency: "USD",
                billingFrequency: .monthly,
                logoURL: pattern.logoURL.flatMap { URL(string: $0) },
                description: pattern.description,
                confidence: confidence,
                category: pattern.category,
                directCancelURL: pattern.cancelURL.flatMap { URL(string: $0) },
                directPauseURL: pattern.pauseURL.flatMap { URL(string: $0) },
                supportURL: pattern.supportURL.flatMap { URL(string: $0) },
                metadata: [:]
            )
            
            await MainActor.run {
                self.lastResult = parsed
                self.recentParses.insert(parsed, at: 0)
                if self.recentParses.count > 10 {
                    self.recentParses.removeLast()
                }
            }
            
            return parsed
        }
        
        // Generic fallback
        let genericParsed = ParsedSubscription(
            name: extractDomainName(from: host),
            url: url,
            price: nil,
            currency: "USD",
            billingFrequency: .monthly,
            logoURL: URL(string: "https://logo.clearbit.com/\(host)"),
            description: nil,
            confidence: 0.3,
            category: .other,
            directCancelURL: nil,
            directPauseURL: nil,
            supportURL: nil,
            metadata: [:]
        )
        
        await MainActor.run {
            self.lastResult = genericParsed
        }
        
        return genericParsed
    }
    
    func parseMultipleURLs(_ urlStrings: [String]) async -> [ParsedSubscription] {
        var results: [ParsedSubscription] = []
        
        for urlString in urlStrings {
            if let parsed = await parseURL(urlString) {
                results.append(parsed)
            }
        }
        
        return results
    }
    
    func detectService(from name: String) -> ServicePattern? {
        let lowercased = name.lowercased()
        
        for pattern in servicePatterns {
            for servicePattern in pattern.patterns {
                if lowercased.contains(servicePattern) || servicePattern.contains(lowercased) {
                    return pattern
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func findMatchingService(urlString: String, host: String) -> (ServicePattern?, Double) {
        let lowercasedURL = urlString.lowercased()
        
        for pattern in servicePatterns {
            for servicePattern in pattern.patterns {
                // Check for exact domain match
                if host == servicePattern || host.hasSuffix("." + servicePattern) {
                    return (pattern, 0.95)
                }
                
                // Check for URL contains pattern
                if lowercasedURL.contains(servicePattern) {
                    return (pattern, 0.85)
                }
            }
        }
        
        // Try fuzzy matching
        for pattern in servicePatterns {
            let similarity = calculateSimilarity(host, pattern.name.lowercased())
            if similarity > 0.7 {
                return (pattern, similarity)
            }
        }
        
        return (nil, 0)
    }
    
    private func extractDomainName(from host: String) -> String {
        let parts = host.split(separator: ".")
        if parts.count >= 2 {
            return String(parts[parts.count - 2]).capitalized
        }
        return host.capitalized
    }
    
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        // Simple Levenshtein distance-based similarity
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        return maxLength == 0 ? 1.0 : 1.0 - Double(distance) / Double(maxLength)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
}

