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


// MARK: - Preview Support

#if DEBUG
#endif
