import Foundation

/// What this iPhone's Keychain remembers about the account between launches: who was signed in (so
/// the app opens on their list without a flash of the welcome screen), the name that goes with an
/// account (Apple gives a name only on the very first sign-in), and a name typed on a sign-up form
/// that hasn't been finished. `AuthManager` decides when; this is only what is kept, and where.
@MainActor
enum AccountMemory {
    private static let userIdKey = "auth_cached_user_id"
    private static let emailKey = "auth_cached_email"
    private static let createdAtKey = "auth_cached_created_at"
    private static let accessTokenKey = "auth_access_token"
    private static let refreshTokenKey = "auth_refresh_token"
    private static let heldFirstNameKey = "pending_firstName"
    private static let heldLastNameKey = "pending_lastName"
    /// The address the held name was typed for.
    private static let heldNameEmailKey = "pending_nameEmail"

    /// Where it is kept. A test puts a Keychain of its own here, so it never touches the app's.
    static var keychain: KeychainManager = .shared

    // MARK: - Who was signed in

    static func rememberSession(userId: String, email: String?, createdAt: Date?) {
        keychain.save(userId, forKey: userIdKey)
        if let email { keychain.save(email, forKey: emailKey) }
        if let createdAt { keychain.save(ISO8601DateFormatter().string(from: createdAt), forKey: createdAtKey) }
    }

    /// The account that was signed in when the app last ran, or nil.
    static var session: (userId: String, email: String?, createdAt: Date?)? {
        guard let userId = keychain.get(userIdKey) else { return nil }
        let createdAt = keychain.get(createdAtKey).flatMap { ISO8601DateFormatter().date(from: $0) }
        return (userId, keychain.get(emailKey), createdAt)
    }

    /// The person who was signed in when the app last ran, with the name kept for them, or nil.
    /// A launch starts from this, before the account service has been asked anything.
    static var rememberedUser: User? {
        guard let remembered = session else { return nil }
        let kept = name(userId: remembered.userId)
        return User(id: remembered.userId, email: remembered.email, createdAt: remembered.createdAt,
                    firstName: kept.firstName, lastName: kept.lastName)
    }

    static func forgetSession() {
        for key in [userIdKey, emailKey, createdAtKey, accessTokenKey, refreshTokenKey] {
            keychain.delete(key: key)
        }
    }

    // MARK: - The name that goes with an account

    static func saveName(userId: String, firstName: String?, lastName: String?) {
        if let firstName { keychain.save(firstName, forKey: "profile_\(userId)_firstName") }
        if let lastName { keychain.save(lastName, forKey: "profile_\(userId)_lastName") }
    }

    static func name(userId: String) -> (firstName: String?, lastName: String?) {
        (keychain.get("profile_\(userId)_firstName"), keychain.get("profile_\(userId)_lastName"))
    }

    /// Removes the name kept for an account. Sign-out keeps it, because Apple gives a name only on the
    /// first sign-in and a returning person would otherwise come back nameless; deleting the account, or
    /// another account taking over this phone, removes it.
    static func forgetName(userId: String) {
        keychain.delete(key: "profile_\(userId)_firstName")
        keychain.delete(key: "profile_\(userId)_lastName")
    }

    // MARK: - A name waiting for a sign-up to finish

    /// Keeps the name typed on a sign-up form, with the address it was typed for.
    static func holdName(first: String?, last: String?, for email: String) {
        forgetHeldName()
        if let first, !first.isEmpty { keychain.save(first, forKey: heldFirstNameKey) }
        if let last, !last.isEmpty { keychain.save(last, forKey: heldLastNameKey) }
        keychain.save(email, forKey: heldNameEmailKey)
    }

    /// The held name, if it was typed for the address that has now signed in.
    static func heldName(for email: String?) -> (first: String?, last: String?) {
        nameTyped(for: email, first: keychain.get(heldFirstNameKey), last: keychain.get(heldLastNameKey),
                  typedFor: keychain.get(heldNameEmailKey))
    }

    /// A name typed on a sign-up form belongs to the address on that form. Left behind by a sign-up
    /// nobody finished, it is never given to a different account that signs in later.
    nonisolated static func nameTyped(for email: String?, first: String?, last: String?,
                                      typedFor: String?) -> (first: String?, last: String?) {
        guard let email, let typedFor, AuthLinkGate.sameAddress(typedFor, email) else { return (nil, nil) }
        return (first, last)
    }

    static func forgetHeldName() {
        for key in [heldFirstNameKey, heldLastNameKey, heldNameEmailKey] { keychain.delete(key: key) }
    }
}
