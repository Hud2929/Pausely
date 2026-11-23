import Foundation
import UserNotifications

/// Everything Pausely keeps about a person on this iPhone: the cached subscription list, the event
/// history behind the Savings Receipt, the Pause Plan and the reminders. Removed when the account is
/// deleted, and when someone else signs in on the same device.
@MainActor
enum LocalUserData {
    private static let ownerKey = "local_data_owner"

    /// Called when the main app appears for a signed-in person. If this device's local history belongs
    /// to a different account, it's removed first so nobody sees someone else's receipt.
    static func claim(for userId: String?) async {
        guard let userId, !userId.isEmpty else { return }
        let defaults = UserDefaults.standard
        if let owner = defaults.string(forKey: ownerKey), owner != userId {
            await wipe()
        }
        defaults.set(userId, forKey: ownerKey)
    }

    /// False when what's on this iPhone was left by a different account. Until `claim` has removed
    /// it, nothing of it is sent anywhere and nothing is fetched into it.
    static func belongs(to userId: String) -> Bool {
        guard let owner = UserDefaults.standard.string(forKey: ownerKey) else { return true }
        return owner.caseInsensitiveCompare(userId) == .orderedSame
    }

    /// Saved under a fixed name and belonging to a person, not to the iPhone. `wipe` removes every one.
    /// `LocalDataGuardTests` reads the sources: a value saved under a new name has to be listed here,
    /// or in the test as a setting of the device with the reason it may outlive an account.
    static let personalKeys = [
        ownerKey, "last_auth_email", "lifecycle_last_run",
        SubscriptionStore.syncedUserKey, "cached_subscriptions", "subscriptions_cache_date", "sync_queue_operations",
        "pausely_user_corrections_v1", "pausely_pro_auto_added", "pausely_pro_grant", "pausely_pro_line_ended",
        "first_run_tally_waiting",
        "gmail_connected_email", "gmail_last_history_id", "mailbox_accounts_v1",
        "auth_reset_requested_at", "auth_link_requested_email", "auth_link_requested_at",
        "subscription_price_history", InboxScanner.assumedDollarKey,
    ]

    /// Saved once per subscription, under its name (the hours a person typed in), and once per account,
    /// under its id (when that person confirmed their age).
    static let personalKeyPrefixes = ["usage_", "age_consent_"]

    static func removeSavedValues(from defaults: UserDefaults = .standard) {
        for key in personalKeys { defaults.removeObject(forKey: key) }
        for key in defaults.dictionaryRepresentation().keys where personalKeyPrefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    static func wipe() async {
        // The name kept for this account.
        if let owner = UserDefaults.standard.string(forKey: ownerKey) {
            AccountMemory.forgetName(userId: owner)
        }
        AccountMemory.forgetHeldName()
        SubscriptionStore.shared.removeAllLocalData()
        LifecycleEventLog.shared.removeAll()
        PausePlanStore.shared.removeAll()
        await InboxScanner.shared.disconnectAll()
        await PaymentManager.shared.setProGrant(false)
        VerdictCenter.shared.forget()
        // "Keep it" presses made before a first unlock and not yet recorded.
        _ = LockedKeeps.take()
        LogoStore.removeSavedLogos()
        removeSavedValues()
        UsageLog.shared.objectWillChange.send()
        removeReminders()
    }

    /// Signing out. What is the person's stays on the iPhone for when they sign back in (the history
    /// behind the Savings Receipt exists nowhere else), but nothing shows it meanwhile: not a widget,
    /// not Spotlight, not a reminder on the Lock Screen, not a Shortcut.
    static func hideWhileSignedOut() {
        SubscriptionStore.shared.hideList()
        VerdictCenter.shared.forget()
        removeReminders()
    }

    private static func removeReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
