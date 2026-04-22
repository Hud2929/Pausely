import AuthenticationServices
import CryptoKit
import Foundation

/// Drives the native Sign in with Apple sheet and returns the identity token + nonce.
@MainActor
final class AppleSignInCoordinator: NSObject, ObservableObject {

    private var currentNonce: String?
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    // MARK: - Public API

    /// Presents the Apple sign-in sheet and returns the data needed to authenticate with Supabase.
    func signIn() async throws -> (idToken: String, rawNonce: String, fullName: PersonNameComponents?) {
        let nonce = Self.generateNonce()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let authorization = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorization, Error>) in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AppleSignInError.missingToken
        }

        return (idToken: idToken, rawNonce: nonce, fullName: credential.fullName)
    }

    // MARK: - Helpers (also exposed as static for use with SignInWithAppleButton)

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
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Error

enum AppleSignInError: LocalizedError {
    case missingToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingToken:  return "Could not get Apple identity token."
        case .cancelled:     return "Sign in was cancelled."
        }
    }
}
