import Foundation
import SwiftUI

enum AlternativeDatabase {
    
    static func getAlternatives(for category: ServiceCategory) -> [AlternativeService] {
        switch category {
        case .streaming:
            return streamingAlternatives
        case .music:
            return musicAlternatives
        case .productivity:
            return productivityAlternatives
        case .storage:
            return storageAlternatives
        case .security:
            return securityAlternatives
        case .gaming:
            return gamingAlternatives
        case .fitness:
            return fitnessAlternatives
        case .food:
            return foodAlternatives
        case .news:
            return newsAlternatives
        case .dating:
            return datingAlternatives
        default:
            return []
        }
    }
    
    // MARK: - Alternative Service Lists
    
    static let streamingAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Tubi",
            description: "Free ad-supported streaming with 20,000+ movies",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Free", "20,000+ movies", "Live TV"],
            pros: ["Completely free", "Good selection", "No account needed"],
            cons: ["Ads", "Not latest releases"],
            websiteURL: "https://tubitv.com",
            rating: 4.0,
            category: .streaming,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Pluto TV",
            description: "Free live TV and on-demand content",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["250+ channels", "Free", "No signup"],
            pros: ["Live TV free", "Easy to use", "Paramount content"],
            cons: ["Ads", "Limited on-demand"],
            websiteURL: "https://pluto.tv",
            rating: 3.8,
            category: .streaming,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Peacock",
            description: "NBCUniversal streaming with free tier",
            monthlyPrice: 5.99,
            annualPrice: 59.99,
            features: ["Free tier available", "Live sports", "NBC shows"],
            pros: ["Affordable", "Live sports", "Next-day NBC"],
            cons: ["Ads on lower tiers"],
            websiteURL: "https://peacocktv.com",
            rating: 4.1,
            category: .streaming,
            savingsPercentage: 40
        ),
        AlternativeService(
            name: "Disney+/Hulu Bundle",
            description: "Bundle with Disney+, Hulu, and ESPN+",
            monthlyPrice: 14.99,
            annualPrice: nil,
            features: ["3 services", "Family content", "Sports"],
            pros: ["Great value", "Diverse content", "One price"],
            cons: ["Hulu has ads"],
            websiteURL: "https://www.disneyplus.com/welcome/disney-hulu-espn-bundle",
            rating: 4.5,
            category: .streaming,
            savingsPercentage: 30
        )
    ]
    
    static let musicAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Spotify Free",
            description: "Ad-supported music streaming",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Shuffle play", "Playlists", "Podcasts"],
            pros: ["Free", "Huge library", "Great playlists"],
            cons: ["Ads", "Shuffle only on mobile", "Limited skips"],
            websiteURL: "https://spotify.com/free",
            rating: 4.0,
            category: .music,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Pandora",
            description: "Radio-style music streaming",
            monthlyPrice: 4.99,
            annualPrice: 54.89,
            features: ["Radio stations", "Thumb feedback", "Offline"],
            pros: ["Cheaper", "Great discovery", "Simple"],
            cons: ["Limited skips", "Lower audio quality"],
            websiteURL: "https://pandora.com",
            rating: 3.9,
            category: .music,
            savingsPercentage: 55
        ),
        AlternativeService(
            name: "YouTube Music",
            description: "Music streaming with YouTube content",
            monthlyPrice: 10.99,
            annualPrice: 99.99,
            features: ["YouTube content", "Music videos", "Lyrics"],
            pros: ["Rare tracks", "Live performances", "Ad-free YouTube"],
            cons: ["Interface issues"],
            websiteURL: "https://music.youtube.com",
            rating: 4.0,
            category: .music,
            savingsPercentage: 8
        ),
        AlternativeService(
            name: "SoundCloud",
            description: "Independent artist platform",
            monthlyPrice: 5.99,
            annualPrice: 71.88,
            features: ["Indie artists", "Uploads", "Remixes"],
            pros: ["Unique content", "Support artists", "Community"],
            cons: ["Quality varies", "Less mainstream"],
            websiteURL: "https://soundcloud.com",
            rating: 4.1,
            category: .music,
            savingsPercentage: 46
        )
    ]
    
    static let productivityAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Google Docs/Sheets",
            description: "Free productivity suite from Google",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Documents", "Spreadsheets", "Cloud storage"],
            pros: ["Free", "Collaboration", "Easy sharing"],
            cons: ["Internet required", "Privacy concerns"],
            websiteURL: "https://workspace.google.com",
            rating: 4.4,
            category: .productivity,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Notion Free",
            description: "Free plan for personal use",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Unlimited pages", "Blocks", "Templates"],
            pros: ["Free for personal", "Flexible", "All-in-one"],
            cons: ["Block limits on free", "Learning curve"],
            websiteURL: "https://notion.so",
            rating: 4.5,
            category: .productivity,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Obsidian",
            description: "Local-first markdown note-taking",
            monthlyPrice: 0,
            annualPrice: 50,
            features: ["Local storage", "Markdown", "Plugins"],
            pros: ["Own your data", "One-time payment", "Fast"],
            cons: ["Sync costs extra", "Learning curve"],
            websiteURL: "https://obsidian.md",
            rating: 4.7,
            category: .productivity,
            savingsPercentage: 60
        ),
        AlternativeService(
            name: "Zoho Workplace",
            description: "Affordable productivity suite",
            monthlyPrice: 3,
            annualPrice: 36,
            features: ["Office apps", "Email", "Storage"],
            pros: ["Very affordable", "Feature-rich", "Good support"],
            cons: ["Less popular", "Interface design"],
            websiteURL: "https://zoho.com/workplace",
            rating: 4.0,
            category: .productivity,
            savingsPercentage: 50
        )
    ]
    
    static let storageAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Google Drive Free",
            description: "15GB free storage",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["15GB free", "Google integration"],
            pros: ["15GB free", "Google integration", "Share easily"],
            cons: ["Privacy concerns", "Counts Gmail/Photos"],
            websiteURL: "https://drive.google.com",
            rating: 4.3,
            category: .storage,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "iCloud Free",
            description: "5GB free Apple storage",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["5GB free", "Apple integration"],
            pros: ["Works with Apple", "Private", "Seamless"],
            cons: ["Only 5GB free", "Apple-only"],
            websiteURL: "https://icloud.com",
            rating: 4.2,
            category: .storage,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "pCloud",
            description: "Lifetime cloud storage option",
            monthlyPrice: 0,
            annualPrice: 399,
            features: ["Lifetime plan", "Client-side encryption", "Media player"],
            pros: ["One-time payment", "Secure", "Swiss privacy"],
            cons: ["Expensive upfront", "Less integrated"],
            websiteURL: "https://pcloud.com",
            rating: 4.3,
            category: .storage,
            savingsPercentage: 65
        ),
        AlternativeService(
            name: "Mega",
            description: "Secure cloud with 20GB free",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["20GB free", "Encryption", "Secure"],
            pros: ["20GB free", "Strong security", "Generous"],
            cons: ["Slower speeds", "Limited support"],
            websiteURL: "https://mega.nz",
            rating: 4.1,
            category: .storage,
            savingsPercentage: 100
        )
    ]
    
    static let securityAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "ProtonVPN Free",
            description: "Free VPN from Swiss provider",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Free tier", "No logs", "Swiss privacy"],
            pros: ["Truly free", "No logs", "Secure"],
            cons: ["Fewer servers", "Slower speeds"],
            websiteURL: "https://protonvpn.com",
            rating: 4.2,
            category: .security,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Bitwarden Free",
            description: "Free password manager",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Unlimited passwords", "Sync", "Generator"],
            pros: ["Completely free", "Open source", "Secure"],
            cons: ["No emergency access free"],
            websiteURL: "https://bitwarden.com",
            rating: 4.6,
            category: .security,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Windscribe",
            description: "VPN with free tier",
            monthlyPrice: 0,
            annualPrice: 69,
            features: ["10GB free", "Build-a-plan", "R.O.B.E.R.T."],
            pros: ["10GB free", "Flexible", "Good features"],
            cons: ["Fewer locations free"],
            websiteURL: "https://windscribe.com",
            rating: 4.0,
            category: .security,
            savingsPercentage: 45
        ),
        AlternativeService(
            name: "Mullvad",
            description: "Privacy-focused VPN",
            monthlyPrice: 5.50,
            annualPrice: 66,
            features: ["Flat pricing", "No email needed", "Anonymous"],
            pros: ["One flat price", "Anonymous", "Fast"],
            cons: ["No mobile apps", "Basic"],
            websiteURL: "https://mullvad.net",
            rating: 4.5,
            category: .security,
            savingsPercentage: 55
        )
    ]
    
    static let gamingAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Epic Games Free",
            description: "Free weekly games",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Free games weekly", "Store", "Launcher"],
            pros: ["Free games", "Keep forever", "Good titles"],
            cons: ["No subscription benefits", "Limited library"],
            websiteURL: "https://epicgames.com",
            rating: 4.3,
            category: .gaming,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Prime Gaming",
            description: "Free with Amazon Prime",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Free games", "Twitch Prime", "Loot"],
            pros: ["Included with Prime", "Good value", "Twitch benefits"],
            cons: ["Need Prime", "Rotating selection"],
            websiteURL: "https://gaming.amazon.com",
            rating: 4.2,
            category: .gaming,
            savingsPercentage: 100
        )
    ]
    
    static let fitnessAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Nike Run Club",
            description: "Free running app",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["GPS tracking", "Coaching", "Challenges"],
            pros: ["Completely free", "Great coaching", "Community"],
            cons: ["Running focused", "Basic features"],
            websiteURL: "https://nike.com/nrc",
            rating: 4.4,
            category: .fitness,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Strava Free",
            description: "Free fitness tracking",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Activity tracking", "Social", "Segments"],
            pros: ["Free tier good", "Social features", "Multi-sport"],
            cons: ["Advanced features paid", "Limited analysis"],
            websiteURL: "https://strava.com",
            rating: 4.3,
            category: .fitness,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "YouTube Fitness",
            description: "Free workout videos",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Unlimited variety", "Free", "All levels"],
            pros: ["Completely free", "Huge variety", "No equipment needed"],
            cons: ["Ads", "No tracking", "Quality varies"],
            websiteURL: "https://youtube.com",
            rating: 4.0,
            category: .fitness,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Down Dog",
            description: "Yoga with free basic version",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Customizable", "Free tier", "Multiple styles"],
            pros: ["Good free tier", "Customizable", "Offline"],
            cons: ["Advanced features paid", "Yoga only"],
            websiteURL: "https://downdogapp.com",
            rating: 4.5,
            category: .fitness,
            savingsPercentage: 100
        )
    ]
    
    static let foodAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Grocery Delivery Apps",
            description: "Order groceries for pickup/delivery",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["No subscription", "Pay per order", "Store choice"],
            pros: ["No commitment", "Often cheaper", "More control"],
            cons: ["Delivery fees", "Plan meals yourself"],
            websiteURL: "https://instacart.com",
            rating: 4.0,
            category: .food,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Meal Planning Apps",
            description: "Apps like Mealime or PlateJoy",
            monthlyPrice: 4.99,
            annualPrice: 49.99,
            features: ["Meal plans", "Shopping lists", "Recipes"],
            pros: ["Cheaper than kits", "Learn to cook", "Flexible"],
            cons: ["Still need to shop", "Prep time"],
            websiteURL: "https://mealime.com",
            rating: 4.2,
            category: .food,
            savingsPercentage: 70
        ),
        AlternativeService(
            name: "Local CSA Box",
            description: "Community Supported Agriculture",
            monthlyPrice: 25,
            annualPrice: nil,
            features: ["Local produce", "Seasonal", "Support farmers"],
            pros: ["Fresh local food", "Often cheaper", "Community"],
            cons: ["Less variety control", "Seasonal"],
            websiteURL: "https://localharvest.org",
            rating: 4.3,
            category: .food,
            savingsPercentage: 50
        )
    ]
    
    static let newsAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Ground News",
            description: "News aggregator with bias comparison",
            monthlyPrice: 0,
            annualPrice: 29.99,
            features: ["Multiple sources", "Bias comparison", "Coverage"],
            pros: ["See all sides", "Comprehensive", "Bias aware"],
            cons: ["Not original content", "App can be busy"],
            websiteURL: "https://ground.news",
            rating: 4.3,
            category: .news,
            savingsPercentage: 70
        ),
        AlternativeService(
            name: "Flipboard",
            description: "Free news aggregator",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Personalized", "Free", "Magazine style"],
            pros: ["Completely free", "Beautiful UI", "Customizable"],
            cons: ["Aggregated content", "Algorithm-driven"],
            websiteURL: "https://flipboard.com",
            rating: 4.0,
            category: .news,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "RSS Readers",
            description: "Feedly, Inoreader, etc.",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Custom feeds", "No algorithm", "Free options"],
            pros: ["You control content", "No tracking", "Free tiers"],
            cons: ["Setup required", "No original content"],
            websiteURL: "https://feedly.com",
            rating: 4.2,
            category: .news,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Apple News Free",
            description: "Free tier of Apple News",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Curated news", "Free tier", "Apple integration"],
            pros: ["Free tier exists", "Clean UI", "Apple integration"],
            cons: ["Limited without Plus", "Apple only"],
            websiteURL: "https://apple.com/apple-news",
            rating: 3.8,
            category: .news,
            savingsPercentage: 100
        )
    ]
    
    static let datingAlternatives: [AlternativeService] = [
        AlternativeService(
            name: "Hinge",
            description: "Designed to be deleted",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Free tier good", "Detailed profiles", "Conversation starters"],
            pros: ["Good free version", "Quality over quantity", "Relationship-focused"],
            cons: ["Limited daily likes", "Some features paid"],
            websiteURL: "https://hinge.co",
            rating: 4.2,
            category: .dating,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Bumble Free",
            description: "Women-first dating app",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Free tier", "Women message first", "BFF mode"],
            pros: ["Good free tier", "Safety features", "Multiple modes"],
            cons: ["Time limits", "Premium for advanced"],
            websiteURL: "https://bumble.com",
            rating: 4.1,
            category: .dating,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "Coffee Meets Bagel",
            description: "Curated daily matches",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Daily matches", "Free beans", "Quality focus"],
            pros: ["Quality matches", "Less overwhelming", "Good free version"],
            cons: ["Limited daily matches", "Slow pace"],
            websiteURL: "https://coffeemeetsbagel.com",
            rating: 4.0,
            category: .dating,
            savingsPercentage: 100
        ),
        AlternativeService(
            name: "OkCupid Free",
            description: "Personality-based matching",
            monthlyPrice: 0,
            annualPrice: 0,
            features: ["Detailed profiles", "Matching questions", "Messaging"],
            pros: ["Robust free version", "Inclusive", "Good matching"],
            cons: ["Ads on free", "Some limits"],
            websiteURL: "https://okcupid.com",
            rating: 4.0,
            category: .dating,
            savingsPercentage: 100
        )
    ]
}

// MARK: - Helper Extensions

extension SubscriptionActionManager {
    
    /// Get quick action buttons for a subscription
    func getQuickActions(for subscription: Subscription) -> [QuickAction] {
        var actions: [QuickAction] = []
        
        // Cancel action
        actions.append(QuickAction(
            type: .cancel,
            title: "Cancel",
            icon: "xmark.circle.fill",
            url: generateCancelURL(for: subscription)
        ))
        
        // Pause action (if available)
        if canPause(subscription) {
            actions.append(QuickAction(
                type: .pause,
                title: "Pause",
                icon: "pause.circle.fill",
                url: generatePauseURL(for: subscription)
            ))
        }
        
        let contacts = getSupportContacts(for: subscription)
        
        // Phone action
        if let phone = contacts.first(where: { $0.type == .phone }) {
            actions.append(QuickAction(
                type: .call,
                title: "Call",
                icon: "phone.fill",
                url: URL(string: "tel:\(phone.value.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: ""))")
            ))
        }
        
        // Chat action
        if let chat = contacts.first(where: { $0.type == .chat }) {
            actions.append(QuickAction(
                type: .chat,
                title: "Chat",
                icon: "message.fill",
                url: URL(string: chat.value)
            ))
        }
        
        // Email action
        if let email = contacts.first(where: { $0.type == .email }) {
            actions.append(QuickAction(
                type: .email,
                title: "Email",
                icon: "envelope.fill",
                url: URL(string: "mailto:\(email.value)")
            ))
        }
        
        return actions
    }
}

/// Quick action button model
struct QuickAction: Identifiable {
    let id = UUID()
    let type: QuickActionType
    let title: String
    let icon: String
    let url: URL?
}

enum QuickActionType {
    case cancel
    case pause
    case call
    case chat
    case email
    case support
}


// MARK: - Additional Service Categories

extension ServiceDatabase {
    
    // MARK: - Education Services
    static let educationServices: [SubscriptionService] = [
        SubscriptionService(
            id: "coursera",
            name: "Coursera Plus",
            category: .education,
            domain: "coursera.org",
            cancelURL: "https://www.coursera.org/settings/subscriptions",
            pauseURL: nil,
            supportURL: "https://www.coursera.support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into coursera.org"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'Subscriptions'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.coursera.org/settings/subscriptions", isCritical: true)
            ],
            aliases: ["coursera"],
            averageMonthlyPrice: 59.00
        ),
        SubscriptionService(
            id: "udemy",
            name: "Udemy Personal Plan",
            category: .education,
            domain: "udemy.com",
            cancelURL: "https://www.udemy.com/dashboard/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.udemy.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into udemy.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'Subscriptions'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.udemy.com/dashboard/subscriptions", isCritical: true)
            ],
            aliases: ["udemy"],
            averageMonthlyPrice: 16.58
        ),
        SubscriptionService(
            id: "skillshare",
            name: "Skillshare",
            category: .education,
            domain: "skillshare.com",
            cancelURL: "https://www.skillshare.com/settings",
            pauseURL: nil,
            supportURL: "https://help.skillshare.com",
            contacts: [.email("support@skillshare.com", label: "Skillshare Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into skillshare.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Membership'", actionURL: "https://www.skillshare.com/settings", isCritical: true)
            ],
            aliases: ["skillshare premium"],
            averageMonthlyPrice: 13.99
        ),
        SubscriptionService(
            id: "masterclass",
            name: "MasterClass",
            category: .education,
            domain: "masterclass.com",
            cancelURL: "https://www.masterclass.com/account/settings",
            pauseURL: nil,
            supportURL: "https://www.masterclass.com/support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into masterclass.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Membership'", actionURL: "https://www.masterclass.com/account/settings", isCritical: true)
            ],
            aliases: ["master class"],
            averageMonthlyPrice: 15.00
        ),
        SubscriptionService(
            id: "duolingo",
            name: "Duolingo Super",
            category: .education,
            domain: "duolingo.com",
            cancelURL: "https://www.duolingo.com/settings",
            pauseURL: nil,
            supportURL: "https://support.duolingo.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App/Website", description: "Open Duolingo"),
                CancellationStep(order: 2, title: "Profile", description: "Tap Profile"),
                CancellationStep(order: 3, title: "Settings", description: "Tap Settings"),
                CancellationStep(order: 4, title: "Super", description: "Tap 'Super Duolingo'"),
                CancellationStep(order: 5, title: "Cancel", description: "Tap 'Cancel'", actionURL: "https://www.duolingo.com/settings", isCritical: true)
            ],
            aliases: ["duolingo plus", "super duolingo"],
            averageMonthlyPrice: 6.99
        ),
        SubscriptionService(
            id: "babbel",
            name: "Babbel",
            category: .education,
            domain: "babbel.com",
            cancelURL: "https://my.babbel.com/settings",
            pauseURL: nil,
            supportURL: "https://support.babbel.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into babbel.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://my.babbel.com/settings", isCritical: true)
            ],
            aliases: ["babbel language"],
            averageMonthlyPrice: 13.95
        ),
        SubscriptionService(
            id: "rosettastone",
            name: "Rosetta Stone",
            category: .education,
            domain: "rosettastone.com",
            cancelURL: "https://www.rosettastone.com/profile",
            pauseURL: nil,
            supportURL: "https://support.rosettastone.com",
            contacts: [.phone("1-800-280-8172", label: "Rosetta Stone Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into rosettastone.com"),
                CancellationStep(order: 2, title: "Profile", description: "Go to Profile"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.rosettastone.com/profile", isCritical: true)
            ],
            aliases: ["rosetta stone"],
            averageMonthlyPrice: 11.99
        ),
        SubscriptionService(
            id: "linkedinlearning",
            name: "LinkedIn Learning",
            category: .education,
            domain: "linkedin.com",
            cancelURL: "https://www.linkedin.com/settings/premium",
            pauseURL: nil,
            supportURL: "https://www.linkedin.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into linkedin.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings & Privacy"),
                CancellationStep(order: 3, title: "Premium", description: "Click 'Premium Subscription'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel subscription'", actionURL: "https://www.linkedin.com/settings/premium", isCritical: true)
            ],
            aliases: ["lynda", "linkedin premium"],
            averageMonthlyPrice: 29.99
        ),
        SubscriptionService(
            id: "brilliant",
            name: "Brilliant",
            category: .education,
            domain: "brilliant.org",
            cancelURL: "https://brilliant.org/profile",
            pauseURL: nil,
            supportURL: "https://brilliant.org/support",
            contacts: [.email("support@brilliant.org", label: "Brilliant Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into brilliant.org"),
                CancellationStep(order: 2, title: "Profile", description: "Go to Profile"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://brilliant.org/profile", isCritical: true)
            ],
            aliases: ["brilliant org"],
            averageMonthlyPrice: 24.99
        ),
        SubscriptionService(
            id: "datacamp",
            name: "DataCamp",
            category: .education,
            domain: "datacamp.com",
            cancelURL: "https://www.datacamp.com/account",
            pauseURL: nil,
            supportURL: "https://support.datacamp.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into datacamp.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.datacamp.com/account", isCritical: true)
            ],
            aliases: ["data camp"],
            averageMonthlyPrice: 12.42
        ),
        SubscriptionService(
            id: "pluralsight",
            name: "Pluralsight",
            category: .education,
            domain: "pluralsight.com",
            cancelURL: "https://www.pluralsight.com/account",
            pauseURL: nil,
            supportURL: "https://help.pluralsight.com",
            contacts: [.phone("1-801-784-9007", label: "Pluralsight Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into pluralsight.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.pluralsight.com/account", isCritical: true)
            ],
            aliases: ["plural sight"],
            averageMonthlyPrice: 29.00
        ),
        SubscriptionService(
            id: "khanacademy",
            name: "Khan Academy",
            category: .education,
            domain: "khanacademy.org",
            cancelURL: "https://www.khanacademy.org/settings",
            pauseURL: nil,
            supportURL: "https://support.khanacademy.org",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into khanacademy.org"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel' if applicable", actionURL: "https://www.khanacademy.org/settings", isCritical: true)
            ],
            aliases: ["khan academy"],
            averageMonthlyPrice: 0.00
        )
    ]
    
    // MARK: - Design Services
    static let designServices: [SubscriptionService] = [
        SubscriptionService(
            id: "canva",
            name: "Canva Pro",
            category: .design,
            domain: "canva.com",
            cancelURL: "https://www.canva.com/account/billing",
            pauseURL: nil,
            supportURL: "https://www.canva.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into canva.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing & Plans'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.canva.com/account/billing", isCritical: true)
            ],
            aliases: ["canva pro"],
            averageMonthlyPrice: 12.99
        ),
        SubscriptionService(
            id: "sketch",
            name: "Sketch",
            category: .design,
            domain: "sketch.com",
            cancelURL: "https://www.sketch.com/account/subscription",
            pauseURL: nil,
            supportURL: "https://www.sketch.com/support",
            contacts: [.email("support@sketch.com", label: "Sketch Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into sketch.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.sketch.com/account/subscription", isCritical: true)
            ],
            aliases: ["sketch app"],
            averageMonthlyPrice: 9.00
        ),
        SubscriptionService(
            id: "invision",
            name: "InVision",
            category: .design,
            domain: "invisionapp.com",
            cancelURL: "https://projects.invisionapp.com/account/subscription",
            pauseURL: nil,
            supportURL: "https://support.invisionapp.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into invisionapp.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://projects.invisionapp.com/account/subscription", isCritical: true)
            ],
            aliases: ["invision app", "invision studio"],
            averageMonthlyPrice: 7.95
        ),
        SubscriptionService(
            id: "adobespark",
            name: "Adobe Creative Cloud Express",
            category: .design,
            domain: "adobe.com",
            cancelURL: "https://account.adobe.com/plans",
            pauseURL: nil,
            supportURL: "https://helpx.adobe.com",
            contacts: [.phone("1-800-833-6687", label: "Adobe Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.adobe.com"),
                CancellationStep(order: 2, title: "Plans", description: "Click 'Manage plan'"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel your plan'", actionURL: "https://account.adobe.com/plans", isCritical: true)
            ],
            aliases: ["adobe spark", "adobe express"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "photopea",
            name: "Photopea Premium",
            category: .design,
            domain: "photopea.com",
            cancelURL: "https://www.photopea.com",
            pauseURL: nil,
            supportURL: "https://www.photopea.com/learn",
            contacts: [.email("support@photopea.com", label: "Photopea Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into photopea.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Premium'", actionURL: "https://www.photopea.com", isCritical: true)
            ],
            aliases: ["photopea"],
            averageMonthlyPrice: 5.00
        ),
        SubscriptionService(
            id: "removebg",
            name: "Remove.bg",
            category: .design,
            domain: "remove.bg",
            cancelURL: "https://www.remove.bg/subscriptions",
            pauseURL: nil,
            supportURL: "https://www.remove.bg/help",
            contacts: [.email("support@remove.bg", label: "Remove.bg Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into remove.bg"),
                CancellationStep(order: 2, title: "Subscriptions", description: "Go to Subscriptions"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.remove.bg/subscriptions", isCritical: true)
            ],
            aliases: ["remove bg", "remove background"],
            averageMonthlyPrice: 9.00
        ),
        SubscriptionService(
            id: "crello",
            name: "VistaCreate",
            category: .design,
            domain: "create.vista.com",
            cancelURL: "https://create.vista.com/account",
            pauseURL: nil,
            supportURL: "https://create.vista.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into create.vista.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://create.vista.com/account", isCritical: true)
            ],
            aliases: ["crello", "vista create"],
            averageMonthlyPrice: 10.00
        )
    ]
    
    // MARK: - Communication Services
    static let communicationServices: [SubscriptionService] = [
        SubscriptionService(
            id: "skype",
            name: "Skype",
            category: .communication,
            domain: "skype.com",
            cancelURL: "https://go.skype.com/account",
            pauseURL: nil,
            supportURL: "https://support.skype.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into skype.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://go.skype.com/account", isCritical: true)
            ],
            aliases: ["skype credit", "skype subscription"],
            averageMonthlyPrice: 2.99
        ),
        SubscriptionService(
            id: "whatsapp",
            name: "WhatsApp Business Premium",
            category: .communication,
            domain: "whatsapp.com",
            cancelURL: "https://business.whatsapp.com/account",
            pauseURL: nil,
            supportURL: "https://business.whatsapp.com/support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open WhatsApp Business"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Premium", description: "Tap 'Premium'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel'", actionURL: "https://business.whatsapp.com/account", isCritical: true)
            ],
            aliases: ["whatsapp business"],
            averageMonthlyPrice: 5.99
        ),
        SubscriptionService(
            id: "telegram",
            name: "Telegram Premium",
            category: .communication,
            domain: "telegram.org",
            cancelURL: "https://t.me/premiumbot",
            pauseURL: nil,
            supportURL: "https://telegram.org/faq",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Telegram"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Telegram Premium", description: "Tap 'Telegram Premium'"),
                CancellationStep(order: 4, title: "Cancel", description: "Cancel through App Store or Google Play", actionURL: "https://t.me/premiumbot", isCritical: true)
            ],
            aliases: ["telegram plus"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "signal",
            name: "Signal",
            category: .communication,
            domain: "signal.org",
            cancelURL: "https://signal.org",
            pauseURL: nil,
            supportURL: "https://support.signal.org",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Signal"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Donations", description: "Manage donations if applicable", actionURL: "https://signal.org", isCritical: true)
            ],
            aliases: ["signal messenger"],
            averageMonthlyPrice: 0.00
        ),
        SubscriptionService(
            id: "discord",
            name: "Discord Nitro",
            category: .communication,
            domain: "discord.com",
            cancelURL: "https://discord.com/settings/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.discord.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App/Web", description: "Open Discord"),
                CancellationStep(order: 2, title: "Settings", description: "Go to User Settings"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'Subscriptions'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://discord.com/settings/subscriptions", isCritical: true)
            ],
            aliases: ["discord nitro classic", "discord boost"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "teamspeak",
            name: "TeamSpeak",
            category: .communication,
            domain: "teamspeak.com",
            cancelURL: "https://myteamspeak.com",
            pauseURL: nil,
            supportURL: "https://support.teamspeak.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into myteamspeak.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://myteamspeak.com", isCritical: true)
            ],
            aliases: ["teamspeak server"],
            averageMonthlyPrice: 5.00
        ),
        SubscriptionService(
            id: "viber",
            name: "Viber",
            category: .communication,
            domain: "viber.com",
            cancelURL: "https://account.viber.com",
            pauseURL: nil,
            supportURL: "https://help.viber.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Viber"),
                CancellationStep(order: 2, title: "More", description: "Tap 'More' > 'Settings'"),
                CancellationStep(order: 3, title: "Account", description: "Tap 'Viber Out'"),
                CancellationStep(order: 4, title: "Cancel", description: "Manage/cancel subscription", actionURL: "https://account.viber.com", isCritical: true)
            ],
            aliases: ["viber out"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "line",
            name: "LINE Premium",
            category: .communication,
            domain: "line.me",
            cancelURL: "https://line.me/settings",
            pauseURL: nil,
            supportURL: "https://help.line.me",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open LINE"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Premium", description: "Tap 'Premium'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel'", actionURL: "https://line.me/settings", isCritical: true)
            ],
            aliases: ["line app"],
            averageMonthlyPrice: 2.99
        ),
        SubscriptionService(
            id: "wechat",
            name: "WeChat",
            category: .communication,
            domain: "wechat.com",
            cancelURL: "https://wechat.com",
            pauseURL: nil,
            supportURL: "https://help.wechat.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open WeChat"),
                CancellationStep(order: 2, title: "Me", description: "Tap 'Me' > 'Settings'"),
                CancellationStep(order: 3, title: "Cancel", description: "Manage subscriptions", actionURL: "https://wechat.com", isCritical: true)
            ],
            aliases: ["wechat pay", "weixin"],
            averageMonthlyPrice: 0.00
        )
    ]
    
    // MARK: - Cloud Computing Services
    static let cloudComputingServices: [SubscriptionService] = [
        SubscriptionService(
            id: "aws",
            name: "AWS",
            category: .cloudComputing,
            domain: "aws.amazon.com",
            cancelURL: "https://console.aws.amazon.com/billing/home",
            pauseURL: nil,
            supportURL: "https://aws.amazon.com/support",
            contacts: [.phone("1-206-266-4064", label: "AWS Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into AWS Console"),
                CancellationStep(order: 2, title: "Billing", description: "Go to Billing & Cost Management"),
                CancellationStep(order: 3, title: "Cancel", description: "Close account or cancel services", actionURL: "https://console.aws.amazon.com/billing/home", isCritical: true)
            ],
            aliases: ["amazon web services", "amazon aws"],
            averageMonthlyPrice: 50.00
        ),
        SubscriptionService(
            id: "googlecloud",
            name: "Google Cloud Platform",
            category: .cloudComputing,
            domain: "cloud.google.com",
            cancelURL: "https://console.cloud.google.com/billing",
            pauseURL: nil,
            supportURL: "https://cloud.google.com/support",
            contacts: [],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into Google Cloud Console"),
                CancellationStep(order: 2, title: "Billing", description: "Go to Billing"),
                CancellationStep(order: 3, title: "Cancel", description: "Close billing account", actionURL: "https://console.cloud.google.com/billing", isCritical: true)
            ],
            aliases: ["gcp", "google cloud"],
            averageMonthlyPrice: 40.00
        ),
        SubscriptionService(
            id: "azure",
            name: "Microsoft Azure",
            category: .cloudComputing,
            domain: "azure.microsoft.com",
            cancelURL: "https://portal.azure.com/#blade/Microsoft_Azure_Billing",
            pauseURL: nil,
            supportURL: "https://azure.microsoft.com/support",
            contacts: [.phone("1-800-867-1389", label: "Azure Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into Azure Portal"),
                CancellationStep(order: 2, title: "Cost Management", description: "Go to Cost Management + Billing"),
                CancellationStep(order: 3, title: "Cancel", description: "Cancel subscriptions", actionURL: "https://portal.azure.com/#blade/Microsoft_Azure_Billing", isCritical: true)
            ],
            aliases: ["microsoft azure", "azure cloud"],
            averageMonthlyPrice: 45.00
        ),
        SubscriptionService(
            id: "heroku",
            name: "Heroku",
            category: .cloudComputing,
            domain: "heroku.com",
            cancelURL: "https://dashboard.heroku.com/account/billing",
            pauseURL: nil,
            supportURL: "https://help.heroku.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into Heroku Dashboard"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://dashboard.heroku.com/account/billing", isCritical: true)
            ],
            aliases: ["heroku cloud"],
            averageMonthlyPrice: 7.00
        ),
        SubscriptionService(
            id: "netlify",
            name: "Netlify",
            category: .cloudComputing,
            domain: "netlify.com",
            cancelURL: "https://app.netlify.com/account/billing",
            pauseURL: nil,
            supportURL: "https://www.netlify.com/support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into Netlify"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://app.netlify.com/account/billing", isCritical: true)
            ],
            aliases: ["netlify hosting"],
            averageMonthlyPrice: 19.00
        ),
        SubscriptionService(
            id: "vercel",
            name: "Vercel",
            category: .cloudComputing,
            domain: "vercel.com",
            cancelURL: "https://vercel.com/dashboard/settings/billing",
            pauseURL: nil,
            supportURL: "https://vercel.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into Vercel"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings > Billing"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://vercel.com/dashboard/settings/billing", isCritical: true)
            ],
            aliases: ["vercel hosting"],
            averageMonthlyPrice: 20.00
        ),
        SubscriptionService(
            id: "digitalocean",
            name: "DigitalOcean",
            category: .cloudComputing,
            domain: "digitalocean.com",
            cancelURL: "https://cloud.digitalocean.com/account/billing",
            pauseURL: nil,
            supportURL: "https://www.digitalocean.com/support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into DigitalOcean"),
                CancellationStep(order: 2, title: "Billing", description: "Go to Billing"),
                CancellationStep(order: 3, title: "Cancel", description: "Delete droplets/cancel subscription", actionURL: "https://cloud.digitalocean.com/account/billing", isCritical: true)
            ],
            aliases: ["digital ocean"],
            averageMonthlyPrice: 6.00
        ),
        SubscriptionService(
            id: "linode",
            name: "Linode",
            category: .cloudComputing,
            domain: "linode.com",
            cancelURL: "https://cloud.linode.com/account/settings",
            pauseURL: nil,
            supportURL: "https://www.linode.com/support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into Linode Cloud Manager"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Delete Linodes/cancel", actionURL: "https://cloud.linode.com/account/settings", isCritical: true)
            ],
            aliases: ["akamai linode"],
            averageMonthlyPrice: 5.00
        )
    ]
}

// MARK: - Parsed Subscription Result
struct ParsedSubscription: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var price: Double?
    var currency: String = "USD"
    var billingFrequency: BillingFrequency = .monthly
    var logoURL: URL?
    var description: String?
    var confidence: Double
    var category: ServiceCategory
    var directCancelURL: URL?
    var directPauseURL: URL?
    var supportURL: URL?
    var metadata: [String: String]
    
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.8...1.0: return .high
        case 0.5..<0.8: return .medium
        default: return .low
        }
    }
    
    enum ConfidenceLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: Color {
            switch self {
            case .high: return .green
            case .medium: return .orange
            case .low: return .red
            }
        }
    }
}

// MARK: - Service Detection Pattern
