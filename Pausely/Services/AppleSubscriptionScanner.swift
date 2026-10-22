//
//  AppleSubscriptionScanner.swift
//  Pausely
//
//  Apple subscription scanner using StoreKit 2 to fetch actual subscription data from receipts
//

import Foundation
import StoreKit
import os.log


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

