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
    @Published var isCheckingEmailConfirmation = false
    
    private var confirmationPollingTask: Task<Void, Never>?
    private var verifyTask: Task<Void, Never>?

    // MARK: - Private Properties
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let biometricKey = "biometric_auth_enabled"
    private let lastEmailKey = "last_auth_email"
    private var refreshTask: Task<Void, Never>?
    private var pendingPassword: String?

    // MARK: - Scale Optimizations
    private let authQueue = DispatchQueue(label: "com.pausely.auth", qos: .userInitiated)
    private var pendingRequests: [String: Task<Any, Error>] = [:]
    private let requestLock = NSLock()
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
        
        func cancelAll() {
            requests.values.forEach { $0.cancel() }
            requests.removeAll()
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

    /// Called after any successful authentication. Previously handled affiliate attribution.
    /// Now kept as a hook for future post-auth logic.
    private func postAuthSetup(user: User) {
        // Affiliate system disabled
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

    private func saveTokensToKeychain(accessToken: String?, refreshToken: String?) {
        if let access = accessToken {
            KeychainManager.shared.save(access, forKey: Self.keychainAccessTokenKey)
        }
        if let refresh = refreshToken {
            KeychainManager.shared.save(refresh, forKey: Self.keychainRefreshTokenKey)
        }
    }

    private func loadTokensFromKeychain() -> (access: String?, refresh: String?) {
        let access = KeychainManager.shared.get(Self.keychainAccessTokenKey)
        let refresh = KeychainManager.shared.get(Self.keychainRefreshTokenKey)
        return (access, refresh)
    }

    private func clearKeychainTokens() {
        KeychainManager.shared.delete(key: Self.keychainAccessTokenKey)
        KeychainManager.shared.delete(key: Self.keychainRefreshTokenKey)
    }
    
    // MARK: - Sign Up with Pausely-branded Email
    
    func signUp(email: String, password: String,
                firstName: String? = nil, lastName: String? = nil) async throws {
        state = .loading

        do {
            var userMetadata: [String: AnyJSON] = ["app_name": .string("Pausely")]
            if let fn = firstName, !fn.isEmpty { userMetadata["first_name"] = .string(fn) }
            if let ln = lastName,  !ln.isEmpty { userMetadata["last_name"]  = .string(ln) }

            let authResponse = try await client.auth.signUp(
                email: email,
                password: password,
                data: userMetadata
            )

            UserDefaults.standard.set(email, forKey: lastEmailKey)

            if let session = authResponse.session {
                let uid = session.user.id.uuidString
                saveProfile(userId: uid, firstName: firstName, lastName: lastName)
                cacheSession(userId: uid, email: session.user.email,
                             createdAt: session.user.createdAt)
                let user = makeUser(from: session.user,
                                    firstName: firstName, lastName: lastName)
                currentUser = user
                isAuthenticated = true
                state = .authenticated(user)
                startSessionRefresh()
                postAuthSetup(user: user)

                #if DEBUG
                PauselyLogger.info("Sign up successful - user auto-confirmed and signed in", category: "auth")
                #endif
            } else {
                // Stash name so it's available after email confirmation
                let uid = authResponse.user.id.uuidString
                saveProfile(userId: uid, firstName: firstName, lastName: lastName)
                state = .emailConfirmationRequired(email)
                #if DEBUG
                PauselyLogger.info("Sign up successful - email confirmation required for: \(email)", category: "auth")
                #endif
            }

        } catch let error as PauselyAuthError {
            state = .error(error)
            throw error
        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    // MARK: - OTP-based Email Verification (REVOLUTIONARY)

    /// Signs up using OTP instead of link-based confirmation.
    /// Sends a 6-digit code to the user's email for verification.
    func signUpWithOTP(email: String, password: String,
                       firstName: String? = nil, lastName: String? = nil) async throws {
        state = .loading

        do {
            // Store password and profile temporarily for after OTP verification
            pendingPassword = password
            if let fn = firstName, !fn.isEmpty { KeychainManager.shared.save(fn, forKey: Self.pendingFirstNameKey) }
            if let ln = lastName, !ln.isEmpty { KeychainManager.shared.save(ln, forKey: Self.pendingLastNameKey) }
            UserDefaults.standard.set(email, forKey: lastEmailKey)

            // Send OTP — creates user if they don't exist
            try await client.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            state = .emailConfirmationRequired(email)

        } catch {
            pendingPassword = nil
            KeychainManager.shared.delete(key: Self.pendingFirstNameKey)
            KeychainManager.shared.delete(key: Self.pendingLastNameKey)
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    /// Verifies the 6-digit OTP code sent to email.
    /// After successful verification, sets the pending password and profile if they exist.
    func verifyEmailOTP(email: String, code: String) async throws {
        state = .loading

        do {
            let session = try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            let supabaseUser = session.user
            let firstName = KeychainManager.shared.get(Self.pendingFirstNameKey)
            let lastName = KeychainManager.shared.get(Self.pendingLastNameKey)

            let user = makeUser(from: supabaseUser, firstName: firstName, lastName: lastName)
            cacheSession(userId: supabaseUser.id.uuidString,
                         email: supabaseUser.email,
                         createdAt: supabaseUser.createdAt)

            // Save profile
            if let fn = firstName { saveProfile(userId: supabaseUser.id.uuidString, firstName: fn, lastName: lastName) }

            // Set password if we have one pending
            if let password = pendingPassword {
                _ = try await client.auth.update(user: UserAttributes(password: password))
                pendingPassword = nil
            }

            // Clean up pending profile data
            KeychainManager.shared.delete(key: Self.pendingFirstNameKey)
            KeychainManager.shared.delete(key: Self.pendingLastNameKey)

            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)

            startSessionRefresh()
            postAuthSetup(user: user)

        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    /// Resend the OTP code to the user's email
    func resendOTP(email: String) async throws {
        do {
            try await client.auth.signInWithOTP(
                email: email,
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

    /// Sign in with remember me option
    func signIn(email: String, password: String, rememberMe: Bool) async throws {
        // Store remember me preference
        UserDefaults.standard.set(rememberMe, forKey: "remember_me_enabled")
        
        // Call regular sign in
        try await signIn(email: email, password: password)
    }
    
    /// Resend confirmation email to the user
    func resendConfirmationEmail(email: String) async throws {
        do {
            // Supabase doesn't have a direct "resend confirmation" API
            // We need to sign up again with the same email to trigger a new confirmation email
            // The user will get a new confirmation link
            try await client.auth.resend(
                email: email,
                type: .signup
            )
        } catch {
            throw PauselyAuthError.unknown(error)
        }
    }
    
    /// Check if there's an active session
    func checkSession() async {
        if let session = client.auth.currentSession {
            let user = makeUser(from: session.user)
            cacheSession(userId: session.user.id.uuidString,
                         email: session.user.email,
                         createdAt: session.user.createdAt)
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            startSessionRefresh()
            postAuthSetup(user: user)
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
    
    func signInWithMagicLink(email: String) async throws {
        state = .loading
        
        do {
            try await client.auth.signInWithOTP(
                email: email,
                shouldCreateUser: false
            )
            
            state = .emailConfirmationRequired(email)

        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    // MARK: - Email Confirmation Polling
    
    func startEmailConfirmationPolling() {
        isCheckingEmailConfirmation = true
        confirmationPollingTask?.cancel()
        confirmationPollingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled && self.isCheckingEmailConfirmation {
                // Check session every 3 seconds
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)

                if Task.isCancelled { break }

                // Try to get current session - if email is confirmed, this will succeed
                if let session = client.auth.currentSession {
                    let user = makeUser(from: session.user)
                    cacheSession(userId: session.user.id.uuidString,
                                 email: session.user.email,
                                 createdAt: session.user.createdAt)
                    currentUser = user
                    isAuthenticated = true
                    state = .authenticated(user)
                    isCheckingEmailConfirmation = false
                    startSessionRefresh()
                    postAuthSetup(user: user)
                    break
                }
            }
        }
    }
    
    func stopEmailConfirmationPolling() {
        isCheckingEmailConfirmation = false
        confirmationPollingTask?.cancel()
        confirmationPollingTask = nil
    }
    
    // MARK: - Deep Link Email Confirmation
    
    /// Handles email confirmation deep link
    /// URL format: pausely://auth/confirm?token=xxx&type=signup&email=xxx
    func confirmEmail(token: String, email: String, type: String = "signup") async throws {
        state = .loading
        
        do {
            guard type == "signup" || type == "email_change" || type == "recovery" else {
                throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid verification type: \(type)"])
            }
            let session = try await client.auth.verifyOTP(
                email: email,
                token: token,
                type: (type == "signup" || type == "email_change") ? .signup : .recovery
            )

            let supabaseUser = session.user

            let user = makeUser(from: supabaseUser)
            cacheSession(userId: supabaseUser.id.uuidString,
                         email: supabaseUser.email,
                         createdAt: supabaseUser.createdAt)

            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)

            startSessionRefresh()
            postAuthSetup(user: user)

        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    /// Handles password reset confirmation from deep link
    /// URL format: pausely://auth/reset-password?token=xxx&email=xxx
    func confirmPasswordReset(token: String, email: String, newPassword: String) async throws {
        state = .loading
        
        do {
            // First verify the token
            _ = try await client.auth.verifyOTP(
                email: email,
                token: token,
                type: .recovery
            )
            
            // Then update password
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
            
            state = .unauthenticated

        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        state = .loading
        
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "pausely://auth/reset-password")
            )
            
            state = .unauthenticated

        } catch {
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
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

        isAuthenticated = false
        currentUser = nil
        state = .unauthenticated
    }
    
    // MARK: - Biometric Authentication
    
    func toggleBiometricAuthentication(enabled: Bool) async throws {
        guard enabled else {
            UserDefaults.standard.set(false, forKey: biometricKey)
            isBiometricEnabled = false
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw PauselyAuthError.biometricFailed
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Enable Face ID to quickly sign in to Pausely"
            )
            
            if success {
                UserDefaults.standard.set(true, forKey: biometricKey)
                isBiometricEnabled = true
            }
        } catch {
            throw PauselyAuthError.biometricFailed
        }
    }
    
    func attemptBiometricAuth() async {
        let context = LAContext()
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Sign in to Pausely"
            )
            
            if success, let lastEmail = UserDefaults.standard.string(forKey: lastEmailKey) {
                NotificationCenter.default.post(
                    name: .biometricAuthSuccess,
                    object: lastEmail
                )
            }
        } catch {
            os_log("Biometric auth failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            NotificationCenter.default.post(
                name: .biometricAuthFailed,
                object: error.localizedDescription
            )
        }
    }
    
    // MARK: - Deep Link Handler
    
    /// Main entry point for handling auth-related deep links
    /// - Parameter url: The deep link URL (e.g., pausely://auth/confirm?token=xxx&email=xxx)
    /// - Returns: true if the deep link was handled successfully
    @discardableResult
    func handleDeepLink(_ url: URL) async -> Bool {
        guard url.scheme == "pausely",
              url.host == "auth" else {
            return false
        }
        
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        switch path {
        case "confirm", "confirm-callback":
            if let token = queryItems.first(where: { $0.name == "token" })?.value,
               let email = queryItems.first(where: { $0.name == "email" })?.value,
               let type = queryItems.first(where: { $0.name == "type" })?.value ?? queryItems.first(where: { $0.name == "verification_type" })?.value {
                do {
                    try await confirmEmail(token: token, email: email, type: type)
                    return true
                } catch {
                    os_log("Email confirmation failed: %{public}@", log: .default, type: .error, error.localizedDescription)
                    NotificationCenter.default.post(
                        name: .emailConfirmationFailed,
                        object: error.localizedDescription
                    )
                    return false
                }
            }
            return false
            
        case "reset-password":
            // Store token and email for password reset view to handle
            if let token = queryItems.first(where: { $0.name == "token" })?.value,
               let email = queryItems.first(where: { $0.name == "email" })?.value {
                NotificationCenter.default.post(
                    name: .passwordResetTokenReceived,
                    object: ["token": token, "email": email]
                )
                return true
            }
            return false
            
        default:
            return false
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let passwordResetTokenReceived = Notification.Name("passwordResetTokenReceived")
    static let biometricAuthFailed = Notification.Name("biometricAuthFailed")
    static let emailConfirmationFailed = Notification.Name("emailConfirmationFailed")
}

// MARK: - Helpers
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

