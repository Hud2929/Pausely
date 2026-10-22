import SwiftUI

enum DashboardTimeframe: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"


    var shortLabel: String {
        switch self {
        case .weekly: return "WK"
        case .monthly: return "MO"
        case .yearly: return "YR"
        }
    }
}
