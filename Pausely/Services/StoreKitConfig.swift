import Foundation
import UIKit
import StoreKit

// MARK: - StoreKit Configuration
/// Central configuration for all StoreKit products
enum StoreKitConfig {
    
    // MARK: - Product IDs
    /// These MUST match exactly what's in App Store Connect
    enum ProductID: String, CaseIterable {
        case monthlyPro = "com.pausely.premium.monthly"
        case annualPro = "com.pausely.premium.annual"
        
        var displayName: String {
            switch self {
            case .monthlyPro: return "Pausely Pro Monthly"
            case .annualPro: return "Pausely Pro Annual"
            }
        }
        
        var description: String {
            switch self {
            case .monthlyPro: return "Unlimited subscriptions + AI features"
            case .annualPro: return "Save 27% with annual billing"
            }
        }
        
        var tier: SubscriptionTier {
            switch self {
            case .monthlyPro: return .premium
            case .annualPro: return .premiumAnnual
            }
        }
    }
    
    // MARK: - Pricing (for display when StoreKit hasn't loaded yet)
    struct FallbackPricing {
        static let monthlyDisplay = "$7.99"
        static let annualDisplay = "$69.99"
        static let monthlyValue = 7.99
        static let annualValue = 69.99
        static let savingsPercent = 27
    }
    
    // MARK: - Trial Configuration
    struct TrialConfig {
        static let enabled = true
        static let days = 7
        static let displayText = "7-Day Free Trial"
    }
    
    // MARK: - Features List
    static let proFeatures: [ProFeature] = [
        ProFeature(icon: "infinity", title: "Unlimited Subscriptions", description: "Track as many subscriptions as you want"),
        ProFeature(icon: "pause.circle.fill", title: "Smart Pause", description: "Pause instead of canceling subscriptions"),
        ProFeature(icon: "sparkles", title: "Subscription Genius AI", description: "Your 24/7 AI subscription advisor"),
        ProFeature(icon: "dollarsign.circle.fill", title: "Auto Refund Hunter", description: "Find & claim refunds for unused time"),
        ProFeature(icon: "wand.and.stars", title: "Bundle Finder", description: "Discover cheaper bundle alternatives"),
        ProFeature(icon: "chart.line.uptrend.xyaxis", title: "Cost Per Hour", description: "See the true value of each service"),
        ProFeature(icon: "brain.head.profile", title: "AI Financial Advisor", description: "Personalized optimization recommendations"),
        ProFeature(icon: "heart.text.square.fill", title: "Health Score", description: "Track your subscription optimization progress"),
        ProFeature(icon: "bell.badge.fill", title: "Price Alerts", description: "Get notified before prices increase"),
        ProFeature(icon: "arrow.left.arrow.right.circle.fill", title: "Smart Alternatives", description: "AI finds cheaper substitutes automatically"),
        ProFeature(icon: "calendar.badge.clock", title: "Renewal Calendar", description: "Visual timeline of upcoming charges"),
        ProFeature(icon: "link.circle.fill", title: "1-Tap Cancel/Pause", description: "Direct links to manage subscriptions"),
        ProFeature(icon: "gift.fill", title: "Referral Rewards", description: "Earn free months by sharing"),
        ProFeature(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed spending insights"),
        ProFeature(icon: "arrow.down.doc.fill", title: "Export Data", description: "Download your data anytime"),
        ProFeature(icon: "envelope.fill", title: "Priority Support", description: "Faster response times")
    ]
    
    struct ProFeature {
        let icon: String
        let title: String
        let description: String
    }
    
    // MARK: - UserDefaults Keys
    struct Keys {
        static let purchasedProductIDs = "storekit_purchased_products"
        static let pendingPurchases = "storekit_pending_purchases"
        static let lastVerificationDate = "storekit_last_verification"
        static let trialUsed = "storekit_trial_used"
        static let originalPurchaseDate = "storekit_original_purchase_date"
    }
}

// MARK: - Review Prompt Manager
/// Manages strategic review prompts at positive user moments.
/// Limits to 3 requests per year to avoid App Store rejection.
@MainActor
final class ReviewPromptManager: ObservableObject {
    static let shared = ReviewPromptManager()

    private let requestsThisYearKey = "review_requests_this_year"
    private let lastRequestDateKey = "review_last_request_date"
    private let currentYearKey = "review_current_year"
    private let hasPromptedAfterOnboardingKey = "review_prompted_after_onboarding"
    private let hasPromptedAfterFirstSubKey = "review_prompted_after_first_sub"
    private let savingsMilestoneKey = "review_savings_milestone_last"
    private let maxRequestsPerYear = 3

    enum ReviewTrigger {
        case onboardingCompleted
        case firstSubscriptionAdded
        case savingsMilestone(amount: Decimal)
    }

    private init() {}

    func requestReviewIfAppropriate(after trigger: ReviewTrigger) {
        guard canRequestReview() else { return }

        switch trigger {
        case .onboardingCompleted:
            guard !UserDefaults.standard.bool(forKey: hasPromptedAfterOnboardingKey) else { return }
            UserDefaults.standard.set(true, forKey: hasPromptedAfterOnboardingKey)
            presentReviewRequest()

        case .firstSubscriptionAdded:
            guard !UserDefaults.standard.bool(forKey: hasPromptedAfterFirstSubKey) else { return }
            UserDefaults.standard.set(true, forKey: hasPromptedAfterFirstSubKey)
            presentReviewRequest()

        case .savingsMilestone(let amount):
            let milestone = Int(truncating: amount as NSNumber) / 50
            let lastMilestone = UserDefaults.standard.integer(forKey: savingsMilestoneKey)
            guard milestone > lastMilestone, milestone >= 1 else { return }
            UserDefaults.standard.set(milestone, forKey: savingsMilestoneKey)
            presentReviewRequest()
        }
    }

    func resetState() {
        UserDefaults.standard.removeObject(forKey: requestsThisYearKey)
        UserDefaults.standard.removeObject(forKey: lastRequestDateKey)
        UserDefaults.standard.removeObject(forKey: currentYearKey)
        UserDefaults.standard.removeObject(forKey: hasPromptedAfterOnboardingKey)
        UserDefaults.standard.removeObject(forKey: hasPromptedAfterFirstSubKey)
        UserDefaults.standard.removeObject(forKey: savingsMilestoneKey)
    }

    private func canRequestReview() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let storedYear = UserDefaults.standard.integer(forKey: currentYearKey)

        if storedYear != currentYear {
            UserDefaults.standard.set(currentYear, forKey: currentYearKey)
            UserDefaults.standard.set(0, forKey: requestsThisYearKey)
            return true
        }

        let requestsThisYear = UserDefaults.standard.integer(forKey: requestsThisYearKey)
        guard requestsThisYear < maxRequestsPerYear else { return false }

        if let lastDate = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let daysSinceLast = calendar.dateComponents([.day], from: lastDate, to: now).day ?? 0
            guard daysSinceLast >= 7 else { return false }
        }

        return true
    }

    private func presentReviewRequest() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let storedYear = UserDefaults.standard.integer(forKey: currentYearKey)
        let requestsThisYear = (storedYear == currentYear)
            ? UserDefaults.standard.integer(forKey: requestsThisYearKey)
            : 0

        UserDefaults.standard.set(currentYear, forKey: currentYearKey)
        UserDefaults.standard.set(requestsThisYear + 1, forKey: requestsThisYearKey)
        UserDefaults.standard.set(Date(), forKey: lastRequestDateKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

// MARK: - StoreKit Product Info
struct StoreKitProductInfo {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
    let price: Decimal
    let currency: String
    let period: String
    let trialPeriod: String?
    let isAnnual: Bool
    
    var formattedPrice: String {
        return displayPrice
    }
    
    var monthlyEquivalent: String? {
        guard isAnnual else { return nil }
        let monthly = (price / 12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: monthly as NSNumber)
    }
}
