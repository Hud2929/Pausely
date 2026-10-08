import Foundation

/// What the user told Pausely about a merchant. Stored only on this device.
enum UserVerdict: String, Codable, Equatable {
    /// "This is not a subscription": never show it again.
    case notSubscription
    /// "Yes, this is a subscription": always rank it as at least likely.
    case trusted
}

enum UserCorrections {
    private static let storageKey = "pausely_user_corrections_v1"

    static func load(defaults: UserDefaults = .standard) -> [String: UserVerdict] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: UserVerdict].self, from: data) else { return [:] }
        return decoded
    }

    /// Pass nil to forget a previous decision.
    static func set(_ merchantKey: String, _ verdict: UserVerdict?, defaults: UserDefaults = .standard) {
        var all = load(defaults: defaults)
        if let verdict { all[merchantKey] = verdict } else { all.removeValue(forKey: merchantKey) }
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: storageKey) }
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
