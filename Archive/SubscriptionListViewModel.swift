//
//  SubscriptionListViewModel.swift
//  Pausely
//
//  Subscription List ViewModel with @Observable
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SubscriptionListViewModel {
    // MARK: - State
    var state: DataState = .loading
    var subscriptions: [Subscription] = []
    var searchQuery: String = ""
    var selectedFilter: SubscriptionFilter = .all
    var sortOption: SortOption = .nextRenewal
    
    // MARK: - Filtered & Sorted Results
    var filteredSubscriptions: [Subscription] {
        var result = subscriptions
        
        // Apply search
        if !searchQuery.isEmpty {
            result = result.filter { sub in
                sub.name.localizedCaseInsensitiveContains(searchQuery) ||
                (sub.category ?? "").localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            result = result.filter { $0.status == .active }
        case .paused:
            result = result.filter { $0.status == .paused }
        case .cancelled:
            result = result.filter { $0.status == .cancelled }
        case .trial:
            result = result.filter { $0.status == .trial }
        case .wasteAlert:
            result = result.filter { sub in
                guard let score = sub.wasteScore else { return false }
                return Double(truncating: score as NSNumber) < 0.4
            }
        case .category(let cat):
            result = result.filter { ($0.category ?? "Other") == cat }
        }
        
        // Apply sort
        switch sortOption {
        case .nextRenewal:
            result.sort { ($0.daysUntilRenewal ?? 999) < ($1.daysUntilRenewal ?? 999) }
        case .amountHighToLow:
            result.sort { $0.amount > $1.amount }
        case .amountLowToHigh:
            result.sort { $0.amount < $1.amount }
        case .name:
            result.sort { $0.name < $1.name }
        case .wasteScore:
            result.sort { sub1, sub2 in
                let score1 = sub1.wasteScore.map { Double(truncating: $0 as NSNumber) } ?? 0
                let score2 = sub2.wasteScore.map { Double(truncating: $0 as NSNumber) } ?? 0
                return score1 < score2
            }
        }
        
        return result
    }
    
    var categories: [String] {
        Array(Set(subscriptions.compactMap { $0.category })).sorted()
    }
    
    // MARK: - Private Properties
    private let repository = SubscriptionRepository.shared
    
    // MARK: - Public Methods
    
    func loadSubscriptions() async {
        state = .loading
        
        await repository.loadSubscriptions()
        subscriptions = repository.subscriptions
        
        if subscriptions.isEmpty {
            state = .empty
        } else {
            state = .loaded
        }
    }
    
    func deleteSubscription(_ id: UUID) async {
        do {
            try await repository.deleteSubscription(id: id)
            subscriptions.removeAll { $0.id == id }
            
            if subscriptions.isEmpty {
                state = .empty
            }
        } catch {
            print("Delete failed: \(error)")
        }
    }
    
    func refresh() async {
        await loadSubscriptions()
    }
}

// MARK: - Supporting Types

enum SubscriptionFilter: Equatable {
    case all
    case active
    case paused
    case cancelled
    case trial
    case wasteAlert
    case category(String)
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .paused: return "Paused"
        case .cancelled: return "Cancelled"
        case .trial: return "Trial"
        case .wasteAlert: return "Waste Alerts"
        case .category(let cat): return cat
        }
    }
}

enum SortOption: CaseIterable {
    case nextRenewal
    case amountHighToLow
    case amountLowToHigh
    case name
    case wasteScore
    
    var displayName: String {
        switch self {
        case .nextRenewal: return "Next Renewal"
        case .amountHighToLow: return "Price: High to Low"
        case .amountLowToHigh: return "Price: Low to High"
        case .name: return "Name"
        case .wasteScore: return "Waste Score"
        }
    }
}
