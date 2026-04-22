//
//  SubscriptionDetectionEngine.swift
//  Pausely
//
//  Auto-detect subscriptions via Screen Time session tracking
//

import Foundation
import SwiftUI

// MARK: - Detected Subscription

/// Represents a subscription detected via Screen Time usage patterns
struct DetectedSubscription: Identifiable {
    let id = UUID()
    let bundleId: String
    let name: String
    let category: SubscriptionCategory
    let weeklySessions: Int
    let confidence: Double
    let suggestedPrice: Double
    let iconName: String
    let familyPlanAvailable: Bool

    var confidencePercent: Int {
        Int(confidence * 100)
    }

    /// Convert to a suggested Subscription
    func toSubscription() -> Subscription {
        Subscription(
            name: name,
            bundleIdentifier: bundleId,
            category: category.rawValue,
            amount: Decimal(suggestedPrice),
            billingFrequency: .monthly,
            status: .active,
            isDetected: true
        )
    }
}

// MARK: - Subscription Detection Engine

/// Engine for automatically detecting subscriptions based on Screen Time usage patterns
/// Monitors app usage sessions and detects subscriptions when usage exceeds thresholds
@MainActor
final class SubscriptionDetectionEngine: ObservableObject {
    static let shared = SubscriptionDetectionEngine()

    // MARK: - Published State

    @Published private(set) var detectedApps: [DetectedSubscription] = []
    @Published private(set) var isDetecting = false
    @Published private(set) var lastDetectionDate: Date?

    // MARK: - Private Properties

    private let screenTimeManager = ScreenTimeManager.shared
    private let sharedDefaults = UserDefaults(suiteName: "group.com.pausely.app.shared")

    /// Sessions per week threshold to be considered a "subscription"
    private let weeklySessionThreshold = 7

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Detect subscriptions based on Screen Time usage patterns
    /// - Returns: Array of detected subscriptions sorted by confidence
    func detectSubscriptions() async -> [DetectedSubscription] {
        isDetecting = true
        defer { isDetecting = false }

        var detected: [DetectedSubscription] = []
        let catalog = SubscriptionCatalogService.shared

        // Get all known bundle IDs from catalog
        for bundleId in catalog.allBundleIds {
            // Skip if already tracked as a subscription
            guard !isAlreadyTracked(bundleId: bundleId) else { continue }

            // Get weekly session count for this app
            let weeklySessions = getWeeklySessions(for: bundleId)

            // Skip if below threshold
            guard weeklySessions >= weeklySessionThreshold else { continue }

            // Find in catalog
            if let info = catalog.entry(for: bundleId) {
                let confidence = calculateConfidence(sessions: weeklySessions, info: info)

                let detectedSub = DetectedSubscription(
                    bundleId: bundleId,
                    name: info.name,
                    category: info.category,
                    weeklySessions: weeklySessions,
                    confidence: confidence,
                    suggestedPrice: info.defaultPrice,
                    iconName: info.iconName,
                    familyPlanAvailable: info.familyPlanAvailable
                )
                detected.append(detectedSub)
            }
        }

        // Sort by confidence (highest first)
        detected.sort { $0.confidence > $1.confidence }
        detectedApps = detected
        lastDetectionDate = Date()

        return detected
    }

    /// Get detailed usage data for a detected subscription
    func getUsageDetails(for bundleId: String) -> (sessions: Int, estimatedMinutes: Int, confidence: Double)? {
        let weeklySessions = getWeeklySessions(for: bundleId)

        guard weeklySessions >= weeklySessionThreshold else { return nil }

        let catalog = SubscriptionCatalogService.shared
        guard let info = catalog.entry(for: bundleId) else { return nil }

        let confidence = calculateConfidence(sessions: weeklySessions, info: info)
        let estimatedMinutes = weeklySessions * 15 // Assume ~15 min per session

        return (weeklySessions, estimatedMinutes, confidence)
    }

    /// Check if a specific app has been detected as a subscription
    func isDetected(bundleId: String) -> Bool {
        detectedApps.contains { $0.bundleId == bundleId }
    }

    /// Get confidence level for an app
    func confidenceFor(bundleId: String) -> Double? {
        detectedApps.first { $0.bundleId == bundleId }?.confidence
    }

    /// Add a detected subscription to tracking
    func addToTrackedSubscriptions(_ detected: DetectedSubscription) async {
        // This would typically call SubscriptionStore to add the subscription
        // For now, we store it in shared UserDefaults for the DeviceActivityMonitor
        var tracked = getTrackedBundleIds()
        if !tracked.contains(detected.bundleId) {
            tracked.append(detected.bundleId)
            sharedDefaults?.set(tracked, forKey: "tracked_subscription_bundle_ids")
        }

        // Remove from detected list
        detectedApps.removeAll { $0.bundleId == detected.bundleId }
    }

    /// Get list of bundle IDs currently being tracked as subscriptions
    func getTrackedBundleIds() -> [String] {
        sharedDefaults?.stringArray(forKey: "tracked_subscription_bundle_ids") ?? []
    }

    /// Get suggested subscriptions based on weekly sessions
    func getSuggestedSubscriptions(limit: Int = 5) -> [DetectedSubscription] {
        Array(detectedApps.prefix(limit))
    }

    /// Clear detection cache and re-detect
    func refreshDetection() async -> [DetectedSubscription] {
        detectedApps.removeAll()
        return await detectSubscriptions()
    }

    // MARK: - Private Methods

    /// Get weekly session count for a bundle ID from shared UserDefaults
    private func getWeeklySessions(for bundleId: String) -> Int {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        let weekKey = "\(year)_week_\(weekOfYear)"
        let key = "weekly_sessions_\(bundleId)_\(weekKey)"
        return sharedDefaults?.integer(forKey: key) ?? 0
    }

    /// Check if a bundle ID is already being tracked as a subscription
    private func isAlreadyTracked(bundleId: String) -> Bool {
        // Check if already in user's subscriptions
        if SubscriptionStore.shared.subscriptions.contains(where: { $0.bundleIdentifier == bundleId }) {
            return true
        }
        // Check if explicitly tracked by detection engine
        return getTrackedBundleIds().contains(bundleId)
    }

    /// Calculate confidence score based on usage patterns
    private func calculateConfidence(sessions: Int, info: CatalogEntry) -> Double {
        var confidence: Double

        // Base confidence on session count
        if sessions <= 14 {
            confidence = 0.70
        } else if sessions <= 30 {
            confidence = 0.90
        } else {
            confidence = 1.0
        }

        // Boost confidence for apps with family plans (common subscription pattern)
        if info.familyPlanAvailable {
            confidence = min(1.0, confidence + 0.05)
        }

        return confidence
    }
}

// MARK: - Preview Support

#if DEBUG
extension SubscriptionDetectionEngine {
    static var preview: SubscriptionDetectionEngine {
        let engine = SubscriptionDetectionEngine()
        engine.detectedApps = [
            DetectedSubscription(
                bundleId: "com.netflix.Netflix",
                name: "Netflix",
                category: .entertainment,
                weeklySessions: 21,
                confidence: 0.95,
                suggestedPrice: 15.49,
                iconName: "tv.fill",
                familyPlanAvailable: true
            ),
            DetectedSubscription(
                bundleId: "com.spotify.client",
                name: "Spotify",
                category: .entertainment,
                weeklySessions: 35,
                confidence: 1.0,
                suggestedPrice: 10.99,
                iconName: "music.note",
                familyPlanAvailable: true
            ),
            DetectedSubscription(
                bundleId: "com.tinyspeck.slackgap",
                name: "Slack",
                category: .productivity,
                weeklySessions: 15,
                confidence: 0.80,
                suggestedPrice: 8.75,
                iconName: "message.fill",
                familyPlanAvailable: true
            ),
        ]
        return engine
    }
}
#endif
