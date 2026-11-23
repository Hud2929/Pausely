import Foundation

/// Everything Pro unlocks, in one list. The paywall shows these rows, gated screens ask
/// `PaymentManager.isUnlocked(_:)`, and the App Store listing should promise exactly these.
/// Adding a Pro feature means adding a case here, not another `isPremium` check.
/// Reminders, Renewal Verdicts, cancel help, the Savings Receipt and Insights are free on purpose:
/// the core promise is never behind the paywall.
enum ProFeature: String, CaseIterable, Identifiable {
    /// Tracking more than `FreeTier.subscriptionLimit` subscriptions.
    case unlimitedSubscriptions
    /// Rotating streaming services one month at a time (Pause Plan).
    case pausePlan
    /// Reading up to 10 screenshots at once on-device (Free reads 1 at a time).
    case batchScreenshotImport
    /// Pre-drafted cancellation and refund request emails.
    case cancelConcierge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedSubscriptions: return L10n.string("Unlimited subscriptions")
        case .pausePlan: return L10n.string("Pause Plan: rotate your streaming")
        case .batchScreenshotImport: return L10n.string("Batch screenshot import (up to 10 at once)")
        case .cancelConcierge: return L10n.string("Cancel & refund email drafts")
        }
    }
}

extension ProFeature {
    /// The one entitlement rule. Today every Pro feature comes with any paid tier; the switch keeps
    /// moving a single feature between free and Pro a one-line change.
    func isUnlocked(isPro: Bool) -> Bool {
        switch self {
        case .unlimitedSubscriptions, .pausePlan, .batchScreenshotImport, .cancelConcierge:
            return isPro
        }
    }

    static func canAddSubscription(currentCount: Int, isPro: Bool) -> Bool {
        ProFeature.unlimitedSubscriptions.isUnlocked(isPro: isPro) || currentCount < FreeTier.subscriptionLimit
    }
}

extension PaymentManager {
    func isUnlocked(_ feature: ProFeature) -> Bool {
        feature.isUnlocked(isPro: isPremium)
    }
}
