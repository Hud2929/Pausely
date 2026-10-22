import Foundation

/// Everything Pro unlocks, in one list. The paywall shows these rows, gated screens ask
/// `PaymentManager.isUnlocked(_:)`, and the App Store listing should promise exactly these.
/// Adding a Pro feature means adding a case here, not another `isPremium` check.
/// Reminders, Renewal Verdicts, cancel help and the Savings Receipt are free on purpose: the core
/// promise is never behind the paywall.
enum ProFeature: String, CaseIterable, Identifiable {
    /// Tracking more than `FreeTier.subscriptionLimit` subscriptions.
    case unlimitedSubscriptions
    /// The full savings analysis on the Analysis tab.
    case deepAnalysis
    /// Cheaper alternatives to a subscription.
    case cheaperAlternatives

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedSubscriptions: return NSLocalizedString("Unlimited subscriptions", comment: "Pro feature")
        case .deepAnalysis: return NSLocalizedString("Deep savings analysis", comment: "Pro feature")
        case .cheaperAlternatives: return NSLocalizedString("Cheaper Alternatives", comment: "Pro feature")
        }
    }

    var icon: String {
        switch self {
        case .unlimitedSubscriptions: return "infinity"
        case .deepAnalysis: return "chart.line.uptrend.xyaxis"
        case .cheaperAlternatives: return "arrow.triangle.swap"
        }
    }
}

extension ProFeature {
    /// The one entitlement rule. Today every Pro feature comes with any paid tier; the switch keeps
    /// moving a single feature between free and Pro a one-line change.
    func isUnlocked(isPro: Bool) -> Bool {
        switch self {
        case .unlimitedSubscriptions, .deepAnalysis, .cheaperAlternatives:
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
