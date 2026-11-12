//
//  PaymentManager.swift
//  Pausely
//
//  The free tier, the Pro tiers and which one this person has. StoreKit itself is StoreKitManager's;
//  what Pro unlocks lives in ProFeature.swift.
//

import Foundation

/// The free tier. One value, used by the store limit, the paywall and the copy in the listing.
enum FreeTier {
    static let subscriptionLimit = 5

    /// How many of the free plan's places a list takes: the subscriptions that are charging. A
    /// cancelled one is history and takes none, so cancelling (which is what the app is for) makes
    /// room. Every screen and importer asks here; nothing else compares a count with the limit.
    static func used(by subscriptions: [Subscription]) -> Int {
        subscriptions.charging.count
    }

    /// The places left on the free plan.
    static func room(in subscriptions: [Subscription]) -> Int {
        max(0, subscriptionLimit - used(by: subscriptions))
    }
}

/// Launch prices in USD, for internal sums only. Never shown and never saved as what someone pays:
/// Apple sets each country's price, and only StoreKit knows it.
enum ProPricing {
    static let annualUSD = Decimal(string: "29.99")!
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
    
    var displayName: String {
        switch self {
        case .free:        return "Free"
        case .pro:         return "Pro"
        case .proAnnual:   return "Pro Annual"
        }
    }
    
    // MARK: - Limits
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

    /// The effective tier including debug override.
    /// Writes still go to `currentTier` so StoreKit and purchase flows work normally.
    private var resolvedTier: SubscriptionTier {
        debugFreePro ? .pro : currentTier
    }

    /// Whether this person has Pro, by any route: an App Store subscription or a grant on the account.
    var isPremium: Bool {
        #if DEBUG
        if debugPremiumOverride { return true }
        #endif
        return resolvedTier > .free
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
            // 2. Ask the App Store (may lower the tier if the subscription ended or was refunded)
            await updateCurrentEntitlements()
            // 3. Pausely's own line, for someone who already has Pro
            await autoAddPauselyProIfNeeded()
        }
    }

    // MARK: - Entitlements

    /// Reads what the App Store says is paid for and sets the tier from it: up when something was
    /// bought, down when it ended, was refunded or was revoked. Runs at launch, after a purchase or
    /// restore, on every transaction update and whenever the app comes to the front.
    func updateCurrentEntitlements() async {
        currentTier = Self.resolveTier(storeKit: await StoreKitManager.shared.entitledTier(), hasGrant: hasProGrant)
    }

    /// Pro comes from an active App Store subscription (a billing grace period counts: StoreKit keeps
    /// it in `currentEntitlements`) or from an admin grant on the account. A subscription that ended
    /// or was refunded leaves only the grant; without one the tier is Free.
    static func resolveTier(storeKit: SubscriptionTier?, hasGrant: Bool) -> SubscriptionTier {
        if let storeKit, storeKit > .free { return storeKit }
        return hasGrant ? .pro : .free
    }

    // MARK: - Admin grant (profiles.is_pro), kept apart from StoreKit

    private let proGrantKey = "pausely_pro_grant"

    private var hasProGrant: Bool { UserDefaults.standard.bool(forKey: proGrantKey) }

    /// Called with the account's `is_pro` on sign-in, and with false on sign-out or account deletion.
    func setProGrant(_ active: Bool) async {
        UserDefaults.standard.set(active, forKey: proGrantKey)
        await updateCurrentEntitlements()
    }
    
    // MARK: - Feature Checks
    
    /// Whether one more subscription that charges fits: always with Pro, otherwise while the free
    /// plan has a place left (`FreeTier.room`).
    func hasRoom(in subscriptions: [Subscription]) -> Bool {
        ProFeature.canAddSubscription(currentCount: FreeTier.used(by: subscriptions), isPro: isPremium)
    }

    // MARK: - Pausely's own line in the list

    private let pauselyProAutoAddedKey = "pausely_pro_auto_added"
    /// The name of Pausely's own line in the list.
    nonisolated static let ownName = "Pausely Pro"

    /// Pausely Pro as a line in the person's own list, so the app watches its own cost like any other.
    /// Everything on it is the App Store's: the price and currency for this storefront, whether the
    /// free trial is running, and the day it next charges.
    static func pauselyLine(_ own: StoreKitManager.OwnSubscription) -> Subscription {
        Subscription(
            name: ownName,
            category: SubscriptionCategory.productivity.rawValue,
            amount: own.price,
            currency: own.currency,
            billingFrequency: own.tier == .proAnnual ? .yearly : .monthly,
            nextBillingDate: own.renews,
            trialEndsAt: own.isTrial ? own.renews : nil,
            status: own.isTrial ? .trial : .active
        )
    }

    /// A line that is already there, brought in step with the App Store's price and currency.
    /// Earlier versions could add it at US launch prices for any country.
    static func corrected(_ line: Subscription, to own: StoreKitManager.OwnSubscription) -> Subscription? {
        let frequency: BillingFrequency = own.tier == .proAnnual ? .yearly : .monthly
        guard line.amount != own.price || line.currency != own.currency || line.billingFrequency != frequency else { return nil }
        var fixed = line
        fixed.amount = own.price
        fixed.currency = own.currency
        fixed.billingFrequency = frequency
        return fixed
    }

    /// Adds Pausely Pro to the list once, when the App Store has stated its price and a verified
    /// purchase exists. Until both are known nothing is added (a person given Pro on their account
    /// pays nothing, so gets no line); this runs again at launch, when prices load and when Pro begins.
    func autoAddPauselyProIfNeeded() async {
        guard currentTier > .free else { return }
        let store = SubscriptionStore.shared
        guard let own = await StoreKitManager.shared.ownSubscription(for: currentTier) else { return }

        if let existing = store.subscriptions.first(where: \.isPausely) {
            if let fixed = Self.corrected(existing, to: own) { await store.updateSubscription(fixed) }
            UserDefaults.standard.set(true, forKey: pauselyProAutoAddedKey)
            return
        }
        // Added once. If the person removed it, or tracks it under their own name, it stays that way.
        guard !UserDefaults.standard.bool(forKey: pauselyProAutoAddedKey),
              !store.subscriptions.contains(where: { $0.name.lowercased().contains("pausely") }) else { return }

        do {
            _ = try await store.addSubscription(Self.pauselyLine(own))
            UserDefaults.standard.set(true, forKey: pauselyProAutoAddedKey)
        } catch {
            // The free limit can't refuse it (Pro is unlimited); logged in case a new refusal appears.
            PauselyLogger.error("Could not add Pausely Pro to the list: \(error)", category: "Payment")
        }
    }
}
