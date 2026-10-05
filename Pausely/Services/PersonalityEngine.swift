//
//  PersonalityEngine.swift
//  Pausely
//
//  Computes a subscription personality archetype from the user's active subscription mix.
//  8 types, each with a shareable headline and description.
//

import Foundation
import SwiftUI

// MARK: - Personality Type

struct SubscriptionPersonality {
    let type: PersonalityType
    let emoji: String
    let name: String
    let headline: String       // Short shareable line
    let description: String    // 1-2 sentence detail
    let shareText: String      // Copy-paste share text

    enum PersonalityType: String {
        case bingeCollector    = "binge_collector"
        case productivityJunkie = "productivity_junkie"
        case wellnessWarrior   = "wellness_warrior"
        case digitalNomad      = "digital_nomad"
        case entertainmentMachine = "entertainment_machine"
        case frugalist         = "frugalist"
        case premiumMaximizer  = "premium_maximizer"
        case trialHopper       = "trial_hopper"
    }
}

// MARK: - Engine

enum PersonalityEngine {

    // MARK: - Category keyword buckets

    private static let streamingKeywords = ["netflix", "hulu", "disney", "max", "hbo", "peacock",
        "paramount", "prime video", "apple tv", "youtube", "crunchyroll", "tubi", "fubo",
        "sling", "philo", "mubi", "shudder", "britbox", "discovery"]

    private static let musicKeywords = ["spotify", "apple music", "tidal", "deezer", "pandora",
        "siriusxm", "amazon music", "soundcloud", "napster"]

    private static let productivityKeywords = ["notion", "slack", "zoom", "microsoft 365", "office",
        "adobe", "figma", "linear", "asana", "monday", "clickup", "todoist", "craft",
        "1password", "lastpass", "dashlane", "dropbox", "onedrive", "google one", "icloud",
        "github", "jetbrains", "grammarly", "readwise"]

    private static let healthKeywords = ["peloton", "whoop", "headspace", "calm", "noom", "ww",
        "weightwatchers", "myfitnesspal", "strava", "garmin", "oura", "eight sleep",
        "future", "tonal", "ifiit", "nutracheck", "loseit", "cronometer", "fitbod",
        "apple fitness", "ten percent", "waking up", "insight timer"]

    private static let vpnCloudKeywords = ["nordvpn", "expressvpn", "surfshark", "mullvad",
        "protonvpn", "cyberghost", "tunnelbear", "backblaze", "carbonite", "pcloud",
        "tresorit", "wasabi", "idrive"]

    // MARK: - Compute

    static func compute(subscriptions: [Subscription]) -> SubscriptionPersonality {
        let active = subscriptions.filter { $0.status == .active || $0.status == .trial }
        let total = active.count
        let monthly = active.reduce(Decimal(0)) { $0 + $1.monthlyCost }
        let trials = subscriptions.filter { $0.status == .trial }.count

        // Count by category
        let streaming = active.filter { matches($0, keywords: streamingKeywords) }.count
        let music     = active.filter { matches($0, keywords: musicKeywords) }.count
        let prod      = active.filter { matches($0, keywords: productivityKeywords) }.count
        let health    = active.filter { matches($0, keywords: healthKeywords) }.count
        let vpnCloud  = active.filter { matches($0, keywords: vpnCloudKeywords) }.count

        let monthlyDouble = NSDecimalNumber(decimal: monthly).doubleValue

        // Trial Hopper — majority are trials
        if trials >= 3 || (total > 0 && Double(trials) / Double(max(1, total)) >= 0.5) {
            return personality(
                type: .trialHopper,
                emoji: "🎣",
                name: "The Trial Hopper",
                headline: "Why buy when you can try?",
                description: "You've mastered the art of free trials. You currently have \(trials) active trials — a true optimization strategy or a very organized form of chaos.",
                monthlyDouble: monthlyDouble,
                count: total
            )
        }

        // Wellness Warrior — health dominates
        if health >= 2 || (total > 0 && Double(health) / Double(max(1, total)) >= 0.4) {
            return personality(
                type: .wellnessWarrior,
                emoji: "🏋️",
                name: "The Wellness Warrior",
                headline: "You invest in yourself — literally.",
                description: "Health and fitness subscriptions make up a significant share of your stack. You're not just spending money — you're optimizing your body.",
                monthlyDouble: monthlyDouble,
                count: total
            )
        }

        // Productivity Junkie — tools dominate
        if prod >= 3 || (total > 0 && Double(prod) / Double(max(1, total)) >= 0.45) {
            return personality(
                type: .productivityJunkie,
                emoji: "⚙️",
                name: "The Productivity Junkie",
                headline: "If it makes you 1% more efficient, you'll pay for it.",
                description: "Your subscription stack reads like a Y Combinator pitch deck. You have \(prod) productivity tools — you definitely have a system.",
                monthlyDouble: monthlyDouble,
                count: total
            )
        }

        // Digital Nomad — VPN/cloud heavy
        if vpnCloud >= 2 {
            return personality(
                type: .digitalNomad,
                emoji: "🌐",
                name: "The Digital Nomad",
                headline: "Your data is encrypted, your files are synced, and your location is private.",
                description: "VPNs, cloud storage, and security tools are your stack of choice. You live digitally — and you protect it seriously.",
                monthlyDouble: monthlyDouble,
                count: total
            )
        }

        // Binge Collector — streaming heavy
        if streaming >= 3 || (streaming >= 2 && music >= 2) {
            return personality(
                type: .bingeCollector,
                emoji: "📺",
                name: "The Binge Collector",
                headline: "You have \(streaming + music) entertainment services and still say there's nothing to watch.",
                description: "Streaming services dominate your subscription stack. The good news: you'll never run out of content. The bad news: you're paying for half of it while asleep.",
                monthlyDouble: monthlyDouble,
                count: total
            )
        }

        // Premium Maximizer — high spend, many subs
        if monthlyDouble > 200 || total >= 10 {
            return personality(
                type: .premiumMaximizer,
                emoji: "💎",
                name: "The Premium Maximizer",
                headline: "You go premium on everything — and you use most of it.",
                description: "High spend, high count. You value quality and convenience above all. \(total) subscriptions, \(CurrencyManager.shared.format(monthly))/month — a power user by any measure.",
                monthlyDouble: monthlyDouble,
                count: total
            )
        }

        // Frugalist — low spend, few subs
        if monthlyDouble < 50 || total <= 3 {
            return personality(
                type: .frugalist,
                emoji: "🎯",
                name: "The Frugalist",
                headline: "Every subscription earns its place. No exceptions.",
                description: "Lean stack, intentional choices. You spend \(CurrencyManager.shared.format(monthly))/month across \(total) subscription\(total == 1 ? "" : "s") — only what you actually use.",
                monthlyDouble: monthlyDouble,
                count: total
            )
        }

        // Entertainment Machine — mixed media
        return personality(
            type: .entertainmentMachine,
            emoji: "🎬",
            name: "The Entertainment Machine",
            headline: "Work hard, stream harder.",
            description: "A balanced mix of entertainment, productivity, and services. \(total) subscriptions, \(CurrencyManager.shared.format(monthly))/month — you live a well-subscribed life.",
            monthlyDouble: monthlyDouble,
            count: total
        )
    }

    // MARK: - Helpers

    private static func matches(_ sub: Subscription, keywords: [String]) -> Bool {
        let name = sub.name.lowercased()
        let cat  = (sub.category ?? "").lowercased()
        return keywords.contains { name.contains($0) || cat.contains($0) }
    }

    private static func personality(
        type: SubscriptionPersonality.PersonalityType,
        emoji: String,
        name: String,
        headline: String,
        description: String,
        monthlyDouble: Double,
        count: Int
    ) -> SubscriptionPersonality {
        let shareText = "\(emoji) My subscription personality: \"\(name)\"\n\(headline)\n\nFound with Pausely — track & optimize your subscriptions."
        return SubscriptionPersonality(
            type: type,
            emoji: emoji,
            name: name,
            headline: headline,
            description: description,
            shareText: shareText
        )
    }
}

// MARK: - Personality Profile Card (Profile tab, always visible)

struct PersonalityProfileCard: View {
    let subscriptions: [Subscription]
    let onTap: () -> Void

    private var personality: SubscriptionPersonality {
        PersonalityEngine.compute(subscriptions: subscriptions)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Emoji badge
                ZStack {
                    Circle()
                        .fill(Color.accentMint.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Text(personality.emoji)
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("YOUR PERSONALITY")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                            .tracking(1.2)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.obsidianTextTertiary)
                    }
                    Text(personality.name)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text(personality.headline)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.accentMint.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
