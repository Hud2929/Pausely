import Foundation
import SwiftUI
import Combine

// MARK: - Service Database

/// Comprehensive database of 200+ subscription services
enum ServiceDatabase {
    
    // MARK: - Streaming Services
    static let streamingServices: [SubscriptionService] = [
        SubscriptionService(
            id: "netflix",
            name: "Netflix",
            category: .streaming,
            domain: "netflix.com",
            cancelURL: "https://www.netflix.com/cancelplan",
            pauseURL: nil,
            supportURL: "https://help.netflix.com",
            contacts: [.phone("1-866-579-7172", label: "Netflix Support", hours: "24/7")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into your Netflix account on a web browser"),
                CancellationStep(order: 2, title: "Account Settings", description: "Click on your profile and select 'Account'"),
                CancellationStep(order: 3, title: "Cancel Membership", description: "Click 'Cancel Membership' under Membership & Billing", actionURL: "https://www.netflix.com/cancelplan", isCritical: true),
                CancellationStep(order: 4, title: "Confirm", description: "Click 'Finish Cancellation' to confirm")
            ],
            aliases: ["netflix", "netflix streaming", "netflix.com"],
            averageMonthlyPrice: 15.49
        ),
        SubscriptionService(
            id: "hulu",
            name: "Hulu",
            category: .streaming,
            domain: "hulu.com",
            cancelURL: "https://secure.hulu.com/account/cancel",
            pauseURL: "https://secure.hulu.com/account/pause",
            supportURL: "https://help.hulu.com",
            contacts: [
                .phone("1-888-265-6650", label: "Hulu Support", hours: "24/7"),
                .chat("https://help.hulu.com/s/chat", label: "Live Chat", hours: "24/7")
            ],
            canPause: true,
            pauseDurations: [.oneMonth, .twoMonths, .threeMonths],
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into your Hulu account"),
                CancellationStep(order: 2, title: "Account Page", description: "Go to your Account page"),
                CancellationStep(order: 3, title: "Cancel", description: "Select 'Cancel' under Your Subscription", actionURL: "https://secure.hulu.com/account/cancel", isCritical: true),
                CancellationStep(order: 4, title: "Continue", description: "Click 'Continue to Cancel'")
            ],
            aliases: ["hulu", "hulu plus", "hulu.com", "disney hulu"],
            averageMonthlyPrice: 7.99
        ),
        SubscriptionService(
            id: "disneyplus",
            name: "Disney+",
            category: .streaming,
            domain: "disneyplus.com",
            cancelURL: "https://www.disneyplus.com/account/billing",
            pauseURL: nil,
            supportURL: "https://help.disneyplus.com",
            contacts: [
                .phone("1-888-905-7888", label: "Disney+ Support", hours: "24/7"),
                .chat("https://help.disneyplus.com/csp", label: "Live Chat")
            ],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into Disney+"),
                CancellationStep(order: 2, title: "Profile", description: "Click on your profile icon"),
                CancellationStep(order: 3, title: "Account", description: "Select 'Account'"),
                CancellationStep(order: 4, title: "Billing", description: "Click on 'Billing History'", actionURL: "https://www.disneyplus.com/account/billing", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Select 'Cancel Subscription'")
            ],
            aliases: ["disney plus", "disney+", "disneyplus", "disney streaming"],
            averageMonthlyPrice: 7.99
        ),
        SubscriptionService(
            id: "hbomax",
            name: "HBO Max",
            category: .streaming,
            domain: "max.com",
            cancelURL: "https://max.com/manage-subscription",
            pauseURL: nil,
            supportURL: "https://help.max.com",
            contacts: [.phone("1-855-442-6629", label: "Max Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to max.com and sign in"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile icon"),
                CancellationStep(order: 3, title: "Settings", description: "Select 'Settings' or 'Subscription'"),
                CancellationStep(order: 4, title: "Manage", description: "Click 'Manage Subscription'", actionURL: "https://max.com/manage-subscription", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Select 'Cancel Subscription'")
            ],
            aliases: ["hbo max", "hbomax", "max", "hbo streaming", "warner max"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "appletvplus",
            name: "Apple TV+",
            category: .streaming,
            domain: "apple.com",
            cancelURL: "https://apps.apple.com/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.apple.com/tv",
            contacts: [.phone("1-800-275-2273", label: "Apple Support", hours: "9AM-9PM")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Settings", description: "On iPhone/iPad, go to Settings > [Your Name] > Subscriptions"),
                CancellationStep(order: 2, title: "Find Apple TV+", description: "Select Apple TV+ from the list"),
                CancellationStep(order: 3, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://apps.apple.com/account/subscriptions", isCritical: true),
                CancellationStep(order: 4, title: "Confirm", description: "Confirm the cancellation")
            ],
            aliases: ["apple tv", "appletv+", "apple tv plus", "tv plus"],
            averageMonthlyPrice: 6.99
        ),
        SubscriptionService(
            id: "amazonprimevideo",
            name: "Amazon Prime Video",
            category: .streaming,
            domain: "primevideo.com",
            cancelURL: "https://www.amazon.com/gp/video/settings",
            pauseURL: nil,
            supportURL: "https://www.amazon.com/gp/help/customer/contact-us",
            contacts: [
                .phone("1-888-280-4331", label: "Amazon Support", hours: "24/7"),
                .chat("https://www.amazon.com/gp/help/customer/contact-us", label: "Chat Support")
            ],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Go to Amazon", description: "Visit amazon.com and sign in"),
                CancellationStep(order: 2, title: "Account", description: "Go to 'Account & Lists' > 'Your Account'"),
                CancellationStep(order: 3, title: "Memberships", description: "Click 'Prime Membership' or 'Memberships & Subscriptions'"),
                CancellationStep(order: 4, title: "End Membership", description: "Click 'End Membership'", actionURL: "https://www.amazon.com/prime/EndMembership", isCritical: true)
            ],
            aliases: ["prime video", "amazon video", "primevideo"],
            averageMonthlyPrice: 8.99
        ),
        SubscriptionService(
            id: "paramountplus",
            name: "Paramount+",
            category: .streaming,
            domain: "paramountplus.com",
            cancelURL: "https://www.paramountplus.com/account/subscription/",
            pauseURL: nil,
            supportURL: "https://help.paramountplus.com",
            contacts: [.phone("1-888-274-5343", label: "Paramount+ Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into paramountplus.com"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile in the top right"),
                CancellationStep(order: 3, title: "Account", description: "Select 'Account'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel subscription'", actionURL: "https://www.paramountplus.com/account/subscription/", isCritical: true)
            ],
            aliases: ["paramount plus", "paramount+", "cbs all access"],
            averageMonthlyPrice: 5.99
        ),
        SubscriptionService(
            id: "peacock",
            name: "Peacock",
            category: .streaming,
            domain: "peacocktv.com",
            cancelURL: "https://www.peacocktv.com/account/plans",
            pauseURL: nil,
            supportURL: "https://www.peacocktv.com/help",
            contacts: [.phone("1-212-664-4444", label: "Peacock Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to peacocktv.com"),
                CancellationStep(order: 2, title: "Account", description: "Click on your profile and select Account"),
                CancellationStep(order: 3, title: "Plans", description: "Go to 'Plans & Payment'", actionURL: "https://www.peacocktv.com/account/plans", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Plan'")
            ],
            aliases: ["peacock tv", "peacocktv", "nbc peacock"],
            averageMonthlyPrice: 5.99
        ),
        SubscriptionService(
            id: "discoveryplus",
            name: "Discovery+",
            category: .streaming,
            domain: "discoveryplus.com",
            cancelURL: "https://www.discoveryplus.com/my-account",
            pauseURL: nil,
            supportURL: "https://help.discoveryplus.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to discoveryplus.com"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile icon"),
                CancellationStep(order: 3, title: "Account", description: "Select 'Account'"),
                CancellationStep(order: 4, title: "Manage", description: "Click 'Manage Your Account'", actionURL: "https://www.discoveryplus.com/my-account", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Select 'Cancel Subscription'")
            ],
            aliases: ["discovery plus", "discovery+", "discovery streaming"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "espnplus",
            name: "ESPN+",
            category: .streaming,
            domain: "plus.espn.com",
            cancelURL: "https://plus.espn.com/",
            pauseURL: nil,
            supportURL: "https://help.espnplus.com",
            contacts: [.phone("1-800-727-1800", label: "ESPN+ Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into plus.espn.com"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile"),
                CancellationStep(order: 3, title: "ESPN+ Subscriptions", description: "Go to ESPN+ Subscriptions"),
                CancellationStep(order: 4, title: "Manage", description: "Click 'Manage'", actionURL: "https://plus.espn.com/", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Select 'Cancel Subscription'")
            ],
            aliases: ["espn plus", "espn+", "espn streaming"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "crunchyroll",
            name: "Crunchyroll",
            category: .streaming,
            domain: "crunchyroll.com",
            cancelURL: "https://www.crunchyroll.com/nAnimePass",
            pauseURL: nil,
            supportURL: "https://help.crunchyroll.com",
            contacts: [.email("support@crunchyroll.com", label: "Support Email")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into crunchyroll.com"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile picture"),
                CancellationStep(order: 3, title: "Settings", description: "Go to 'Settings'"),
                CancellationStep(order: 4, title: "Premium", description: "Click 'Premium Membership'", actionURL: "https://www.crunchyroll.com/nAnimePass", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Select 'Cancel Recurring Payments'")
            ],
            aliases: ["crunchy roll", "crunchyroll premium"],
            averageMonthlyPrice: 7.99
        ),
        SubscriptionService(
            id: "funimation",
            name: "Funimation",
            category: .streaming,
            domain: "funimation.com",
            cancelURL: "https://www.funimation.com/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://help.funimation.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into funimation.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.funimation.com/account/subscriptions", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'")
            ],
            aliases: ["funimation now", "funimation premium"],
            averageMonthlyPrice: 5.99
        ),
        SubscriptionService(
            id: "youtubepremium",
            name: "YouTube Premium",
            category: .streaming,
            domain: "youtube.com",
            cancelURL: "https://www.youtube.com/paid_memberships",
            pauseURL: nil,
            supportURL: "https://support.google.com/youtube",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to youtube.com and sign in"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile picture"),
                CancellationStep(order: 3, title: "Purchases", description: "Click 'Purchases and Memberships'"),
                CancellationStep(order: 4, title: "Manage", description: "Click 'Manage Membership'", actionURL: "https://www.youtube.com/paid_memberships", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Select 'Deactivate' next to Premium")
            ],
            aliases: ["youtube red", "yt premium", "youtube music premium"],
            averageMonthlyPrice: 13.99
        ),
        SubscriptionService(
            id: "shudder",
            name: "Shudder",
            category: .streaming,
            domain: "shudder.com",
            cancelURL: "https://www.shudder.com/my-account",
            pauseURL: nil,
            supportURL: "https://help.shudder.com",
            contacts: [.email("support@shudder.com", label: "Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into shudder.com"),
                CancellationStep(order: 2, title: "My Account", description: "Click 'My Account'"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Membership'", actionURL: "https://www.shudder.com/my-account", isCritical: true)
            ],
            aliases: ["shudder tv", "shudder horror"],
            averageMonthlyPrice: 5.99
        ),
        SubscriptionService(
            id: "stars",
            name: "Starz",
            category: .streaming,
            domain: "starz.com",
            cancelURL: "https://www.starz.com/settings/subscription",
            pauseURL: nil,
            supportURL: "https://help.starz.com",
            contacts: [.phone("1-855-247-9177", label: "Starz Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into starz.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.starz.com/settings/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["starzplay", "starz app"],
            averageMonthlyPrice: 8.99
        ),
        SubscriptionService(
            id: "showtime",
            name: "Showtime",
            category: .streaming,
            domain: "showtime.com",
            cancelURL: "https://www.showtime.com/settings",
            pauseURL: nil,
            supportURL: "https://help.showtime.com",
            contacts: [.email("support@showtime.com", label: "Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into showtime.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Select Subscription Settings", actionURL: "https://www.showtime.com/settings", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Your Subscription'")
            ],
            aliases: ["showtime anytime", "showtime streaming"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "fubo",
            name: "FuboTV",
            category: .streaming,
            domain: "fubo.tv",
            cancelURL: "https://www.fubo.tv/account/subscriptions",
            pauseURL: "https://www.fubo.tv/account/subscriptions",
            supportURL: "https://support.fubo.tv",
            contacts: [
                .phone("1-844-238-2688", label: "FuboTV Support"),
                .chat("https://support.fubo.tv/hc/en-us/requests/new", label: "Support Chat")
            ],
            canPause: true,
            pauseDurations: [.oneWeek, .twoWeeks, .oneMonth, .twoMonths, .threeMonths],
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into fubo.tv"),
                CancellationStep(order: 2, title: "Account", description: "Click on My Account"),
                CancellationStep(order: 3, title: "Subscription", description: "Go to Subscription & Billing", actionURL: "https://www.fubo.tv/account/subscriptions", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["fubo tv", "fubo", "fubotv streaming"],
            averageMonthlyPrice: 74.99
        ),
        SubscriptionService(
            id: "slingtv",
            name: "Sling TV",
            category: .streaming,
            domain: "sling.com",
            cancelURL: "https://www.sling.com/account",
            pauseURL: nil,
            supportURL: "https://help.sling.com",
            contacts: [.phone("1-888-363-1777", label: "Sling TV Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into sling.com"),
                CancellationStep(order: 2, title: "My Account", description: "Click 'My Account'"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.sling.com/account", isCritical: true),
                CancellationStep(order: 4, title: "Confirm", description: "Follow prompts to confirm cancellation")
            ],
            aliases: ["sling", "sling television"],
            averageMonthlyPrice: 40.00
        ),
        SubscriptionService(
            id: "directvstream",
            name: "DirecTV Stream",
            category: .streaming,
            domain: "stream.directv.com",
            cancelURL: "https://stream.directv.com/accounts/manage",
            pauseURL: nil,
            supportURL: "https://www.directv.com/support/stream",
            contacts: [.phone("1-800-288-2020", label: "DirecTV Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into stream.directv.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Overview"),
                CancellationStep(order: 3, title: "Manage", description: "Click 'Manage My TV Package'", actionURL: "https://stream.directv.com/accounts/manage", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Select 'I want to cancel'")
            ],
            aliases: ["directv stream", "at&t tv", "att tv now"],
            averageMonthlyPrice: 69.99
        ),
        SubscriptionService(
            id: "philo",
            name: "Philo",
            category: .streaming,
            domain: "philo.com",
            cancelURL: "https://www.philo.com/account",
            pauseURL: nil,
            supportURL: "https://help.philo.com",
            contacts: [.phone("1-855-277-4456", label: "Philo Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into philo.com"),
                CancellationStep(order: 2, title: "Account", description: "Click the Account link"),
                CancellationStep(order: 3, title: "Cancel", description: "Scroll down and click 'Cancel my account'", actionURL: "https://www.philo.com/account", isCritical: true)
            ],
            aliases: ["philo tv", "philo streaming"],
            averageMonthlyPrice: 25.00
        ),
        SubscriptionService(
            id: "tubitv",
            name: "Tubi TV",
            category: .streaming,
            domain: "tubitv.com",
            cancelURL: "https://tubitv.com/account",
            pauseURL: nil,
            supportURL: "https://support.tubitv.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into tubitv.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Select 'Cancel Ad-Free' if applicable", actionURL: "https://tubitv.com/account", isCritical: true)
            ],
            aliases: ["tubi", "tubi free"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "plutotv",
            name: "Pluto TV",
            category: .streaming,
            domain: "pluto.tv",
            cancelURL: "https://pluto.tv/account",
            pauseURL: nil,
            supportURL: "https://support.pluto.tv",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into pluto.tv"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel' if applicable", actionURL: "https://pluto.tv/account", isCritical: true)
            ],
            aliases: ["pluto", "pluto tv free"],
            averageMonthlyPrice: 0.00
        ),
        SubscriptionService(
            id: "amcplus",
            name: "AMC+",
            category: .streaming,
            domain: "amcplus.com",
            cancelURL: "https://www.amcplus.com/account",
            pauseURL: nil,
            supportURL: "https://www.amcplus.com/support",
            contacts: [.phone("1-888-560-1538", label: "AMC+ Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into amcplus.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.amcplus.com/account", isCritical: true)
            ],
            aliases: ["amc plus", "amc streaming"],
            averageMonthlyPrice: 8.99
        ),
        SubscriptionService(
            id: "britbox",
            name: "BritBox",
            category: .streaming,
            domain: "britbox.com",
            cancelURL: "https://www.britbox.com/account",
            pauseURL: nil,
            supportURL: "https://support.britbox.com",
            contacts: [.email("support@britbox.com", label: "BritBox Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into britbox.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.britbox.com/account", isCritical: true)
            ],
            aliases: ["brit box", "britbox uk"],
            averageMonthlyPrice: 8.99
        ),
        SubscriptionService(
            id: "mubi",
            name: "Mubi",
            category: .streaming,
            domain: "mubi.com",
            cancelURL: "https://mubi.com/account/subscription",
            pauseURL: nil,
            supportURL: "https://help.mubi.com",
            contacts: [.email("support@mubi.com", label: "Mubi Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into mubi.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://mubi.com/account/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'")
            ],
            aliases: ["mubi film"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "criterion",
            name: "Criterion Channel",
            category: .streaming,
            domain: "criterionchannel.com",
            cancelURL: "https://www.criterionchannel.com/account",
            pauseURL: nil,
            supportURL: "https://www.criterionchannel.com/help",
            contacts: [.email("support@criterionchannel.com", label: "Criterion Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into criterionchannel.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.criterionchannel.com/account", isCritical: true)
            ],
            aliases: ["criterion", "criterion collection streaming"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "acorntv",
            name: "Acorn TV",
            category: .streaming,
            domain: "acorn.tv",
            cancelURL: "https://acorn.tv/account",
            pauseURL: nil,
            supportURL: "https://help.acorn.tv",
            contacts: [.email("help@acorn.tv", label: "Acorn TV Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into acorn.tv"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://acorn.tv/account", isCritical: true)
            ],
            aliases: ["acorn tv", "acorn"],
            averageMonthlyPrice: 6.99
        )
    ]
    
    // MARK: - Music Services
    static let musicServices: [SubscriptionService] = [
        SubscriptionService(
            id: "spotify",
            name: "Spotify",
            category: .music,
            domain: "spotify.com",
            cancelURL: "https://www.spotify.com/account/cancel",
            pauseURL: nil,
            supportURL: "https://support.spotify.com",
            contacts: [.chat("https://support.spotify.com/contact-spotify-support", label: "Spotify Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to spotify.com/account"),
                CancellationStep(order: 2, title: "Change Plan", description: "Click 'Change or Cancel'"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Premium'", actionURL: "https://www.spotify.com/account/cancel", isCritical: true),
                CancellationStep(order: 4, title: "Confirm", description: "Click 'Yes, Cancel'")
            ],
            aliases: ["spotify premium", "spotify plus"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "applemusic",
            name: "Apple Music",
            category: .music,
            domain: "apple.com",
            cancelURL: "https://apps.apple.com/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.apple.com/music",
            contacts: [.phone("1-800-275-2273", label: "Apple Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Settings", description: "On iPhone, go to Settings > [Your Name] > Subscriptions"),
                CancellationStep(order: 2, title: "Find Apple Music", description: "Tap Apple Music"),
                CancellationStep(order: 3, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://apps.apple.com/account/subscriptions", isCritical: true)
            ],
            aliases: ["apple music", "itunes music"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "youtubemusic",
            name: "YouTube Music",
            category: .music,
            domain: "music.youtube.com",
            cancelURL: "https://www.youtube.com/paid_memberships",
            pauseURL: nil,
            supportURL: "https://support.google.com/youtubemusic",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to music.youtube.com"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile picture"),
                CancellationStep(order: 3, title: "Paid Memberships", description: "Select 'Paid memberships'", actionURL: "https://www.youtube.com/paid_memberships", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Manage Membership' then 'Deactivate'")
            ],
            aliases: ["youtube music premium", "yt music"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "tidal",
            name: "Tidal",
            category: .music,
            domain: "tidal.com",
            cancelURL: "https://my.tidal.com/subscription",
            pauseURL: nil,
            supportURL: "https://support.tidal.com",
            contacts: [.email("support@tidal.com", label: "Tidal Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into my.tidal.com"),
                CancellationStep(order: 2, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://my.tidal.com/subscription", isCritical: true),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["tidal music", "tidal hifi"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "deezer",
            name: "Deezer",
            category: .music,
            domain: "deezer.com",
            cancelURL: "https://www.deezer.com/account/subscription",
            pauseURL: nil,
            supportURL: "https://support.deezer.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into deezer.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Manage", description: "Click 'Manage my subscription'", actionURL: "https://www.deezer.com/account/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Select 'Cancel my subscription'")
            ],
            aliases: ["deezer music", "deezer premium"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "pandora",
            name: "Pandora",
            category: .music,
            domain: "pandora.com",
            cancelURL: "https://www.pandora.com/settings/subscription",
            pauseURL: nil,
            supportURL: "https://help.pandora.com",
            contacts: [.email("support@pandora.com", label: "Pandora Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into pandora.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.pandora.com/settings/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["pandora radio", "pandora plus", "pandora premium"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "amazonmusic",
            name: "Amazon Music Unlimited",
            category: .music,
            domain: "music.amazon.com",
            cancelURL: "https://music.amazon.com/settings",
            pauseURL: nil,
            supportURL: "https://www.amazon.com/gp/help/customer/contact-us",
            contacts: [.phone("1-888-280-4331", label: "Amazon Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to music.amazon.com"),
                CancellationStep(order: 2, title: "Settings", description: "Click the Settings gear icon"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Amazon Music Unlimited Settings' then 'Cancel'", actionURL: "https://music.amazon.com/settings", isCritical: true)
            ],
            aliases: ["amazon music", "amazon music hd"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "soundcloudgo",
            name: "SoundCloud Go+",
            category: .music,
            domain: "soundcloud.com",
            cancelURL: "https://soundcloud.com/settings/subscription",
            pauseURL: nil,
            supportURL: "https://help.soundcloud.com",
            contacts: [.email("support@soundcloud.com", label: "SoundCloud Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into soundcloud.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://soundcloud.com/settings/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["soundcloud", "soundcloud pro"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "qobuz",
            name: "Qobuz",
            category: .music,
            domain: "qobuz.com",
            cancelURL: "https://www.qobuz.com/account/settings",
            pauseURL: nil,
            supportURL: "https://www.qobuz.com/help",
            contacts: [.email("support@qobuz.com", label: "Qobuz Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into qobuz.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.qobuz.com/account/settings", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["qobuz hifi", "qobuz studio"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "napster",
            name: "Napster",
            category: .music,
            domain: "napster.com",
            cancelURL: "https://app.napster.com/settings",
            pauseURL: nil,
            supportURL: "https://support.napster.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into napster.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Account", description: "Click 'Account Settings'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://app.napster.com/settings", isCritical: true)
            ],
            aliases: ["napster music"],
            averageMonthlyPrice: 9.99
        )
    ]
    
    // MARK: - Productivity Services
    static let productivityServices: [SubscriptionService] = [
        SubscriptionService(
            id: "notion",
            name: "Notion",
            category: .productivity,
            domain: "notion.so",
            cancelURL: "https://www.notion.so/settings/billing",
            pauseURL: nil,
            supportURL: "https://www.notion.so/help",
            contacts: [.email("support@makenotion.com", label: "Notion Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to notion.so and log in"),
                CancellationStep(order: 2, title: "Settings", description: "Click Settings & Members"),
                CancellationStep(order: 3, title: "Billing", description: "Click the Billing tab", actionURL: "https://www.notion.so/settings/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["notion.so", "notion workspace"],
            averageMonthlyPrice: 10.00
        ),
        SubscriptionService(
            id: "slack",
            name: "Slack",
            category: .productivity,
            domain: "slack.com",
            cancelURL: "https://my.slack.com/admin/billing",
            pauseURL: nil,
            supportURL: "https://slack.com/help",
            contacts: [.email("feedback@slack.com", label: "Slack Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into your Slack workspace as an owner/admin"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings & Administration > Workspace Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click the Billing tab", actionURL: "https://my.slack.com/admin/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Downgrade Workspace'")
            ],
            aliases: ["slack pro", "slack business"],
            averageMonthlyPrice: 7.25
        ),
        SubscriptionService(
            id: "zoom",
            name: "Zoom",
            category: .productivity,
            domain: "zoom.us",
            cancelURL: "https://zoom.us/billing",
            pauseURL: nil,
            supportURL: "https://support.zoom.us",
            contacts: [.phone("1-888-799-9666", label: "Zoom Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into zoom.us"),
                CancellationStep(order: 2, title: "Profile", description: "Click My Account in the sidebar"),
                CancellationStep(order: 3, title: "Billing", description: "Click Account Management > Billing", actionURL: "https://zoom.us/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription' under Current Plans")
            ],
            aliases: ["zoom pro", "zoom meetings"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "microsoft365",
            name: "Microsoft 365",
            category: .productivity,
            domain: "microsoft.com",
            cancelURL: "https://account.microsoft.com/services",
            pauseURL: nil,
            supportURL: "https://support.microsoft.com",
            contacts: [.phone("1-877-696-7786", label: "Microsoft Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to account.microsoft.com/services"),
                CancellationStep(order: 2, title: "Services", description: "Find your Microsoft 365 subscription"),
                CancellationStep(order: 3, title: "Manage", description: "Click 'Manage' or 'Cancel'", actionURL: "https://account.microsoft.com/services", isCritical: true),
                CancellationStep(order: 4, title: "Confirm", description: "Follow the cancellation prompts")
            ],
            aliases: ["office 365", "microsoft office", "ms 365", "o365"],
            averageMonthlyPrice: 6.99
        ),
        SubscriptionService(
            id: "googleworkspace",
            name: "Google Workspace",
            category: .productivity,
            domain: "workspace.google.com",
            cancelURL: "https://admin.google.com/AC_BillingAccounts",
            pauseURL: nil,
            supportURL: "https://support.google.com/a",
            contacts: [.phone("1-877-355-5787", label: "Google Workspace Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Admin Console", description: "Sign in to admin.google.com as admin"),
                CancellationStep(order: 2, title: "Billing", description: "Go to Billing"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'More' next to your subscription", actionURL: "https://admin.google.com/AC_BillingAccounts", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Select 'Cancel Subscription'")
            ],
            aliases: ["g suite", "google apps", "workspace"],
            averageMonthlyPrice: 6.00
        ),
        SubscriptionService(
            id: "adobecc",
            name: "Adobe Creative Cloud",
            category: .productivity,
            domain: "adobe.com",
            cancelURL: "https://account.adobe.com/plans",
            pauseURL: "https://account.adobe.com/plans",
            supportURL: "https://helpx.adobe.com",
            contacts: [
                .phone("1-800-833-6687", label: "Adobe Support"),
                .chat("https://helpx.adobe.com/contact.html", label: "Live Chat")
            ],
            canPause: true,
            pauseDurations: [.oneMonth, .twoMonths, .threeMonths],
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to account.adobe.com"),
                CancellationStep(order: 2, title: "Plans", description: "Click 'Manage plan' for your subscription", actionURL: "https://account.adobe.com/plans", isCritical: true),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel your plan'"),
                CancellationStep(order: 4, title: "Continue", description: "Continue through any retention offers"),
                CancellationStep(order: 5, title: "Confirm", description: "Select reason and confirm cancellation")
            ],
            aliases: ["adobe", "creative cloud", "adobe cc", "photoshop subscription"],
            averageMonthlyPrice: 54.99
        ),
        SubscriptionService(
            id: "figma",
            name: "Figma",
            category: .productivity,
            domain: "figma.com",
            cancelURL: "https://www.figma.com/admin/billing",
            pauseURL: nil,
            supportURL: "https://help.figma.com",
            contacts: [.email("support@figma.com", label: "Figma Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into figma.com as admin"),
                CancellationStep(order: 2, title: "Admin", description: "Go to Admin Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://www.figma.com/admin/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Plan'")
            ],
            aliases: ["figma pro", "figma professional"],
            averageMonthlyPrice: 12.00
        ),
        SubscriptionService(
            id: "linear",
            name: "Linear",
            category: .productivity,
            domain: "linear.app",
            cancelURL: "https://linear.app/settings/billing",
            pauseURL: nil,
            supportURL: "https://linear.app/docs",
            contacts: [.email("support@linear.app", label: "Linear Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into linear.app"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Workspace Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://linear.app/settings/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["linear.app", "linear issue tracking"],
            averageMonthlyPrice: 8.00
        ),
        SubscriptionService(
            id: "todoist",
            name: "Todoist",
            category: .productivity,
            domain: "todoist.com",
            cancelURL: "https://todoist.com/app/settings/subscription",
            pauseURL: nil,
            supportURL: "https://todoist.com/help",
            contacts: [.email("support@todoist.com", label: "Todoist Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into todoist.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://todoist.com/app/settings/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Plan'")
            ],
            aliases: ["todoist premium", "todoist pro"],
            averageMonthlyPrice: 4.00
        ),
        SubscriptionService(
            id: "evernote",
            name: "Evernote",
            category: .productivity,
            domain: "evernote.com",
            cancelURL: "https://www.evernote.com/Settings.action",
            pauseURL: nil,
            supportURL: "https://help.evernote.com",
            contacts: [],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into evernote.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://www.evernote.com/Settings.action", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["evernote premium", "evernote personal"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "monday",
            name: "Monday.com",
            category: .productivity,
            domain: "monday.com",
            cancelURL: "https://admin.monday.com/admin/billing",
            pauseURL: nil,
            supportURL: "https://support.monday.com",
            contacts: [.email("support@monday.com", label: "Monday.com Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into monday.com as admin"),
                CancellationStep(order: 2, title: "Admin", description: "Go to Admin"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://admin.monday.com/admin/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Account'")
            ],
            aliases: ["monday", "monday com"],
            averageMonthlyPrice: 8.00
        ),
        SubscriptionService(
            id: "asana",
            name: "Asana",
            category: .productivity,
            domain: "asana.com",
            cancelURL: "https://app.asana.com/admin/billing",
            pauseURL: nil,
            supportURL: "https://help.asana.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into asana.com as admin"),
                CancellationStep(order: 2, title: "Admin", description: "Click your profile > Admin"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://app.asana.com/admin/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Plan' or 'Cancel Subscription'")
            ],
            aliases: ["asana premium", "asana business"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "clickup",
            name: "ClickUp",
            category: .productivity,
            domain: "clickup.com",
            cancelURL: "https://app.clickup.com/settings/billing",
            pauseURL: nil,
            supportURL: "https://docs.clickup.com",
            contacts: [.email("support@clickup.com", label: "ClickUp Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into clickup.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://app.clickup.com/settings/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["click up", "clickup unlimited"],
            averageMonthlyPrice: 7.00
        ),
        SubscriptionService(
            id: "grammarly",
            name: "Grammarly",
            category: .productivity,
            domain: "grammarly.com",
            cancelURL: "https://account.grammarly.com/subscription",
            pauseURL: nil,
            supportURL: "https://support.grammarly.com",
            contacts: [.email("support@grammarly.com", label: "Grammarly Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.grammarly.com"),
                CancellationStep(order: 2, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://account.grammarly.com/subscription", isCritical: true),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["grammarly premium", "grammarly business"],
            averageMonthlyPrice: 12.00
        ),
        SubscriptionService(
            id: "chatgpt",
            name: "ChatGPT Plus",
            category: .productivity,
            domain: "chat.openai.com",
            cancelURL: "https://chat.openai.com/account/manage",
            pauseURL: nil,
            supportURL: "https://help.openai.com",
            contacts: [.email("support@openai.com", label: "OpenAI Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into chat.openai.com"),
                CancellationStep(order: 2, title: "Settings", description: "Click your profile > Settings"),
                CancellationStep(order: 3, title: "Manage", description: "Click 'Manage my subscription'", actionURL: "https://chat.openai.com/account/manage", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Plan'")
            ],
            aliases: ["openai", "chatgpt", "gpt plus", "openai plus"],
            averageMonthlyPrice: 20.00
        ),
        SubscriptionService(
            id: "claude",
            name: "Claude Pro",
            category: .productivity,
            domain: "claude.ai",
            cancelURL: "https://claude.ai/settings",
            pauseURL: nil,
            supportURL: "https://support.anthropic.com",
            contacts: [.email("support@anthropic.com", label: "Anthropic Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into claude.ai"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing' or 'Subscription'", actionURL: "https://claude.ai/settings", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["anthropic claude", "claude ai"],
            averageMonthlyPrice: 20.00
        ),
        SubscriptionService(
            id: "midjourney",
            name: "Midjourney",
            category: .productivity,
            domain: "midjourney.com",
            cancelURL: "https://www.midjourney.com/account/",
            pauseURL: nil,
            supportURL: "https://docs.midjourney.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into midjourney.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Manage Account"),
                CancellationStep(order: 3, title: "Plan", description: "Click your plan", actionURL: "https://www.midjourney.com/account/", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["midjourney ai", "mj subscription"],
            averageMonthlyPrice: 10.00
        ),
        SubscriptionService(
            id: "notionai",
            name: "Notion AI",
            category: .productivity,
            domain: "notion.so",
            cancelURL: "https://www.notion.so/settings/billing",
            pauseURL: nil,
            supportURL: "https://www.notion.so/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into notion.so"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://www.notion.so/settings/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel' next to Notion AI")
            ],
            aliases: ["notion ai addon"],
            averageMonthlyPrice: 10.00
        ),
        SubscriptionService(
            id: "perplexity",
            name: "Perplexity Pro",
            category: .productivity,
            domain: "perplexity.ai",
            cancelURL: "https://www.perplexity.ai/settings",
            pauseURL: nil,
            supportURL: "https://www.perplexity.ai/support",
            contacts: [.email("support@perplexity.ai", label: "Perplexity Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into perplexity.ai"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.perplexity.ai/settings", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'")
            ],
            aliases: ["perplexity ai"],
            averageMonthlyPrice: 20.00
        )
    ]
    
    // Combine all services
    static var allServices: [SubscriptionService] {
        streamingServices + musicServices + productivityServices
    }
}


// MARK: - Extended Service Database

extension ServiceDatabase {
    
    // MARK: - Storage Services
    static let storageServices: [SubscriptionService] = [
        SubscriptionService(
            id: "icloudplus",
            name: "iCloud+",
            category: .storage,
            domain: "apple.com",
            cancelURL: "https://apps.apple.com/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.apple.com/icloud",
            contacts: [.phone("1-800-275-2273", label: "Apple Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Settings", description: "On iPhone/iPad: Settings > [Your Name] > iCloud"),
                CancellationStep(order: 2, title: "Manage", description: "Tap 'Manage Storage' or 'Upgrade to iCloud+'"),
                CancellationStep(order: 3, title: "Downgrade", description: "Tap 'Downgrade Options'", actionURL: "https://apps.apple.com/account/subscriptions", isCritical: true),
                CancellationStep(order: 4, title: "Free", description: "Select the free 5GB plan")
            ],
            aliases: ["icloud", "apple icloud", "apple storage"],
            averageMonthlyPrice: 0.99
        ),
        SubscriptionService(
            id: "googleone",
            name: "Google One",
            category: .storage,
            domain: "one.google.com",
            cancelURL: "https://one.google.com/storage",
            pauseURL: nil,
            supportURL: "https://support.google.com/one",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to one.google.com"),
                CancellationStep(order: 2, title: "Settings", description: "Click the Settings gear"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel membership'", actionURL: "https://one.google.com/storage", isCritical: true)
            ],
            aliases: ["google drive storage", "google storage", "gdrive"],
            averageMonthlyPrice: 1.99
        ),
        SubscriptionService(
            id: "dropbox",
            name: "Dropbox",
            category: .storage,
            domain: "dropbox.com",
            cancelURL: "https://www.dropbox.com/account/plan",
            pauseURL: nil,
            supportURL: "https://help.dropbox.com",
            contacts: [],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into dropbox.com"),
                CancellationStep(order: 2, title: "Settings", description: "Click your avatar > Settings"),
                CancellationStep(order: 3, title: "Plan", description: "Go to the Plan tab"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel plan' or 'Cancel trial'", actionURL: "https://www.dropbox.com/account/plan", isCritical: true)
            ],
            aliases: ["dropbox plus", "dropbox pro", "dropbox business"],
            averageMonthlyPrice: 11.99
        ),
        SubscriptionService(
            id: "onedrive",
            name: "OneDrive",
            category: .storage,
            domain: "onedrive.live.com",
            cancelURL: "https://account.microsoft.com/services",
            pauseURL: nil,
            supportURL: "https://support.microsoft.com/onedrive",
            contacts: [.phone("1-877-696-7786", label: "Microsoft Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to account.microsoft.com/services"),
                CancellationStep(order: 2, title: "OneDrive", description: "Find your OneDrive subscription"),
                CancellationStep(order: 3, title: "Manage", description: "Click 'Manage' or 'Cancel'", actionURL: "https://account.microsoft.com/services", isCritical: true)
            ],
            aliases: ["microsoft onedrive", "onedrive storage"],
            averageMonthlyPrice: 1.99
        ),
        SubscriptionService(
            id: "box",
            name: "Box",
            category: .storage,
            domain: "box.com",
            cancelURL: "https://app.box.com/billing/cancel",
            pauseURL: nil,
            supportURL: "https://support.box.com",
            contacts: [.email("support@box.com", label: "Box Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into box.com as admin"),
                CancellationStep(order: 2, title: "Admin", description: "Go to Admin Console"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing & Upgrade'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://app.box.com/billing/cancel", isCritical: true)
            ],
            aliases: ["box cloud", "box storage"],
            averageMonthlyPrice: 10.00
        ),
        SubscriptionService(
            id: "pcloud",
            name: "pCloud",
            category: .storage,
            domain: "pcloud.com",
            cancelURL: "https://my.pcloud.com/billing",
            pauseURL: nil,
            supportURL: "https://www.pcloud.com/help",
            contacts: [.email("support@pcloud.com", label: "pCloud Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into my.pcloud.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Click 'Billing'", actionURL: "https://my.pcloud.com/billing", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["pcloud storage", "pcloud lifetime"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "sync",
            name: "Sync.com",
            category: .storage,
            domain: "sync.com",
            cancelURL: "https://www.sync.com/account/upgrade",
            pauseURL: nil,
            supportURL: "https://www.sync.com/help",
            contacts: [.email("support@sync.com", label: "Sync Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into sync.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Plan", description: "Click 'Upgrade' or 'Manage Plan'", actionURL: "https://www.sync.com/account/upgrade", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["sync storage", "sync com"],
            averageMonthlyPrice: 8.00
        ),
        SubscriptionService(
            id: "idrive",
            name: "IDrive",
            category: .storage,
            domain: "idrive.com",
            cancelURL: "https://www.idrive.com/account/subscription",
            pauseURL: nil,
            supportURL: "https://www.idrive.com/help",
            contacts: [.phone("1-855-815-8705", label: "IDrive Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into idrive.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.idrive.com/account/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Contact support to cancel or use auto-downgrade")
            ],
            aliases: ["idrive backup", "idrive cloud"],
            averageMonthlyPrice: 9.95
        ),
        SubscriptionService(
            id: "carbonite",
            name: "Carbonite",
            category: .storage,
            domain: "carbonite.com",
            cancelURL: "https://account.carbonite.com",
            pauseURL: nil,
            supportURL: "https://www.carbonite.com/support",
            contacts: [.phone("1-617-587-1100", label: "Carbonite Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.carbonite.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "You must call to cancel", actionURL: "tel:16175871100", isCritical: true)
            ],
            aliases: ["carbonite backup", "carbonite safe"],
            averageMonthlyPrice: 6.00
        )
    ]
    
    // MARK: - Security/VPN Services
    static let securityServices: [SubscriptionService] = [
        SubscriptionService(
            id: "nordvpn",
            name: "NordVPN",
            category: .security,
            domain: "nordvpn.com",
            cancelURL: "https://my.nordaccount.com/dashboard/nordvpn",
            pauseURL: nil,
            supportURL: "https://support.nordvpn.com",
            contacts: [.chat("https://nordvpn.com/contact-us", label: "Live Chat", hours: "24/7")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to my.nordaccount.com"),
                CancellationStep(order: 2, title: "Services", description: "Click 'NordVPN' under Services"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel automatic payments'", actionURL: "https://my.nordaccount.com/dashboard/nordvpn", isCritical: true),
                CancellationStep(order: 4, title: "Confirm", description: "Follow the prompts to confirm")
            ],
            aliases: ["nord vpn", "nord"],
            averageMonthlyPrice: 12.99
        ),
        SubscriptionService(
            id: "expressvpn",
            name: "ExpressVPN",
            category: .security,
            domain: "expressvpn.com",
            cancelURL: "https://www.expressvpn.com/support/subscription/change-or-cancel/",
            pauseURL: nil,
            supportURL: "https://www.expressvpn.com/support",
            contacts: [
                .phone("1-855-527-3721", label: "ExpressVPN Support", hours: "24/7"),
                .chat("https://www.expressvpn.com/support/?utm_source=contact&utm_medium=livechat", label: "Live Chat", hours: "24/7")
            ],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into expressvpn.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Edit", description: "Click 'Edit subscription settings'", actionURL: "https://www.expressvpn.com/support/subscription/change-or-cancel/", isCritical: true),
                CancellationStep(order: 4, title: "Turn Off", description: "Turn off 'Automatic renewal'")
            ],
            aliases: ["express vpn", "express"],
            averageMonthlyPrice: 12.95
        ),
        SubscriptionService(
            id: "surfshark",
            name: "Surfshark",
            category: .security,
            domain: "surfshark.com",
            cancelURL: "https://account.surfshark.com/dashboard",
            pauseURL: nil,
            supportURL: "https://support.surfshark.com",
            contacts: [.email("support@surfshark.com", label: "Surfshark Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.surfshark.com"),
                CancellationStep(order: 2, title: "Subscription", description: "Click on your subscription"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel subscription'", actionURL: "https://account.surfshark.com/dashboard", isCritical: true)
            ],
            aliases: ["surf shark", "surfshark vpn"],
            averageMonthlyPrice: 12.95
        ),
        SubscriptionService(
            id: "protonvpn",
            name: "Proton VPN",
            category: .security,
            domain: "protonvpn.com",
            cancelURL: "https://account.protonvpn.com/dashboard",
            pauseURL: nil,
            supportURL: "https://protonvpn.com/support",
            contacts: [.email("support@protonvpn.com", label: "Proton VPN Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.protonvpn.com"),
                CancellationStep(order: 2, title: "Subscription", description: "Go to Subscription"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel subscription'", actionURL: "https://account.protonvpn.com/dashboard", isCritical: true)
            ],
            aliases: ["proton vpn", "proton"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "cyberghost",
            name: "CyberGhost VPN",
            category: .security,
            domain: "cyberghostvpn.com",
            cancelURL: "https://my.cyberghostvpn.com/en_US/account",
            pauseURL: nil,
            supportURL: "https://support.cyberghostvpn.com",
            contacts: [.chat("https://support.cyberghostvpn.com/hc/en-us/requests/new", label: "Support Ticket")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into my.cyberghostvpn.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'My Subscriptions'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://my.cyberghostvpn.com/en_US/account", isCritical: true)
            ],
            aliases: ["cyberghost", "cyber ghost"],
            averageMonthlyPrice: 12.99
        ),
        SubscriptionService(
            id: "ipvanish",
            name: "IPVanish",
            category: .security,
            domain: "ipvanish.com",
            cancelURL: "https://account.ipvanish.com/dashboard.php",
            pauseURL: nil,
            supportURL: "https://support.ipvanish.com",
            contacts: [.phone("1-800-591-5241", label: "IPVanish Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.ipvanish.com"),
                CancellationStep(order: 2, title: "Subscription", description: "Go to Subscription"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://account.ipvanish.com/dashboard.php", isCritical: true)
            ],
            aliases: ["ip vanish"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "1password",
            name: "1Password",
            category: .security,
            domain: "1password.com",
            cancelURL: "https://my.1password.com/billing",
            pauseURL: nil,
            supportURL: "https://support.1password.com",
            contacts: [.email("support@1password.com", label: "1Password Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into my.1password.com as owner"),
                CancellationStep(order: 2, title: "Billing", description: "Go to Billing"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://my.1password.com/billing", isCritical: true)
            ],
            aliases: ["1password", "one password"],
            averageMonthlyPrice: 2.99
        ),
        SubscriptionService(
            id: "lastpass",
            name: "LastPass",
            category: .security,
            domain: "lastpass.com",
            cancelURL: "https://lastpass.com/my.php",
            pauseURL: nil,
            supportURL: "https://support.lastpass.com",
            contacts: [.phone("1-800-830-6685", label: "LastPass Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into lastpass.com"),
                CancellationStep(order: 2, title: "Vault", description: "Open your Vault"),
                CancellationStep(order: 3, title: "More Options", description: "Go to More Options > Advanced > My Account"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Premium'", actionURL: "https://lastpass.com/my.php", isCritical: true)
            ],
            aliases: ["last pass", "lastpass premium"],
            averageMonthlyPrice: 3.00
        ),
        SubscriptionService(
            id: "bitwarden",
            name: "Bitwarden",
            category: .security,
            domain: "bitwarden.com",
            cancelURL: "https://vault.bitwarden.com/#/settings/subscription",
            pauseURL: nil,
            supportURL: "https://bitwarden.com/help",
            contacts: [.email("support@bitwarden.com", label: "Bitwarden Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into vault.bitwarden.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings > Subscription"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://vault.bitwarden.com/#/settings/subscription", isCritical: true)
            ],
            aliases: ["bit warden", "bitwarden premium"],
            averageMonthlyPrice: 0.83
        ),
        SubscriptionService(
            id: "dashlane",
            name: "Dashlane",
            category: .security,
            domain: "dashlane.com",
            cancelURL: "https://app.dashlane.com/account/subscription",
            pauseURL: nil,
            supportURL: "https://support.dashlane.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into app.dashlane.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://app.dashlane.com/account/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["dashlane premium"],
            averageMonthlyPrice: 3.33
        ),
        SubscriptionService(
            id: "norton",
            name: "Norton 360",
            category: .security,
            domain: "norton.com",
            cancelURL: "https://my.norton.com/extspa/login",
            pauseURL: nil,
            supportURL: "https://support.norton.com",
            contacts: [.phone("1-855-815-2726", label: "Norton Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into my.norton.com"),
                CancellationStep(order: 2, title: "Services", description: "Go to Services tab"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription Renewal'", actionURL: "https://my.norton.com/extspa/login", isCritical: true)
            ],
            aliases: ["norton antivirus", "norton security", "nortonlife"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "mcafee",
            name: "McAfee",
            category: .security,
            domain: "mcafee.com",
            cancelURL: "https://www.mcafee.com/myaccount",
            pauseURL: nil,
            supportURL: "https://www.mcafee.com/support",
            contacts: [.phone("1-866-622-3911", label: "McAfee Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into mcafee.com/myaccount"),
                CancellationStep(order: 2, title: "Auto-Renewal", description: "Go to Auto-Renewal settings"),
                CancellationStep(order: 3, title: "Turn Off", description: "Turn off Auto-Renewal", actionURL: "https://www.mcafee.com/myaccount", isCritical: true)
            ],
            aliases: ["mcafee antivirus", "mcafee total protection"],
            averageMonthlyPrice: 8.33
        ),
        SubscriptionService(
            id: "malwarebytes",
            name: "Malwarebytes",
            category: .security,
            domain: "malwarebytes.com",
            cancelURL: "https://my.malwarebytes.com/consumer/subscription",
            pauseURL: nil,
            supportURL: "https://support.malwarebytes.com",
            contacts: [.email("support@malwarebytes.com", label: "Malwarebytes Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into my.malwarebytes.com"),
                CancellationStep(order: 2, title: "Subscriptions", description: "Click 'Subscriptions'"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://my.malwarebytes.com/consumer/subscription", isCritical: true)
            ],
            aliases: ["malware bytes"],
            averageMonthlyPrice: 3.33
        ),
        SubscriptionService(
            id: "kaspersky",
            name: "Kaspersky",
            category: .security,
            domain: "kaspersky.com",
            cancelURL: "https://my.kaspersky.com/mylicenses",
            pauseURL: nil,
            supportURL: "https://support.kaspersky.com",
            contacts: [.phone("1-866-328-5700", label: "Kaspersky Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into my.kaspersky.com"),
                CancellationStep(order: 2, title: "Licenses", description: "Go to Licenses"),
                CancellationStep(order: 3, title: "Details", description: "Click license details"),
                CancellationStep(order: 4, title: "Cancel", description: "Disable Auto-Renewal", actionURL: "https://my.kaspersky.com/mylicenses", isCritical: true)
            ],
            aliases: ["kaspersky antivirus", "kaspersky security"],
            averageMonthlyPrice: 8.33
        ),
        SubscriptionService(
            id: "avast",
            name: "Avast",
            category: .security,
            domain: "avast.com",
            cancelURL: "https://id.avast.com/account/resume",
            pauseURL: nil,
            supportURL: "https://support.avast.com",
            contacts: [.phone("1-844-340-9251", label: "Avast Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into id.avast.com"),
                CancellationStep(order: 2, title: "Subscriptions", description: "Go to Subscriptions"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Unsubscribe'", actionURL: "https://id.avast.com/account/resume", isCritical: true)
            ],
            aliases: ["avast antivirus", "avast premium"],
            averageMonthlyPrice: 4.19
        ),
        SubscriptionService(
            id: "tunnelbear",
            name: "TunnelBear",
            category: .security,
            domain: "tunnelbear.com",
            cancelURL: "https://www.tunnelbear.com/account",
            pauseURL: nil,
            supportURL: "https://help.tunnelbear.com",
            contacts: [.email("support@tunnelbear.com", label: "TunnelBear Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into tunnelbear.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.tunnelbear.com/account", isCritical: true)
            ],
            aliases: ["tunnel bear"],
            averageMonthlyPrice: 3.33
        ),
        SubscriptionService(
            id: "privateinternetaccess",
            name: "Private Internet Access",
            category: .security,
            domain: "privateinternetaccess.com",
            cancelURL: "https://www.privateinternetaccess.com/pages/client-sign-in",
            pauseURL: nil,
            supportURL: "https://www.privateinternetaccess.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into client area"),
                CancellationStep(order: 2, title: "Subscriptions", description: "Go to Subscriptions"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.privateinternetaccess.com/pages/client-sign-in", isCritical: true)
            ],
            aliases: ["pia", "pia vpn", "private internet"],
            averageMonthlyPrice: 11.99
        ),
        SubscriptionService(
            id: "windscribe",
            name: "Windscribe",
            category: .security,
            domain: "windscribe.com",
            cancelURL: "https://windscribe.com/myaccount",
            pauseURL: nil,
            supportURL: "https://windscribe.com/support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into windscribe.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://windscribe.com/myaccount", isCritical: true)
            ],
            aliases: ["windscribe vpn"],
            averageMonthlyPrice: 9.00
        ),
        SubscriptionService(
            id: "mullvad",
            name: "Mullvad VPN",
            category: .security,
            domain: "mullvad.net",
            cancelURL: "https://mullvad.net/en/account",
            pauseURL: nil,
            supportURL: "https://mullvad.net/en/help",
            contacts: [.email("support@mullvad.net", label: "Mullvad Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into mullvad.net"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Cancel auto-renewal", actionURL: "https://mullvad.net/en/account", isCritical: true)
            ],
            aliases: ["mullvad"],
            averageMonthlyPrice: 5.50
        )
    ]
}


// MARK: - More Service Categories

extension ServiceDatabase {
    
    // MARK: - Gaming Services
    static let gamingServices: [SubscriptionService] = [
        SubscriptionService(
            id: "xboxgamepass",
            name: "Xbox Game Pass",
            category: .gaming,
            domain: "xbox.com",
            cancelURL: "https://account.microsoft.com/services",
            pauseURL: "https://account.microsoft.com/services",
            supportURL: "https://support.xbox.com",
            contacts: [.phone("1-800-469-9269", label: "Xbox Support")],
            canPause: true,
            pauseDurations: [.oneMonth, .twoMonths],
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to account.microsoft.com/services"),
                CancellationStep(order: 2, title: "Xbox", description: "Find Xbox Game Pass"),
                CancellationStep(order: 3, title: "Manage", description: "Click 'Manage' or 'Cancel'", actionURL: "https://account.microsoft.com/services", isCritical: true)
            ],
            aliases: ["game pass", "xbox pass", "xgp", "gamepass"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "playstationplus",
            name: "PlayStation Plus",
            category: .gaming,
            domain: "playstation.com",
            cancelURL: "https://account.sonyentertainmentnetwork.com/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.playstation.com",
            contacts: [.phone("1-800-345-7669", label: "PlayStation Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to account.sonyentertainmentnetwork.com"),
                CancellationStep(order: 2, title: "Subscription", description: "Go to Subscription Management"),
                CancellationStep(order: 3, title: "Cancel", description: "Turn off Auto-Renew", actionURL: "https://account.sonyentertainmentnetwork.com/subscriptions", isCritical: true)
            ],
            aliases: ["ps plus", "playstation+", "ps+", "psplus"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "nintendoswitch",
            name: "Nintendo Switch Online",
            category: .gaming,
            domain: "nintendo.com",
            cancelURL: "https://accounts.nintendo.com",
            pauseURL: nil,
            supportURL: "https://en-americas-support.nintendo.com",
            contacts: [.phone("1-855-548-4693", label: "Nintendo Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to accounts.nintendo.com"),
                CancellationStep(order: 2, title: "Shop", description: "Go to Nintendo eShop on your Switch"),
                CancellationStep(order: 3, title: "Account", description: "Select your profile"),
                CancellationStep(order: 4, title: "Cancel", description: "Turn off Auto-Renewal", actionURL: "https://accounts.nintendo.com", isCritical: true)
            ],
            aliases: ["nintendo online", "switch online", "nso"],
            averageMonthlyPrice: 3.99
        ),
        SubscriptionService(
            id: "geforcenow",
            name: "GeForce NOW",
            category: .gaming,
            domain: "nvidia.com",
            cancelURL: "https://www.nvidia.com/en-us/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://www.nvidia.com/en-us/support",
            contacts: [.chat("https://www.nvidia.com/en-us/support", label: "NVIDIA Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to nvidia.com and sign in"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account > Subscriptions"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.nvidia.com/en-us/account/subscriptions", isCritical: true)
            ],
            aliases: ["geforce now", "nvidia geforce", "gfn"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "eaaccess",
            name: "EA Play",
            category: .gaming,
            domain: "ea.com",
            cancelURL: "https://myaccount.ea.com/cp-ui/billing/index",
            pauseURL: nil,
            supportURL: "https://help.ea.com",
            contacts: [],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into myaccount.ea.com"),
                CancellationStep(order: 2, title: "Payment", description: "Go to Payment & Shipping"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'Subscriptions'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel' next to EA Play", actionURL: "https://myaccount.ea.com/cp-ui/billing/index", isCritical: true)
            ],
            aliases: ["ea play", "ea access", "electronic arts"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "ubisoftplus",
            name: "Ubisoft+",
            category: .gaming,
            domain: "ubisoft.com",
            cancelURL: "https://account.ubisoft.com/en-US/billing-history",
            pauseURL: nil,
            supportURL: "https://support.ubisoft.com",
            contacts: [.phone("1-919-460-9778", label: "Ubisoft Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.ubisoft.com"),
                CancellationStep(order: 2, title: "Billing", description: "Go to Billing"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://account.ubisoft.com/en-US/billing-history", isCritical: true)
            ],
            aliases: ["ubisoft plus", "uplay plus"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "applearcade",
            name: "Apple Arcade",
            category: .gaming,
            domain: "apple.com",
            cancelURL: "https://apps.apple.com/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.apple.com/arcade",
            contacts: [.phone("1-800-275-2273", label: "Apple Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Settings", description: "On iPhone/iPad: Settings > [Your Name] > Subscriptions"),
                CancellationStep(order: 2, title: "Arcade", description: "Tap Apple Arcade"),
                CancellationStep(order: 3, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://apps.apple.com/account/subscriptions", isCritical: true)
            ],
            aliases: ["arcade", "apple games"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "humblechoice",
            name: "Humble Choice",
            category: .gaming,
            domain: "humblebundle.com",
            cancelURL: "https://www.humblebundle.com/subscription",
            pauseURL: "https://www.humblebundle.com/subscription",
            supportURL: "https://support.humblebundle.com",
            contacts: [.email("support@humblebundle.com", label: "Humble Support")],
            canPause: true,
            pauseDurations: [.oneMonth],
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into humblebundle.com"),
                CancellationStep(order: 2, title: "Subscription", description: "Go to Humble Choice settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Pause Subscription' or 'Cancel Subscription'", actionURL: "https://www.humblebundle.com/subscription", isCritical: true)
            ],
            aliases: ["humble monthly", "humble choice"],
            averageMonthlyPrice: 11.99
        ),
        SubscriptionService(
            id: "shadow",
            name: "Shadow PC",
            category: .gaming,
            domain: "shadow.tech",
            cancelURL: "https://account.shadow.tech/subscription",
            pauseURL: nil,
            supportURL: "https://help.shadow.tech",
            contacts: [.email("support@shadow.tech", label: "Shadow Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into account.shadow.tech"),
                CancellationStep(order: 2, title: "Subscription", description: "Go to My Subscription"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://account.shadow.tech/subscription", isCritical: true)
            ],
            aliases: ["shadow", "shadow gaming"],
            averageMonthlyPrice: 29.99
        ),
        SubscriptionService(
            id: "googleplaypass",
            name: "Google Play Pass",
            category: .gaming,
            domain: "play.google.com",
            cancelURL: "https://play.google.com/store/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.google.com/googleplay",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Play Store", description: "Open Google Play Store app"),
                CancellationStep(order: 2, title: "Profile", description: "Tap Profile > Payments & subscriptions"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Tap Subscriptions"),
                CancellationStep(order: 4, title: "Cancel", description: "Select Play Pass and cancel", actionURL: "https://play.google.com/store/account/subscriptions", isCritical: true)
            ],
            aliases: ["play pass", "google pass"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "boosteroid",
            name: "Boosteroid",
            category: .gaming,
            domain: "boosteroid.com",
            cancelURL: "https://cloud.boosteroid.com/dashboard",
            pauseURL: nil,
            supportURL: "https://boosteroid.com/support",
            contacts: [.email("support@boosteroid.com", label: "Boosteroid Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into cloud.boosteroid.com"),
                CancellationStep(order: 2, title: "Dashboard", description: "Go to Dashboard"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://cloud.boosteroid.com/dashboard", isCritical: true)
            ],
            aliases: ["boosteroid cloud"],
            averageMonthlyPrice: 9.89
        ),
        SubscriptionService(
            id: "blacknut",
            name: "Blacknut",
            category: .gaming,
            domain: "blacknut.com",
            cancelURL: "https://www.blacknut.com/en/account",
            pauseURL: nil,
            supportURL: "https://www.blacknut.com/en/support",
            contacts: [.email("support@blacknut.com", label: "Blacknut Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into blacknut.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.blacknut.com/en/account", isCritical: true)
            ],
            aliases: ["blacknut cloud gaming"],
            averageMonthlyPrice: 12.99
        )
    ]
    
    // MARK: - Fitness Services
    static let fitnessServices: [SubscriptionService] = [
        SubscriptionService(
            id: "peloton",
            name: "Peloton",
            category: .fitness,
            domain: "onepeloton.com",
            cancelURL: "https://members.onepeloton.com/settings/subscription",
            pauseURL: nil,
            supportURL: "https://support.onepeloton.com",
            contacts: [.phone("1-866-679-9129", label: "Peloton Support", hours: "9AM-7PM ET")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into members.onepeloton.com"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile picture"),
                CancellationStep(order: 3, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 4, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://members.onepeloton.com/settings/subscription", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["peloton app", "peloton digital", "peloton membership"],
            averageMonthlyPrice: 12.99
        ),
        SubscriptionService(
            id: "applefitness",
            name: "Apple Fitness+",
            category: .fitness,
            domain: "apple.com",
            cancelURL: "https://apps.apple.com/account/subscriptions",
            pauseURL: nil,
            supportURL: "https://support.apple.com/fitnessplus",
            contacts: [.phone("1-800-275-2273", label: "Apple Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Settings", description: "On iPhone: Settings > [Your Name] > Subscriptions"),
                CancellationStep(order: 2, title: "Fitness", description: "Tap Apple Fitness+"),
                CancellationStep(order: 3, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://apps.apple.com/account/subscriptions", isCritical: true)
            ],
            aliases: ["apple fitness", "fitness plus", "fitness+"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "calm",
            name: "Calm",
            category: .fitness,
            domain: "calm.com",
            cancelURL: "https://www.calm.com/settings/manage-subscription",
            pauseURL: nil,
            supportURL: "https://www.calm.com/support",
            contacts: [.email("support@calm.com", label: "Calm Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into calm.com"),
                CancellationStep(order: 2, title: "Profile", description: "Click your profile"),
                CancellationStep(order: 3, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 4, title: "Manage", description: "Click 'Manage Subscription'", actionURL: "https://www.calm.com/settings/manage-subscription", isCritical: true),
                CancellationStep(order: 5, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["calm app", "calm meditation"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "headspace",
            name: "Headspace",
            category: .fitness,
            domain: "headspace.com",
            cancelURL: "https://www.headspace.com/settings/account",
            pauseURL: nil,
            supportURL: "https://help.headspace.com",
            contacts: [.email("help@headspace.com", label: "Headspace Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into headspace.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription' or 'Manage'", actionURL: "https://www.headspace.com/settings/account", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["headspace app", "headspace meditation"],
            averageMonthlyPrice: 12.99
        ),
        SubscriptionService(
            id: "strava",
            name: "Strava",
            category: .fitness,
            domain: "strava.com",
            cancelURL: "https://www.strava.com/settings/premium",
            pauseURL: nil,
            supportURL: "https://support.strava.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into strava.com"),
                CancellationStep(order: 2, title: "Settings", description: "Hover over your profile > Settings"),
                CancellationStep(order: 3, title: "Premium", description: "Click 'My Account' or 'Premium'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.strava.com/settings/premium", isCritical: true)
            ],
            aliases: ["strava premium", "strava summit"],
            averageMonthlyPrice: 11.99
        ),
        SubscriptionService(
            id: "myfitnesspal",
            name: "MyFitnessPal",
            category: .fitness,
            domain: "myfitnesspal.com",
            cancelURL: "https://www.myfitnesspal.com/account/settings",
            pauseURL: nil,
            supportURL: "https://support.myfitnesspal.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into myfitnesspal.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings > Subscription"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.myfitnesspal.com/account/settings", isCritical: true)
            ],
            aliases: ["my fitness pal", "mfp"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "nike",
            name: "Nike Training Club Premium",
            category: .fitness,
            domain: "nike.com",
            cancelURL: "https://www.nike.com/membership/settings",
            pauseURL: nil,
            supportURL: "https://www.nike.com/help",
            contacts: [.phone("1-800-806-6453", label: "Nike Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Nike Training Club app"),
                CancellationStep(order: 2, title: "Profile", description: "Go to Profile > Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Manage Subscription'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.nike.com/membership/settings", isCritical: true)
            ],
            aliases: ["nike training", "nike app", "ntc"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "fitbod",
            name: "Fitbod",
            category: .fitness,
            domain: "fitbod.me",
            cancelURL: "https://www.fitbod.me/account",
            pauseURL: nil,
            supportURL: "https://support.fitbod.me",
            contacts: [.email("support@fitbod.me", label: "Fitbod Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into fitbod.me"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.fitbod.me/account", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["fitbod app"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "centr",
            name: "Centr",
            category: .fitness,
            domain: "centr.com",
            cancelURL: "https://www.centr.com/my-account",
            pauseURL: nil,
            supportURL: "https://support.centr.com",
            contacts: [.email("support@centr.com", label: "Centr Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into centr.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.centr.com/my-account", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["centr by chris hemsworth", "centr fitness"],
            averageMonthlyPrice: 10.00
        ),
        SubscriptionService(
            id: "aaptiv",
            name: "Aaptiv",
            category: .fitness,
            domain: "aaptiv.com",
            cancelURL: "https://aaptiv.com/settings",
            pauseURL: nil,
            supportURL: "https://aaptiv.com/support",
            contacts: [.email("support@aaptiv.com", label: "Aaptiv Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into aaptiv.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://aaptiv.com/settings", isCritical: true)
            ],
            aliases: ["aaptiv app"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "jefit",
            name: "JEFIT",
            category: .fitness,
            domain: "jefit.com",
            cancelURL: "https://www.jefit.com/account/subscription",
            pauseURL: nil,
            supportURL: "https://www.jefit.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into jefit.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'", actionURL: "https://www.jefit.com/account/subscription", isCritical: true),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'")
            ],
            aliases: ["jefit elite"],
            averageMonthlyPrice: 6.99
        ),
        SubscriptionService(
            id: "dailyburn",
            name: "Daily Burn",
            category: .fitness,
            domain: "dailyburn.com",
            cancelURL: "https://dailyburn.com/account",
            pauseURL: nil,
            supportURL: "https://dailyburn.com/help",
            contacts: [.email("support@dailyburn.com", label: "Daily Burn Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into dailyburn.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://dailyburn.com/account", isCritical: true)
            ],
            aliases: ["dailyburn"],
            averageMonthlyPrice: 14.95
        ),
        SubscriptionService(
            id: "nikeplus",
            name: "Nike Run Club Premium",
            category: .fitness,
            domain: "nike.com",
            cancelURL: "https://www.nike.com/membership/settings",
            pauseURL: nil,
            supportURL: "https://www.nike.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Nike Run Club app"),
                CancellationStep(order: 2, title: "Profile", description: "Go to Profile"),
                CancellationStep(order: 3, title: "Settings", description: "Click Settings"),
                CancellationStep(order: 4, title: "Cancel", description: "Manage subscription", actionURL: "https://www.nike.com/membership/settings", isCritical: true)
            ],
            aliases: ["nrc premium", "nike running"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "freeletics",
            name: "Freeletics",
            category: .fitness,
            domain: "freeletics.com",
            cancelURL: "https://www.freeletics.com/settings",
            pauseURL: nil,
            supportURL: "https://support.freeletics.com",
            contacts: [.email("support@freeletics.com", label: "Freeletics Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into freeletics.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.freeletics.com/settings", isCritical: true)
            ],
            aliases: ["freeletics training"],
            averageMonthlyPrice: 11.99
        )
    ]
    
    // MARK: - Food/Meal Kit Services
    static let foodServices: [SubscriptionService] = [
        SubscriptionService(
            id: "hellofresh",
            name: "HelloFresh",
            category: .food,
            domain: "hellofresh.com",
            cancelURL: "https://www.hellofresh.com/account-settings/subscription-settings",
            pauseURL: "https://www.hellofresh.com/account-settings/subscription-settings",
            supportURL: "https://www.hellofresh.com/contact",
            contacts: [
                .phone("1-646-846-3663", label: "HelloFresh Support"),
                .chat("https://www.hellofresh.com/contact", label: "Live Chat")
            ],
            canPause: true,
            pauseDurations: [.oneWeek, .twoWeeks, .oneMonth, .twoMonths, .threeMonths],
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into hellofresh.com"),
                CancellationStep(order: 2, title: "Account", description: "Click your name > Account Settings"),
                CancellationStep(order: 3, title: "Status", description: "Scroll to Status and click 'Cancel Plan'", actionURL: "https://www.hellofresh.com/account-settings/subscription-settings", isCritical: true),
                CancellationStep(order: 4, title: "Reason", description: "Select a reason for cancellation"),
                CancellationStep(order: 5, title: "Confirm", description: "Click 'Cancel Anyway'")
            ],
            aliases: ["hello fresh"],
            averageMonthlyPrice: 60.00
        ),
        SubscriptionService(
            id: "blueapron",
            name: "Blue Apron",
            category: .food,
            domain: "blueapron.com",
            cancelURL: "https://www.blueapron.com/account",
            pauseURL: "https://www.blueapron.com/account",
            supportURL: "https://support.blueapron.com",
            contacts: [.email("support@blueapron.com", label: "Blue Apron Support")],
            canPause: true,
            pauseDurations: [.oneWeek, .twoWeeks, .oneMonth],
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into blueapron.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Account'", actionURL: "https://www.blueapron.com/account", isCritical: true)
            ],
            aliases: ["blueapron"],
            averageMonthlyPrice: 47.95
        ),
        SubscriptionService(
            id: "factor",
            name: "Factor",
            category: .food,
            domain: "factor75.com",
            cancelURL: "https://www.factor75.com/r/account",
            pauseURL: "https://www.factor75.com/r/account",
            supportURL: "https://www.factor75.com/faqs",
            contacts: [.email("support@factor75.com", label: "Factor Support")],
            canPause: true,
            pauseDurations: [.oneWeek, .twoWeeks, .oneMonth],
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into factor75.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Status", description: "Click 'Deactivate My Plan'", actionURL: "https://www.factor75.com/r/account", isCritical: true)
            ],
            aliases: ["factor 75", "factor75"],
            averageMonthlyPrice: 60.00
        ),
        SubscriptionService(
            id: "dailyharvest",
            name: "Daily Harvest",
            category: .food,
            domain: "daily-harvest.com",
            cancelURL: "https://www.daily-harvest.com/account",
            pauseURL: "https://www.daily-harvest.com/account",
            supportURL: "https://support.daily-harvest.com",
            contacts: [.email("support@daily-harvest.com", label: "Daily Harvest Support")],
            canPause: true,
            pauseDurations: [.oneWeek, .twoWeeks, .oneMonth, .twoMonths],
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into daily-harvest.com"),
                CancellationStep(order: 2, title: "Plan", description: "Go to Plan Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Plan'", actionURL: "https://www.daily-harvest.com/account", isCritical: true)
            ],
            aliases: ["dailyharvest"],
            averageMonthlyPrice: 50.00
        ),
        SubscriptionService(
            id: "gousto",
            name: "Gousto",
            category: .food,
            domain: "gousto.co.uk",
            cancelURL: "https://www.gousto.co.uk/account",
            pauseURL: nil,
            supportURL: "https://www.gousto.co.uk/help",
            contacts: [.email("support@gousto.co.uk", label: "Gousto Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into gousto.co.uk"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.gousto.co.uk/account", isCritical: true)
            ],
            aliases: ["gousto uk"],
            averageMonthlyPrice: 30.00
        ),
        SubscriptionService(
            id: "sunbasket",
            name: "Sunbasket",
            category: .food,
            domain: "sunbasket.com",
            cancelURL: "https://sunbasket.com/account",
            pauseURL: nil,
            supportURL: "https://support.sunbasket.com",
            contacts: [.phone("1-855-204-7591", label: "Sunbasket Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into sunbasket.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Account'", actionURL: "https://sunbasket.com/account", isCritical: true)
            ],
            aliases: ["sun basket"],
            averageMonthlyPrice: 51.96
        ),
        SubscriptionService(
            id: "greenblender",
            name: "Green Blender",
            category: .food,
            domain: "greenblender.com",
            cancelURL: "https://greenblender.com/account",
            pauseURL: nil,
            supportURL: "https://greenblender.com/faqs",
            contacts: [.email("hello@greenblender.com", label: "Green Blender Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into greenblender.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://greenblender.com/account", isCritical: true)
            ],
            aliases: ["green blender"],
            averageMonthlyPrice: 29.99
        ),
        SubscriptionService(
            id: "purplecarrot",
            name: "Purple Carrot",
            category: .food,
            domain: "purplecarrot.com",
            cancelURL: "https://www.purplecarrot.com/account",
            pauseURL: nil,
            supportURL: "https://support.purplecarrot.com",
            contacts: [.email("support@purplecarrot.com", label: "Purple Carrot Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into purplecarrot.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.purplecarrot.com/account", isCritical: true)
            ],
            aliases: ["purple carrot"],
            averageMonthlyPrice: 71.00
        ),
        SubscriptionService(
            id: "homedelivered",
            name: "Home Chef",
            category: .food,
            domain: "homechef.com",
            cancelURL: "https://www.homechef.com/account",
            pauseURL: "https://www.homechef.com/account",
            supportURL: "https://support.homechef.com",
            contacts: [.phone("1-872-225-2433", label: "Home Chef Support")],
            canPause: true,
            pauseDurations: [.oneWeek, .twoWeeks, .oneMonth],
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into homechef.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Account'", actionURL: "https://www.homechef.com/account", isCritical: true)
            ],
            aliases: ["homechef"],
            averageMonthlyPrice: 49.80
        ),
        SubscriptionService(
            id: "sakara",
            name: "Sakara Life",
            category: .food,
            domain: "sakara.com",
            cancelURL: "https://www.sakara.com/account",
            pauseURL: nil,
            supportURL: "https://www.sakara.com/pages/contact",
            contacts: [.email("info@sakara.com", label: "Sakara Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into sakara.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Contact support or use cancel link", actionURL: "https://www.sakara.com/account", isCritical: true)
            ],
            aliases: ["sakara"],
            averageMonthlyPrice: 70.00
        ),
        SubscriptionService(
            id: "territory",
            name: "Territory Foods",
            category: .food,
            domain: "territoryfoods.com",
            cancelURL: "https://www.territoryfoods.com/account",
            pauseURL: nil,
            supportURL: "https://www.territoryfoods.com/faq",
            contacts: [.email("hello@territoryfoods.com", label: "Territory Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into territoryfoods.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.territoryfoods.com/account", isCritical: true)
            ],
            aliases: ["territoryfoods"],
            averageMonthlyPrice: 100.00
        ),
        SubscriptionService(
            id: "goldsbelly",
            name: "Goldbelly",
            category: .food,
            domain: "goldbelly.com",
            cancelURL: "https://www.goldbelly.com/account",
            pauseURL: nil,
            supportURL: "https://www.goldbelly.com/pages/contact",
            contacts: [.email("support@goldbelly.com", label: "Goldbelly Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into goldbelly.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Manage subscriptions", actionURL: "https://www.goldbelly.com/account", isCritical: true)
            ],
            aliases: ["goldbelly"],
            averageMonthlyPrice: 45.00
        )
    ]
}


// MARK: - More Service Categories Continued

extension ServiceDatabase {
    
    // MARK: - News/Media Services
    static let newsServices: [SubscriptionService] = [
        SubscriptionService(
            id: "nyt",
            name: "New York Times",
            category: .news,
            domain: "nytimes.com",
            cancelURL: "https://myaccount.nytimes.com/seg/subscription",
            pauseURL: nil,
            supportURL: "https://help.nytimes.com",
            contacts: [.phone("1-800-698-4637", label: "NYT Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to myaccount.nytimes.com"),
                CancellationStep(order: 2, title: "Account", description: "Click 'Account'"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://myaccount.nytimes.com/seg/subscription", isCritical: true)
            ],
            aliases: ["new york times", "nytimes", "the new york times"],
            averageMonthlyPrice: 17.00
        ),
        SubscriptionService(
            id: "wapo",
            name: "Washington Post",
            category: .news,
            domain: "washingtonpost.com",
            cancelURL: "https://www.washingtonpost.com/subscriptionmanagement",
            pauseURL: nil,
            supportURL: "https://help.washingtonpost.com",
            contacts: [.phone("1-202-334-6100", label: "WaPo Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into washingtonpost.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.washingtonpost.com/subscriptionmanagement", isCritical: true)
            ],
            aliases: ["washington post", "wpost", "wp"],
            averageMonthlyPrice: 10.00
        ),
        SubscriptionService(
            id: "wsj",
            name: "Wall Street Journal",
            category: .news,
            domain: "wsj.com",
            cancelURL: "https://www.wsj.com/account",
            pauseURL: nil,
            supportURL: "https://www.wsj.com/customer-center",
            contacts: [.phone("1-800-568-7625", label: "WSJ Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into wsj.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Cancel", description: "You must call to cancel", actionURL: "https://www.wsj.com/account", isCritical: true)
            ],
            aliases: ["wall street journal", "wsj", "the journal"],
            averageMonthlyPrice: 38.00
        ),
        SubscriptionService(
            id: "medium",
            name: "Medium",
            category: .news,
            domain: "medium.com",
            cancelURL: "https://medium.com/me/settings",
            pauseURL: nil,
            supportURL: "https://help.medium.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into medium.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Membership", description: "Click 'Membership'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel subscription'", actionURL: "https://medium.com/me/settings", isCritical: true)
            ],
            aliases: ["medium membership", "medium partner"],
            averageMonthlyPrice: 5.00
        ),
        SubscriptionService(
            id: "substack",
            name: "Substack",
            category: .news,
            domain: "substack.com",
            cancelURL: "https://substack.com/account",
            pauseURL: nil,
            supportURL: "https://support.substack.com",
            contacts: [.email("support@substack.com", label: "Substack Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into substack.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'Subscriptions'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://substack.com/account", isCritical: true)
            ],
            aliases: ["substack paid"],
            averageMonthlyPrice: 5.00
        ),
        SubscriptionService(
            id: "economist",
            name: "The Economist",
            category: .news,
            domain: "economist.com",
            cancelURL: "https://www.economist.com/myeconomist",
            pauseURL: nil,
            supportURL: "https://www.economist.com/help",
            contacts: [.phone("1-800-456-6086", label: "Economist Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into economist.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Economist"),
                CancellationStep(order: 3, title: "Cancel", description: "Call to cancel subscription", actionURL: "tel:18004566086", isCritical: true)
            ],
            aliases: ["the economist", "economist digital"],
            averageMonthlyPrice: 19.00
        ),
        SubscriptionService(
            id: "guardian",
            name: "The Guardian",
            category: .news,
            domain: "theguardian.com",
            cancelURL: "https://manage.theguardian.com",
            pauseURL: nil,
            supportURL: "https://www.theguardian.com/help",
            contacts: [.email("customer.help@theguardian.com", label: "Guardian Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to manage.theguardian.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://manage.theguardian.com", isCritical: true)
            ],
            aliases: ["guardian", "theguardian"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "atlantic",
            name: "The Atlantic",
            category: .news,
            domain: "theatlantic.com",
            cancelURL: "https://www.theatlantic.com/account",
            pauseURL: nil,
            supportURL: "https://www.theatlantic.com/support",
            contacts: [.phone("1-800-234-2411", label: "Atlantic Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into theatlantic.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to My Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.theatlantic.com/account", isCritical: true)
            ],
            aliases: ["the atlantic"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "bloomberg",
            name: "Bloomberg",
            category: .news,
            domain: "bloomberg.com",
            cancelURL: "https://www.bloomberg.com/account",
            pauseURL: nil,
            supportURL: "https://www.bloomberg.com/professional-support",
            contacts: [.phone("1-888-318-4570", label: "Bloomberg Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into bloomberg.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Contact support to cancel", actionURL: "https://www.bloomberg.com/account", isCritical: true)
            ],
            aliases: ["bloomberg news", "bloomberg digital"],
            averageMonthlyPrice: 34.99
        ),
        SubscriptionService(
            id: "wired",
            name: "Wired",
            category: .news,
            domain: "wired.com",
            cancelURL: "https://www.wired.com/account",
            pauseURL: nil,
            supportURL: "https://www.wired.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into wired.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.wired.com/account", isCritical: true)
            ],
            aliases: ["wired magazine"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "newyorker",
            name: "The New Yorker",
            category: .news,
            domain: "newyorker.com",
            cancelURL: "https://www.newyorker.com/account",
            pauseURL: nil,
            supportURL: "https://www.newyorker.com/support",
            contacts: [.phone("1-800-825-2510", label: "New Yorker Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into newyorker.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Call to cancel", actionURL: "tel:18008252510", isCritical: true)
            ],
            aliases: ["new yorker", "the new yorker magazine"],
            averageMonthlyPrice: 11.99
        ),
        SubscriptionService(
            id: "apnews",
            name: "AP News Premium",
            category: .news,
            domain: "apnews.com",
            cancelURL: "https://apnews.com/account",
            pauseURL: nil,
            supportURL: "https://apnews.com/hub/ap-help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into apnews.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://apnews.com/account", isCritical: true)
            ],
            aliases: ["ap news", "associated press"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "reuters",
            name: "Reuters Plus",
            category: .news,
            domain: "reuters.com",
            cancelURL: "https://www.reuters.com/account",
            pauseURL: nil,
            supportURL: "https://www.reuters.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into reuters.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.reuters.com/account", isCritical: true)
            ],
            aliases: ["reuters news"],
            averageMonthlyPrice: 4.99
        )
    ]
    
    // MARK: - Dating Services
    static let datingServices: [SubscriptionService] = [
        SubscriptionService(
            id: "tinder",
            name: "Tinder",
            category: .dating,
            domain: "tinder.com",
            cancelURL: "https://www.tinder.com/settings",
            pauseURL: nil,
            supportURL: "https://www.gotinder.com/help",
            contacts: [.email("support@gotinder.com", label: "Tinder Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Tinder app or tinder.com"),
                CancellationStep(order: 2, title: "Profile", description: "Tap your profile icon"),
                CancellationStep(order: 3, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 4, title: "Manage", description: "Tap 'Manage Payment Account'"),
                CancellationStep(order: 5, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://www.tinder.com/settings", isCritical: true)
            ],
            aliases: ["tinder plus", "tinder gold", "tinder platinum"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "bumble",
            name: "Bumble",
            category: .dating,
            domain: "bumble.com",
            cancelURL: "https://bumble.com/settings",
            pauseURL: nil,
            supportURL: "https://bumble.com/help",
            contacts: [.email("contact@team.bumble.com", label: "Bumble Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Bumble app"),
                CancellationStep(order: 2, title: "Profile", description: "Tap the profile icon"),
                CancellationStep(order: 3, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 4, title: "Bumble Boost/Premium", description: "Tap your subscription type"),
                CancellationStep(order: 5, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://bumble.com/settings", isCritical: true)
            ],
            aliases: ["bumble boost", "bumble premium"],
            averageMonthlyPrice: 16.99
        ),
        SubscriptionService(
            id: "hinge",
            name: "Hinge",
            category: .dating,
            domain: "hinge.co",
            cancelURL: "https://hinge.co/settings",
            pauseURL: nil,
            supportURL: "https://hinge.co/help",
            contacts: [.email("support@hinge.co", label: "Hinge Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Hinge app"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Account", description: "Tap 'Account'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://hinge.co/settings", isCritical: true)
            ],
            aliases: ["hinge premium", "hinge+"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "match",
            name: "Match.com",
            category: .dating,
            domain: "match.com",
            cancelURL: "https://www.match.com/accountsettings/change/cancel",
            pauseURL: nil,
            supportURL: "https://www.match.com/help",
            contacts: [.phone("1-800-92-MATCH", label: "Match Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into match.com"),
                CancellationStep(order: 2, title: "Gear", description: "Click the gear icon"),
                CancellationStep(order: 3, title: "Settings", description: "Select 'Settings'"),
                CancellationStep(order: 4, title: "Manage", description: "Click 'Manage/cancel membership'", actionURL: "https://www.match.com/accountsettings/change/cancel", isCritical: true),
                CancellationStep(order: 5, title: "Confirm", description: "Follow the cancellation process")
            ],
            aliases: ["match", "match com"],
            averageMonthlyPrice: 35.99
        ),
        SubscriptionService(
            id: "eharmony",
            name: "eHarmony",
            category: .dating,
            domain: "eharmony.com",
            cancelURL: "https://www.eharmony.com/subscription",
            pauseURL: nil,
            supportURL: "https://www.eharmony.com/support",
            contacts: [.phone("1-844-527-7421", label: "eHarmony Support")],
            canPause: false,
            difficulty: .veryHard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into eharmony.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Billing", description: "Go to Billing"),
                CancellationStep(order: 4, title: "Cancel", description: "You must call to cancel", actionURL: "tel:18445277421", isCritical: true)
            ],
            aliases: ["eharmony", "e harmony"],
            averageMonthlyPrice: 35.90
        ),
        SubscriptionService(
            id: "okcupid",
            name: "OkCupid",
            category: .dating,
            domain: "okcupid.com",
            cancelURL: "https://www.okcupid.com/settings",
            pauseURL: nil,
            supportURL: "https://help.okcupid.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into okcupid.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscriptions", description: "Click 'Subscriptions'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.okcupid.com/settings", isCritical: true)
            ],
            aliases: ["okcupid premium", "a-list"],
            averageMonthlyPrice: 19.95
        ),
        SubscriptionService(
            id: "coffeemeetsbagel",
            name: "Coffee Meets Bagel",
            category: .dating,
            domain: "coffeemeetsbagel.com",
            cancelURL: "https://coffeemeetsbagel.com/settings",
            pauseURL: nil,
            supportURL: "https://coffeemeetsbagel.com/support",
            contacts: [.email("contact@coffeemeetsbagel.com", label: "CMB Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Coffee Meets Bagel app"),
                CancellationStep(order: 2, title: "Profile", description: "Go to Profile"),
                CancellationStep(order: 3, title: "Settings", description: "Tap Settings"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://coffeemeetsbagel.com/settings", isCritical: true)
            ],
            aliases: ["cmb", "coffee meets bagel"],
            averageMonthlyPrice: 34.99
        ),
        SubscriptionService(
            id: "ourtime",
            name: "OurTime",
            category: .dating,
            domain: "ourtime.com",
            cancelURL: "https://www.ourtime.com/account",
            pauseURL: nil,
            supportURL: "https://www.ourtime.com/help",
            contacts: [.phone("1-866-727-8920", label: "OurTime Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into ourtime.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel' - may require call", actionURL: "https://www.ourtime.com/account", isCritical: true)
            ],
            aliases: ["our time"],
            averageMonthlyPrice: 29.96
        ),
        SubscriptionService(
            id: "zoosk",
            name: "Zoosk",
            category: .dating,
            domain: "zoosk.com",
            cancelURL: "https://www.zoosk.com/subscription",
            pauseURL: nil,
            supportURL: "https://www.zoosk.com/help",
            contacts: [.phone("1-888-939-6675", label: "Zoosk Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into zoosk.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription' - may require call", actionURL: "https://www.zoosk.com/subscription", isCritical: true)
            ],
            aliases: ["zoosk premium"],
            averageMonthlyPrice: 29.95
        ),
        SubscriptionService(
            id: "plentyoffish",
            name: "Plenty of Fish",
            category: .dating,
            domain: "pof.com",
            cancelURL: "https://www.pof.com/account",
            pauseURL: nil,
            supportURL: "https://www.pof.com/help",
            contacts: [.email("customerservice@pof.com", label: "POF Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into pof.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://www.pof.com/account", isCritical: true)
            ],
            aliases: ["pof", "plenty of fish"],
            averageMonthlyPrice: 19.35
        ),
        SubscriptionService(
            id: "grindr",
            name: "Grindr",
            category: .dating,
            domain: "grindr.com",
            cancelURL: "https://www.grindr.com/account",
            pauseURL: nil,
            supportURL: "https://help.grindr.com",
            contacts: [.email("help@grindr.com", label: "Grindr Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Grindr app"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Tap 'Grindr Xtra/Unlimited'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel Subscription'", actionURL: "https://www.grindr.com/account", isCritical: true)
            ],
            aliases: ["grindr xtra", "grindr unlimited"],
            averageMonthlyPrice: 19.99
        ),
        SubscriptionService(
            id: "scruff",
            name: "Scruff",
            category: .dating,
            domain: "scruff.com",
            cancelURL: "https://www.scruff.com/account",
            pauseURL: nil,
            supportURL: "https://support.scruff.com",
            contacts: [.email("support@scruff.com", label: "Scruff Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Scruff app"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Pro", description: "Tap 'Scruff Pro'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel'", actionURL: "https://www.scruff.com/account", isCritical: true)
            ],
            aliases: ["scruff pro"],
            averageMonthlyPrice: 14.99
        )
    ]
}


// MARK: - Final Service Categories

extension ServiceDatabase {
    
    // MARK: - Shopping Services
    static let shoppingServices: [SubscriptionService] = [
        SubscriptionService(
            id: "amazonprime",
            name: "Amazon Prime",
            category: .shopping,
            domain: "amazon.com",
            cancelURL: "https://www.amazon.com/prime/EndMembership",
            pauseURL: nil,
            supportURL: "https://www.amazon.com/gp/help/customer/contact-us",
            contacts: [
                .phone("1-888-280-4331", label: "Amazon Support", hours: "24/7"),
                .chat("https://www.amazon.com/gp/help/customer/contact-us", label: "Chat Support")
            ],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Go to amazon.com and sign in"),
                CancellationStep(order: 2, title: "Account", description: "Hover over 'Account & Lists'"),
                CancellationStep(order: 3, title: "Prime", description: "Click 'Prime Membership'"),
                CancellationStep(order: 4, title: "End", description: "Click 'End Membership'", actionURL: "https://www.amazon.com/prime/EndMembership", isCritical: true)
            ],
            aliases: ["amazon prime", "prime", "amazon membership"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "walmartplus",
            name: "Walmart+",
            category: .shopping,
            domain: "walmart.com",
            cancelURL: "https://www.walmart.com/account/walmartplus",
            pauseURL: nil,
            supportURL: "https://help.walmart.com",
            contacts: [.phone("1-800-925-6278", label: "Walmart Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into walmart.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Walmart+", description: "Click 'Walmart+'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Membership'", actionURL: "https://www.walmart.com/account/walmartplus", isCritical: true)
            ],
            aliases: ["walmart plus", "walmart+ membership"],
            averageMonthlyPrice: 12.95
        ),
        SubscriptionService(
            id: "targetcircle",
            name: "Target Circle 360",
            category: .shopping,
            domain: "target.com",
            cancelURL: "https://www.target.com/circle",
            pauseURL: nil,
            supportURL: "https://help.target.com",
            contacts: [.phone("1-800-440-0680", label: "Target Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into target.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Circle", description: "Click 'Target Circle'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.target.com/circle", isCritical: true)
            ],
            aliases: ["target circle", "target membership"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "instacartplus",
            name: "Instacart+",
            category: .shopping,
            domain: "instacart.com",
            cancelURL: "https://www.instacart.com/store/account/instacart+",
            pauseURL: nil,
            supportURL: "https://help.instacart.com",
            contacts: [.phone("1-888-246-7822", label: "Instacart Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App/Website", description: "Open Instacart app or website"),
                CancellationStep(order: 2, title: "Account", description: "Tap the Account icon"),
                CancellationStep(order: 3, title: "Instacart+", description: "Tap 'Instacart+'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel membership'", actionURL: "https://www.instacart.com/store/account/instacart+", isCritical: true)
            ],
            aliases: ["instacart plus", "instacart express"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "shipt",
            name: "Shipt",
            category: .shopping,
            domain: "shipt.com",
            cancelURL: "https://www.shipt.com/account",
            pauseURL: nil,
            supportURL: "https://www.shipt.com/help",
            contacts: [.phone("1-205-502-2500", label: "Shipt Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into shipt.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Membership'", actionURL: "https://www.shipt.com/account", isCritical: true)
            ],
            aliases: ["shipt membership"],
            averageMonthlyPrice: 10.99
        ),
        SubscriptionService(
            id: "doordashplus",
            name: "DoorDash DashPass",
            category: .shopping,
            domain: "doordash.com",
            cancelURL: "https://www.doordash.com/consumer/subscription",
            pauseURL: nil,
            supportURL: "https://help.doordash.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open DoorDash app"),
                CancellationStep(order: 2, title: "Account", description: "Tap Account tab"),
                CancellationStep(order: 3, title: "DashPass", description: "Tap 'DashPass'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'End Subscription'", actionURL: "https://www.doordash.com/consumer/subscription", isCritical: true)
            ],
            aliases: ["dashpass", "doordash dashpass"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "ubereats",
            name: "Uber One",
            category: .shopping,
            domain: "uber.com",
            cancelURL: "https://www.uber.com/account/uber-one",
            pauseURL: nil,
            supportURL: "https://help.uber.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Uber or Uber Eats app"),
                CancellationStep(order: 2, title: "Account", description: "Tap Account"),
                CancellationStep(order: 3, title: "Uber One", description: "Tap 'Uber One'"),
                CancellationStep(order: 4, title: "Manage", description: "Tap 'Manage Membership'"),
                CancellationStep(order: 5, title: "Cancel", description: "Tap 'End Membership'", actionURL: "https://www.uber.com/account/uber-one", isCritical: true)
            ],
            aliases: ["uber one", "ubereats pass"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "grubhubplus",
            name: "Grubhub+",
            category: .shopping,
            domain: "grubhub.com",
            cancelURL: "https://www.grubhub.com/account/gh-plus",
            pauseURL: nil,
            supportURL: "https://help.grubhub.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "App", description: "Open Grubhub app"),
                CancellationStep(order: 2, title: "Account", description: "Tap My Grubhub > Settings"),
                CancellationStep(order: 3, title: "Grubhub+", description: "Tap 'Grubhub+'"),
                CancellationStep(order: 4, title: "Cancel", description: "Tap 'Cancel membership'", actionURL: "https://www.grubhub.com/account/gh-plus", isCritical: true)
            ],
            aliases: ["grubhub plus", "grubhub+"],
            averageMonthlyPrice: 9.99
        ),
        SubscriptionService(
            id: "thredup",
            name: "ThredUp Goody Boxes",
            category: .shopping,
            domain: "thredup.com",
            cancelURL: "https://www.thredup.com/account",
            pauseURL: nil,
            supportURL: "https://www.thredup.com/help",
            contacts: [.email("support@thredup.com", label: "ThredUp Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into thredup.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Cancel subscription", actionURL: "https://www.thredup.com/account", isCritical: true)
            ],
            aliases: ["thredup"],
            averageMonthlyPrice: 10.00
        )
    ]
    
    // MARK: - Finance Services
    static let financeServices: [SubscriptionService] = [
        SubscriptionService(
            id: "mint",
            name: "Mint Premium",
            category: .finance,
            domain: "mint.com",
            cancelURL: "https://mint.intuit.com/settings",
            pauseURL: nil,
            supportURL: "https://mint.intuit.com/help",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into mint.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel Premium'", actionURL: "https://mint.intuit.com/settings", isCritical: true)
            ],
            aliases: ["mint premium", "mint insights"],
            averageMonthlyPrice: 4.99
        ),
        SubscriptionService(
            id: "ynab",
            name: "YNAB",
            category: .finance,
            domain: "ynab.com",
            cancelURL: "https://app.ynab.com/settings",
            pauseURL: nil,
            supportURL: "https://ynab.com/support",
            contacts: [.email("support@ynab.com", label: "YNAB Support")],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into app.ynab.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Subscription", description: "Click 'Subscription'"),
                CancellationStep(order: 4, title: "Cancel", description: "Click 'Cancel Subscription'", actionURL: "https://app.ynab.com/settings", isCritical: true)
            ],
            aliases: ["you need a budget", "ynab budget"],
            averageMonthlyPrice: 14.99
        ),
        SubscriptionService(
            id: "personalcapital",
            name: "Empower (formerly Personal Capital)",
            category: .finance,
            domain: "empower.com",
            cancelURL: "https://home.empower.com/settings",
            pauseURL: nil,
            supportURL: "https://www.empower.com/support",
            contacts: [.phone("1-855-855-8265", label: "Empower Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into empower.com"),
                CancellationStep(order: 2, title: "Settings", description: "Go to Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://home.empower.com/settings", isCritical: true)
            ],
            aliases: ["personal capital", "empower"],
            averageMonthlyPrice: 8.99
        ),
        SubscriptionService(
            id: "quickbooks",
            name: "QuickBooks",
            category: .finance,
            domain: "quickbooks.intuit.com",
            cancelURL: "https://qbo.intuit.com/app/accountsettings",
            pauseURL: nil,
            supportURL: "https://quickbooks.intuit.com/support",
            contacts: [.phone("1-800-446-8848", label: "QuickBooks Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into qbo.intuit.com"),
                CancellationStep(order: 2, title: "Gear", description: "Click the Gear icon"),
                CancellationStep(order: 3, title: "Account", description: "Click 'Account and Settings'"),
                CancellationStep(order: 4, title: "Billing", description: "Click 'Billing & Subscription'"),
                CancellationStep(order: 5, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://qbo.intuit.com/app/accountsettings", isCritical: true)
            ],
            aliases: ["quickbooks online", "qbo"],
            averageMonthlyPrice: 30.00
        ),
        SubscriptionService(
            id: "turbotax",
            name: "TurboTax",
            category: .finance,
            domain: "turbotax.intuit.com",
            cancelURL: "https://myturbotax.intuit.com",
            pauseURL: nil,
            supportURL: "https://ttlc.intuit.com",
            contacts: [.phone("1-800-446-8848", label: "TurboTax Support")],
            canPause: false,
            difficulty: .medium,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into myturbotax.intuit.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://myturbotax.intuit.com", isCritical: true)
            ],
            aliases: ["turbo tax"],
            averageMonthlyPrice: 29.99
        ),
        SubscriptionService(
            id: "creditkarma",
            name: "Credit Karma",
            category: .finance,
            domain: "creditkarma.com",
            cancelURL: "https://www.creditkarma.com/account",
            pauseURL: nil,
            supportURL: "https://support.creditkarma.com",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into creditkarma.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account Settings"),
                CancellationStep(order: 3, title: "Cancel", description: "Cancel any premium features", actionURL: "https://www.creditkarma.com/account", isCritical: true)
            ],
            aliases: ["credit karma"],
            averageMonthlyPrice: 0.00
        ),
        SubscriptionService(
            id: "experian",
            name: "Experian",
            category: .finance,
            domain: "experian.com",
            cancelURL: "https://usa.experian.com/mycredit/report",
            pauseURL: nil,
            supportURL: "https://www.experian.com/help",
            contacts: [.phone("1-866-617-1894", label: "Experian Support")],
            canPause: false,
            difficulty: .hard,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into experian.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel' - may require call", actionURL: "https://usa.experian.com/mycredit/report", isCritical: true)
            ],
            aliases: ["experian credit", "experianworks"],
            averageMonthlyPrice: 24.99
        ),
        SubscriptionService(
            id: "nerdwallet",
            name: "NerdWallet+",
            category: .finance,
            domain: "nerdwallet.com",
            cancelURL: "https://www.nerdwallet.com/my/account",
            pauseURL: nil,
            supportURL: "https://www.nerdwallet.com/support",
            contacts: [],
            canPause: false,
            difficulty: .easy,
            instructions: [
                CancellationStep(order: 1, title: "Sign In", description: "Log into nerdwallet.com"),
                CancellationStep(order: 2, title: "Account", description: "Go to Account"),
                CancellationStep(order: 3, title: "Cancel", description: "Click 'Cancel'", actionURL: "https://www.nerdwallet.com/my/account", isCritical: true)
            ],
            aliases: ["nerdwallet plus"],
            averageMonthlyPrice: 4.99
        )
    ]
    
    // Combine all services into one array (200+ services)
    static var services: [SubscriptionService] {
        streamingServices + musicServices + productivityServices + storageServices +
        securityServices + gamingServices + fitnessServices + foodServices +
        newsServices + datingServices + shoppingServices + financeServices
    }
}


// MARK: - Subscription Action Manager

/// Main manager class for handling subscription cancellations, pauses, and alternatives
@MainActor
class SubscriptionActionManager: ObservableObject {
    static let shared = SubscriptionActionManager()
    
    // Published properties for UI binding
    @Published var activePauses: [PauseRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Storage for pause records
    private let pauseStorageKey = "com.pausely.pauseRecords"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Service Lookup
    
    /// Get all available services
    var allServices: [SubscriptionService] {
        ServiceDatabase.services
    }
    
    /// Get services by category
    func services(in category: ServiceCategory) -> [SubscriptionService] {
        allServices.filter { $0.category == category }
    }
    
    /// Get a specific service by ID
    func service(withId id: String) -> SubscriptionService? {
        allServices.first { $0.id == id }
    }
    
    /// Fuzzy matching to find the best service match for a subscription name
    func findService(for subscriptionName: String) -> SubscriptionService? {
        let normalizedName = subscriptionName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Try exact ID match
        if let service = service(withId: normalizedName.replacingOccurrences(of: " ", with: "")) {
            return service
        }
        
        // 2. Try exact name match
        if let service = allServices.first(where: { $0.name.lowercased() == normalizedName }) {
            return service
        }
        
        // 3. Try alias match
        if let service = allServices.first(where: { 
            $0.aliases.contains(where: { $0.lowercased() == normalizedName })
        }) {
            return service
        }
        
        // 4. Try contains match (requires match to be at least 3 characters)
        if let service = allServices.first(where: {
            let serviceName = $0.name.lowercased()
            return (normalizedName.contains(serviceName) && serviceName.count >= 3) ||
                   (serviceName.contains(normalizedName) && normalizedName.count >= 3)
        }) {
            return service
        }

        // 5. Try partial word matching (stricter: min 3 chars per word, need 2+ matches)
        let nameWords = normalizedName.split(separator: " ")
        var bestMatch: SubscriptionService?
        var bestScore = 0

        for service in allServices {
            let serviceWords = service.name.lowercased().split(separator: " ")
            let aliasWords = service.aliases.flatMap { $0.lowercased().split(separator: " ") }
            let allWords = Set(serviceWords + aliasWords)

            let matchCount = nameWords.filter { word in
                guard word.count >= 3 else { return false }
                return allWords.contains(where: {
                    let w = $0
                    guard w.count >= 3 else { return false }
                    return w.hasPrefix(word) || word.hasPrefix(w)
                })
            }.count

            if matchCount > bestScore {
                bestScore = matchCount
                bestMatch = service
            }
        }

        // Require at least 2 matching words, or if single-word query, exact prefix match
        if bestScore >= 2 {
            return bestMatch
        }

        // For single-word queries: only match if the word is a strong prefix (≥4 chars)
        if nameWords.count == 1, let word = nameWords.first, word.count >= 4, bestScore >= 1 {
            return bestMatch
        }

        return nil
    }
    
    /// Alias for findService to maintain backward compatibility
    func getService(for subscriptionName: String) -> SubscriptionService? {
        return findService(for: subscriptionName)
    }
    
    /// Get service with confidence score for fuzzy matching
    func findServiceWithConfidence(for subscriptionName: String) -> (service: SubscriptionService, confidence: Double)? {
        let normalizedName = subscriptionName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match = 100% confidence
        if let service = allServices.first(where: { $0.name.lowercased() == normalizedName }) {
            return (service, 1.0)
        }
        
        // Alias match = 95% confidence
        if let service = allServices.first(where: {
            $0.aliases.contains(where: { $0.lowercased() == normalizedName })
        }) {
            return (service, 0.95)
        }
        
        // Contains match = 80% confidence
        if let service = allServices.first(where: {
            normalizedName.contains($0.name.lowercased()) ||
            $0.name.lowercased().contains(normalizedName)
        }) {
            return (service, 0.8)
        }
        
        // Partial word match = variable confidence
        let nameWords = normalizedName.split(separator: " ")
        var bestMatch: SubscriptionService?
        var bestScore = 0
        
        for service in allServices {
            let serviceWords = service.name.lowercased().split(separator: " ")
            let aliasWords = service.aliases.flatMap { $0.lowercased().split(separator: " ") }
            let allWords = Set(serviceWords + aliasWords)
            
            let matchCount = nameWords.filter { word in
                allWords.contains(where: { $0.hasPrefix(word) || word.hasPrefix($0) })
            }.count
            
            if matchCount > bestScore {
                bestScore = matchCount
                bestMatch = service
            }
        }
        
        if bestScore >= 1, let match = bestMatch {
            let confidence = min(0.7, Double(bestScore) / Double(nameWords.count))
            return (match, confidence)
        }
        
        return nil
    }
    
    // MARK: - URL Generation
    
    /// Generate the cancel URL for a subscription
    func generateCancelURL(for subscription: Subscription) -> URL? {
        if let service = findService(for: subscription.name) {
            return URL(string: service.cancelURL)
        }
        
        // Fallback to generic search
        let searchQuery = "cancel \(subscription.name) subscription"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/search?q=\(encodedQuery)")
    }
    
    /// Generate the pause URL for a subscription
    func generatePauseURL(for subscription: Subscription) -> URL? {
        guard let service = findService(for: subscription.name),
              service.canPause,
              let pauseURL = service.pauseURL else {
            return nil
        }
        return URL(string: pauseURL)
    }
    
    /// Generate the support URL for a subscription
    func generateSupportURL(for subscription: Subscription) -> URL? {
        if let service = findService(for: subscription.name) {
            return URL(string: service.supportURL)
        }
        return nil
    }
    
    /// Get support contact information
    func getSupportContacts(for subscription: Subscription) -> [SupportContact] {
        guard let service = findService(for: subscription.name) else {
            return []
        }
        return service.contacts
    }
    
    // MARK: - Cancellation Info
    
    /// Get cancellation instructions for a subscription
    func getCancellationInstructions(for subscription: Subscription) -> [CancellationStep] {
        guard let service = findService(for: subscription.name) else {
            return [CancellationStep(
                order: 1,
                title: "Search Online",
                description: "Search for 'how to cancel \(subscription.name)' for specific instructions",
                actionURL: generateCancelURL(for: subscription)?.absoluteString,
                isCritical: true
            )]
        }
        return service.instructions
    }
    
    /// Get cancellation difficulty
    func getCancellationDifficulty(for subscription: Subscription) -> CancellationDifficulty {
        guard let service = findService(for: subscription.name) else {
            return .medium
        }
        return service.difficulty
    }
    
    /// Get estimated time to cancel
    func getEstimatedCancellationTime(for subscription: Subscription) -> Int {
        return getCancellationDifficulty(for: subscription).estimatedMinutes
    }
    
    // MARK: - Pause Management
    
    /// Check if a subscription can be paused
    func canPause(_ subscription: Subscription) -> Bool {
        guard let service = findService(for: subscription.name) else {
            return false
        }
        return service.canPause
    }
    
    /// Get available pause durations for a subscription
    func getPauseDurations(for subscription: Subscription) -> [PauseDuration] {
        guard let service = findService(for: subscription.name), service.canPause else {
            return []
        }
        return service.pauseDurations
    }
    
    /// Create a pause record
    func createPause(for subscription: Subscription, duration: PauseDuration, setReminder: Bool = true) -> PauseRecord {
        let calendar = Calendar.current
        let endsAt = calendar.date(byAdding: .day, value: duration.rawValue, to: Date()) ?? Date()
        let reminderDate = calendar.date(byAdding: .day, value: duration.rawValue - 2, to: Date())
        
        let record = PauseRecord(
            id: UUID(),
            subscriptionId: subscription.id,
            serviceId: findService(for: subscription.name)?.id ?? "",
            startedAt: Date(),
            endsAt: endsAt,
            reminderSet: setReminder,
            reminderDate: setReminder ? reminderDate : nil,
            status: .active
        )
        
        activePauses.append(record)
        savePauseRecords()
        
        // Schedule notification if needed
        if setReminder, let reminder = reminderDate {
            schedulePauseReminder(for: record, at: reminder)
        }
        
        return record
    }
    
    /// End a pause early
    func endPause(_ pause: PauseRecord) {
        if let index = activePauses.firstIndex(where: { $0.id == pause.id }) {
            activePauses[index].status = .ended
            savePauseRecords()
        }
    }
    
    /// Cancel a pause
    func cancelPause(_ pause: PauseRecord) {
        if let index = activePauses.firstIndex(where: { $0.id == pause.id }) {
            activePauses[index].status = .cancelled
            savePauseRecords()
        }
    }
    
    /// Get active pause for a subscription
    func getActivePause(for subscription: Subscription) -> PauseRecord? {
        return activePauses.first { 
            $0.subscriptionId == subscription.id && $0.status == .active 
        }
    }
    
    /// Check if subscription is currently paused
    func isPaused(_ subscription: Subscription) -> Bool {
        return getActivePause(for: subscription) != nil
    }
    
    /// Get all active pauses
    func getAllActivePauses() -> [PauseRecord] {
        return activePauses.filter { $0.status == .active }
    }
    
    /// Clean up expired pauses
    func cleanupExpiredPauses() {
        for (index, pause) in activePauses.enumerated() {
            if pause.isExpired && pause.status == .active {
                activePauses[index].status = .ended
            }
        }
        savePauseRecords()
    }
    
    // MARK: - Alternative Services
    
    /// Find alternative services for a subscription
    func findAlternatives(for subscription: Subscription) -> [AlternativeService] {
        guard let service = findService(for: subscription.name) else {
            // Return generic alternatives based on category
            if let category = subscription.category.flatMap({ catStr in
                ServiceCategory.allCases.first { $0.rawValue.lowercased() == catStr.lowercased() }
            }) {
                return AlternativeDatabase.getAlternatives(for: category)
            }
            return []
        }

        return AlternativeDatabase.getAlternatives(for: service.category)
    }
    
    /// Calculate potential savings
    func calculateSavings(current: Subscription, alternative: AlternativeService) -> Double {
        let currentMonthly = NSDecimalNumber(decimal: current.amount).doubleValue
        return alternative.calculateSavings(comparedTo: currentMonthly)
    }
    
    /// Get best alternative with highest savings
    func getBestAlternative(for subscription: Subscription) -> AlternativeService? {
        let alternatives = findAlternatives(for: subscription)
        let currentMonthly = NSDecimalNumber(decimal: subscription.amount).doubleValue
        
        return alternatives.max { a, b in
            a.calculateSavings(comparedTo: currentMonthly) < b.calculateSavings(comparedTo: currentMonthly)
        }
    }
    
    // MARK: - Private Helpers
    
    private func savePauseRecords() {
        if let encoded = try? JSONEncoder().encode(activePauses) {
            UserDefaults.standard.set(encoded, forKey: pauseStorageKey)
        }
    }
    
    private func loadPauseRecords() {
        guard let data = UserDefaults.standard.data(forKey: pauseStorageKey),
              let records = try? JSONDecoder().decode([PauseRecord].self, from: data) else {
            return
        }
        activePauses = records
        cleanupExpiredPauses()
    }
    
    private func schedulePauseReminder(for pause: PauseRecord, at date: Date) {
        // Implementation would use UNUserNotificationCenter
        // This is a placeholder for the notification scheduling logic
    }
    
    // MARK: - Initialization
    
    private init() {
        loadPauseRecords()
    }
}

// MARK: - Alternative Services Database

