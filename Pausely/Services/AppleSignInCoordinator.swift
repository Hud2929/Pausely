import AuthenticationServices
import CryptoKit
import Foundation

/// Sign in with Apple outside Apple's own button: the nonce the button needs, and the confirmation
/// Apple's sheet gives when an account is being deleted.
@MainActor
final class AppleSignInCoordinator: NSObject {

    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    /// Has the person confirm with Apple and returns the one-time code Apple issues for it: what the
    /// server needs to revoke the tokens Apple gave Pausely for this person (`AppleRevocation`).
    func authorizationCode() async throws -> String {
        let controller = ASAuthorizationController(authorizationRequests: [ASAuthorizationAppleIDProvider().createRequest()])
        controller.delegate = self
        controller.presentationContextProvider = self
        let authorization = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.authorizationCode,
              let code = String(data: data, encoding: .utf8), !code.isEmpty else {
            throw ASAuthorizationError(.invalidResponse)
        }
        return code
    }

    // MARK: - The nonce for Apple's button

    static func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                // Fallback to less secure random generation if SecRandomCopyBytes fails
                for _ in 0..<remaining {
                    let index = Int.random(in: 0..<charset.count)
                    result.append(charset[index])
                }
                return result
            }
            for byte in randoms where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            self.continuation?.resume(returning: authorization)
            self.continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    @MainActor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        if let window = activeScene?.windows.first(where: \.isKeyWindow) ?? activeScene?.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}
