import Foundation
import StoreKit
import SwiftUI

// MARK: - StoreKit Manager
/// Handles in-app purchases using Apple's StoreKit 2
@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    // MARK: - Published State
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingPurchase: Product?
    
    // MARK: - Product IDs (must match App Store Connect)
    enum ProductID: String, CaseIterable {
        case monthly = "com.pausely.premium.monthly"
        case annual = "com.pausely.premium.annual"
        
        var displayName: String {
            switch self {
            case .monthly: return "Monthly Pro"
            case .annual: return "Annual Pro"
            }
        }
    }
    
    // MARK: - Private
    private var updates: Task<Void, Never>?
    private let entitlementManager = EntitlementManager.shared
    
    private init() {
        // Start listening for transaction updates
        updates = observeTransactionUpdates()
        
        // Load purchased products on init
        Task {
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Product Loading
    
    /// Fetches available products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            PauselyLogger.info("Loaded \(products.count) products from App Store", category: "StoreKit")

            for product in products {
                PauselyLogger.debug("   - \(product.displayName): \(product.displayPrice) (ID: \(product.id))", category: "StoreKit")
            }
        } catch {
            PauselyLogger.error("Failed to load StoreKit products: \(error.localizedDescription)", category: "StoreKit")
            // Don't show error message - products will load when app is run on device with proper StoreKit config
            errorMessage = nil
        }

        isLoading = false
    }
    
    // MARK: - Purchasing
    
    /// Initiates a purchase for the given product
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        pendingPurchase = product
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)
                
                // Update entitlements
                await updatePurchasedProducts()
                
                // Finish the transaction
                await transaction.finish()
                
                PauselyLogger.info("Purchase successful: \(product.displayName)", category: "StoreKit")
                isLoading = false
                pendingPurchase = nil
                return true
                
            case .userCancelled:
                PauselyLogger.debug("User cancelled purchase", category: "StoreKit")
                errorMessage = "Purchase cancelled"
                isLoading = false
                pendingPurchase = nil
                return false

            case .pending:
                PauselyLogger.info("Purchase pending approval (family sharing)", category: "StoreKit")
                errorMessage = "Purchase pending approval"
                isLoading = false
                pendingPurchase = nil
                return false

            @unknown default:
                PauselyLogger.error("Unknown purchase result", category: "StoreKit")
                errorMessage = "Purchase failed. Please try again."
                isLoading = false
                pendingPurchase = nil
                return false
            }
        } catch StoreKitError.invalidOfferIdentifier {
            PauselyLogger.error("Invalid product ID", category: "StoreKit")
            errorMessage = "This subscription is not available."
        } catch StoreKitError.invalidOfferPrice {
            PauselyLogger.error("Invalid price", category: "StoreKit")
            errorMessage = "Price information is incorrect."
        } catch {
            PauselyLogger.error("Purchase failed: \(error)", category: "StoreKit")
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        isLoading = false
        pendingPurchase = nil
        return false
    }

    // MARK: - Restore Purchases

    /// Restores previous purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()

            if purchasedProductIDs.isEmpty {
                errorMessage = "No previous purchases found."
                isLoading = false
                return false
            } else {
                PauselyLogger.info("Restored \(purchasedProductIDs.count) purchases", category: "StoreKit")
                isLoading = false
                return true
            }
        } catch {
            PauselyLogger.error("Restore failed: \(error)", category: "StoreKit")
            errorMessage = "Could not restore purchases."
            isLoading = false
            return false
        }
    }

    // MARK: - Transaction Handling

    /// Observes transaction updates (renewals, cancellations, etc.)
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            for await verificationResult in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(verificationResult)

                    // Handle the transaction update
                    await self.updatePurchasedProducts()

                    // Finish the transaction
                    await transaction.finish()

                    PauselyLogger.info("Transaction updated: \(transaction.productID)", category: "StoreKit")
                } catch {
                    PauselyLogger.error("Transaction verification failed: \(error)", category: "StoreKit")
                }
            }
        }
    }

    /// Updates the list of purchased products
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        for await verificationResult in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verificationResult)

                if transaction.revocationDate == nil {
                    // Active entitlement
                    purchasedIDs.insert(transaction.productID)

                    // Activate premium in app
                    await MainActor.run {
                        if transaction.productID == ProductID.monthly.rawValue {
                            PaymentManager.shared.activatePremium(source: .storeKitMonthly)
                        } else if transaction.productID == ProductID.annual.rawValue {
                            PaymentManager.shared.activatePremium(source: .storeKitAnnual)
                        }
                    }
                }
            } catch {
                PauselyLogger.error("Failed to verify transaction: \(error)", category: "StoreKit")
            }
        }

        await MainActor.run {
            self.purchasedProductIDs = purchasedIDs
        }
    }
    
    // MARK: - Helpers
    
    /// Verifies a StoreKit transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    /// Gets the product for a specific tier
    func product(for tier: SubscriptionTier) -> Product? {
        switch tier {
        case .free:
            return nil
        case .plus, .premium:
            return products.first { $0.id == ProductID.monthly.rawValue }
        case .plusAnnual, .premiumAnnual:
            return products.first { $0.id == ProductID.annual.rawValue }
        case .pro, .proAnnual:
            return products.first { $0.id == ProductID.monthly.rawValue }
        }
    }
    
    /// Checks if user has active subscription
    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    /// Gets formatted price for a product (uses our pricing, not StoreKit sandbox prices)
    func price(for tier: SubscriptionTier) -> String {
        return tier.priceInUserCurrency()
    }
}

// MARK: - Entitlement Manager
/// Manages user entitlements based on purchases
@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()
    
    @Published var isPremium: Bool = false
    @Published var subscriptionTier: SubscriptionTier = .free
    
    private init() {
        // Load saved state
        isPremium = UserDefaults.standard.bool(forKey: "is_premium")
        if let tierString = UserDefaults.standard.string(forKey: "subscription_tier"),
           let tier = SubscriptionTier(rawValue: tierString) {
            subscriptionTier = tier
        }
    }
    
    func grantPremium(tier: SubscriptionTier) {
        isPremium = true
        subscriptionTier = tier
        UserDefaults.standard.set(true, forKey: "is_premium")
        UserDefaults.standard.set(tier.rawValue, forKey: "subscription_tier")
    }
    
    func revokePremium() {
        isPremium = false
        subscriptionTier = .free
        UserDefaults.standard.set(false, forKey: "is_premium")
        UserDefaults.standard.removeObject(forKey: "subscription_tier")
    }
}

// MARK: - Errors
enum StoreKitError: Error {
    case failedVerification
    case invalidOfferIdentifier
    case invalidOfferPrice
}

// MARK: - Payment Source Extension
// Add StoreKit cases to the existing PaymentSource enum in PaymentManager.swift
