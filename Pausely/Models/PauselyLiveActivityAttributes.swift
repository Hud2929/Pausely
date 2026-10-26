//
//  PauselyLiveActivityAttributes.swift
//  Pausely
//
//  Live Activity Attributes for renewal countdown
//

import ActivityKit
import Foundation
import os.log

// MARK: - Live Activity Attributes
// NOTE: This file must be included in BOTH the main app target AND the widget extension target
struct PauselyLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var daysUntilRenewal: Int
        var hoursUntilRenewal: Int
        var isUrgent: Bool // true when <= 3 days
    }

    // Static data set when starting the activity
    var subscriptionName: String
    var renewalDate: Date
    /// The next charge in the subscription's own currency, formatted by the app ("$129.99").
    var amountText: String
    var frequency: String
}

// MARK: - Live Activity Manager
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<PauselyLiveActivityAttributes>?

    private init() {}

    // MARK: - Start

    func startLiveActivity(for subscription: Subscription) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            os_log("Live Activities not enabled", log: .default, type: .info)
            return
        }

        // End any existing activity first
        endCurrentActivity()

        let attributes = PauselyLiveActivityAttributes(
            subscriptionName: subscription.name,
            renewalDate: subscription.calculatedNextBillingDate ?? Date().addingTimeInterval(86400 * 7),
            amountText: subscription.chargeText,
            frequency: subscription.billingFrequency.displayName
        )

        let initialState = calculateState(for: attributes.renewalDate)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            currentActivity = activity
            os_log("Started Live Activity: %{public}@ id=%{public}@", log: .default, type: .info, subscription.name, activity.id)
        } catch {
            os_log("Failed to start Live Activity: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    // MARK: - Update


    // MARK: - End

    func endCurrentActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .default)
            currentActivity = nil
        }
    }


    // MARK: - Private

    private func calculateState(for renewalDate: Date) -> PauselyLiveActivityAttributes.ContentState {
        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: renewalDate)
        let days = max(0, components.day ?? 0)
        let hours = max(0, components.hour ?? 0)
        return PauselyLiveActivityAttributes.ContentState(
            daysUntilRenewal: days,
            hoursUntilRenewal: hours,
            isUrgent: days <= 3
        )
    }
}

// MARK: - App Intent for Live Activity (iOS 16.2+)
#if canImport(AppIntents)
import AppIntents

struct EndLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Live Activity"

    func perform() async throws -> some IntentResult {
        await LiveActivityManager.shared.endCurrentActivity()
        return .result()
    }
}
#endif
