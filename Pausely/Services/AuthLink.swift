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

/// Whether a link from an account email may be acted on.
///
/// A link is honoured only when this device asked for a code or a reset in the last hour (the life of a
/// code), nobody is signed in, and the account it opens has the address that was asked for. Without
/// this, anyone could put a sign-in code for their own account in a `pausely://auth/...` link, and a tap
/// would sign whoever holds the phone into the sender's account.
struct AuthLinkGate: Equatable {
    /// How long an emailed code or link lasts.
    static let window: TimeInterval = 3_600

    /// The address this device last asked a code or a reset for, and when.
    var requestedEmail: String?
    var requestedAt: Date?
    var isSignedIn: Bool

    /// May the app act on this link at all? Checked before anything is sent to the account service.
    func allows(_ link: AuthLink, now: Date) -> Bool {
        guard !isSignedIn, let requestedEmail, let requestedAt,
              now.timeIntervalSince(requestedAt) <= Self.window else { return false }
        // A link that names its address has to name the one that was asked for.
        if case .emailToken(_, let email, _) = link { return Self.sameAddress(email, requestedEmail) }
        return true
    }

    /// Once the account service has answered: is this the account that was asked for?
    func accepts(accountEmail: String?) -> Bool {
        guard let requestedEmail, let accountEmail else { return false }
        return Self.sameAddress(accountEmail, requestedEmail)
    }

    static func sameAddress(_ first: String, _ second: String) -> Bool {
        let a = normalized(first)
        return !a.isEmpty && a == normalized(second)
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

    /// The moments the waiting line changes: one a second until the wait is over, and none after.
    /// (The button was redrawn every second for as long as its screen was open.)
    func ticks(from now: Date) -> [Date] {
        (0...secondsLeft(at: now)).map { now.addingTimeInterval(TimeInterval($0)) }
    }
}

/// An email or web address as it is shown: whole, on as many lines as it needs. It may break
/// after "@", after a dot, after a hyphen of its own and before a slash, so a long one is not
/// cut in the middle the way "firstname.las…pany.co.uk" was. Everywhere else its characters are joined, so the line can
/// neither break there nor be given a hyphen: at the accessibility text sizes iOS hyphenates
/// long words, and "account.apple.com" was drawn as "accoun-t.apple.-com", a different address.
enum AddressText {
    /// A place where the address may go on to the next line (zero-width space).
    static let gap = "\u{200B}"
    /// Between two characters that stay together (word joiner).
    static let joiner = "\u{2060}"

    static func breakable(_ address: String) -> String {
        let characters = Array(address)
        var shown = ""
        for (index, character) in characters.enumerated() {
            shown.append(character)
            guard index + 1 < characters.count else { break }
            shown += character == "@" || character == "." || character == "-" || characters[index + 1] == "/" ? gap : joiner
        }
        return shown
    }

    /// What was typed, without the marks: what VoiceOver is given to say, and what is compared.
    static func plain(_ shown: String) -> String {
        shown.replacingOccurrences(of: gap, with: "").replacingOccurrences(of: joiner, with: "")
    }

    /// A sentence with every address in it made `breakable` ("Open account.apple.com and sign
    /// in."). The words around the addresses are left as they are.
    static func inSentence(_ sentence: String) -> String {
        guard let addresses = try? NSRegularExpression(pattern: pattern) else { return sentence }
        var shown = sentence
        let whole = NSRange(sentence.startIndex..., in: sentence)
        for match in addresses.matches(in: sentence, range: whole).reversed() {
            guard let range = Range(match.range, in: shown) else { continue }
            shown.replaceSubrange(range, with: breakable(String(shown[range])))
        }
        return shown
    }

    /// name@host.tld, or host.tld with an optional path. A full stop that ends the sentence is
    /// not part of either.
    private static let pattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)+"
        + "|[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}(?:/[A-Za-z0-9_~/-]+)*"
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
