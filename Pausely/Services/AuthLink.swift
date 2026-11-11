import Foundation

/// What a link opened from one of Pausely's account emails carries.
///
/// The emails are sent by the account service, and their templates are edited in its dashboard, not in
/// this app. A template can put a 6-digit code in the email, a link, or both, and the link's shape depends
/// on settings there. The app accepts every shape, so a template change can't lock anyone out.
enum AuthLink: Equatable {
    /// `?code=…`: a one-time code the app exchanges for a session (the service's default for apps).
    case code(String)
    /// `#access_token=…&refresh_token=…`: the session is in the link itself.
    case tokens(access: String, refresh: String)
    /// `?token_hash=…&type=…`: a hashed token the app verifies.
    case tokenHash(String, type: String)
    /// `?token=…&email=…&type=…`: the emailed code placed in a link.
    case emailToken(String, email: String, type: String)
    /// The service refused the link before sending it on ("Email link is invalid or has expired").
    case failed(String)
    /// Not an account link.
    case none

    static func parse(_ url: URL) -> AuthLink {
        let params = parameters(of: url)
        if params["error"] != nil || params["error_code"] != nil || params["error_description"] != nil {
            let description = (params["error_description"] ?? params["error"] ?? "")
                .replacingOccurrences(of: "+", with: " ")
            return .failed(description.removingPercentEncoding ?? description)
        }
        if let code = params["code"], !code.isEmpty { return .code(code) }
        if let access = params["access_token"], let refresh = params["refresh_token"], !access.isEmpty, !refresh.isEmpty {
            return .tokens(access: access, refresh: refresh)
        }
        let type = params["type"] ?? params["verification_type"] ?? "email"
        if let hash = params["token_hash"], !hash.isEmpty { return .tokenHash(hash, type: type) }
        if let token = params["token"], let email = params["email"], !token.isEmpty, !email.isEmpty {
            return .emailToken(token, email: email, type: type)
        }
        return .none
    }

    /// The link is the end of a password reset, as far as the link itself says.
    static func isRecovery(_ url: URL) -> Bool {
        if parameters(of: url)["type"]?.lowercased() == "recovery" { return true }
        return url.path.lowercased().contains("reset-password") || url.host?.lowercased() == "reset-password"
    }

    /// Query and fragment together: the service puts sessions in the fragment and codes in the query.
    static func parameters(of url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
        var result: [String: String] = [:]
        if let fragment = components.percentEncodedFragment {
            for pair in fragment.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                result[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        for item in components.queryItems ?? [] {
            if let value = item.value { result[item.name] = value }
        }
        return result
    }
}

/// How long until another code can be requested. The account service refuses a second email inside a
/// minute, so the button waits that long instead of failing.
struct ResendCountdown: Equatable {
    static let wait: TimeInterval = 60

    var lastSent: Date

    func secondsLeft(at now: Date) -> Int {
        max(0, Int((Self.wait - now.timeIntervalSince(lastSent)).rounded(.up)))
    }

    func canResend(at now: Date) -> Bool { secondsLeft(at: now) == 0 }
}

/// The six digits of an emailed code, from whatever was typed or pasted ("123 456", "Your code is 123456").
enum EmailCode {
    static let length = 6

    static func digits(from text: String) -> String {
        // Arabic-Indic and full-width digits are digits too: someone typing on an Arabic keyboard gets ١٢٣.
        let western = text.unicodeScalars.compactMap { scalar -> Character? in
            guard let value = scalar.properties.numericType == .decimal ? scalar.properties.numericValue : nil else { return nil }
            return Character(String(Int(value)))
        }
        return String(western.prefix(length))
    }
}
