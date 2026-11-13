import Foundation
import StoreKit

/// The only code that talks to StoreKit: the two Pausely Pro plans and their App Store prices, buying
/// and restoring, and what the App Store says this person is paying for right now. `PaymentManager`
/// turns that into the tier the rest of the app reads.
@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    /// The plans as the App Store sells them in this storefront. Empty until they have loaded.
    @Published private(set) var products: [Product] = []
    /// Prices are being fetched, or a purchase or restore is under way.
    @Published private(set) var isLoading = false

    /// Must match App Store Connect.
    enum ProductID: String, CaseIterable {
        case monthly = "com.pausely.premium.monthly"
        case annual = "com.pausely.premium.annual"

        var tier: SubscriptionTier { self == .annual ? .proAnnual : .pro }
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        /// The person closed Apple's sheet themselves.
        case cancelled
        /// Waiting for someone else's approval (Ask to Buy). Pro arrives through `Transaction.updates`.
        case pending
        /// The App Store reported a purchase Pausely couldn't verify.
        case unverified
        case failed
    }

    enum RestoreOutcome: Equatable {
        case restored
        case nothingToRestore
        /// The person dismissed the App Store's sign-in.
        case cancelled
        case failed
    }

    /// What Pausely itself costs this customer, exactly as the App Store states it.
    struct OwnSubscription: Equatable {
        let tier: SubscriptionTier
        let price: Decimal
        let currency: String
        /// When the current period (or free trial) ends and the next charge happens.
        let renews: Date?
        let isTrial: Bool
        /// The purchase itself, for Apple's refund sheet.
        var transactionId: UInt64?
        /// False once the person has turned renewal off: the plan ends on `renews`. Nil when unknown.
        var willRenew: Bool?
        /// Apple tried to charge and couldn't (billing retry, or the grace period it gives meanwhile).
        var hasBillingProblem = false

        /// One line under the plan's name: "Free trial ends Nov 24, 2026", "Renews…", or "Ends…" once
        /// renewal is off. Nil when the App Store gave no date.
        func statusLine(locale: Locale = L10n.locale) -> String? {
            guard let renews else { return nil }
            let day = renews.formatted(.dateTime.month(.abbreviated).day().year().locale(locale))
            if willRenew == false { return L10n.string("Ends \(day)") }
            return isTrial ? L10n.string("Free trial ends \(day)") : L10n.string("Renews \(day)")
        }
    }

    /// One thing the App Store says is paid for.
    struct Entitlement: Equatable {
        let productID: String
        var isRevoked = false
    }

    // Where the answers come from. The app asks StoreKit; tests put their own answers here, because
    // Apple's local test store can't complete a purchase inside a unit-test host.
    var fetchProducts: ([String]) async throws -> [Product] = { try await Product.products(for: $0) }
    var currentEntitlements: () async -> [Entitlement] = {
        var found: [Entitlement] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            found.append(Entitlement(productID: transaction.productID, isRevoked: transaction.revocationDate != nil))
        }
        return found
    }
    var syncWithAppStore: () async throws -> Void = { try await AppStore.sync() }

    private var updates: Task<Void, Never>?
    private var isLoadingProducts = false

    /// The app uses `shared`. Tests make their own to start from no prices.
    init() {
        updates = observeTransactionUpdates()
    }

    deinit {
        updates?.cancel()
    }

    // MARK: - Prices

    /// Asks the App Store for the plans unless they are already here. A failure leaves them missing,
    /// so the next call asks again (it used to count a failure as loaded, and the paywall then had
    /// no prices until the app was restarted).
    func loadProducts() async {
        guard products.count < ProductID.allCases.count, !isLoadingProducts else { return }
        // `--demo-store-offline` (DEBUG): the App Store never answers, so the paywall without prices
        // can be looked at.
        if LaunchFlag.isSet("--demo-store-offline") { return }
        isLoadingProducts = true
        isLoading = true
        defer {
            isLoadingProducts = false
            isLoading = false
        }
        do {
            let loaded = try await fetchProducts(ProductID.allCases.map(\.rawValue))
            guard !loaded.isEmpty else { return }
            products = loaded
            // Pausely's own line in the list waits for the App Store's price; it may be able to go in now.
            await PaymentManager.shared.autoAddPauselyProIfNeeded()
        } catch {
            PauselyLogger.error("Failed to load StoreKit products: \(error.localizedDescription)", category: "StoreKit")
        }
    }

    func product(for tier: SubscriptionTier) -> Product? {
        guard let id = ProductID.allCases.first(where: { $0.tier == tier }) else { return nil }
        return products.first { $0.id == id.rawValue }
    }

    // MARK: - Buying and restoring

    func purchase(_ product: Product) async -> PurchaseOutcome {
        isLoading = true
        defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .unverified }
                await PaymentManager.shared.updateCurrentEntitlements()
                await transaction.finish()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            PauselyLogger.error("Purchase failed: \(error)", category: "StoreKit")
            return .failed
        }
    }

    func restorePurchases() async -> RestoreOutcome {
        isLoading = true
        defer { isLoading = false }
        do {
            try await syncWithAppStore()
        } catch StoreKit.StoreKitError.userCancelled {
            return .cancelled
        } catch {
            PauselyLogger.error("Restore failed: \(error)", category: "StoreKit")
            return .failed
        }
        await PaymentManager.shared.updateCurrentEntitlements()
        return await entitledTier() == nil ? .nothingToRestore : .restored
    }

    // MARK: - What the App Store says is paid for

    /// The plan this person is paying for right now, or nil. A free trial and a billing grace period
    /// count (StoreKit keeps both in `currentEntitlements`); a refunded or revoked purchase does not.
    func entitledTier() async -> SubscriptionTier? {
        await currentEntitlements()
            .filter { !$0.isRevoked }
            .compactMap { ProductID(rawValue: $0.productID)?.tier }
            .max()
    }

    /// Pausely's own subscription for this plan, or nil until both the App Store's price and a
    /// verified purchase are known. Nothing here is ever estimated.
    func ownSubscription(for tier: SubscriptionTier) async -> OwnSubscription? {
        guard let product = product(for: tier), let latest = await Transaction.latest(for: product.id),
              case .verified(let transaction) = latest, transaction.revocationDate == nil else { return nil }
        var own = OwnSubscription(tier: tier, price: product.price, currency: product.priceFormatStyle.currencyCode,
                                  renews: transaction.expirationDate, isTrial: transaction.offer?.type == .introductory)
        own.transactionId = transaction.id
        // Whether it will renew, and whether Apple is having trouble charging for it.
        if let statuses = try? await product.subscription?.status {
            let status = statuses.first { status in
                if case .verified(let latest) = status.transaction { return latest.productID == product.id }
                return false
            } ?? statuses.first
            if let status {
                own.hasBillingProblem = status.state == .inBillingRetryPeriod || status.state == .inGracePeriod
                if case .verified(let renewal) = status.renewalInfo { own.willRenew = renewal.willAutoRenew }
            }
        }
        return own
    }

    /// Renewals, refunds, revocations and approved Ask to Buy purchases arrive here while the app
    /// runs. Whatever the update is, the entitlements are read again, so Pro is taken away as well as given.
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await update in Transaction.updates {
                await PaymentManager.shared.updateCurrentEntitlements()
                if case .verified(let transaction) = update { await transaction.finish() }
            }
        }
    }
}

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

#if DEBUG
extension StoreKitManager.OwnSubscription {
    /// The yearly plan as Profile shows it: renewing, in its free trial (`trial`), with renewal
    /// turned off (`ending`), or with a payment Apple could not take (`problem`).
    static func demo(_ state: String, now: Date = Date()) -> StoreKitManager.OwnSubscription {
        var plan = StoreKitManager.OwnSubscription(
            tier: .proAnnual, price: ProPricing.annualUSD, currency: "USD",
            renews: Calendar.billing.date(byAdding: .month, value: state == "trial" ? 0 : 9, to: now)
                .flatMap { Calendar.billing.date(byAdding: .day, value: state == "trial" ? 5 : 0, to: $0) },
            isTrial: state == "trial", transactionId: 1, willRenew: state != "ending")
        plan.hasBillingProblem = state == "problem"
        return plan
    }
}
#endif
