import SwiftUI

// MARK: - Global App Sheet Navigation

enum AppSheet: Identifiable {
    case addSubscription
    case subscriptionDetail(Subscription)
    case subscriptionBrowser
    case paywall
    case referral
    case settings
    case currencySettings
    case helpSupport
    case notificationsSettings
    case privacySecurity
    case themeSettings
    case languageSettings
    case screenTimeSetup
    case bulkAdd
    case trialProtection
    case billingHistory

    var id: String {
        switch self {
        case .addSubscription: return "addSubscription"
        case .subscriptionDetail(let sub): return "subscriptionDetail-\(sub.id)"
        case .subscriptionBrowser: return "subscriptionBrowser"
        case .paywall: return "paywall"
        case .referral: return "referral"
        case .settings: return "settings"
        case .currencySettings: return "currencySettings"
        case .helpSupport: return "helpSupport"
        case .notificationsSettings: return "notificationsSettings"
        case .privacySecurity: return "privacySecurity"
        case .themeSettings: return "themeSettings"
        case .languageSettings: return "languageSettings"
        case .screenTimeSetup: return "screenTimeSetup"
        case .bulkAdd: return "bulkAdd"
        case .trialProtection: return "trialProtection"
        case .billingHistory: return "billingHistory"
        }
    }
}

