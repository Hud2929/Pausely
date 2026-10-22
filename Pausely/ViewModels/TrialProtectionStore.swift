//
//  TrialProtectionStore.swift
//  Pausely
//
//  Revolutionary trial protection WITHOUT needing virtual cards
//  Tracks trials, sends reminders, provides one-tap cancel
//

import Foundation
import SwiftUI
import Supabase
import os.log

/// Represents a free trial being tracked
struct TrackedTrial: Identifiable, Codable {
    let id: UUID
    var serviceName: String
    var startDate: Date
    var endDate: Date
    var costAfterTrial: Decimal
    var currency: String
    var category: String
    var status: TrialStatus
    var cancelURL: String?
    var notes: String
    var reminderDates: [Date]
    var hasBeenReminded: Bool
    
    enum TrialStatus: String, Codable {
        case active = "active"         // Currently in trial period
        case endingSoon = "ending_soon" // Less than 48 hours left
        case converted = "converted"    // User decided to keep it
        case cancelled = "cancelled"    // User cancelled
        case expired = "expired"        // Trial ended without action
        
        var displayName: String {
            switch self {
            case .active: return "Active Trial"
            case .endingSoon: return "Ending Soon!"
            case .converted: return "Converted"
            case .cancelled: return "Cancelled"
            case .expired: return "Expired"
            }
        }
        
        var color: Color {
            switch self {
            case .active: return .blue
            case .endingSoon: return .orange
            case .converted: return .green
            case .cancelled: return .gray
            case .expired: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "clock.fill"
            case .endingSoon: return "exclamationmark.triangle.fill"
            case .converted: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle.fill"
            case .expired: return "clock.badge.xmark"
            }
        }
    }
    
    /// Total hours remaining in trial — computed correctly using day*24 + hour
    var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: endDate)
        let totalHours = (components.day ?? 0) * 24 + (components.hour ?? 0)
        return max(0, totalHours) / 24
    }

    /// Total hours remaining (not hour-of-day) for "ending soon" detection
    var hoursRemaining: Int {
        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: endDate)
        let totalHours = (components.day ?? 0) * 24 + (components.hour ?? 0)
        return max(0, totalHours)
    }
    
    /// Whether trial is ending within 48 hours
    var isEndingSoon: Bool {
        hoursRemaining <= 48 && hoursRemaining > 0 && status == .active
    }
    
    /// Progress percentage (0-100)
    var progressPercentage: Double {
        let totalDuration = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        return min(100, max(0, (elapsed / totalDuration) * 100))
    }
    
    /// Estimated savings if cancelled
    var estimatedAnnualSavings: Decimal {
        costAfterTrial * 12
    }
}


// MARK: - Trial Stats


// MARK: - Trial Templates


// MARK: - Supabase Database Model

