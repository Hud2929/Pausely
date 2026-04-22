//
//  AppleSubscriptionScanner.swift
//  Pausely
//
//  Apple subscription scanner using StoreKit 2 to fetch actual subscription data from receipts
//

import Foundation
import StoreKit

@MainActor
final class AppleSubscriptionScanner: ObservableObject {
    static let shared = AppleSubscriptionScanner()

    // MARK: - Published State
    @Published private(set) var detectedSubscriptions: [AppleDetectedSubscription] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var scanError: String?
    @Published private(set) var hasPermission = false

    // MARK: - Private
    private let catalogService = SubscriptionCatalogService.shared
    private var updateTask: Task<Void, Never>?

    private init() {
        // Listen for transaction updates
        updateTask = observeTransactionUpdates()
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Public Methods

    /// Scan for subscriptions using StoreKit 2
    func scanSubscriptions() async {
        guard !isScanning else { return }

        isScanning = true
        scanError = nil
        detectedSubscriptions = []

        var detected: [AppleDetectedSubscription] = []

        // Iterate through current entitlements (subscriptions and purchases)
        for await result in Transaction.currentEntitlements {
            if let subscription = try? await processEntitlement(result) {
                detected.append(subscription)
            }
        }

        // Sort by name
        detected.sort { $0.name < $1.name }
        detectedSubscriptions = detected
        lastScanDate = Date()

        #if DEBUG
        print("✅ Apple Subscription Scanner: Found \(detected.count) entitlements")
        for sub in detected {
            print("   - \(sub.name): \(sub.formattedPrice) (\(sub.billingDisplay)) - \(sub.status)")
        }
        #endif

        isScanning = false
    }

    /// Check if we have Family Controls permission (for Screen Time features)
    func checkPermission() async -> Bool {
        // Family Controls permission is checked via ScreenTimeManager
        // This is a placeholder for the StoreKit-related permission check
        hasPermission = true
        return hasPermission
    }

    /// Get subscription info for a specific bundle ID from the catalog
    func catalogEntry(for bundleId: String) -> CatalogEntry? {
        catalogService.entry(for: bundleId)
    }

    // MARK: - Private Methods

    private func processEntitlement(_ result: VerificationResult<Transaction>) async throws -> AppleDetectedSubscription? {
        let transaction = try checkVerified(result)

        // Skip revoked entitlements
        guard transaction.revocationDate == nil else {
            return nil
        }

        // Get the product ID (bundle ID for subscriptions)
        let productId = transaction.productID

        // Look up in our catalog
        let catalogEntry = catalogService.entry(for: productId)

        // Extract pricing info from StoreKit product
        let product = try? await Product.products(for: [productId]).first

        // Determine subscription tier from product ID
        let tier = inferTier(from: productId)

        // Determine billing frequency from subscription info
        let billingFrequency = inferBillingFrequency(from: transaction)

        // Calculate price
        let price: Decimal
        let currency: String

        if let product = product {
            price = product.price
            currency = product.priceFormatStyle.currencyCode
        } else {
            // Fallback to catalog pricing
            if let catalog = catalogEntry,
               let tierPricing = catalog.pricing(for: tier) {
                price = Decimal(tierPricing.monthlyPriceUSD)
                currency = "USD"
            } else {
                price = 0
                currency = "USD"
            }
        }

        // Determine status
        let status = determineStatus(from: transaction)

        // Extract expiration date
        let expirationDate = transaction.expirationDate

        // Check if in trial period (using the correct StoreKit 2 API)
        let isInTrial: Bool
        if let offer = transaction.offer {
            switch offer.type {
            case .introductory, .promotional:
                isInTrial = true
            default:
                isInTrial = false
            }
        } else {
            isInTrial = false
        }

        return AppleDetectedSubscription(
            id: UUID(),
            bundleId: productId,
            name: catalogEntry?.name ?? productId.components(separatedBy: ".").last?.capitalized ?? productId,
            category: catalogEntry?.category ?? .other,
            iconName: catalogEntry?.iconName ?? "square.grid.2x2",
            price: price,
            currency: currency,
            billingFrequency: billingFrequency,
            tier: tier,
            status: status,
            expirationDate: expirationDate,
            isInTrial: isInTrial,
            trialEndDate: isInTrial ? expirationDate : nil,
            productType: SubscriptionProductType.recurringSubscription,
            originalPurchaseDate: transaction.originalPurchaseDate,
            catalogEntry: catalogEntry
        )
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TransactionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func inferTier(from productId: String) -> PricingTier {
        let lower = productId.lowercased()
        if lower.contains("family") || lower.contains("plus") {
            return .family
        } else if lower.contains("student") {
            return .student
        } else if lower.contains("duo") {
            return .duo
        } else if lower.contains("team") {
            return .team
        } else if lower.contains("enterprise") {
            return .enterprise
        }
        return .individual
    }

    private func inferBillingFrequency(from transaction: Transaction) -> BillingFrequency {
        // StoreKit doesn't directly expose billing frequency in the transaction
        // We infer from product ID patterns or assume monthly as default

        let productId = transaction.productID.lowercased()

        if productId.contains("annual") || productId.contains("yearly") || productId.contains("year") {
            return .yearly
        } else if productId.contains("semiannual") || productId.contains("6month") {
            return .semiannual
        } else if productId.contains("quarterly") || productId.contains("3month") {
            return .quarterly
        } else if productId.contains("weekly") {
            return .weekly
        } else if productId.contains("biweekly") || productId.contains("2week") {
            return .biweekly
        }

        return .monthly
    }

    private func determineStatus(from transaction: Transaction) -> AppleSubscriptionStatus {
        if transaction.revocationDate != nil {
            return .cancelled
        }

        if let expirationDate = transaction.expirationDate {
            if expirationDate < Date() {
                return .expired
            }
        }

        if let offer = transaction.offer {
            switch offer.type {
            case .introductory, .promotional:
                return .trial
            default:
                break
            }
        }

        return .active
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            for await _ in Transaction.updates {
                await self.scanSubscriptions()
            }
        }
    }
}

// MARK: - Apple Detected Subscription Model

struct AppleDetectedSubscription: Identifiable {
    let id: UUID
    let bundleId: String
    let name: String
    let category: SubscriptionCategory
    let iconName: String
    let price: Decimal
    let currency: String
    let billingFrequency: BillingFrequency
    let tier: PricingTier
    let status: AppleSubscriptionStatus
    let expirationDate: Date?
    let isInTrial: Bool
    let trialEndDate: Date?
    let productType: SubscriptionProductType
    let originalPurchaseDate: Date?
    let catalogEntry: CatalogEntry?

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: price as NSDecimalNumber) ?? "\(currency) \(price)"
    }

    var billingDisplay: String {
        billingFrequency.displayName
    }

    var monthlyPrice: Decimal {
        billingFrequency.multiplierToMonthly * price
    }

    var annualPrice: Decimal {
        billingFrequency.multiplierToYearly * price
    }

    /// Convert to a User Subscription for the local database
    func toSubscription() -> Subscription {
        Subscription(
            name: name,
            bundleIdentifier: bundleId,
            description: catalogEntry?.description,
            category: category.rawValue,
            amount: price,
            currency: currency,
            billingFrequency: billingFrequency,
            nextBillingDate: expirationDate,
            status: status.toSubscriptionStatus(),
            isDetected: true,
            canPause: catalogEntry?.canPause ?? true,
            selectedTier: tier
        )
    }
}

// MARK: - Subscription Product Type

enum SubscriptionProductType {
    case recurringSubscription
    case nonRecurringSubscription
    case consumable
    case nonConsumable
    case unknown
}

// MARK: - Apple Subscription Status

enum AppleSubscriptionStatus {
    case active
    case trial
    case expired
    case cancelled
    case paused

    func toSubscriptionStatus() -> SubscriptionStatus {
        switch self {
        case .active: return .active
        case .trial: return .trial
        case .expired: return .expired
        case .cancelled: return .cancelled
        case .paused: return .paused
        }
    }
}

// MARK: - Transaction Error

enum TransactionError: Error {
    case failedVerification
}
