import Foundation

/// What the paywall says after a purchase or a restore that didn't end with Pro.
///
/// Each outcome gets its own words. Nothing is said when it worked (the paywall shows that itself) or
/// when the person closed Apple's sheet: they know what they did.
struct PaywallNotice: Equatable, Identifiable {
    let title: String
    let message: String
    /// Whether trying the same thing again can help.
    var offersRetry = false

    var id: String { title }

    static func after(_ outcome: StoreKitManager.PurchaseOutcome) -> PaywallNotice? {
        switch outcome {
        case .purchased, .cancelled:
            return nil
        case .pending:
            return PaywallNotice(title: L10n.string("Waiting for Approval"),
                                 message: L10n.string("This purchase needs someone's approval first. Pausely Pro turns on by itself once it's approved."))
        case .unverified:
            return PaywallNotice(title: L10n.string("Purchase Not Confirmed"),
                                 message: L10n.string("The App Store couldn't confirm this purchase. If you were charged, tap Restore Purchases."))
        case .failed:
            return PaywallNotice(title: L10n.string("The Purchase Didn't Go Through"),
                                 message: L10n.string("The App Store didn't complete it. Check your connection and try again."),
                                 offersRetry: true)
        }
    }

    static func after(_ outcome: StoreKitManager.RestoreOutcome) -> PaywallNotice? {
        switch outcome {
        case .restored, .cancelled:
            return nil
        case .nothingToRestore:
            return PaywallNotice(title: L10n.string("Nothing to Restore"),
                                 message: L10n.string("There's no Pausely Pro subscription on this Apple Account."))
        case .failed:
            return PaywallNotice(title: L10n.string("Couldn't Restore"),
                                 message: L10n.string("The App Store couldn't be reached. Try again in a moment."),
                                 offersRetry: true)
        }
    }
}
