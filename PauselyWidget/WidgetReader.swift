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
            activeCount: defaults.integer(forKey: "widget_activeCount"),
            upcomingCount: defaults.integer(forKey: "widget_upcomingCount"),
            topInsight: defaults.string(forKey: "widget_topInsight") ?? "Track your subscriptions",
            monthlyText: defaults.string(forKey: "widget_monthlySpendText") ?? "–",
            monthlyWholeText: defaults.string(forKey: "widget_monthlySpendWholeText") ?? "–",
            yearlyWholeText: defaults.string(forKey: "widget_yearlySpendWholeText") ?? "–"
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

    // MARK: - Next charge
    // The key names date from an earlier design. They stay as they are, so a widget that refreshes after an
    // update, before the app is next opened, still finds what the previous version wrote.

    /// The subscription that charges next, or "" when there is none.
    static func readNextChargeName() -> String {
        UserDefaults(suiteName: suiteName)?.string(forKey: "liveActivity_subscriptionName") ?? ""
    }

    /// The day of that charge, or nil when there is none.
    static func readNextChargeDate() -> Date? {
        let seconds = UserDefaults(suiteName: suiteName)?.double(forKey: "liveActivity_renewalDate") ?? 0
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    /// The amount of that charge as the app formatted it, or "" when there is none.
    static func readNextChargeText() -> String {
        UserDefaults(suiteName: suiteName)?.string(forKey: "liveActivity_amountText") ?? ""
    }
}
