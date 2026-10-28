import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Sign-in with an OAuth provider (Google, Microsoft) as a public client: authorization code with PKCE
/// (S256) and a random `state` checked on return. Tokens are kept only in the Keychain.
enum OAuthSession {
    struct Provider {
        var authorizeURL: URL
        var tokenURL: URL
        var clientID: String
        var redirectURI: String
        var callbackScheme: String
        var scopes: [String]
        var extraAuthorizeParameters: [String: String] = [:]
        /// Microsoft wants the scope repeated on token requests; Google doesn't.
        var sendsScopeOnTokenRequest = false
    }

    struct Tokens: Codable, Equatable {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date

        var isFresh: Bool { expiresAt.timeIntervalSinceNow > 90 }
    }

    // MARK: - Sign-in

    @MainActor
    static func signIn(_ provider: Provider) async throws -> Tokens {
        let verifier = randomURLSafe(bytes: 32)
        let state = randomURLSafe(bytes: 16)
        var components = URLComponents(url: provider.authorizeURL, resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "client_id", value: provider.clientID),
            URLQueryItem(name: "redirect_uri", value: provider.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: provider.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        items += provider.extraAuthorizeParameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        components?.queryItems = items
        guard let url = components?.url else { throw MailboxError.notConfigured("Couldn't build the sign-in address.") }

        let callback = try await present(url: url, callbackScheme: provider.callbackScheme)
        let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = query.first(where: { $0.name == "error" })?.value {
            if error == "access_denied" { throw MailboxError.cancelled }
            throw MailboxError.authFailed("Sign-in didn't finish (\(error)).")
        }
        guard query.first(where: { $0.name == "state" })?.value == state else {
            throw MailboxError.insecure("The sign-in response didn't match this request, so Pausely ignored it.")
        }
        guard let code = query.first(where: { $0.name == "code" })?.value else {
            throw MailboxError.authFailed("No sign-in code came back.")
        }

        var form = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": provider.redirectURI,
            "client_id": provider.clientID,
            "code_verifier": verifier
        ]
        if provider.sendsScopeOnTokenRequest { form["scope"] = provider.scopes.joined(separator: " ") }
        return try await tokenRequest(provider.tokenURL, form: form, previousRefresh: nil)
    }

    static func refresh(_ provider: Provider, refreshToken: String) async throws -> Tokens {
        var form = ["grant_type": "refresh_token", "refresh_token": refreshToken, "client_id": provider.clientID]
        if provider.sendsScopeOnTokenRequest { form["scope"] = provider.scopes.joined(separator: " ") }
        return try await tokenRequest(provider.tokenURL, form: form, previousRefresh: refreshToken)
    }

    private static func tokenRequest(_ url: URL, form: [String: String], previousRefresh: String?) async throws -> Tokens {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(formEncode(form).utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        struct Payload: Decodable {
            let access_token: String?
            let refresh_token: String?
            let expires_in: Double?
            let error: String?
        }
        let payload = try? JSONDecoder().decode(Payload.self, from: data)
        guard status == 200, let access = payload?.access_token else {
            if payload?.error == "invalid_grant" { throw MailboxError.authExpired }
            throw MailboxError.authFailed("Sign-in couldn't be completed (\(payload?.error ?? "HTTP \(status)")).")
        }
        return Tokens(accessToken: access,
                      refreshToken: payload?.refresh_token ?? previousRefresh,
                      expiresAt: Date().addingTimeInterval(payload?.expires_in ?? 3_000))
    }

    // MARK: - Token storage

    static func store(_ tokens: Tokens, for accountID: String) {
        if let data = try? JSONEncoder().encode(tokens), let text = String(data: data, encoding: .utf8) {
            MailboxAccountStore.setSecret(text, .accessToken, for: accountID)
        }
        if let refresh = tokens.refreshToken { MailboxAccountStore.setSecret(refresh, .refreshToken, for: accountID) }
    }

    static func load(for accountID: String) -> Tokens? {
        guard let text = MailboxAccountStore.secret(.accessToken, for: accountID),
              var tokens = try? JSONDecoder().decode(Tokens.self, from: Data(text.utf8)) else { return nil }
        if tokens.refreshToken == nil { tokens.refreshToken = MailboxAccountStore.secret(.refreshToken, for: accountID) }
        return tokens
    }

    /// A usable access token, refreshed when it's about to expire.
    static func validAccessToken(_ provider: Provider, accountID: String) async throws -> String {
        guard let tokens = load(for: accountID) else { throw MailboxError.authExpired }
        if tokens.isFresh { return tokens.accessToken }
        guard let refresh = tokens.refreshToken else { throw MailboxError.authExpired }
        let renewed = try await self.refresh(provider, refreshToken: refresh)
        store(renewed, for: accountID)
        return renewed.accessToken
    }

    static func forceRefresh(_ provider: Provider, accountID: String) async throws -> String {
        guard let refresh = load(for: accountID)?.refreshToken else { throw MailboxError.authExpired }
        let renewed = try await self.refresh(provider, refreshToken: refresh)
        store(renewed, for: accountID)
        return renewed.accessToken
    }

    // MARK: - Helpers

    static func formEncode(_ form: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return form.sorted { $0.key < $1.key }.map { key, value in
            "\(key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
    }

    static func randomURLSafe(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URL(Data(bytes))
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decodeBase64URL(_ text: String) -> Data? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        return Data(base64Encoded: base64)
    }

    @MainActor
    private static func present(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let anchor = PresentationAnchor()
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                _ = anchor  // keep the anchor alive until the session ends
                if let error {
                    let cancelled = (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue
                    continuation.resume(throwing: cancelled ? MailboxError.cancelled : MailboxError.authFailed(error.localizedDescription))
                } else if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: MailboxError.authFailed("No response from the sign-in page."))
                }
            }
            session.presentationContextProvider = anchor
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: MailboxError.authFailed("The sign-in page couldn't open."))
            }
        }
    }

    private final class PresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

// MARK: - HTTP with retries

enum MailboxHTTP {
    /// Sends a request with a bearer token. Retries once after refreshing on 401, and waits out 429/503
    /// (Retry-After, at most 30 seconds, up to three times).
    static func data(_ request: URLRequest, token: () async throws -> String, refresh: () async throws -> String) async throws -> Data {
        var current = try await token()
        var refreshed = false
        var throttles = 0
        while true {
            try Task.checkCancellation()
            var authorized = request
            authorized.setValue("Bearer \(current)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: authorized)
            let http = response as? HTTPURLResponse
            switch http?.statusCode ?? 0 {
            case 200...299:
                return data
            case 401 where !refreshed:
                refreshed = true
                current = try await refresh()
            case 401, 403:
                throw MailboxError.authExpired
            case 404:
                throw MailboxError.server("Not found")
            case 429 where throttles < 3, 503 where throttles < 3:  // `where` binds per pattern in Swift
                throttles += 1
                let wait = min(30, Double(http?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? Double(2 << throttles))
                try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            case 429, 503:
                throw MailboxError.throttled(retryAfter: 60)
            default:
                throw MailboxError.server("HTTP \(http?.statusCode ?? 0)")
            }
        }
    }
}
