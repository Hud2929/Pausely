//
//  PaymentManager.swift
//  Pausely
//
//  Free tier, Pro tiers and StoreKit purchases. What Pro unlocks lives in ProFeature.swift.
//

import Foundation
import StoreKit

// MARK: - Payment Source (Backward Compatibility)
/// The free tier. One value, used by the store limit, the paywall and the copy in the listing.
enum FreeTier {
    static let subscriptionLimit = 5
}

/// Launch prices in USD. Only used for estimates before StoreKit has loaded; once it has, the paywall
/// shows Apple's real price for the customer's storefront.
enum ProPricing {
    static let monthlyUSD = Decimal(string: "4.99")!
    static let annualUSD = Decimal(string: "29.99")!
}

enum PaymentSource: String, Codable {
    case storeKitMonthly = "storekit_monthly"
    case storeKitAnnual = "storekit_annual"
    case referral = "referral"
    case promoCode = "promo_code"
}

// MARK: - Subscription Tier
enum SubscriptionTier: String, CaseIterable, Comparable, Codable {
    case free = "free"
    case pro = "pro"
    case proAnnual = "pro_annual"
    
    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        let order: [SubscriptionTier] = [.free, .pro, .proAnnual]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
    
    // MARK: - Backward Compatibility
    static let premium = pro
    static let premiumAnnual = proAnnual
    
    var displayName: String {
        switch self {
        case .free:        return "Free"
        case .pro:         return "Pro"
        case .proAnnual:   return "Pro Annual"
        }
    }
    
    var shortName: String {
        switch self {
        case .free:        return "Free"
        case .pro:         return "Pro"
        case .proAnnual:   return "Pro"
        }
    }
    
    var monthlyPrice: Decimal {
        switch self {
        case .free:        return 0
        case .pro:         return ProPricing.monthlyUSD
        case .proAnnual:   return ProPricing.annualUSD / 12
        }
    }

    // MARK: - Limits
    
    /// FREE: up to `FreeTier.subscriptionLimit` subscriptions, enough for most people's real list.
    /// PRO: Unlimited
    var subscriptionLimit: Int {
        switch self {
        case .free:        return FreeTier.subscriptionLimit
        case .pro, .proAnnual: return Int.max
        }
    }
    
}

// MARK: - Payment Manager
@MainActor
final class PaymentManager: ObservableObject {
    static let shared = PaymentManager()
    
    // MARK: - State
    private(set) var currentTier: SubscriptionTier = .free {
        didSet {
            guard oldValue != currentTier else { return }
            AppSettings.shared.currentTier = currentTier
            objectWillChange.send()
            // Auto-add Pausely Pro to subscription list when user upgrades
            if oldValue == .free && currentTier > .free {
                Task { await autoAddPauselyProIfNeeded() }
            }
        }
    }
    private(set) var products: [Product] = []

    // MARK: - Debug Override
    #if DEBUG
    private var debugPremiumOverride: Bool {
        UserDefaults.standard.bool(forKey: "debug_premium_override")
    }

    private var debugFreePro: Bool {
        UserDefaults.standard.bool(forKey: "debug_free_pro")
    }
    #else
    private var debugPremiumOverride: Bool { false }
    private var debugFreePro: Bool { false }
    #endif

    // MARK: - Product IDs (must match App Store Connect)
    private let productIDs: Set<String> = [
        "com.pausely.premium.monthly",
        "com.pausely.premium.annual"
    ]

    /// The effective tier including debug override.
    /// Writes still go to `currentTier` so StoreKit and purchase flows work normally.
    private var resolvedTier: SubscriptionTier {
        debugFreePro ? .pro : currentTier
    }

    // MARK: - Backward Compatibility Properties
    var isPremium: Bool {
        get {
            #if DEBUG
            if debugPremiumOverride { return true }
            #endif
            return resolvedTier > .free
        }
        set { /* No-op - tier is managed by StoreKit */ }
    }


    
    // MARK: - Initialization
    private init() {
        #if DEBUG
        if debugPremiumOverride {
            self.currentTier = .pro
        } else {
            self.currentTier = AppSettings.shared.currentTier
        }
        #else
        // 1. Restore persisted tier first (survives app restarts)
        self.currentTier = AppSettings.shared.currentTier
        #endif

        Task {
            await loadProducts()
            // 2. Verify against StoreKit (may downgrade if subscription expired)
            await updateCurrentEntitlements()
            // 3. Auto-add Pausely Pro if user is already Pro on launch
            if self.currentTier > .free {
                await autoAddPauselyProIfNeeded()
            }
        }

    }
    
    // MARK: - StoreKit Integration
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            PauselyLogger.error("Failed to load products: \(error)", category: "Payment")
        }
    }
    
    
    
    // MARK: - Entitlements
    
    func updateCurrentEntitlements() async {
        var storeKitTier: SubscriptionTier = .free
        var hasStoreKitEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.revocationDate == nil else { continue }

            hasStoreKitEntitlement = true
            let tier = tierForProduct(transaction.productID)
            if tier > storeKitTier {
                storeKitTier = tier
            }
        }

        // Only override persisted tier if StoreKit has an active entitlement.
        // If StoreKit is empty (e.g. referral Pro), keep the persisted tier.
        if hasStoreKitEntitlement {
            currentTier = storeKitTier
        }
    }
    
    private func tierForProduct(_ productID: String) -> SubscriptionTier {
        switch productID {
        case "com.pausely.premium.monthly":  return .pro
        case "com.pausely.premium.annual":   return .proAnnual
        default:                             return .free
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Feature Checks
    
    /// Check if user can add more subscriptions
    func canAddSubscription(currentCount: Int) -> Bool {
        ProFeature.canAddSubscription(currentCount: currentCount, isPro: isPremium)
    }

    func hasReachedSubscriptionLimit(currentCount: Int) -> Bool {
        !canAddSubscription(currentCount: currentCount)
    }

    // MARK: - Backward Compatibility Methods
    
    /// Legacy method for activating premium (now maps to Pro)
    func activatePremium(source: PaymentSource) {
        Task {
            switch source {
            case .storeKitMonthly, .storeKitAnnual:
                await updateCurrentEntitlements()
            case .referral, .promoCode:
                currentTier = .pro
            }
        }
    }


    // MARK: - Auto-Add Pausely Pro Subscription

    private let pauselyProAutoAddedKey = "pausely_pro_auto_added"

    /// Automatically adds Pausely Pro to the user's subscription list when they upgrade.
    /// Uses a UserDefaults flag to prevent duplicate additions.
    /// What Pausely itself costs this customer, from StoreKit: the storefront's price and currency,
    /// whether the free trial is running, and when the next charge happens.
    static func pauselyEntry(for tier: SubscriptionTier) async -> (amount: Decimal, currency: String, frequency: BillingFrequency, nextCharge: Date?, isTrial: Bool) {
        let frequency: BillingFrequency = tier == .proAnnual ? .yearly : .monthly
        let product = StoreKitManager.shared.product(for: tier)
        var amount = product?.price ?? (tier == .proAnnual ? ProPricing.annualUSD : ProPricing.monthlyUSD)
        let currency = product?.priceFormatStyle.currencyCode ?? "USD"
        var nextCharge = Calendar.current.date(byAdding: frequency == .yearly ? .year : .month, value: 1, to: Date())
        var isTrial = false
        if let product, let latest = await Transaction.latest(for: product.id), case .verified(let transaction) = latest {
            if let expires = transaction.expirationDate { nextCharge = expires }
            isTrial = transaction.offer?.type == .introductory
        }
        if amount <= 0 { amount = tier == .proAnnual ? ProPricing.annualUSD : ProPricing.monthlyUSD }
        return (amount, currency, frequency, nextCharge, isTrial)
    }

    func autoAddPauselyProIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: pauselyProAutoAddedKey) else { return }

        let store = SubscriptionStore.shared

        // Check if Pausely Pro is already tracked
        let alreadyAdded = store.subscriptions.contains {
            $0.bundleIdentifier == "com.pausely.app.Pausely" ||
            $0.name.lowercased().contains("pausely")
        }
        guard !alreadyAdded else {
            UserDefaults.standard.set(true, forKey: pauselyProAutoAddedKey)
            return
        }

        guard currentTier > .free else { return }
        let entry = await Self.pauselyEntry(for: currentTier)
        let subscription = Subscription(
            name: "Pausely Pro",
            bundleIdentifier: "com.pausely.app.Pausely",
            category: SubscriptionCategory.productivity.rawValue,
            amount: entry.amount,
            currency: entry.currency,
            billingFrequency: entry.frequency,
            nextBillingDate: entry.nextCharge,
            trialEndsAt: entry.isTrial ? entry.nextCharge : nil,
            status: entry.isTrial ? .trial : .active,
            isDetected: true
        )

        do {
            _ = try await store.addSubscription(subscription)
            UserDefaults.standard.set(true, forKey: pauselyProAutoAddedKey)
            PauselyLogger.info("Auto-added Pausely Pro subscription (\(currentTier.displayName))", category: "Payment")
        } catch {
            PauselyLogger.error("Failed to auto-add Pausely Pro: \(error)", category: "Payment")
        }
    }

}
