import Foundation

/// Pure generator for polite, unambiguous cancellation and refund request emails so the person
/// doesn't have to draft them from scratch when a service hides online cancellation.
enum CancelConcierge {

    struct Draft: Equatable, Sendable {
        let subject: String
        let body: String
    }

    /// Apple's official refund portal for App Store billed subscriptions.
    static let appleRefundURL = URL(string: "https://reportaproblem.apple.com")

    /// Strips CR/LF and Unicode control characters so multiline names can never inject mail headers.
    private static func sanitizedSubject(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> UnicodeScalar in
            (scalar.value < 0x20 || scalar.value == 0x7F || CharacterSet.newlines.contains(scalar)) ? UnicodeScalar(0x20) : scalar
        }
        return String(String.UnicodeScalarView(scalars))
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Omits blank values and Apple's Hide My Email relay so we never hand a private relay address
    /// to third-party support where the user's real account email is needed.
    private static func cleanAccountEmail(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasSuffix("@privaterelay.appleid.com") { return nil }
        return trimmed
    }

    /// Builds a `mailto:` URL (RFC 6068) so Gmail, Outlook, or Spark can launch a pre-filled draft
    /// directly without Apple Mail. Encodes `+` as `%2B` and uses CRLF line breaks in the body.
    static func mailtoURL(for draft: Draft) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        let crlfBody = draft.body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\r\n")
        components.queryItems = [
            URLQueryItem(name: "subject", value: sanitizedSubject(draft.subject)),
            URLQueryItem(name: "body", value: crlfBody)
        ]
        if let query = components.percentEncodedQuery {
            components.percentEncodedQuery = query.replacingOccurrences(of: "+", with: "%2B")
        }
        return components.url
    }

    /// Generates a clear, dated cancellation request email in the reader's chosen language.
    static func cancellationDraft(for subscription: Subscription,
                                  accountEmail: String? = nil,
                                  now: Date = Date(),
                                  calendar: Calendar = .billing,
                                  locale: Locale = L10n.locale) -> Draft {
        let price = subscription.billingFrequency.priced(MoneyFormat.string(subscription.amount, subscription.currency, locale: locale))
        let subject = sanitizedSubject(L10n.string("Cancellation request: \(subscription.name)"))
        let upcoming = RenewalDecisions.upcomingCharge(for: subscription, now: now, calendar: calendar)
        let isTrial = subscription.status == .trial || upcoming?.isTrialEnd == true
        let requestLine = isTrial
            ? L10n.string("Please cancel my \(subscription.name) free trial before it converts to a paid plan (\(price)), and turn off auto-renewal so I am not charged.")
            : L10n.string("Please cancel my \(subscription.name) subscription (\(price)) effective immediately, and turn off auto-renewal so no further charges are billed.")
        var paragraphs: [String] = [
            L10n.string("Hello \(subscription.name) Support,"),
            requestLine,
        ]
        if let renewal = upcoming?.date {
            let day = DayText.date(renewal, locale: locale)
            paragraphs.append(isTrial
                              ? L10n.string("My free trial ends on \(day). Please confirm cancellation in writing before that date.")
                              : L10n.string("My next scheduled renewal date is \(day). Please confirm cancellation in writing before that date."))
        } else {
            paragraphs.append(L10n.string("Please reply with written confirmation once my subscription has been cancelled."))
        }
        if let email = cleanAccountEmail(accountEmail) {
            paragraphs.append(L10n.string("Account email: \(email)"))
        }
        if let method = subscription.paymentMethod?.trimmingCharacters(in: .whitespacesAndNewlines), !method.isEmpty {
            paragraphs.append(L10n.string("Billed to: \(method)"))
        }
        paragraphs.append(L10n.string("Thank you."))
        return Draft(subject: subject, body: paragraphs.joined(separator: "\n\n"))
    }

    /// Generates a polite refund request email for an unexpected or unwanted renewal charge.
    static func refundDraft(for subscription: Subscription,
                            accountEmail: String? = nil,
                            locale: Locale = L10n.locale) -> Draft {
        let subject = sanitizedSubject(L10n.string("Refund request: \(subscription.name)"))
        let opening: String
        if subscription.amount > 0 {
            let charge = MoneyFormat.string(subscription.amount, subscription.currency, locale: locale)
            opening = subscription.status == .trial
                ? L10n.string("I recently noticed a charge of \(charge) after a \(subscription.name) free trial that I did not intend to continue. I would like to cancel the plan and request a refund for this charge.")
                : L10n.string("I recently noticed a charge of \(charge) for my \(subscription.name) subscription that I no longer intend to use. I would like to cancel the plan and request a refund for this charge.")
        } else {
            opening = subscription.status == .trial
                ? L10n.string("I recently noticed a charge after a \(subscription.name) free trial that I did not intend to continue. I would like to cancel the plan and request a refund for this charge.")
                : L10n.string("I recently noticed a charge for my \(subscription.name) subscription that I no longer intend to use. I would like to cancel the plan and request a refund for this charge.")
        }
        var paragraphs: [String] = [
            L10n.string("Hello \(subscription.name) Support,"),
            opening,
            L10n.string("Please confirm once the cancellation and refund have been processed."),
        ]
        if let email = cleanAccountEmail(accountEmail) {
            paragraphs.append(L10n.string("Account email: \(email)"))
        }
        if let method = subscription.paymentMethod?.trimmingCharacters(in: .whitespacesAndNewlines), !method.isEmpty {
            paragraphs.append(L10n.string("Billed to: \(method)"))
        }
        paragraphs.append(L10n.string("Thank you."))
        return Draft(subject: subject, body: paragraphs.joined(separator: "\n\n"))
    }
}
