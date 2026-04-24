//
//  TipKitConfig.swift
//  Pausely
//
//  TipKit integration for contextual feature discovery
//

import TipKit
import SwiftUI
import os.log

// MARK: - TipKit Configuration
@MainActor
enum TipKitConfiguration {
    static func configure() {
        do {
            try Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        } catch {
            os_log("TipKit configuration failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
}

// MARK: - Add Subscription Tip
struct AddSubscriptionTip: Tip {
    var title: Text {
        Text("Track your first subscription")
    }

    var message: Text? {
        Text("Tap the + button to add Netflix, Spotify, or any service you pay for.")
    }

    var image: Image? {
        Image(systemName: "plus.circle.fill")
    }
}

// MARK: - Pause Tip
struct PauseSubscriptionTip: Tip {
    var title: Text {
        Text("Save money with Pause")
    }

    var message: Text? {
        Text("Temporarily pause subscriptions you aren't using. We'll remind you before they resume.")
    }

    var image: Image? {
        Image(systemName: "pause.circle.fill")
    }
}

// MARK: - Cost Per Use Tip
struct CostPerUseTip: Tip {
    var title: Text {
        Text("Discover cost-per-use")
    }

    var message: Text? {
        Text("See how much you pay per hour of actual usage. Great for finding waste!")
    }

    var image: Image? {
        Image(systemName: "chart.bar.fill")
    }
}

// MARK: - Live Activity Tip
struct LiveActivityTip: Tip {
    var title: Text {
        Text("Live Activity on Lock Screen")
    }

    var message: Text? {
        Text("Enable Live Activities in Settings to see renewal countdowns on your Lock Screen.")
    }

    var image: Image? {
        Image(systemName: "lock.rectangle.on.rectangle.fill")
    }
}

// MARK: - Smart Insights Tip
struct SmartInsightsTip: Tip {
    var title: Text {
        Text("Smart Insights")
    }

    var message: Text? {
        Text("Pausely analyzes your spending and suggests ways to save money.")
    }

    var image: Image? {
        Image(systemName: "lightbulb.fill")
    }
}

// MARK: - Referral Tip
struct ReferralTip: Tip {
    var title: Text {
        Text("Get Pro for Free")
    }

    var message: Text? {
        Text("Share your referral code with friends and earn free Pro time.")
    }

    var image: Image? {
        Image(systemName: "gift.fill")
    }
}
