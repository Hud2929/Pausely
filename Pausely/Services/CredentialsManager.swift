
import Foundation

enum CredentialKey: String {
    case supabaseURL = "SUPABASE_URL"
    case supabaseAnonKey = "SUPABASE_ANON_KEY"
    case privacyAPIKey = "PRIVACY_API_KEY"
}

final class CredentialsManager {
    static let shared = CredentialsManager()
    private init() {}

    /// Fetch from Info.plist first, then environment variable
    nonisolated func get(_ key: CredentialKey) -> String? {
        // 1. Check Info.plist
        if let plistValue = Bundle.main.infoDictionary?[key.rawValue] as? String, !plistValue.isEmpty, !plistValue.contains("$") {  // money-guard: "$(VAR)" is an unexpanded build setting, not money
            return plistValue
        }
        // 2. Environment variable
        if let envValue = ProcessInfo.processInfo.environment[key.rawValue], !envValue.isEmpty, !envValue.contains("$") {  // money-guard: "$(VAR)" is an unexpanded build setting, not money
            return envValue
        }
        return nil
    }
}
