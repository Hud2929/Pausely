import Foundation

@propertyWrapper
struct AppSetting<T: Codable> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return defaultValue
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                return defaultValue
            }
        }
        nonmutating set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: key)
            } catch {
                // Silently fail; caller can log if needed
            }
        }
    }

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private init() {}

    @AppSetting("selected_currency", defaultValue: "USD")
    var selectedCurrency: String

    @AppSetting("is_biometric_enabled", defaultValue: false)
    var isBiometricEnabled: Bool

    @AppSetting("has_completed_onboarding", defaultValue: false)
    var hasCompletedOnboarding: Bool

    @AppSetting("use_local_storage_fallback", defaultValue: false)
    var useLocalStorageFallback: Bool

    @AppSetting("cached_subscriptions", defaultValue: Data())
    var cachedSubscriptions: Data

    @AppSetting("subscriptions_cache_date", defaultValue: Date.distantPast)
    var subscriptionsCacheDate: Date

    @AppSetting("local_subscriptions", defaultValue: Data())
    var localSubscriptions: Data

    @AppSetting("sync_queue_operations", defaultValue: Data())
    var syncQueueOperations: Data

    @AppSetting("app_theme", defaultValue: "system")
    var appTheme: String

    @AppSetting("has_seen_review_prompt", defaultValue: false)
    var hasSeenReviewPrompt: Bool

    @AppSetting("referral_code", defaultValue: "")
    var referralCode: String

    @AppSetting("referral_discount_used", defaultValue: false)
    var referralDiscountUsed: Bool

    @AppSetting("total_savings_tracked", defaultValue: 0.0)
    var totalSavingsTracked: Double

    @AppSetting("price_history", defaultValue: Data())
    var priceHistory: Data

    @AppSetting("widget_data", defaultValue: Data())
    var widgetData: Data

    @AppSetting("spotlight_indexed_ids", defaultValue: [String]())
    var spotlightIndexedIds: [String]

    @AppSetting("screen_time_cached_state", defaultValue: Data())
    var screenTimeCachedState: Data

    @AppSetting("last_live_activity_id", defaultValue: "")
    var lastLiveActivityId: String

    @AppSetting("trial_start_date", defaultValue: Date.distantPast)
    var trialStartDate: Date

    @AppSetting("premium_purchase_date", defaultValue: Date.distantPast)
    var premiumPurchaseDate: Date

    @AppSetting("premium_source", defaultValue: "")
    var premiumSource: String

    @AppSetting("last_sync_date", defaultValue: Date.distantPast)
    var lastSyncDate: Date

    @AppSetting("user_preferences", defaultValue: Data())
    var userPreferences: Data

    @AppSetting("notification_settings", defaultValue: Data())
    var notificationSettings: Data

    @AppSetting("has_migrated_to_app_settings", defaultValue: false)
    var hasMigratedToAppSettings: Bool

    @AppSetting("cancellation_requests", defaultValue: Data())
    var cancellationRequests: Data

    @AppSetting("tracked_trials", defaultValue: Data())
    var trackedTrials: Data

    @AppSetting("trial_stats", defaultValue: Data())
    var trialStats: Data

    @AppSetting("live_activities_enabled", defaultValue: false)
    var liveActivitiesEnabled: Bool

    @AppSetting("local_referral_code", defaultValue: "")
    var localReferralCode: String

    @AppSetting("active_perks", defaultValue: Data())
    var activePerks: Data

    @AppSetting("completed_actions", defaultValue: Data())
    var completedActions: Data

    @AppSetting("total_money_saved", defaultValue: 0.0)
    var totalMoneySaved: Double

    @AppSetting("current_subscription_tier", defaultValue: SubscriptionTier.free)
    var currentTier: SubscriptionTier
}
