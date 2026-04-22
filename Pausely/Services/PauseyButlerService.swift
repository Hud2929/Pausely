//
//  PauseyButlerService.swift
//  Pausely
//
//  Your personal subscription butler - one tap cancel anything
//

import Foundation
import StoreKit
import SwiftUI

// MARK: - Pausey

/// Pausey is your subscription butler - one tap to cancel or pause any subscription
@MainActor
@Observable
final class PauseyButler {
    static let shared = PauseyButler()

    /// Known cancellation URLs for popular services (external subscriptions)
    private let knownCancellationURLs: [String: String] = [
        // Video Streaming
        "netflix": "https://www.netflix.com/cancelplan",
        "hulu": "https://secure.hulu.com/account",
        "disney": "https://www.disneyplus.com/account",
        "disney+": "https://www.disneyplus.com/account",
        "hbo": "https://www.max.com/settings/subscription",
        "max": "https://www.max.com/settings/subscription",
        "amazon prime": "https://www.amazon.com/gp/primecentral",
        "prime video": "https://www.amazon.com/gp/primecentral",
        "paramount": "https://www.paramountplus.com/account/",
        "peacock": "https://www.peacocktv.com/account/subscription",
        "apple tv": "https://tv.apple.com/settings",
        "apple tv+": "https://tv.apple.com/settings",
        "youtube premium": "https://www.youtube.com/paid_memberships",
        "youtube music": "https://www.youtube.com/paid_memberships",
        "crunchyroll": "https://www.crunchyroll.com/account/membership",
        "mubi": "https://mubi.com/settings/subscription",

        // Music Streaming
        "spotify": "https://www.spotify.com/account/subscription/",
        "apple music": "https://support.apple.com/en-us/HT202039",
        "tidal": "https://account.tidal.com/subscription",
        "deezer": "https://www.deezer.com/account/subscription",
        "amazon music": "https://www.amazon.com/gp/primecentral",
        "pandora": "https://www.pandora.com/account/subscription",

        // Gaming
        "xbox": "https://account.microsoft.com/services/",
        "playstation": "https://store.playstation.com/subscriptions",
        "nintendo": "https://accounts.nintendo.com/membership",
        "ea play": "https://www.ea.com/accountEA/payments-billing",
        "ubisoft": "https://account.ubisoft.com/subscriptions",
        "xbox game pass": "https://account.microsoft.com/services/",
        "playstation plus": "https://store.playstation.com/subscriptions",

        // Cloud Storage
        "icloud": "https://support.apple.com/en-us/HT207594",
        "google one": "https://one.google.com/storage",
        "onedrive": "https://account.microsoft.com/services/",
        "box": "https://www.box.com/account/plan",
        "pcloud": "https://my.pcloud.com/#page=plans",

        // Productivity
        "notion": "https://www.notion.so/my-account",
        "slack": "https://slack.com/billing",
        "microsoft 365": "https://account.microsoft.com/services/",
        "google workspace": "https://admin.google.com/ac/billing",
        "dropbox": "https://www.dropbox.com/account/plan",

        // News & Reading
        "new york times": "https://www.nytimes.com/account/cancel",
        "nyt": "https://www.nytimes.com/account/cancel",
        "washington post": "https://subscription.washingtonpost.com/myaccount",
        "wall street journal": "https://account.wsj.com/billing",
        "wsj": "https://account.wsj.com/billing",
        "kindle unlimited": "https://www.amazon.com/hz/mycd/myx#/home/settings/payment",
        "audible": "https://www.audible.com/account/overview",
        "apple news": "https://news.apple.com/settings",

        // Fitness
        "peloton": "https://members.onepeloton.com/settings/subscription",
        "strava": "https://www.strava.com/settings/subscription",
        "classpass": "https://classpass.com/settings/subscription",

        // VPN & Security
        "nordvpn": "https://my.nordaccount.com/dashboard/nordvpn/",
        "expressvpn": "https://www.expressvpn.com/subscriptions",
        "1password": "https://my.1password.com/settings/billing",
        "lastpass": "https://lastpass.com/account.php",
    ]

    /// Services that support pause (not full cancel)
    private let pausableServices: [String] = [
        "netflix", "spotify", "hulu", "disney+", "apple music", "youtube premium",
        "amazon prime", "hbo max", "paramount+", "peacock", "crunchyroll"
    ]

    private init() {}

    // MARK: - Public Interface

    /// Get cancellation info for a subscription
    func getCancellationInfo(for subscription: Subscription) -> CancellationInfo {
        let name = subscription.name.lowercased()

        // Check if it's a StoreKit subscription (in-app purchase)
        if subscription.isStoreKitManaged {
            return CancellationInfo(
                type: PauseyCancellationType.storeKit,
                serviceName: subscription.name,
                cancelURL: nil, // Will use StoreKit API
                pauseAvailable: false,
                pauseURL: nil,
                difficulty: .easy,
                message: "This is an in-app purchase. Tap below to manage."
            )
        }

        // Check for known cancellation URL
        if let cancelURL = findCancellationURL(for: name) {
            let isPausable = pausableServices.contains { name.contains($0) }

            return CancellationInfo(
                type: PauseyCancellationType.external,
                serviceName: subscription.name,
                cancelURL: URL(string: cancelURL),
                pauseAvailable: isPausable,
                pauseURL: isPausable ? URL(string: cancelURL) : nil,
                difficulty: getDifficulty(for: name),
                message: getDifficultyMessage(for: getDifficulty(for: name))
            )
        }

        // Unknown service - offer to search
        return CancellationInfo(
            type: PauseyCancellationType.unknown,
            serviceName: subscription.name,
            cancelURL: URL(string: "https://www.google.com/search?q=how+to+cancel+\(subscription.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subscription.name)+subscription"),
            pauseAvailable: false,
            pauseURL: nil,
            difficulty: .medium,
            message: "I'll search for how to cancel \(subscription.name)"
        )
    }

    /// Open cancellation flow for a subscription
    func cancel(subscription: Subscription) async -> PauseyCancellationResult {
        let info = getCancellationInfo(for: subscription)

        switch info.type {
        case PauseyCancellationType.storeKit:
            // Open Apple subscription management
            return await cancelStoreKitSubscription()

        case PauseyCancellationType.external, PauseyCancellationType.unknown:
            if let url = info.cancelURL {
                await openURL(url)
                return .initiated(url: url)
            }
            return .failed(reason: "Could not find cancellation URL")

        case PauseyCancellationType.pause:
            if let url = info.pauseURL {
                await openURL(url)
                return .initiated(url: url)
            }
            return .failed(reason: "Pause not available")
        }
    }

    /// Pause a subscription (if supported)
    func pause(subscription: Subscription) async -> PauseyCancellationResult {
        let info = getCancellationInfo(for: subscription)

        if info.pauseAvailable, let url = info.pauseURL {
            await openURL(url)
            return .initiated(url: url)
        }

        // If not specifically pausable, treat as cancel
        return await cancel(subscription: subscription)
    }

    /// Open Apple subscription management
    func openSubscriptionManagement() async {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        await openURL(url)
    }

    /// Cancel via StoreKit (opens subscription management)
    private func cancelStoreKitSubscription() async -> PauseyCancellationResult {
        await openSubscriptionManagement()
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
            return .failed(reason: "Invalid subscription management URL")
        }
        return .initiated(url: url)
    }

    /// Check if a subscription is StoreKit managed (in-app purchase)
    private func isStoreKitManaged(productId: String) -> Bool {
        // In a full implementation, we'd check against StoreKit products
        // For now, return false as most subscriptions are external
        return false
    }

    // MARK: - Private Helpers

    private func findCancellationURL(for serviceName: String) -> String? {
        for (key, url) in knownCancellationURLs {
            if serviceName.contains(key) {
                return url
            }
        }
        return nil
    }

    private func getDifficulty(for serviceName: String) -> PauseyCancellationDifficulty {
        let easy = ["netflix", "spotify", "apple music", "youtube premium", "amazon prime", "hulu", "disney+"]
        let hard = ["gym", "fitness", "insurance", "newspaper", "magazine"]

        for easyService in easy {
            if serviceName.contains(easyService) {
                return .easy
            }
        }

        for hardService in hard {
            if serviceName.contains(hardService) {
                return .hard
            }
        }

        return .medium
    }

    private func getDifficultyMessage(for difficulty: PauseyCancellationDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "One-click cancellation available"
        case .medium:
            return "May require chat or phone support"
        case .hard:
            return "May require written request or visit"
        }
    }

    @MainActor
    private func openURL(_ url: URL) async {
        await UIApplication.shared.open(url)
    }
}

// MARK: - Models

enum PauseyCancellationType {
    case storeKit      // In-app purchase via StoreKit
    case external      // External subscription (Netflix, etc.)
    case pause         // Only pause available, not cancel
    case unknown       // Unknown service
}

enum PauseyCancellationDifficulty {
    case easy, medium, hard

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var icon: String {
        switch self {
        case .easy: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .hard: return "xmark.circle.fill"
        }
    }
}

struct CancellationInfo {
    let type: PauseyCancellationType
    let serviceName: String
    let cancelURL: URL?
    let pauseAvailable: Bool
    let pauseURL: URL?
    let difficulty: PauseyCancellationDifficulty
    let message: String

    var isStoreKit: Bool { type == PauseyCancellationType.storeKit }
    var isExternal: Bool { type == PauseyCancellationType.external }
    var isUnknown: Bool { type == PauseyCancellationType.unknown }
    var canPause: Bool { pauseAvailable }
}

enum PauseyCancellationResult {
    case initiated(url: URL)
    case failed(reason: String)
    case cancelled // User backed out
}
