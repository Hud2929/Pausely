import Foundation

/// A value kept in UserDefaults as JSON under one key.
@propertyWrapper
struct AppSetting<T: Codable> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else { return defaultValue }
            return value
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
}

/// What the app keeps on the device between launches, besides the files with their own stores.
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private init() {}

    /// The subscription list as last seen, so the app opens with it before the network answers.
    @AppSetting("cached_subscriptions", defaultValue: Data())
    var cachedSubscriptions: Data

    @AppSetting("subscriptions_cache_date", defaultValue: Date.distantPast)
    var subscriptionsCacheDate: Date

    /// Changes made on this device that the server has not confirmed yet (`SyncQueue`).
    @AppSetting("sync_queue_operations", defaultValue: Data())
    var syncQueueOperations: Data

    /// The plan last confirmed by StoreKit.
    @AppSetting("current_subscription_tier", defaultValue: SubscriptionTier.free)
    var currentTier: SubscriptionTier
}
