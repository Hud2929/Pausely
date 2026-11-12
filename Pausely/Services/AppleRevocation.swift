import AuthenticationServices
import Foundation

/// Deleting an account that signs in with Apple. The person confirms with Apple, and the tokens Apple
/// gave Pausely for them are revoked before the account goes, as Apple asks of apps that offer Sign in
/// with Apple (developer.apple.com/support/offering-account-deletion-in-your-app). The server does the
/// revoking (`supabase/functions/apple-revoke`); the app only hands it Apple's one-time code.
///
/// Backing out of Apple's sheet stops the deletion. Any other trouble does not: deleting the account
/// is what the person asked for, and Apple lets them remove Pausely themselves under Sign in with Apple
/// in Settings.
struct AppleRevocation {
    enum Outcome: Equatable {
        case revoked
        /// The person closed Apple's sheet: nothing is deleted.
        case backedOut
        /// Apple or the server could not be reached, or the server has no key yet. The account is still deleted.
        case notRevoked
    }

    /// Shows Apple's sheet and returns the one-time code it issues.
    var authorizationCode: () async throws -> String
    /// Sends the code to the server, which exchanges it and revokes at once.
    var revoke: (String) async throws -> Void

    func run() async -> Outcome {
        let code: String
        do {
            code = try await authorizationCode()
        } catch let error as ASAuthorizationError where error.code == .canceled {
            return .backedOut
        } catch {
            return .notRevoked
        }
        do {
            try await revoke(code)
            return .revoked
        } catch {
            return .notRevoked
        }
    }
}
