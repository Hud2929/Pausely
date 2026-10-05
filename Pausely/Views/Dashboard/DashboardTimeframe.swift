import SwiftUI

enum DashboardTimeframe: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var short: String {
        switch self {
        case .weekly: return "wk"
        case .monthly: return "mo"
        case .yearly: return "yr"
        }
    }

    var shortLabel: String {
        switch self {
        case .weekly: return "WK"
        case .monthly: return "MO"
        case .yearly: return "YR"
        }
    }
}
