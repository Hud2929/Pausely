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

    static func wipe() async {
        SubscriptionStore.shared.removeAllLocalData()
        LifecycleEventLog.shared.removeAll()
        PausePlanStore.shared.removeAll()
        await InboxScanner.shared.disconnectAll()
        UserDefaults.standard.removeObject(forKey: "lifecycle_last_run")
        UserDefaults.standard.removeObject(forKey: ownerKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
