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

    static func wipe() async {
        // The name kept for this account, and an email address older versions saved and never read.
        if let owner = UserDefaults.standard.string(forKey: ownerKey) {
            RevolutionaryAuthManager.forgetProfile(userId: owner)
        }
        UserDefaults.standard.removeObject(forKey: "last_auth_email")
        SubscriptionStore.shared.removeAllLocalData()
        LifecycleEventLog.shared.removeAll()
        PausePlanStore.shared.removeAll()
        await InboxScanner.shared.disconnectAll()
        await PaymentManager.shared.setProGrant(false)
        UserDefaults.standard.removeObject(forKey: "lifecycle_last_run")
        UserDefaults.standard.removeObject(forKey: ownerKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
