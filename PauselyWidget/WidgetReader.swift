//
//  WidgetReader.swift
//  PauselyWidget
//
//  Reads data published by the main app into the shared App Group UserDefaults.
//  Self-contained — no dependencies on the main app target.
//

import Foundation

enum WidgetReader {
    private static let suiteName = "group.com.pausely.app.shared"

    // MARK: - Summary

    static func readSummary() -> WidgetSummaryData {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return WidgetSummaryData()
        }
        return WidgetSummaryData(
            monthlySpend: defaults.double(forKey: "widget_monthlySpend"),
            activeCount: defaults.integer(forKey: "widget_activeCount"),
            upcomingCount: defaults.integer(forKey: "widget_upcomingCount"),
            currencyCode: defaults.string(forKey: "widget_currencyCode") ?? "USD",
            topInsight: defaults.string(forKey: "widget_topInsight") ?? "Track your subscriptions"
        )
    }

    // MARK: - Trials

    static func readTrials() -> [WidgetTrialInfo] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "widget_trials"),
              let trials = try? JSONDecoder().decode([WidgetTrialInfo].self, from: data) else {
            return []
        }
        return trials.filter { $0.trialEndsAt > Date() }.sorted { $0.trialEndsAt < $1.trialEndsAt }
    }

    // MARK: - Live Activity

    static func readLiveActivityName() -> String {
        UserDefaults(suiteName: suiteName)?.string(forKey: "liveActivity_subscriptionName") ?? "Subscription"
    }

    static func readLiveActivityDate() -> Date {
        let ts = UserDefaults(suiteName: suiteName)?.double(forKey: "liveActivity_renewalDate") ?? 0
        return Date(timeIntervalSince1970: ts)
    }

    static func readLiveActivityAmount() -> Double {
        UserDefaults(suiteName: suiteName)?.double(forKey: "liveActivity_amount") ?? 0
    }

    static func readLiveActivityFrequency() -> String {
        UserDefaults(suiteName: suiteName)?.string(forKey: "liveActivity_frequency") ?? "Monthly"
    }
}
