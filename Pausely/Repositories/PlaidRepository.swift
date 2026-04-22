//
//  PlaidRepository.swift
//  Pausely
//
//  Plaid Link Integration for Bank Sync
//

import Foundation
import SwiftUI

// MARK: - Plaid Repository
@Observable
@MainActor
final class PlaidRepository {
    static let shared = PlaidRepository()
    
    // MARK: - State
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var connectedAccounts: [PlaidAccount] = []
    private(set) var pendingSuggestions: [SubscriptionSuggestion] = []
    
    // MARK: - Private Properties
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Initialization
    private init() {
        Task {
            await loadConnectedAccounts()
        }
    }
    
    // MARK: - Public Methods

    /// Create a Plaid Link token for bank connection
    /// Bank connection via Plaid is planned for a future update
    func createLinkToken() async throws -> String {
        #if DEBUG
        print("Bank connection: Plaid integration not available in this build")
        #endif
        throw PlaidError.notImplemented
    }

    /// Exchange public token for access token after user connects bank
    func exchangePublicToken(_ publicToken: String, institutionId: String, institutionName: String) async throws {
        throw PlaidError.notImplemented
    }

    /// Sync transactions from all connected banks
    func syncTransactions() async throws {
        throw PlaidError.notImplemented
    }

    /// Load connected bank accounts
    func loadConnectedAccounts() async {
        // No bank accounts connected - feature not yet available
        connectedAccounts = []
    }

    /// Disconnect a bank account
    func disconnectAccount(_ accountId: UUID) async throws {
        connectedAccounts.removeAll { $0.id == accountId }
    }
    
    /// Accept a subscription suggestion and create subscription
    func acceptSuggestion(_ suggestion: SubscriptionSuggestion) async throws -> Subscription {
        let subscription = Subscription(
            name: suggestion.merchantName,
            amount: suggestion.amount,
            billingFrequency: suggestion.frequency,
            isDetected: true
        )
        
        // Save to repository
        return try await SubscriptionRepository.shared.addSubscription(subscription)
    }
    
    /// Dismiss a suggestion
    func dismissSuggestion(_ suggestion: SubscriptionSuggestion) {
        pendingSuggestions.removeAll { $0.id == suggestion.id }
    }
}

// MARK: - Data Models

struct PlaidAccount: Identifiable, Codable {
    let id: UUID
    let institutionName: String
    let institutionId: String
    let status: String
    var lastSyncedAt: Date?
}

struct SubscriptionSuggestion: Identifiable, Codable {
    let id: UUID
    let merchantName: String
    let amount: Decimal
    let frequency: BillingFrequency
    let lastSeen: Date
    let confidence: Double // 0.0 to 1.0
}

// MARK: - Errors
enum PlaidError: LocalizedError {
    case notImplemented
    case notAuthenticated
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Bank connection feature coming soon"
        case .notAuthenticated:
            return "Please authenticate to connect your bank"
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let transactionsSynced = Notification.Name("transactionsSynced")
}
