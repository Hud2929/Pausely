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
}
