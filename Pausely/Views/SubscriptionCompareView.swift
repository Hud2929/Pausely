//
//  SubscriptionCompareView.swift
//  Pausely
//
//  Side-by-side subscription comparison for best value
//

import SwiftUI


// MARK: - Compare Metric Row


// MARK: - Alternative Plan Card


// MARK: - Recommendation Card


// MARK: - Subscription Picker Sheet


// MARK: - Safe Array Access


// MARK: - SubscriptionStatus Extensions

extension SubscriptionStatus {
    var displayColor: Color {
        switch self {
        case .active: return .green
        case .paused: return .orange
        case .cancelled: return .red
        case .trial: return .blue
        case .expired: return .gray
        }
    }
}

// MARK: - Preview

