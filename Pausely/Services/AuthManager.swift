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
    
    // Keychain keys for secure storage
    private static let keychainAccessTokenKey = "auth_access_token"
    private static let keychainRefreshTokenKey = "auth_refresh_token"

    // MARK: - Initialization
    private init() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: biometricKey)

        // Restore session synchronously so the UI is correct on the very first frame,
        // with no flash of the login screen for returning users.
        if let uid = UserDefaults.standard.string(forKey: Self.cachedUserIdKey) {
            let email     = UserDefaults.standard.string(forKey: Self.cachedEmailKey)
            let createdAt = UserDefaults.standard.object(forKey: Self.cachedCreatedAtKey) as? Date
            let profile   = Self.loadProfileStatic(userId: uid)
            let user = User(id: uid, email: email, createdAt: createdAt,
                            firstName: profile.firstName, lastName: profile.lastName)
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            #if DEBUG
            print("✅ [Cache] Restored session for: \(email ?? uid)")
            #endif
        }

        // Async: verify the Supabase token is still valid and refresh user data.
        Task { await verifySession() }
    }

    // MARK: - Session Cache

    private func cacheSession(userId: String, email: String?, createdAt: Date?) {
        UserDefaults.standard.set(userId,    forKey: Self.cachedUserIdKey)
        UserDefaults.standard.set(email,     forKey: Self.cachedEmailKey)
        UserDefaults.standard.set(createdAt, forKey: Self.cachedCreatedAtKey)
    }

    private func clearSessionCache() {
        UserDefaults.standard.removeObject(forKey: Self.cachedUserIdKey)
        UserDefaults.standard.removeObject(forKey: Self.cachedEmailKey)
        UserDefaults.standard.removeObject(forKey: Self.cachedCreatedAtKey)
        clearKeychainTokens()
    }

    // MARK: - Profile Persistence

    private func saveProfile(userId: String, firstName: String?, lastName: String?) {
        UserDefaults.standard.set(firstName, forKey: "profile_\(userId)_firstName")
        UserDefaults.standard.set(lastName,  forKey: "profile_\(userId)_lastName")
    }

    private func loadProfile(userId: String) -> (firstName: String?, lastName: String?) {
        Self.loadProfileStatic(userId: userId)
    }

    private static func loadProfileStatic(userId: String) -> (firstName: String?, lastName: String?) {
        let fn = UserDefaults.standard.string(forKey: "profile_\(userId)_firstName")
        let ln = UserDefaults.standard.string(forKey: "profile_\(userId)_lastName")
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

    deinit {
        refreshTask?.cancel()
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
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.state = .authenticated(user)
                #if DEBUG
                print("✅ [Supabase] Session verified for: \(user.email ?? user.id)")
                #endif
            }
            startSessionRefresh()


        } else if isAuthenticated {
            // Cache said we're logged in but Supabase disagrees — token expired.
            #if DEBUG
            print("⚠️ Cached session invalid — signing out")
            #endif
            clearSessionCache()
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.state = .unauthenticated
            }
        } else {
            await MainActor.run { self.state = .unauthenticated }
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
            Task {
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
        await MainActor.run { state = .loading }

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

            await MainActor.run {
                if let session = authResponse.session {
                    let uid = session.user.id.uuidString
                    self.saveProfile(userId: uid, firstName: firstName, lastName: lastName)
                    self.cacheSession(userId: uid, email: session.user.email,
                                      createdAt: session.user.createdAt)
                    let user = self.makeUser(from: session.user,
                                             firstName: firstName, lastName: lastName)
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.state = .authenticated(user)
                    self.startSessionRefresh()
                    
                            
                    #if DEBUG
                    print("✅ Sign up successful - user auto-confirmed and signed in")
                    #endif
                } else {
                    // Stash name so it's available after email confirmation
                    let uid = authResponse.user.id.uuidString
                    self.saveProfile(userId: uid, firstName: firstName, lastName: lastName)
                    self.state = .emailConfirmationRequired(email)
                    #if DEBUG
                    print("📧 Sign up successful - email confirmation required for: \(email)")
                    #endif
                }
            }

        } catch let error as PauselyAuthError {
            await MainActor.run { self.state = .error(error) }
            throw error
        } catch {
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run { self.state = .error(authError) }
            throw authError
        }
    }

    // MARK: - OTP-based Email Verification (REVOLUTIONARY)

    /// Signs up using OTP instead of link-based confirmation.
    /// Sends a 6-digit code to the user's email for verification.
    func signUpWithOTP(email: String, password: String,
                       firstName: String? = nil, lastName: String? = nil) async throws {
        await MainActor.run { state = .loading }

        do {
            // Store password and profile temporarily for after OTP verification
            pendingPassword = password
            if let fn = firstName, !fn.isEmpty { UserDefaults.standard.set(fn, forKey: "pending_firstName") }
            if let ln = lastName, !ln.isEmpty { UserDefaults.standard.set(ln, forKey: "pending_lastName") }
            UserDefaults.standard.set(email, forKey: lastEmailKey)

            // Send OTP — creates user if they don't exist
            try await client.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            await MainActor.run {
                self.state = .emailConfirmationRequired(email)
            }

        } catch {
            pendingPassword = nil
            UserDefaults.standard.removeObject(forKey: "pending_firstName")
            UserDefaults.standard.removeObject(forKey: "pending_lastName")
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run { self.state = .error(authError) }
            throw authError
        }
    }

    /// Verifies the 6-digit OTP code sent to email.
    /// After successful verification, sets the pending password and profile if they exist.
    func verifyEmailOTP(email: String, code: String) async throws {
        await MainActor.run { state = .loading }

        do {
            let session = try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            let supabaseUser = session.user
            let firstName = UserDefaults.standard.string(forKey: "pending_firstName")
            let lastName = UserDefaults.standard.string(forKey: "pending_lastName")

            let user = makeUser(from: supabaseUser, firstName: firstName, lastName: lastName)
            cacheSession(userId: supabaseUser.id.uuidString,
                         email: supabaseUser.email,
                         createdAt: supabaseUser.createdAt)

            // Save profile
            if let fn = firstName { saveProfile(userId: supabaseUser.id.uuidString, firstName: fn, lastName: lastName) }

            // Set password if we have one pending
            if let password = pendingPassword {
                _ = try? await client.auth.update(user: UserAttributes(password: password))
                pendingPassword = nil
            }

            // Clean up pending profile data
            UserDefaults.standard.removeObject(forKey: "pending_firstName")
            UserDefaults.standard.removeObject(forKey: "pending_lastName")

            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.state = .authenticated(user)
            }

            startSessionRefresh()

        } catch {
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run { self.state = .error(authError) }
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
        await MainActor.run { state = .loading }
        #if DEBUG
        print("🔐 Attempting sign in for: \(email)")
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

            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.state = .authenticated(user)
                #if DEBUG
                print("✅ Sign in successful for: \(email)")
                #endif
            }

            startSessionRefresh()
            
            
        } catch let error as PauselyAuthError {
            #if DEBUG
            print("❌ Sign in failed with AuthError: \(error.localizedDescription)")
            #endif
            await MainActor.run {
                self.state = .error(error)
            }
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
            print("❌ Sign in failed with error: \(authError.localizedDescription)")
            #endif
            await MainActor.run {
                self.state = .error(authError)
            }
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
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.state = .authenticated(user)
            }
            startSessionRefresh()
        }
    }
    
    // MARK: - Sign in with Apple

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        await MainActor.run { state = .loading }

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

            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.state = .authenticated(user)
                #if DEBUG
                print("✅ Apple Sign In successful for user: \(user.id)")
                #endif
            }

            startSessionRefresh()
            

        } catch {
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run { self.state = .error(authError) }
            throw authError
        }
    }

    // MARK: - Magic Link Sign In
    
    func signInWithMagicLink(email: String) async throws {
        await MainActor.run { state = .loading }
        
        do {
            try await client.auth.signInWithOTP(
                email: email,
                shouldCreateUser: false
            )
            
            await MainActor.run {
                self.state = .emailConfirmationRequired(email)
            }
            
        } catch {
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run {
                self.state = .error(authError)
            }
            throw authError
        }
    }
    
    // MARK: - Email Confirmation Polling
    
    func startEmailConfirmationPolling() {
        isCheckingEmailConfirmation = true
        confirmationPollingTask?.cancel()
        confirmationPollingTask = Task {
            while !Task.isCancelled && isCheckingEmailConfirmation {
                // Check session every 3 seconds
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)

                if Task.isCancelled { break }

                // Try to get current session - if email is confirmed, this will succeed
                if let session = client.auth.currentSession {
                    let user = makeUser(from: session.user)
                    cacheSession(userId: session.user.id.uuidString,
                                 email: session.user.email,
                                 createdAt: session.user.createdAt)
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                        self.state = .authenticated(user)
                        self.isCheckingEmailConfirmation = false
                    }
                    startSessionRefresh()
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
        await MainActor.run { state = .loading }
        
        do {
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

            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.state = .authenticated(user)
            }

            startSessionRefresh()
            

        } catch {
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run { self.state = .error(authError) }
            throw authError
        }
    }

    /// Handles password reset confirmation from deep link
    /// URL format: pausely://auth/reset-password?token=xxx&email=xxx
    func confirmPasswordReset(token: String, email: String, newPassword: String) async throws {
        await MainActor.run { state = .loading }
        
        do {
            // First verify the token
            _ = try await client.auth.verifyOTP(
                email: email,
                token: token,
                type: .recovery
            )
            
            // Then update password
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
            
            await MainActor.run {
                self.state = .unauthenticated
            }
            
        } catch {
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run {
                self.state = .error(authError)
            }
            throw authError
        }
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String) async throws {
        await MainActor.run { state = .loading }
        
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "pausely://auth/reset-password")
            )
            
            await MainActor.run {
                self.state = .unauthenticated
            }
            
        } catch {
            let authError = PauselyAuthError.unknown(error)
            await MainActor.run {
                self.state = .error(authError)
            }
            throw authError
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        refreshTask?.cancel()
        refreshTask = nil
        
        // Cancel all pending auth requests (async-safe)
        await MainActor.run {
            pendingRequests.values.forEach { $0.cancel() }
            pendingRequests.removeAll()
        }
        
        clearSessionCache()

        do {
            try await client.auth.signOut()
        } catch {
            os_log("Sign out failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }

        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
            self.state = .unauthenticated
        }
    }
    
    // MARK: - Biometric Authentication
    
    func toggleBiometricAuthentication(enabled: Bool) async throws {
        guard enabled else {
            UserDefaults.standard.set(false, forKey: biometricKey)
            await MainActor.run {
                self.isBiometricEnabled = false
            }
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
                await MainActor.run {
                    self.isBiometricEnabled = true
                }
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
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .biometricAuthSuccess,
                        object: lastEmail
                    )
                }
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

