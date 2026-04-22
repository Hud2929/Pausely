//
//  SubscriptionRepository.swift
//  Pausely
//
//  Modern Repository Pattern with @Observable
//  REPLACES: SubscriptionStore (ObservableObject)
//

import Foundation
import SwiftUI

// MARK: - Subscription Repository
@Observable
@MainActor
final class SubscriptionRepository {
    static let shared = SubscriptionRepository()
    
    // MARK: - Published State (via @Observable)
    private(set) var subscriptions: [Subscription] = []
    private(set) var state: DataState = .idle
    private(set) var lastError: Error?
    
    // MARK: - Computed Properties
    var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == .active }
    }
    
    var monthlySpend: Decimal {
        activeSubscriptions.reduce(0) { $0 + $1.monthlyCost }
    }
    
    var annualSpend: Decimal {
        activeSubscriptions.reduce(0) { $0 + $1.annualCost }
    }
    
    var upcomingRenewals: [Subscription] {
        activeSubscriptions
            .filter { $0.daysUntilRenewal != nil && $0.daysUntilRenewal! <= 7 }
            .sorted { ($0.daysUntilRenewal ?? 999) < ($1.daysUntilRenewal ?? 999) }
    }
    
    var totalWasteScore: Double {
        let scores = activeSubscriptions.compactMap { $0.wasteScore }
        guard !scores.isEmpty else { return 0 }
        let sum = scores.reduce(Decimal(0)) { $0 + $1 }
        return Double(truncating: sum as NSNumber) / Double(scores.count)
    }
    
    // MARK: - Private Properties
    private let supabase = SupabaseManager.shared.client
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cached_subscriptions"
    
    // MARK: - Initialization
    private init() {
        // Load from cache immediately for UI responsiveness
        loadFromCache()
    }
    
    // MARK: - Public Methods
    
    /// Load subscriptions from Supabase (with cache fallback)
    func loadSubscriptions() async {
        state = .loading
        
        do {
            let userId = try await getCurrentUserId()
            
            let response = try await supabase
                .from("subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            let records = try JSONDecoder().decode([SubscriptionRecord].self, from: response.data)
            subscriptions = records.map { $0.toSubscription() }
            
            // Cache for offline access
            cacheSubscriptions(subscriptions)
            
            state = subscriptions.isEmpty ? .empty : .loaded
            
        } catch {
            lastError = error
            state = .error(error.localizedDescription)
            
            // Fallback to cache if available
            if subscriptions.isEmpty {
                loadFromCache()
            }
        }
    }
    
    /// Add a new subscription
    func addSubscription(_ subscription: Subscription) async throws -> Subscription {
        state = .loading
        
        do {
            let userId = try await getCurrentUserId()
            var newSubscription = subscription
            newSubscription.userId = userId
            
            let record = SubscriptionRecord(from: newSubscription)
            
            let response = try await supabase
                .from("subscriptions")
                .insert(record)
                .select()
                .single()
                .execute()
            
            let savedRecord = try JSONDecoder().decode(SubscriptionRecord.self, from: response.data)
            let savedSubscription = savedRecord.toSubscription()
            
            // Update local state
            subscriptions.insert(savedSubscription, at: 0)
            state = .loaded
            
            // Update cache
            cacheSubscriptions(subscriptions)
            
            STAnimation.success()
            return savedSubscription
            
        } catch {
            lastError = error
            state = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Update an existing subscription
    func updateSubscription(_ subscription: Subscription) async throws {
        state = .loading
        
        do {
            let record = SubscriptionRecord(from: subscription)
            
            let response = try await supabase
                .from("subscriptions")
                .update(record)
                .eq("id", value: subscription.id.uuidString)
                .select()
                .single()
                .execute()
            
            let updatedRecord = try JSONDecoder().decode(SubscriptionRecord.self, from: response.data)
            let updatedSubscription = updatedRecord.toSubscription()
            
            // Update local state
            if let index = subscriptions.firstIndex(where: { $0.id == updatedSubscription.id }) {
                subscriptions[index] = updatedSubscription
            }
            
            state = .loaded
            cacheSubscriptions(subscriptions)
            
        } catch {
            lastError = error
            state = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Delete a subscription
    func deleteSubscription(id: UUID) async throws {
        do {
            try await supabase
                .from("subscriptions")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            
            // Update local state
            subscriptions.removeAll { $0.id == id }
            
            if subscriptions.isEmpty {
                state = .empty
            }
            
            cacheSubscriptions(subscriptions)
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Cancel a subscription
    func cancelSubscription(id: UUID) async throws {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.subscriptionNotFound
        }

        var updated = subscriptions[index]

        // Update local state
        updated.markAsCancelled()
        subscriptions[index] = updated

        // Persist to backend
        try await updateSubscription(updated)
    }

    /// Pause a subscription
    func pauseSubscription(id: UUID, until date: Date) async throws {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.subscriptionNotFound
        }

        var updated = subscriptions[index]

        // Update local state
        updated.markAsPaused(until: date)
        subscriptions[index] = updated

        // Persist to backend
        try await updateSubscription(updated)
    }

    /// Resume a subscription
    func resumeSubscription(id: UUID) async throws {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.subscriptionNotFound
        }

        var updated = subscriptions[index]

        // Update local state
        updated.resume()
        subscriptions[index] = updated

        // Persist to backend
        try await updateSubscription(updated)
    }
    
    /// Calculate and update waste score for a subscription
    func updateWasteScore(for subscriptionId: UUID, monthlyMinutes: Int) async throws {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            throw RepositoryError.subscriptionNotFound
        }
        
        var updated = subscriptions[index]
        updated.monthlyUsageMinutes = monthlyMinutes
        
        // Calculate waste score: 0.0 = total waste, 1.0 = great value
        // Formula: usage relative to expected usage based on cost
        let monthlyCost = Double(truncating: updated.monthlyCost as NSNumber)
        let expectedMinutes = monthlyCost * 10 // Expect 10 min per dollar
        let score = min(Double(monthlyMinutes) / expectedMinutes, 1.0)
        
        updated.wasteScore = Decimal(score)
        
        // Calculate cost per hour
        if monthlyMinutes > 0 {
            let hours = Decimal(monthlyMinutes) / 60
            updated.costPerHour = updated.monthlyCost / hours
        }
        
        try await updateSubscription(updated)
    }
    
    /// Refresh data from server
    func refresh() async {
        await loadSubscriptions()
    }
    
    /// Clear all data (logout)
    func clear() {
        subscriptions = []
        state = .idle
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    // MARK: - Private Methods
    
    private func getCurrentUserId() async throws -> UUID {
        guard let session = supabase.auth.currentSession else {
            throw RepositoryError.notAuthenticated
        }
        return session.user.id
    }
    
    private func cacheSubscriptions(_ subs: [Subscription]) {
        if let encoded = try? JSONEncoder().encode(subs) {
            userDefaults.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadFromCache() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([Subscription].self, from: data) else {
            return
        }
        subscriptions = cached
        state = cached.isEmpty ? .empty : .loaded
    }
}

// MARK: - Repository Errors
enum RepositoryError: LocalizedError {
    case notAuthenticated
    case subscriptionNotFound
    case networkError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .subscriptionNotFound:
            return "Subscription not found"
        case .networkError:
            return "Network error. Please check your connection."
        case .decodingError:
            return "Failed to process data"
        }
    }
}
