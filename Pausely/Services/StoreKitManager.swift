import Foundation
import StoreKit
import SwiftUI
import Supabase

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
        
    }
    
    // MARK: - Private
    private var updates: Task<Void, Never>?
    private var hasLoadedProducts = false
    
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

    /// Loads products only if they haven't been loaded yet this session.
    func loadProductsIfNeeded() async {
        guard !hasLoadedProducts else { return }
        await loadProducts()
    }

    /// Fetches available products from App Store
    func loadProducts() async {
        guard !hasLoadedProducts else { return }
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

        hasLoadedProducts = true
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

                // Finish the transaction with retry
                do {
                    try await finishTransactionWithRetry(transaction)
                } catch {
                    PauselyLogger.error("Failed to finish transaction after retries: \(error)", category: "StoreKit")
                }

                // Notify PaymentManager so tier updates immediately
                await PaymentManager.shared.updateCurrentEntitlements()

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
                    do {
                        try await self.finishTransactionWithRetry(transaction)
                    } catch {
                        PauselyLogger.error("Failed to finish transaction update: \(error)", category: "StoreKit")
                    }

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
                    if transaction.productID == ProductID.monthly.rawValue {
                        PaymentManager.shared.activatePremium(source: .storeKitMonthly)
                    } else if transaction.productID == ProductID.annual.rawValue {
                        PaymentManager.shared.activatePremium(source: .storeKitAnnual)
                    }
                }
            } catch {
                PauselyLogger.error("Failed to verify transaction: \(error)", category: "StoreKit")
            }
        }

        purchasedProductIDs = purchasedIDs
    }
    
    // MARK: - Helpers

    /// Finishes a transaction with exponential backoff retry
    private func finishTransactionWithRetry(_ transaction: StoreKit.Transaction, maxRetries: Int = 3) async throws {
        var attempt = 0
        while attempt < maxRetries {
            do {
                try await transaction.finish()
                return
            } catch {
                attempt += 1
                if attempt >= maxRetries { throw error }
                let delay = UInt64(pow(2.0, Double(attempt)) * 100_000_000) // 200ms, 400ms, 800ms
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

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
        case .pro:
            return products.first { $0.id == ProductID.monthly.rawValue }
        case .proAnnual:
            return products.first { $0.id == ProductID.annual.rawValue }
        }
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

// MARK: - Derived pricing (always from the real App Store prices)
extension StoreKitManager {
    /// Percentage saved by paying yearly instead of twelve monthly payments; nil when there is no saving.
    nonisolated static func annualSavingsPercent(monthly: Decimal, annual: Decimal) -> Int? {
        guard monthly > 0 else { return nil }
        let twelveMonths = monthly * 12
        let percent = NSDecimalNumber(decimal: (twelveMonths - annual) / twelveMonths * 100).doubleValue.rounded()
        return percent > 0 ? Int(percent) : nil
    }

    /// The yearly price spread over twelve months, rounded to cents.
    nonisolated static func perMonth(annual: Decimal) -> Decimal {
        var value = annual / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
    }

    /// Percentage saved by the yearly plan, from the loaded products; nil until both are loaded.
    var annualSavingsPercent: Int? {
        guard let monthly = product(for: .pro), let annual = product(for: .proAnnual) else { return nil }
        return Self.annualSavingsPercent(monthly: monthly.price, annual: annual.price)
    }

    /// The yearly price per month, formatted for this storefront; nil until products load.
    var annualPricePerMonth: String? {
        guard let annual = product(for: .proAnnual) else { return nil }
        return Self.perMonth(annual: annual.price).formatted(annual.priceFormatStyle)
    }
}
