//
//  DataState.swift
//  Pausely
//
//  Loading/Empty/Error State Management
//

import Foundation

// MARK: - Data State
enum DataState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
    
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - View State Helpers
enum ListState<T> {
    case idle
    case loading
    case loaded([T])
    case empty
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
    
    var hasData: Bool {
        if case .loaded(let items) = self { return !items.isEmpty }
        return false
    }
    
    var items: [T] {
        if case .loaded(let items) = self { return items }
        return []
    }
}
