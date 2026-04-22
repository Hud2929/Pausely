//  TimeRange.swift
//  Pausely
//
//  Shared TimeRange enum to consolidate multiple view-specific definitions
//  Replaces: InsightsView.TimeRange, PremiumMainTabView.TimeRange, etc.

import Foundation

/// Unified time range selection for analytics and insights
/// Consolidates multiple TimeRange definitions across the codebase
enum TimeRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
    case all = "All Time"
    
    var id: String { rawValue }
    
    /// Display title for the time range
    var title: String { rawValue }
    
    /// Short title for compact displays
    var shortTitle: String {
        switch self {
        case .today: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .quarter: return "3M"
        case .year: return "1Y"
        case .all: return "ALL"
        }
    }
    
    /// Number of days for calculations
    var days: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .all: return 365 * 10 // 10 years default for "all time"
        }
    }
    
    /// Date interval for the time range
    var dateInterval: DateInterval {
        let now = Date()
        let calendar = Calendar.current
        let startDate: Date

        switch self {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .week:
            guard let date = calendar.date(byAdding: .day, value: -7, to: now) else {
                startDate = now
                break
            }
            startDate = date
        case .month:
            guard let date = calendar.date(byAdding: .day, value: -30, to: now) else {
                startDate = now
                break
            }
            startDate = date
        case .quarter:
            guard let date = calendar.date(byAdding: .day, value: -90, to: now) else {
                startDate = now
                break
            }
            startDate = date
        case .year:
            guard let date = calendar.date(byAdding: .day, value: -365, to: now) else {
                startDate = now
                break
            }
            startDate = date
        case .all:
            guard let date = calendar.date(byAdding: .year, value: -10, to: now) else {
                startDate = now
                break
            }
            startDate = date
        }

        return DateInterval(start: startDate, end: now)
    }
}

// MARK: - Legacy Support

/// Deprecated: Use TimeRange instead
/// This typealias provides backward compatibility for RevolutionaryScreenTimeDashboard
@available(*, deprecated, renamed: "TimeRange")
typealias DashboardTimeRange = TimeRange
