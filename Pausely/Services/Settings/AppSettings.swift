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

/// Hardware-protected file storage for sensitive local caches (`subscriptions_cache.json`,
/// `sync_queue.json`). Transparently migrates legacy UserDefaults copies on first read and deletes
/// the legacy plaintext entry immediately.
@MainActor
enum ProtectedBlobStore {
    static func directory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Pausely", isDirectory: true)
    }

    static func read(filename: String, legacyKey: String,
                     directory: URL? = nil, defaults: UserDefaults = .standard,
                     fileManager: FileManager = .default) -> Data {
        let url = (directory ?? Self.directory(fileManager: fileManager)).appendingPathComponent(filename)
        if fileManager.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url) {
                DeviceFile.relaxProtection(of: url, fileManager: fileManager)
                return data
            }
            return Data()
        }
        // One-time migration from earlier versions that stored JSON Data in UserDefaults.
        guard let legacyData = defaults.data(forKey: legacyKey),
              let unwrapped = try? JSONDecoder().decode(Data.self, from: legacyData),
              !unwrapped.isEmpty else {
            return Data()
        }
        write(unwrapped, filename: filename, legacyKey: legacyKey, directory: directory, defaults: defaults, fileManager: fileManager)
        return unwrapped
    }

    static func write(_ data: Data, filename: String, legacyKey: String,
                      directory: URL? = nil, defaults: UserDefaults = .standard,
                      fileManager: FileManager = .default) {
        let dir = directory ?? Self.directory(fileManager: fileManager)
        let url = dir.appendingPathComponent(filename)
        defaults.removeObject(forKey: legacyKey)
        if data.isEmpty {
            try? fileManager.removeItem(at: url)
            return
        }
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// What the app keeps on the device between launches, besides the files with their own stores.
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private init() {}

    /// The subscription list as last seen, stored under iOS hardware data protection.
    var cachedSubscriptions: Data {
        get { ProtectedBlobStore.read(filename: "subscriptions_cache.json", legacyKey: "cached_subscriptions") }
        set { ProtectedBlobStore.write(newValue, filename: "subscriptions_cache.json", legacyKey: "cached_subscriptions") }
    }

    @AppSetting("subscriptions_cache_date", defaultValue: Date.distantPast)
    var subscriptionsCacheDate: Date

    /// Changes made on this device that the server has not confirmed yet (`SyncQueue`), stored under
    /// iOS hardware data protection.
    var syncQueueOperations: Data {
        get { ProtectedBlobStore.read(filename: "sync_queue.json", legacyKey: "sync_queue_operations") }
        set { ProtectedBlobStore.write(newValue, filename: "sync_queue.json", legacyKey: "sync_queue_operations") }
    }

    /// The plan last confirmed by StoreKit.
    @AppSetting("current_subscription_tier", defaultValue: SubscriptionTier.free)
    var currentTier: SubscriptionTier
}
