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

}

// MARK: - Transaction Error

