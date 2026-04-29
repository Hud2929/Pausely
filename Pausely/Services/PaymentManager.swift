//
//  PaymentManager.swift
//  Pausely
//
//  OPTIMIZED Tier Structure - 2-Sub Limit Drives Conversion
//

import Foundation
import StoreKit

// MARK: - Payment Source (Backward Compatibility)
enum PaymentSource: String, Codable {
    case storeKitMonthly = "storekit_monthly"
    case storeKitAnnual = "storekit_annual"
    case referral = "referral"
    case promoCode = "promo_code"
}

// MARK: - Subscription Tier (OPTIMIZED FOR CONVERSION)
/// Strategic tier structure: 2-sub limit creates urgency, killer features drive upgrade
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
    static let plus = pro
    static let plusAnnual = proAnnual
    
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
    
    var price: String {
        let currencyCode = CurrencyManager.shared.selectedCurrency
        return formatPrice(priceDecimal, currencyCode: currencyCode)
    }

    var monthlyPrice: Decimal {
        switch self {
        case .free:        return 0
        case .pro:         return 7.99
        case .proAnnual:   return Decimal(79.99) / 12
        }
    }

    // MARK: - Currency-Aware Pricing (rounded to .99)

    /// Base USD prices for Pro tier
    private var baseUSDPrice: Decimal {
        switch self {
        case .free:        return 0
        case .pro:         return 7.99
        case .proAnnual:   return 79.99
        }
    }

    private var priceDecimal: Decimal {
        baseUSDPrice
    }

    /// Get price formatted in user's selected currency, rounded to .99
    func priceInUserCurrency() -> String {
        let currencyCode = CurrencyManager.shared.selectedCurrency
        let price = convertToUserCurrency(baseUSDPrice)
        let rounded = roundTo99(price)
        return formatPrice(rounded, currencyCode: currencyCode)
    }

    /// Get monthly price in user's selected currency, rounded to .99
    func monthlyPriceInUserCurrency() -> String {
        let currencyCode = CurrencyManager.shared.selectedCurrency
        let monthly = monthlyPrice
        if monthly == 0 { return formatPrice(0, currencyCode: currencyCode) }
        let price = convertToUserCurrency(monthly)
        let rounded = roundTo99(price)
        return formatPrice(rounded, currencyCode: currencyCode)
    }

    /// Convert USD price to user's selected currency
    /// USD and CAD use the same base price (7.99); other currencies are converted.
    private func convertToUserCurrency(_ usdPrice: Decimal) -> Decimal {
        let currencyCode = CurrencyManager.shared.selectedCurrency
        guard currencyCode != "USD", currencyCode != "CAD" else { return usdPrice }

        let rate = CurrencyManager.shared.exchangeRates[currencyCode] ?? 1.0
        return usdPrice * Decimal(rate)
    }

    /// Round price to nearest .99
    private func roundTo99(_ price: Decimal) -> Decimal {
        let doublePrice = NSDecimalNumber(decimal: price).doubleValue
        let dollars = floor(doublePrice)
        return Decimal(dollars + 0.99)
    }

    /// Format price with proper currency formatting
    private func formatPrice(_ price: Decimal, currencyCode: String) -> String {
        return CurrencyManager.shared.format(price, currencyCode: currencyCode)
    }
    
    var savingsPercent: String {
        switch self {
        case .free:        return ""
        case .pro:         return ""
        case .proAnnual:   return "Save 17%"
        }
    }
    
    // MARK: - STRATEGIC LIMITS (Drives Conversion)
    
    /// FREE: Limited to 2 subscriptions to demonstrate core features.
    /// PRO: Unlimited
    var subscriptionLimit: Int {
        switch self {
        case .free:        return 2
        case .pro, .proAnnual: return Int.max
        }
    }
    
    /// FREE: No bank sync (manual friction drives upgrade)
    /// PRO: Bank sync enabled
    var maxBankAccounts: Int {
        switch self {
        case .free:        return 0
        case .pro, .proAnnual: return Int.max
        }
    }
    
    /// Bank sync is optional feature (not forced)
    var hasBankSync: Bool {
        self >= .pro
    }
    
    /// Cancellation concierge - PREMIUM feature
    var hasCancellationAssist: Bool {
        self >= .pro
    }
    
    /// Pre-filled cancellation forms - PREMIUM
    var hasPreFilledCancellation: Bool {
        self >= .pro
    }
    
    /// Analytics and insights - PREMIUM
    var hasAnalytics: Bool {
        self >= .pro
    }
    
    /// Waste score - PREMIUM (the "aha" moment)
    var hasWasteScore: Bool {
        self >= .pro
    }
    
    /// Price increase alerts - PREMIUM
    var hasPriceAlerts: Bool {
        self >= .pro
    }
    
    /// CSV/PDF export - PREMIUM
    var hasExport: Bool {
        self >= .pro
    }
    
    /// Smart reminders (customizable) - PREMIUM
    var hasSmartReminders: Bool {
        self >= .pro
    }
    
    /// Duplicate detection - PREMIUM
    var hasDuplicateDetection: Bool {
        self >= .pro
    }
    
    /// Annual savings calculator - PREMIUM
    var hasSavingsCalculator: Bool {
        self >= .pro
    }
    
    /// Unlimited categories - PREMIUM
    var hasUnlimitedCategories: Bool {
        self >= .pro
    }
    
    // MARK: - Feature Lists (Optimized for Conversion)
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "✓ Track 2 subscriptions",
                "✓ Manual entry only",
                "✓ Basic spend view",
                "✗ No cancellation help",
                "✗ No waste score",
                "✗ No bank sync"
            ]
        case .pro, .proAnnual:
            return [
                "✓ Unlimited subscriptions",
                "✓ Bank sync (optional)",
                "✓ 1-tap cancellation",
                "✓ Waste score AI",
                "✓ Smart insights",
                "✓ Price alerts",
                "✓ Export data",
                "✓ Advanced reminders"
            ]
        }
    }
    
    /// Features that show in paywall highlights
    var highlightedFeatures: [String] {
        switch self {
        case .free:
            return ["2 Subscriptions", "Manual Only"]
        case .pro, .proAnnual:
            return [
                "Cancel for Me 🎯",
                "Find Hidden Subs 🔍",
                "Waste Score AI 📊",
                "Save $100s/yr 💰"
            ]
        }
    }
    
    /// Conversion-optimized marketing copy - personalized, no generic stats
    var marketingCopy: String {
        switch self {
        case .free:
            return "Track up to 2 subscriptions free. Upgrade for unlimited tracking, Smart Import, and cancellation tools."
        case .pro, .proAnnual:
            return "Unlock unlimited subscriptions, Smart Import from bank statements, and instant cancellation assistance."
        }
    }
    
    /// Paywall title
    var paywallTitle: String {
        switch self {
        case .free:        return ""
        case .pro:         return "Unlock Pro"
        case .proAnnual:   return "Unlock Pro"
        }
    }
    
    /// Paywall subtitle
    var paywallSubtitle: String {
        switch self {
        case .free:        return ""
        case .pro:         return "Save money by canceling unused subscriptions"
        case .proAnnual:   return "Save money by canceling unused subscriptions"
        }
    }
}

// MARK: - Payment Manager (OPTIMIZED)
@MainActor
final class PaymentManager: ObservableObject {
    static let shared = PaymentManager()
    
    // MARK: - State
    private(set) var currentTier: SubscriptionTier = .free {
        didSet {
            guard oldValue != currentTier else { return }
            AppSettings.shared.currentTier = currentTier
            objectWillChange.send()
        }
    }
    private(set) var isLoading = false
    private(set) var products: [Product] = []

    // MARK: - Debug Override
    #if DEBUG
    private var debugPremiumOverride: Bool {
        UserDefaults.standard.bool(forKey: "debug_auth_bypass")
    }
    #endif
    
    // MARK: - Product IDs (must match App Store Connect)
    private let productIDs: Set<String> = [
        "com.pausely.premium.monthly",
        "com.pausely.premium.annual"
    ]
    
    // MARK: - Backward Compatibility Properties
    var isPremium: Bool {
        get {
            #if DEBUG
            if debugPremiumOverride { return true }
            #endif
            return currentTier > .free
        }
        set { /* No-op - tier is managed by StoreKit */ }
    }
    var isPro: Bool { isPremium }
    var canPauseSubscriptions: Bool { isPremium }
    
    /// Legacy property - free tier is now 2 subs
    static let freeTierLimit: Int = 2
    var freeTierLimit: Int { Self.freeTierLimit }
    
    /// Can pause subscriptions
    var canPause: Bool { currentTier > .free }
    
    // MARK: - Initialization
    private init() {
        // 1. Restore persisted tier first (survives app restarts)
        self.currentTier = AppSettings.shared.currentTier

        Task {
            await loadProducts()
            // 2. Verify against StoreKit (may downgrade if subscription expired)
            await updateCurrentEntitlements()
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
    
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCurrentEntitlements()
            await transaction.finish()
            STAnimation.success()
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        try? await AppStore.sync()
        await updateCurrentEntitlements()
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
        // If StoreKit is empty (e.g. referral/LemonSqueezy Pro), keep the persisted tier.
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
    
    // MARK: - Feature Checks (OPTIMIZED)
    
    /// Check if user can add more subscriptions
    func canAddSubscription(currentCount: Int) -> Bool {
        currentCount < currentTier.subscriptionLimit
    }
    
    func hasReachedSubscriptionLimit(currentCount: Int) -> Bool {
        currentTier == .free && currentCount >= Self.freeTierLimit
    }
    
    /// Check if user can use bank sync (optional feature)
    var canUseBankSync: Bool {
        currentTier.hasBankSync
    }
    
    /// Check if user can connect bank accounts
    func canConnectBankAccount(currentCount: Int) -> Bool {
        currentCount < currentTier.maxBankAccounts
    }
    
    /// Check if cancellation assist is available
    var canUseCancellationAssist: Bool {
        currentTier.hasCancellationAssist
    }
    
    /// Check if waste score is available
    var canUseWasteScore: Bool {
        currentTier.hasWasteScore
    }
    
    /// Check if analytics are available
    var canUseAnalytics: Bool {
        currentTier.hasAnalytics
    }
    
    /// Check if export is available
    var canUseExport: Bool {
        currentTier.hasExport
    }
    
    /// Check if smart reminders available
    var canUseSmartReminders: Bool {
        currentTier.hasSmartReminders
    }
    
    // MARK: - Backward Compatibility Methods
    
    /// Legacy method for activating premium (now maps to Pro)
    func activatePremium(source: PaymentSource) {
        Task {
            await updateCurrentEntitlements()
        }
    }
    
    /// Legacy method for granting free Pro (referrals)
    func grantFreeProForReferrals() {
        currentTier = .pro
    }
    
    /// Check if export is available
    var canUseExportFeature: Bool {
        currentTier.hasExport
    }
}
