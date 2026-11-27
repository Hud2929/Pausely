import Foundation
import SwiftUI
import Supabase
import os.log

// MARK: - Supabase Integration
import Auth

/// Who is signed in: sign-up and sign-in by emailed code or with Apple, the session between launches,
/// links from account emails, sign-out and account deletion.
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // MARK: - Published State
    @Published var state: PauselyAuthState = .initial
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    /// A password-reset code or link was accepted: the next thing the person sees is "choose a new password".
    @Published var needsNewPassword = false {
        didSet {
            if needsNewPassword {
                UserDefaults.standard.set(true, forKey: Self.needsNewPasswordKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.needsNewPasswordKey)
            }
        }
    }
    /// Why a link from an account email didn't work, in words the person can act on.
    @Published var linkProblem: String?

    private var verifyTask: Task<Void, Never>?

    // MARK: - Private Properties
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var refreshTask: Task<Void, Never>?
    private static let pendingPasswordKey = "pending_signup_password"
    private static let pendingPasswordEmailKey = "pending_signup_password_email"
    private static let needsNewPasswordKey = "auth_needs_new_password"
    private static let resetRequestedKey = "auth_reset_requested_at"
    /// The address this device last asked a code or a reset for, and when (see `AuthLinkGate`).
    private static let linkRequestedEmailKey = "auth_link_requested_email"
    private static let linkRequestedAtKey = "auth_link_requested_at"

    private func holdPendingSignupPassword(_ password: String, for email: String) {
        KeychainManager.shared.save(password, forKey: Self.pendingPasswordKey)
        KeychainManager.shared.save(email, forKey: Self.pendingPasswordEmailKey)
    }

    private func takePendingSignupPassword() -> (password: String, email: String)? {
        defer { Self.clearPendingSignupPassword() }
        guard let password = KeychainManager.shared.get(Self.pendingPasswordKey),
              let email = KeychainManager.shared.get(Self.pendingPasswordEmailKey) else { return nil }
        return (password, email)
    }

    static func clearPendingSignupPassword() {
        KeychainManager.shared.delete(key: pendingPasswordKey)
        KeychainManager.shared.delete(key: pendingPasswordEmailKey)
    }

    /// Where the links in sign-up and sign-in emails come back to. It has to be on the account service's
    /// list of allowed redirect addresses; if it isn't, the service uses its own default address instead.
    static let confirmRedirect = URL(string: "pausely://auth/confirm")
    static let resetRedirect = URL(string: "pausely://auth/reset-password")

    /// The built-in test user's id (DEBUG builds only sign in as it; the name is kept in release so code
    /// that asks about it needs no `#if`).
    nonisolated static let localTestUserID = "debug-user"

    /// Local-only mode: the person uses Pausely on this iPhone without creating a cloud account.
    /// Everything stays protected on-device and upgrades seamlessly if they later sign up.
    nonisolated static let guestUserID = "local-guest"
    static let guestModeKey = "local_guest_mode"

    /// True when the person is using Pausely locally without a cloud account.
    var isGuest: Bool { currentUser?.id == Self.guestUserID }

    /// True when signed into a real cloud account (excludes local-only guest mode).
    var isSignedIntoCloud: Bool { isAuthenticated && !isGuest }

    // MARK: - Initialization
    private init() {

        #if DEBUG
        // UI tests pass --reset-state to start signed out, whatever a previous run left behind.
        if LaunchFlag.isSet("--reset-state") {
            AccountMemory.forgetSession()
            UserDefaults.standard.removeObject(forKey: "debug_auth_bypass")
            UserDefaults.standard.removeObject(forKey: Self.guestModeKey)
            Task { [client] in try? await client.auth.signOut(scope: .local) }
            return
        }

        // Debug bypass for simulator testing — set via:
        // defaults write com.pausely.app.Pausely debug_auth_bypass -bool true
        if UserDefaults.standard.bool(forKey: "debug_auth_bypass") {
            let user = User(id: AuthManager.localTestUserID, email: "debug@pausely.app", createdAt: Date(),
                            firstName: "Debug", lastName: "User")
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            return
        }
        #endif

        // The Keychain outlives the app. On the first launch after an install whatever it holds was
        // left by a copy that has been deleted: clear it and start signed out (see `InstallState`).
        let leftByADeletedCopy = InstallState.firstLaunch
        if leftByADeletedCopy {
            KeychainManager.shared.deleteAll()
            MailboxAccountStore.deleteAllSecrets()
        }

        if !leftByADeletedCopy && UserDefaults.standard.bool(forKey: Self.needsNewPasswordKey) {
            needsNewPassword = true
        }

        // Restore session synchronously so the UI is correct on the very first frame,
        // with no flash of the login screen for returning users.
        if let user = AccountMemory.rememberedUser {
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
        } else if !leftByADeletedCopy, UserDefaults.standard.bool(forKey: Self.guestModeKey) {
            let guest = User(id: Self.guestUserID, email: nil, createdAt: Date())
            currentUser = guest
            isAuthenticated = true
            state = .authenticated(guest)
        }

        // Async: verify the Supabase token is still valid and refresh user data.
        verifyTask = Task { [weak self] in
            guard let self = self else { return }
            // The sign-in library keeps its own copy of the session in the Keychain. It has to be gone
            // before the session is looked at, or the deleted copy's sign-in is restored after all.
            if leftByADeletedCopy { try? await self.client.auth.signOut(scope: .local) }
            await verifySession()
        }
    }

    private func makeUser(from supabaseUser: Auth.User,
                          firstName: String? = nil,
                          lastName: String? = nil) -> User {
        let profile = AccountMemory.name(userId: supabaseUser.id.uuidString)
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
            // Require a valid, refreshed session so an expired token never queries `profiles` as `anon`
            // and revokes an admin-granted Pro entitlement.
            let session = try await SupabaseManager.shared.client.auth.session
            guard !session.isExpired else { return }
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
    /// Signs out if the refresh token is revoked/expired, while preserving cached offline access on network errors.
    private func verifySession() async {
        if let cached = client.auth.currentSession {
            let activeSession: Session
            do {
                activeSession = try await client.auth.session
            } catch {
                guard !Task.isCancelled else { return }
                if SyncQueue.isUnreachable(error) {
                    activeSession = cached
                } else {
                    PauselyLogger.info("Stored session could not be refreshed — signing out", category: "auth")
                    try? await client.auth.signOut(scope: .local)
                    guard !Task.isCancelled else { return }
                    await clearLocalSignedOutSession()
                    return
                }
            }
            guard !Task.isCancelled else { return }
            if needsNewPassword { return }
            UserDefaults.standard.removeObject(forKey: Self.guestModeKey)
            let user = makeUser(from: activeSession.user)
            AccountMemory.rememberSession(userId: activeSession.user.id.uuidString,
                         email: activeSession.user.email,
                         createdAt: activeSession.user.createdAt)
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)
            startSessionRefresh()
            postAuthSetup(user: user)

        } else if isGuest {
            // Local-only mode has no cloud session to verify; keep the person in.
            return
        } else if isAuthenticated {
            // Cache said we're logged in but Supabase disagrees — token expired.
            PauselyLogger.info("Cached session invalid — signing out", category: "auth")
            await clearLocalSignedOutSession()
        } else {
            needsNewPassword = false
            state = .unauthenticated
            if !LaunchFlag.isDemoLaunch { LocalUserData.hideWhileSignedOut() }
        }
    }

    private func clearLocalSignedOutSession() async {
        needsNewPassword = false
        Self.clearPendingSignupPassword(); forgetCodeRequest(); refreshTask?.cancel(); refreshTask = nil
        AccountMemory.forgetSession()
        AgeConsentManager.shared.clearDeviceGate()
        PaymentManager.shared.clearProGrantSynchronously()
        await InboxScanner.shared.disconnectAll()
        currentUser = nil
        isAuthenticated = false
        state = .unauthenticated
        LocalUserData.hideWhileSignedOut()
    }
    
    /// Every fifteen minutes while signed in, asks the account service for the session, which renews
    /// the token when it is close to expiring. One loop, so two refreshes never overlap.
    private func startSessionRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
                guard !Task.isCancelled, let self else { break }
                _ = try? await self.client.auth.session
            }
        }
    }

    // MARK: - Sign up and sign in with an emailed code

    /// Signs up using OTP instead of link-based confirmation.
    /// Sends a 6-digit code to the user's email for verification.
    func signUpWithOTP(email: String, password: String,
                       firstName: String? = nil, lastName: String? = nil) async throws {
        guard AgeConsentManager.shared.hasPassedDeviceGate else { throw PauselyAuthError.ageConsentRequired }
        state = .loading

        do {
            // Persist password transiently in Keychain so iOS background kills between Mail & Pausely don't lose it.
            holdPendingSignupPassword(password, for: email)
            noteCodeRequested(for: email)
            AccountMemory.holdName(first: firstName, last: lastName, for: email)

            // Send OTP — creates user if they don't exist
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: Self.confirmRedirect,
                shouldCreateUser: true
            )

            state = .emailConfirmationRequired(email)

        } catch {
            Self.clearPendingSignupPassword()
            AccountMemory.forgetHeldName()
            let authError = PauselyAuthError.unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    /// Verifies the 6-digit code sent by email, then finishes the sign-up.
    func verifyEmailOTP(email: String, code: String) async throws {
        verifyTask?.cancel()
        verifyTask = nil
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
        verifyTask?.cancel(); verifyTask = nil
        if let pending = takePendingSignupPassword(),
           AuthLinkGate.sameAddress(pending.email, supabaseUser.email ?? "") {
            do {
                _ = try await client.auth.update(user: UserAttributes(password: pending.password))
            } catch {
                os_log("Saving the sign-up password failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
                needsNewPassword = true
                return
            }
        }
        let (firstName, lastName) = AccountMemory.heldName(for: supabaseUser.email)
        let user = makeUser(from: supabaseUser, firstName: firstName, lastName: lastName)
        AccountMemory.rememberSession(userId: supabaseUser.id.uuidString, email: supabaseUser.email, createdAt: supabaseUser.createdAt)
        if let firstName { AccountMemory.saveName(userId: supabaseUser.id.uuidString, firstName: firstName, lastName: lastName) }
        forgetCodeRequest(); AccountMemory.forgetHeldName()
        UserDefaults.standard.removeObject(forKey: Self.guestModeKey)
        currentUser = user; isAuthenticated = true; state = .authenticated(user)
        startSessionRefresh(); postAuthSetup(user: user)
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
        verifyTask?.cancel()
        verifyTask = nil
        state = .loading
        
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            

            let supabaseUser = session.user

            let user = makeUser(from: supabaseUser)
            AccountMemory.rememberSession(userId: supabaseUser.id.uuidString,
                         email: supabaseUser.email,
                         createdAt: supabaseUser.createdAt)

            UserDefaults.standard.removeObject(forKey: Self.guestModeKey)
            currentUser = user
            isAuthenticated = true
            state = .authenticated(user)

            startSessionRefresh()
            postAuthSetup(user: user)

        } catch {
            // The screen says what went wrong in the reader's language (`AccountProblem`); here the
            // error is only passed on.
            let authError = (error as? PauselyAuthError) ?? .unknown(error)
            state = .error(authError)
            throw authError
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        verifyTask?.cancel()
        verifyTask = nil
        state = .loading

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce)
            )

            let supabaseUser = session.user
            // Apple only provides fullName on first sign-in; persist it immediately
            let firstName = fullName?.givenName?.nilIfEmpty
            let lastName  = fullName?.familyName?.nilIfEmpty
            let existingProfile = AccountMemory.name(userId: supabaseUser.id.uuidString)
            AccountMemory.saveName(userId: supabaseUser.id.uuidString,
                        firstName: firstName ?? existingProfile.firstName,
                        lastName:  lastName  ?? existingProfile.lastName)
            AccountMemory.rememberSession(userId: supabaseUser.id.uuidString,
                         email: supabaseUser.email,
                         createdAt: supabaseUser.createdAt)

            let user = makeUser(from: supabaseUser, firstName: firstName, lastName: lastName)

            UserDefaults.standard.removeObject(forKey: Self.guestModeKey)
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

    /// Whether this account signs in with Apple (it may also have a password).
    var signsInWithApple: Bool {
        client.auth.currentSession?.user.identities?.contains { $0.provider == "apple" } ?? false
    }

    /// Deletes the account and everything stored with it: on the server (supabase function
    /// `delete_my_account`, which cascades to every table) and on this iPhone. Subscriptions billed by
    /// Apple, including Pausely Pro, are not cancelled; Apple manages those.
    ///
    /// An account that signs in with Apple confirms with Apple first, and the tokens Apple gave Pausely
    /// are revoked (`AppleRevocation`). Closing Apple's sheet stops the deletion (`CancellationError`).
    func deleteAccount() async throws {
        if signsInWithApple {
            let coordinator = AppleSignInCoordinator()
            let revocation = AppleRevocation(
                authorizationCode: { try await coordinator.authorizationCode() },
                revoke: { [client] code in
                    try await client.functions.invoke("apple-revoke", options: FunctionInvokeOptions(body: ["code": code]))
                })
            if await revocation.run() == .backedOut { throw CancellationError() }
        }
        try await client.rpc("delete_my_account").execute()
        await LocalUserData.wipe()
        await signOut()
    }

    // MARK: - Sign Out
    
    func signOut() async {
        verifyTask?.cancel()
        verifyTask = nil
        refreshTask?.cancel()
        refreshTask = nil

        // The cache goes first, whatever the server says. Offline, the library drops its own session and
        // then throws; a cache left behind would open the next launch as the person who just signed out.
        AccountMemory.forgetSession()
        AgeConsentManager.shared.clearDeviceGate()
        UserDefaults.standard.removeObject(forKey: "last_auth_email")
        LocalUserData.hideWhileSignedOut()
        await InboxScanner.shared.disconnectAll()
        // Delete account-linked Pro grant synchronously before any new sign-in can race it.
        PaymentManager.shared.clearProGrantSynchronously()
        do {
            try await client.auth.signOut()
        } catch {
            os_log("Sign out failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }

        UserDefaults.standard.removeObject(forKey: Self.guestModeKey)
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: "debug_auth_bypass")
        #endif
        needsNewPassword = false
        Self.clearPendingSignupPassword()
        forgetCodeRequest()
        isAuthenticated = false
        currentUser = nil
        state = .unauthenticated
    }

    /// Starts local-only mode without requiring an account. Everything stays on this iPhone until
    /// the person chooses to create an account or sign in.
    func enterGuestMode(persist: Bool = true) {
        verifyTask?.cancel()
        verifyTask = nil
        if persist { UserDefaults.standard.set(true, forKey: Self.guestModeKey) }
        #if DEBUG
        // A guest is a guest on the next launch too, not the built-in test user (a rater met the age gate there).
        UserDefaults.standard.removeObject(forKey: "debug_auth_bypass")
        #endif
        let guest = User(id: Self.guestUserID, email: nil, createdAt: Date())
        currentUser = guest
        isAuthenticated = true
        state = .authenticated(guest)
    }

    /// Removes all local data for a guest user and returns to the welcome screen.
    func eraseLocalGuestData() async {
        await LocalUserData.wipe()
        await signOut()
    }

    #if DEBUG
    /// Debug builds only: use the app without an account, as the built-in test user. Nothing is sent to
    /// the server; everything stays on this device. Signing out leaves it.
    func enterAsDebugUser() {
        UserDefaults.standard.set(true, forKey: "debug_auth_bypass")
        let user = User(id: AuthManager.localTestUserID, email: "debug@pausely.app", createdAt: Date(), firstName: "Debug", lastName: "User")
        currentUser = user
        isAuthenticated = true
        state = .authenticated(user)
    }
    #endif

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
            // Someone already signed into a cloud account has nothing to fix; guests upgrading or signed-out users are told to ask again.
            if !isSignedIntoCloud { linkProblem = expired }
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
                Self.clearPendingSignupPassword()
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
            if error is CancellationError || Task.isCancelled { return false }
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
                            isSignedIn: isSignedIntoCloud)
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

    private func beginNewPassword(for _: Auth.User) {
        UserDefaults.standard.removeObject(forKey: Self.resetRequestedKey)
        forgetCodeRequest()
        needsNewPassword = true
    }

    /// Saves the new password and signs the person in.
    func setNewPassword(_ password: String) async throws {
        do {
            let updated = try await client.auth.update(user: UserAttributes(password: password))
            needsNewPassword = false
            await finishEmailSignIn(updated)
        } catch {
            throw PauselyAuthError.unknown(error)
        }
    }

    /// The person backed out of choosing a password: the reset is dropped and nobody is signed in.
    func cancelNewPassword() async {
        try? await client.auth.signOut(scope: .local)
        if !isGuest { await clearLocalSignedOutSession() } else { needsNewPassword = false }
    }
}

// MARK: - Helpers
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

