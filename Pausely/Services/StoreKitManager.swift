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

    /// An eligible Apple StoreKit 2 Win-Back free-trial offer for returning customers (requires zero
    /// server signing on iOS 18+; populated automatically once configured in App Store Connect).
    struct FreeExtensionOffer: Equatable {
        let id: String
        let days: Int
        let offer: Product.SubscriptionOffer
    }

    /// Minimal status snapshot used by pure unit-tested Win-Back eligibility filtering.
    struct StatusSnapshot: Equatable {
        let state: Product.SubscriptionInfo.RenewalState
        let transactionProductID: String?
        let renewalProductID: String?
        let eligibleOfferIDs: [String]
    }

    /// Pure eligibility filter: Win-Back offers apply ONLY when the subscription group has no active,
    /// grace, or billing-retry status AND an `.expired` status matching `productID` lists the offer ID.
    /// Prevents cross-product offer ID collisions across Monthly and Annual in the same group.
    nonisolated static func eligibleWinBackIDs(forProductID productID: String,
                                               statuses: [StatusSnapshot]) -> Set<String> {
        let hasActiveStatus = statuses.contains {
            $0.state == .subscribed || $0.state == .inGracePeriod || $0.state == .inBillingRetryPeriod
        }
        guard !hasActiveStatus else { return [] }

        var eligibleIDs: Set<String> = []
        for status in statuses where status.state == .expired {
            let statusProductID = status.transactionProductID ?? status.renewalProductID
            guard statusProductID == productID else { continue }
            eligibleIDs.formUnion(status.eligibleOfferIDs)
        }
        return eligibleIDs
    }

    /// Returns the best eligible free Win-Back offer (e.g., 7 more days free) on `product`, ONLY when
    /// Apple reports an expired subscription for THIS exact `product.id` and lists that offer ID in
    /// `renewalInfo.eligibleWinBackOfferIDs`. Never returned for active subscribers or active trials.
    func freeWinBackOffer(for product: Product) async -> FreeExtensionOffer? {
        guard let subscription = product.subscription,
              let statuses = try? await subscription.status else { return nil }

        let snapshots: [StatusSnapshot] = statuses.map { status in
            let txProductID: String? = {
                if case .verified(let tx) = status.transaction { return tx.productID }
                return nil
            }()
            let renewalProductID: String?
            let eligibleOfferIDs: [String]
            if case .verified(let renewal) = status.renewalInfo {
                renewalProductID = renewal.currentProductID
                eligibleOfferIDs = renewal.eligibleWinBackOfferIDs
            } else {
                renewalProductID = nil
                eligibleOfferIDs = []
            }
            return StatusSnapshot(state: status.state,
                                  transactionProductID: txProductID,
                                  renewalProductID: renewalProductID,
                                  eligibleOfferIDs: eligibleOfferIDs)
        }

        let eligibleIDs = Self.eligibleWinBackIDs(forProductID: product.id, statuses: snapshots)
        guard !eligibleIDs.isEmpty else { return nil }

        return subscription.winBackOffers
            .filter { offer in
                guard offer.paymentMode == .freeTrial, let id = offer.id else { return false }
                return eligibleIDs.contains(id)
            }
            .compactMap { offer -> FreeExtensionOffer? in
                guard let id = offer.id,
                      let days = PaywallCase.trialDays(value: offer.period.value, unit: offer.period.unit) else {
                    return nil
                }
                return FreeExtensionOffer(id: id, days: days, offer: offer)
            }
            .max { $0.days < $1.days }
    }

    /// Best eligible free Win-Back offer across Annual and Monthly products for a lapsed customer.
    func bestEligibleWinBackOffer() async -> (product: Product, offer: FreeExtensionOffer)? {
        for tier in [SubscriptionTier.proAnnual, .pro] {
            if let product = product(for: tier), let offer = await freeWinBackOffer(for: product) {
                return (product, offer)
            }
        }
        return nil
    }

    // MARK: - Buying and restoring

    func purchase(_ product: Product, winBackOffer: Product.SubscriptionOffer? = nil) async -> PurchaseOutcome {
        isLoading = true
        defer { isLoading = false }
        do {
            var options: Set<Product.PurchaseOption> = []
            if let uidString = AuthManager.shared.currentUser?.id,
               let accountToken = UUID(uuidString: uidString) {
                options.insert(.appAccountToken(accountToken))
            }
            if let winBackOffer {
                options.insert(.winBackOffer(winBackOffer))
            }
            switch try await product.purchase(options: options) {
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
    /// currently active, verified entitlement are known. Nothing here is ever estimated.
    func ownSubscription(for tier: SubscriptionTier) async -> OwnSubscription? {
        guard let product = product(for: tier) else { return nil }
        var activeTransaction: StoreKit.Transaction?
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == product.id,
               transaction.revocationDate == nil {
                activeTransaction = transaction
                break
            }
        }
        guard let transaction = activeTransaction else { return nil }
        let isFreeOffer = transaction.offer?.type == .introductory
            || (transaction.offer?.type == .winBack && transaction.offer?.paymentMode == .freeTrial)
        var own = OwnSubscription(tier: tier, price: product.price, currency: product.priceFormatStyle.currencyCode,
                                  renews: transaction.expirationDate, isTrial: isFreeOffer)
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
        // Rounded down: a saving is never overstated ($29.99 against 12 × $4.99 is 49.9%, not "Save 50%", 2026-11-23).
        let percent = NSDecimalNumber(decimal: (twelveMonths - annual) / twelveMonths * 100).doubleValue.rounded(.down)
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
