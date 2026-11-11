import Foundation
import LocalAuthentication
import SwiftUI
import Supabase
import os.log

// MARK: - Supabase Integration
import Auth

/// Revolutionary authentication manager with Pausely-branded custom emails,
/// deep linking support for email verification, and comprehensive auth state management
@MainActor
class RevolutionaryAuthManager: ObservableObject {
    static let shared = RevolutionaryAuthManager()
    
    // MARK: - Published State
    @Published var state: PauselyAuthState = .initial
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isBiometricEnabled = false
    /// A password-reset code or link was accepted: the next thing the person sees is "choose a new password".
    @Published var needsNewPassword = false
    /// Why a link from an account email didn't work, in words the person can act on.
    @Published var linkProblem: String?

    private var verifyTask: Task<Void, Never>?

    // MARK: - Private Properties
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let biometricKey = "biometric_auth_enabled"
    private let lastEmailKey = "last_auth_email"
    private var refreshTask: Task<Void, Never>?
    private var pendingPassword: String?
    /// The address `pendingPassword` was typed for. The password is saved only on that account.
    private var pendingPasswordEmail: String?
    /// The account a reset was accepted for, held until the new password is saved.
    private var recoveryUser: Auth.User?
    private static let resetRequestedKey = "auth_reset_requested_at"
    /// The address this device last asked a code or a reset for, and when (see `AuthLinkGate`).
    private static let linkRequestedEmailKey = "auth_link_requested_email"
    private static let linkRequestedAtKey = "auth_link_requested_at"

    /// Where the links in sign-up and sign-in emails come back to. It has to be on the account service's
    /// list of allowed redirect addresses; if it isn't, the service uses its own default address instead.
    static let confirmRedirect = URL(string: "pausely://auth/confirm")
    static let resetRedirect = URL(string: "pausely://auth/reset-password")

    // MARK: - Scale Optimizations
    private var pendingRequests: [String: Task<Any, Error>] = [:]
    private var lastTokenRefresh: Date?
    private let minRefreshInterval: TimeInterval = 60 // Minimum 60 seconds between refresh
    
    // Actor for thread-safe request management
    private actor RequestManager {
        private var requests: [String: Task<Any, Error>] = [:]
        
        func getRequest(for key: String) -> Task<Any, Error>? {
            return requests[key]
        }
        
        func setRequest(_ task: Task<Any, Error>, for key: String) {
            requests[key] = task
        }
        
        func removeRequest(for key: String) {
            requests.removeValue(forKey: key)
        }
        
    }
    private let requestManager = RequestManager()

    // UserDefaults keys for session cache
    private static let cachedUserIdKey    = "auth_cached_user_id"
    private static let cachedEmailKey     = "auth_cached_email"
    private static let cachedCreatedAtKey = "auth_cached_created_at"
    private static let pendingFirstNameKey = "pending_firstName"
    private static let pendingLastNameKey  = "pending_lastName"
    
    // Keychain keys for secure storage
    private static let keychainAccessTokenKey = "auth_access_token"
    private static let keychainRefreshTokenKey = "auth_refresh_token"

    // MARK: - Initialization
    private init() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: biometricKey)

        #if DEBUG
        // UI tests pass --reset-state to start signed out, whatever a previous run left behind.
        if ProcessInfo.processInfo.arguments.contains("--reset-state") {
            Self.forgetSessionForUITests()
            Task { [client] in try? await client.auth.signOut(scope: .local) }
            return
        }

        // Debug bypass for simulator testing — set via:
        // defaults write com.pausely.app.Pausely debug_auth_bypass -bool true
        if UserDefaults.standard.bool(forKey: "debug_auth_bypass") {
            let user = User(id: "debug-user", email: "debug@pausely.app", createdAt: Date(),
                            firstName: "Debug", lastName: "User")
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            return
        }
        #endif

        // Restore session synchronously so the UI is correct on the very first frame,
        // with no flash of the login screen for returning users.
        if let uid = KeychainManager.shared.get(Self.cachedUserIdKey) {
            let email     = KeychainManager.shared.get(Self.cachedEmailKey)
            let createdAtString = KeychainManager.shared.get(Self.cachedCreatedAtKey)
            let createdAt = createdAtString.flatMap { ISO8601DateFormatter().date(from: $0) }
            let profile   = Self.loadProfileStatic(userId: uid)
            let user = User(id: uid, email: email, createdAt: createdAt,
                            firstName: profile.firstName, lastName: profile.lastName)
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            PauselyLogger.info("Restored cached session for: \(email ?? uid)", category: "auth")
        }

        // Async: verify the Supabase token is still valid and refresh user data.
        verifyTask = Task { [weak self] in
            guard let self = self else { return }
            await verifySession()
        }
    }

    // MARK: - Session Cache

    private func cacheSession(userId: String, email: String?, createdAt: Date?) {
        KeychainManager.shared.save(userId, forKey: Self.cachedUserIdKey)
        if let email = email { KeychainManager.shared.save(email, forKey: Self.cachedEmailKey) }
        if let createdAt = createdAt {
            KeychainManager.shared.save(ISO8601DateFormatter().string(from: createdAt), forKey: Self.cachedCreatedAtKey)
        }
    }

    private func clearSessionCache() {
        KeychainManager.shared.delete(key: Self.cachedUserIdKey)
        KeychainManager.shared.delete(key: Self.cachedEmailKey)
        KeychainManager.shared.delete(key: Self.cachedCreatedAtKey)
        clearKeychainTokens()
    }

    #if DEBUG
    /// UI tests (`--reset-state`): forget any session a previous run left, before it's restored.
    static func forgetSessionForUITests() {
        for key in [cachedUserIdKey, cachedEmailKey, cachedCreatedAtKey, keychainAccessTokenKey, keychainRefreshTokenKey] {
            KeychainManager.shared.delete(key: key)
        }
        UserDefaults.standard.removeObject(forKey: "debug_auth_bypass")
    }
    #endif

    // MARK: - Profile Persistence

    private func saveProfile(userId: String, firstName: String?, lastName: String?) {
        if let fn = firstName { KeychainManager.shared.save(fn, forKey: "profile_\(userId)_firstName") }
        if let ln = lastName  { KeychainManager.shared.save(ln, forKey: "profile_\(userId)_lastName") }
    }

    private func loadProfile(userId: String) -> (firstName: String?, lastName: String?) {
        Self.loadProfileStatic(userId: userId)
    }

    private static func loadProfileStatic(userId: String) -> (firstName: String?, lastName: String?) {
        let fn = KeychainManager.shared.get("profile_\(userId)_firstName")
        let ln = KeychainManager.shared.get("profile_\(userId)_lastName")
        return (fn, ln)
    }

    private func makeUser(from supabaseUser: Auth.User,
                          firstName: String? = nil,
                          lastName: String? = nil) -> User {
        let profile = loadProfile(userId: supabaseUser.id.uuidString)
        return User(
            id: supabaseUser.id.uuidString,
            email: supabaseUser.email,
            createdAt: supabaseUser.createdAt,
            firstName: firstName ?? profile.firstName,
            lastName:  lastName  ?? profile.lastName
        )
    }

    // MARK: - Post Auth Setup

    /// Called after any successful authentication.
    /// Checks Supabase `profiles.is_pro` to honor lifetime/admin-granted Pro status.
    private func postAuthSetup(user: User) {
        Task {
            await checkLifetimeProStatus(userId: user.id)
        }
    }

    private func checkLifetimeProStatus(userId: String) async {
        struct ProfileRow: Decodable {
            let is_pro: Bool?
        }
        do {
            let rows: [ProfileRow] = try await SupabaseManager.shared.client
                .from("profiles")
                .select("is_pro")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            // Admin-granted Pro follows the account: granted, or taken away when the flag is cleared.
            await PaymentManager.shared.setProGrant(rows.first?.is_pro == true)
        } catch {
            PauselyLogger.error("Failed to check lifetime pro: \(error)", category: "auth")
        }
    }

    deinit {
        refreshTask?.cancel()
        verifyTask?.cancel()
    }

    // MARK: - Session Verification

    /// Verifies the Supabase session asynchronously after a cached restore.
    /// Signs out silently if the token has expired and cannot be refreshed.
    private func verifySession() async {
        if let session = client.auth.currentSession {
            let user = makeUser(from: session.user)
            cacheSession(userId: session.user.id.uuidString,
                         email: session.user.email,
                         createdAt: session.user.createdAt)
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            PauselyLogger.info("Session verified for: \(user.email ?? user.id)", category: "auth")
            startSessionRefresh()
            postAuthSetup(user: user)

        } else if isAuthenticated {
            // Cache said we're logged in but Supabase disagrees — token expired.
            PauselyLogger.info("Cached session invalid — signing out", category: "auth")
            clearSessionCache()
            currentUser = nil
            isAuthenticated = false
            state = .unauthenticated
        } else {
            state = .unauthenticated
        }
    }
    
    private func startSessionRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000) // 15 minutes (was 5)
                
                if Task.isCancelled { break }
                
                // Throttle refresh to prevent hammering
                if let lastRefresh = self.lastTokenRefresh,
                   Date().timeIntervalSince(lastRefresh) < self.minRefreshInterval {
                    continue
                }
                
                await self.performTokenRefresh()
            }
        }
    }
    
    /// Optimized token refresh with deduplication using actor
    private func performTokenRefresh() async {
        let requestKey = "token_refresh"
        
        // Check for existing request
        if let existingTask = await requestManager.getRequest(for: requestKey) {
            _ = try? await existingTask.value
            return
        }
        
        let task = Task<Any, Error> { [weak self] in
            guard let self = self else { throw PauselyAuthError.unknown(NSError(domain: "Auth", code: -1)) }

            self.lastTokenRefresh = Date()
            _ = try await self.client.auth.session
            return true
        }
        
        await requestManager.setRequest(task, for: requestKey)
        
        defer {
            Task { [weak self] in
                guard let self = self else { return }
                await requestManager.removeRequest(for: requestKey)
            }
        }
        
        _ = try? await task.value
    }
    
    // MARK: - Secure Token Storage (Using KeychainManager)


    private func clearKeychainTokens() {
        KeychainManager.shared.delete(key: Self.keychainAccessTokenKey)
        KeychainManager.shared.delete(key: Self.keychainRefreshTokenKey)
    }
    
    // MARK: - Sign Up with Pausely-branded Email
    

    // MARK: - OTP-based Email Verification (REVOLUTIONARY)

    /// Signs up using OTP instead of link-based confirmation.
    /// Sends a 6-digit code to the user's email for verification.
    func signUpWithOTP(email: String, password: String,
                       firstName: String? = nil, lastName: String? = nil) async throws {
        guard AgeConsentManager.shared.hasPassedDeviceGate else { throw PauselyAuthError.ageConsentRequired }
        state = .loading

        do {
            // Store password and profile temporarily for after OTP verification
            pendingPassword = password
            pendingPasswordEmail = email
            noteCodeRequested(for: email)
            if let fn = firstName, !fn.isEmpty { KeychainManager.shared.save(fn, forKey: Self.pendingFirstNameKey) }
            if let ln = lastName, !ln.isEmpty { KeychainManager.shared.save(ln, forKey: Self.pendingLastNameKey) }
            UserDefaults.standard.set(email, forKey: lastEmailKey)

            // Send OTP — creates user if they don't exist
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: Self.confirmRedirect,
                shouldCreateUser: true
            )

            state = .emailConfirmationRequired(email)

        } catch {
            pendingPassword = nil
            pendingPasswordEmail = nil
            KeychainManager.shared.delete(key: Self.pendingFirstNameKey)
            KeychainManager.shared.delete(key: Self.pendingLastNameKey)
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    /// Verifies the 6-digit code sent by email, then finishes the sign-up.
    func verifyEmailOTP(email: String, code: String) async throws {
        state = .loading
        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            await finishEmailSignIn(response.user)
        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .emailConfirmationRequired(email)
            throw authError
        }
    }

    /// The end of every email sign-up or sign-in, by code or by link: remember the session, apply the name
    /// and password typed on the sign-up form if this finishes one, and show the app.
    private func finishEmailSignIn(_ supabaseUser: Auth.User) async {
        let firstName = KeychainManager.shared.get(Self.pendingFirstNameKey)
        let lastName = KeychainManager.shared.get(Self.pendingLastNameKey)

        let user = makeUser(from: supabaseUser, firstName: firstName, lastName: lastName)
        cacheSession(userId: supabaseUser.id.uuidString, email: supabaseUser.email, createdAt: supabaseUser.createdAt)
        if let firstName { saveProfile(userId: supabaseUser.id.uuidString, firstName: firstName, lastName: lastName) }

        if let password = pendingPassword {
            let typedFor = pendingPasswordEmail
            pendingPassword = nil
            pendingPasswordEmail = nil
            // The email is proven and the account exists. If saving the password fails (it's the one the
            // account already has, or the network dropped), the person is still in, and "Forgot password"
            // sets one later. A password typed for one address is never saved on a different account.
            if let typedFor, AuthLinkGate.sameAddress(typedFor, supabaseUser.email ?? "") {
                do {
                    _ = try await client.auth.update(user: UserAttributes(password: password))
                } catch {
                    os_log("Saving the sign-up password failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
                }
            }
        }
        forgetCodeRequest()
        KeychainManager.shared.delete(key: Self.pendingFirstNameKey)
        KeychainManager.shared.delete(key: Self.pendingLastNameKey)

        currentUser = user
        isAuthenticated = true
        state = .authenticated(user)
        startSessionRefresh()
        postAuthSetup(user: user)
    }

    /// Resend the OTP code to the user's email
    func resendOTP(email: String) async throws {
        noteCodeRequested(for: email)
        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: Self.confirmRedirect,
                shouldCreateUser: true
            )
        } catch {
            throw PauselyAuthError.unknown(error)
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        state = .loading
        #if DEBUG
        PauselyLogger.info("Attempting sign in for: \(email)", category: "auth")
        #endif
        
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            // Save email for biometric auth
            UserDefaults.standard.set(email, forKey: lastEmailKey)

            let supabaseUser = session.user

            let user = makeUser(from: supabaseUser)
            cacheSession(userId: supabaseUser.id.uuidString,
                         email: supabaseUser.email,
                         createdAt: supabaseUser.createdAt)

            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            #if DEBUG
            PauselyLogger.info("Sign in successful for: \(email)", category: "auth")
            #endif

            startSessionRefresh()
            postAuthSetup(user: user)

        } catch let error as PauselyAuthError {
            #if DEBUG
            PauselyLogger.error("Sign in failed with AuthError: \(error.localizedDescription)", category: "auth")
            #endif
            state = .error(error)
            throw error
        } catch {
            let authError: PauselyAuthError
            if let authErr = error as? PauselyAuthError {
                authError = authErr
            } else {
                let nsError = error as NSError
                if nsError.domain == "PauselyAuthError" {
                    switch nsError.code {
                    case 400:
                        authError = .invalidCredentials
                    default:
                        authError = .unknown(error)
                    }
                } else {
                    authError = .unknown(error)
                }
            }
            #if DEBUG
            PauselyLogger.error("Sign in failed with error: \(authError.localizedDescription)", category: "auth")
            #endif
            state = .error(authError)
            throw authError
        }
    }

    
    

    // MARK: - Sign in with Apple

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        state = .loading

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce)
            )

            let supabaseUser = session.user
            // Apple only provides fullName on first sign-in; persist it immediately
            let firstName = fullName?.givenName?.nilIfEmpty
            let lastName  = fullName?.familyName?.nilIfEmpty
            let existingProfile = loadProfile(userId: supabaseUser.id.uuidString)
            saveProfile(userId: supabaseUser.id.uuidString,
                        firstName: firstName ?? existingProfile.firstName,
                        lastName:  lastName  ?? existingProfile.lastName)
            cacheSession(userId: supabaseUser.id.uuidString,
                         email: supabaseUser.email,
                         createdAt: supabaseUser.createdAt)

            let user = makeUser(from: supabaseUser, firstName: firstName, lastName: lastName)

            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            #if DEBUG
            PauselyLogger.info("Apple Sign In successful for user: \(user.id)", category: "auth")
            #endif

            startSessionRefresh()
            postAuthSetup(user: user)

        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    // MARK: - Magic Link Sign In
    

    // MARK: - Email Confirmation Polling
    
    
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        state = .loading
        noteCodeRequested(for: email)

        do {
            try await client.auth.resetPasswordForEmail(email, redirectTo: Self.resetRedirect)
            // A reset link that comes back without saying what it is (the service's default address) is
            // still a reset if one was asked for here within the hour the link lasts.
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.resetRequestedKey)
            
            state = .unauthenticated

        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }
    
    // MARK: - Delete Account

    /// Deletes the account and everything stored with it: on the server (supabase function
    /// `delete_my_account`, which cascades to every table) and on this iPhone. Subscriptions billed by
    /// Apple, including Pausely Pro, are not cancelled; Apple manages those.
    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
        await LocalUserData.wipe()
        await signOut()
    }

    // MARK: - Sign Out
    
    func signOut() async {
        refreshTask?.cancel()
        refreshTask = nil
        
        // Cancel all pending auth requests (async-safe)
        pendingRequests.values.forEach { $0.cancel() }
        pendingRequests.removeAll()
        
        do {
            try await client.auth.signOut()
            clearSessionCache()
        } catch {
            os_log("Sign out failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }

        #if DEBUG
        UserDefaults.standard.removeObject(forKey: "debug_auth_bypass")
        #endif
        needsNewPassword = false
        recoveryUser = nil
        pendingPassword = nil
        pendingPasswordEmail = nil
        forgetCodeRequest()
        isAuthenticated = false
        currentUser = nil
        state = .unauthenticated
    }

    #if DEBUG
    /// Debug builds only: use the app without an account, as the built-in test user. Nothing is sent to
    /// the server; everything stays on this device. Signing out leaves it.
    func enterAsDebugUser() {
        UserDefaults.standard.set(true, forKey: "debug_auth_bypass")
        let user = User(id: "debug-user", email: "debug@pausely.app", createdAt: Date(), firstName: "Debug", lastName: "User")
        currentUser = user
        isAuthenticated = true
        state = .authenticated(user)
    }
    #endif

    // MARK: - Biometric Authentication
    
    
    
    // MARK: - Links from account emails

    /// A link from a sign-up, sign-in or reset email was opened. Whatever shape the account service gave
    /// it (see `AuthLink`), the person ends up signed in, or choosing a new password after a reset.
    ///
    /// Only a link this device asked for is acted on (see `AuthLinkGate`): a code or reset was requested
    /// here within the hour, nobody is signed in, and the account that comes back has that address.
    /// Anything else is ignored, so a link someone else made can't switch the account on this phone.
    /// - Returns: true when the link signed someone in or started a reset.
    @discardableResult
    func handleDeepLink(_ url: URL) async -> Bool {
        guard url.scheme?.lowercased() == "pausely", url.host?.lowercased() == "auth" else { return false }
        let link = AuthLink.parse(url)
        if link == .none { return false }
        let expired = L10n.string("That link has expired or was already used. Ask for a new one.")

        let gate = linkGate
        guard gate.allows(link, now: Date()) else {
            os_log("An account link this device did not ask for was ignored", log: .default, type: .info)
            // Someone already signed in has nothing to fix; someone signing in is told to ask again.
            if !isAuthenticated { linkProblem = expired }
            return false
        }
        let recovery = AuthLink.isRecovery(url) || resetWasRequestedRecently

        do {
            let user: Auth.User
            switch link {
            case .none:
                return false
            case .failed:
                linkProblem = expired
                return false
            case .code(let code):
                user = try await client.auth.exchangeCodeForSession(authCode: code).user
            case .tokens(let access, let refresh):
                user = try await client.auth.setSession(accessToken: access, refreshToken: refresh).user
            case .tokenHash(let hash, let type):
                user = try await client.auth.verifyOTP(tokenHash: hash, type: Self.emailOTPType(type, recovery: recovery)).user
            case .emailToken(let token, let email, let type):
                user = try await client.auth.verifyOTP(email: email, token: token,
                                                       type: Self.emailOTPType(type, recovery: recovery)).user
            }
            guard gate.accepts(accountEmail: user.email) else {
                // The link opened some other account. Drop that session; nobody is signed in.
                os_log("An account link for a different address was refused", log: .default, type: .error)
                pendingPassword = nil
                pendingPasswordEmail = nil
                try? await client.auth.signOut(scope: .local)
                linkProblem = expired
                return false
            }
            if recovery {
                beginNewPassword(for: user)
            } else {
                await finishEmailSignIn(user)
            }
            return true
        } catch {
            os_log("An account link failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
            linkProblem = expired
            return false
        }
    }

    // MARK: - Which account links are acted on

    /// This device asked the account service for a code or a reset for `email`. Links for that address
    /// are honoured for the next hour.
    private func noteCodeRequested(for email: String) {
        UserDefaults.standard.set(email, forKey: Self.linkRequestedEmailKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.linkRequestedAtKey)
    }

    private func forgetCodeRequest() {
        UserDefaults.standard.removeObject(forKey: Self.linkRequestedEmailKey)
        UserDefaults.standard.removeObject(forKey: Self.linkRequestedAtKey)
    }

    private var linkGate: AuthLinkGate {
        let requestedAt = UserDefaults.standard.double(forKey: Self.linkRequestedAtKey)
        return AuthLinkGate(requestedEmail: UserDefaults.standard.string(forKey: Self.linkRequestedEmailKey),
                            requestedAt: requestedAt > 0 ? Date(timeIntervalSince1970: requestedAt) : nil,
                            isSignedIn: isAuthenticated)
    }

    private static func emailOTPType(_ type: String, recovery: Bool) -> EmailOTPType {
        switch type.lowercased() {
        case "recovery": return .recovery
        case "signup": return .signup
        case "magiclink": return .magiclink
        case "invite": return .invite
        case "email_change": return .emailChange
        default: return recovery ? .recovery : .email
        }
    }

    private var resetWasRequestedRecently: Bool {
        let requested = UserDefaults.standard.double(forKey: Self.resetRequestedKey)
        return requested > 0 && Date().timeIntervalSince1970 - requested < 3_600
    }

    // MARK: - Choosing a new password after a reset

    /// Checks the 6-digit code from a reset email. On success the person is asked for a new password.
    func verifyRecoveryCode(email: String, code: String) async throws {
        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .recovery)
            beginNewPassword(for: response.user)
        } catch {
            throw PauselyAuthError.unknown(error)
        }
    }

    private func beginNewPassword(for user: Auth.User) {
        UserDefaults.standard.removeObject(forKey: Self.resetRequestedKey)
        forgetCodeRequest()
        recoveryUser = user
        needsNewPassword = true
    }

    /// Saves the new password and signs the person in.
    func setNewPassword(_ password: String) async throws {
        do {
            let updated = try await client.auth.update(user: UserAttributes(password: password))
            needsNewPassword = false
            recoveryUser = nil
            await finishEmailSignIn(updated)
        } catch {
            throw PauselyAuthError.unknown(error)
        }
    }

    /// The person backed out of choosing a password: the reset is dropped and nobody is signed in.
    func cancelNewPassword() async {
        needsNewPassword = false
        recoveryUser = nil
        try? await client.auth.signOut(scope: .local)
    }
}

// MARK: - Helpers
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

