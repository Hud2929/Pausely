import Foundation
import Security

/// How Pausely reaches an inbox.
enum MailboxKind: String, Codable, CaseIterable {
    case gmail       // Gmail API (Google sign-in)
    case microsoft   // Microsoft Graph (Outlook, Hotmail, Live, MSN, Microsoft 365)
    case imap        // IMAP over TLS with an app password (iCloud, Yahoo, AOL and others)
}

/// A connected inbox. Only the address and server live here; passwords and tokens live in the Keychain.
struct MailboxAccount: Codable, Identifiable, Hashable {
    var id: String
    var kind: MailboxKind
    var address: String
    var presetID: String?
    var host: String?
    var port: Int?
    var addedAt: Date
    var lastScan: Date?

    var providerName: String {
        switch kind {
        case .gmail: return "Gmail"
        case .microsoft: return "Outlook"
        case .imap: return IMAPPreset.find(presetID)?.name ?? host ?? "Email"
        }
    }
}

// MARK: - IMAP presets

/// Servers for providers that only offer IMAP to other apps. All use implicit TLS on port 993.
struct IMAPPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
    let domains: [String]
    /// Where the person creates an app password.
    let passwordPage: URL?
    /// Short, ordered steps shown while connecting.
    let steps: [String]

    static let all: [IMAPPreset] = [
        IMAPPreset(id: "icloud", name: "iCloud Mail", host: "imap.mail.me.com",
                   domains: ["icloud.com", "me.com", "mac.com"],
                   passwordPage: URL(string: "https://account.apple.com/account/manage"),
                   steps: ["Open account.apple.com and sign in.",
                           "Go to Sign-In and Security, then App-Specific Passwords.",
                           "Create one named Pausely and paste it here."]),
        IMAPPreset(id: "yahoo", name: "Yahoo Mail", host: "imap.mail.yahoo.com",
                   domains: ["yahoo.com", "ymail.com", "rocketmail.com", "yahoo.ca", "yahoo.co.uk", "yahoo.fr",
                             "yahoo.de", "yahoo.es", "yahoo.it", "yahoo.com.au", "yahoo.co.in", "yahoo.com.br"],
                   passwordPage: URL(string: "https://login.yahoo.com/account/security"),
                   steps: ["Open Yahoo Account Security.", "Choose Generate app password and name it Pausely.",
                           "Paste the password here."]),
        IMAPPreset(id: "aol", name: "AOL Mail", host: "imap.aol.com",
                   domains: ["aol.com", "aim.com", "verizon.net", "love.com", "wow.com", "games.com"],
                   passwordPage: URL(string: "https://login.aol.com/account/security"),
                   steps: ["Open AOL Account Security.", "Choose Generate app password and name it Pausely.",
                           "Paste the password here."]),
        IMAPPreset(id: "gmail-imap", name: "Gmail (app password)", host: "imap.gmail.com",
                   domains: [],
                   passwordPage: URL(string: "https://myaccount.google.com/apppasswords"),
                   steps: ["Turn on 2-Step Verification for your Google Account if it isn't on.",
                           "Open myaccount.google.com/apppasswords and create one named Pausely.",
                           "Paste the 16-letter password here."]),
        IMAPPreset(id: "gmx", name: "GMX", host: "imap.gmx.com",
                   domains: ["gmx.com", "gmx.us", "gmx.co.uk"],
                   passwordPage: URL(string: "https://www.gmx.com"),
                   steps: ["In GMX settings, allow access through POP3 and IMAP.",
                           "Use your GMX password, or an app password if you use two-factor sign-in."]),
        IMAPPreset(id: "gmx-de", name: "GMX (gmx.net)", host: "imap.gmx.net",
                   domains: ["gmx.net", "gmx.de", "gmx.at", "gmx.ch"],
                   passwordPage: URL(string: "https://www.gmx.net"),
                   steps: ["In GMX settings, allow access through POP3 and IMAP.",
                           "Use your GMX password, or an app password if you use two-factor sign-in."]),
        IMAPPreset(id: "webde", name: "WEB.DE", host: "imap.web.de",
                   domains: ["web.de"],
                   passwordPage: URL(string: "https://web.de"),
                   steps: ["In WEB.DE settings, allow access through POP3 and IMAP.",
                           "Use your WEB.DE password, or an app password if you use two-factor sign-in."]),
        IMAPPreset(id: "zoho", name: "Zoho Mail", host: "imap.zoho.com",
                   domains: ["zoho.com", "zohomail.com"],
                   passwordPage: URL(string: "https://accounts.zoho.com/home#security/app_password"),
                   steps: ["In Zoho, turn on IMAP access in Mail settings.",
                           "Create an app-specific password and paste it here."]),
        IMAPPreset(id: "fastmail", name: "Fastmail", host: "imap.fastmail.com",
                   domains: ["fastmail.com", "fastmail.fm"],
                   passwordPage: URL(string: "https://app.fastmail.com/settings/security/integrations"),
                   steps: ["In Fastmail, open Settings, Privacy & Security, Integrations.",
                           "Create a new app password with IMAP access and paste it here."]),
        IMAPPreset(id: "xfinity", name: "Xfinity (Comcast)", host: "imap.comcast.net",
                   domains: ["comcast.net"],
                   passwordPage: URL(string: "https://www.xfinity.com"),
                   steps: ["In Xfinity Connect settings, allow third-party access.", "Use your Xfinity password."])
    ]

    static func find(_ id: String?) -> IMAPPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// The preset for an address, by its domain ("jane@me.com" → iCloud).
    static func forAddress(_ address: String) -> IMAPPreset? {
        guard let domain = address.split(separator: "@").last?.lowercased() else { return nil }
        if domain == "gmail.com" || domain == "googlemail.com" { return find("gmail-imap") }
        return all.first { $0.domains.contains(domain) }
    }
}

// MARK: - Storage

/// Connected inboxes (metadata in UserDefaults) and their secrets (Keychain, this device only, readable
/// after the first unlock so background checks can run while the phone is locked).
enum MailboxAccountStore {
    private static let accountsKey = "mailbox_accounts_v1"
    private static let cursorPrefix = "mailbox_cursor_"
    private static let service = "com.pausely.app.mailbox"

    enum Secret: String {
        case password, accessToken, refreshToken
    }

    static func all() -> [MailboxAccount] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey) else { return [] }
        return (try? JSONDecoder().decode([MailboxAccount].self, from: data)) ?? []
    }

    static func upsert(_ account: MailboxAccount) {
        var accounts = all().filter { $0.id != account.id }
        accounts.append(account)
        accounts.sort { $0.addedAt < $1.addedAt }
        if let data = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(data, forKey: accountsKey) }
    }

    /// Removes the account, its secrets and its sync position.
    static func remove(_ id: String) {
        let accounts = all().filter { $0.id != id }
        if let data = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(data, forKey: accountsKey) }
        for secret in [Secret.password, .accessToken, .refreshToken] { deleteSecret(secret, for: id) }
        UserDefaults.standard.removeObject(forKey: cursorPrefix + id)
    }

    static func removeAll() {
        for account in all() { remove(account.id) }
        UserDefaults.standard.removeObject(forKey: accountsKey)
    }

    // MARK: Sync position (Gmail history id, Graph delta link, IMAP uidvalidity:uid)

    static func cursor(for id: String) -> String? { UserDefaults.standard.string(forKey: cursorPrefix + id) }
    static func setCursor(_ value: String?, for id: String) {
        if let value { UserDefaults.standard.set(value, forKey: cursorPrefix + id) }
        else { UserDefaults.standard.removeObject(forKey: cursorPrefix + id) }
    }

    // MARK: Keychain

    static func secret(_ secret: Secret, for id: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(id).\(secret.rawValue)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func setSecret(_ value: String, _ secret: Secret, for id: String) -> Bool {
        let account = "\(id).\(secret.rawValue)"
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(base as CFDictionary, attributes as CFDictionary) == errSecSuccess { return true }
        let status = SecItemAdd(base.merging(attributes) { $1 } as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func deleteSecret(_ secret: Secret, for id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(id).\(secret.rawValue)"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
