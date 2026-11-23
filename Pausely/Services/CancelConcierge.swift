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

    /// Builds a `mailto:` URL so people using Gmail, Outlook, or Spark as their default iOS Mail
    /// app can launch a pre-filled draft directly without needing Apple Mail configured.
    static func mailtoURL(for draft: Draft) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.queryItems = [
            URLQueryItem(name: "subject", value: draft.subject),
            URLQueryItem(name: "body", value: draft.body)
        ]
        return components.url
    }

    /// Generates a clear, dated cancellation request email in the reader's chosen language.
    static func cancellationDraft(for subscription: Subscription,
                                  accountEmail: String? = nil,
                                  now: Date = Date(),
                                  calendar: Calendar = .billing,
                                  locale: Locale = L10n.locale) -> Draft {
        let price = subscription.billingFrequency.priced(MoneyFormat.string(subscription.amount, subscription.currency, locale: locale))
        let subject = L10n.string("Cancellation request: \(subscription.name)")
        var paragraphs: [String] = [
            L10n.string("Hello \(subscription.name) Support,"),
            L10n.string("Please cancel my \(subscription.name) subscription (\(price)) effective immediately, and turn off auto-renewal so no further charges are billed."),
        ]
        if let renewal = subscription.nextRenewal(onOrAfter: now, calendar: calendar) {
            let day = DayText.date(renewal, locale: locale)
            paragraphs.append(L10n.string("My next scheduled renewal date is \(day). Please confirm cancellation in writing before that date."))
        } else {
            paragraphs.append(L10n.string("Please reply with written confirmation once my subscription has been cancelled."))
        }
        if let email = accountEmail, !email.isEmpty {
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
        let charge = MoneyFormat.string(subscription.amount, subscription.currency, locale: locale)
        let subject = L10n.string("Refund request: \(subscription.name)")
        let opening = subscription.status == .trial
            ? L10n.string("I recently noticed a charge of \(charge) after a \(subscription.name) free trial that I did not intend to continue. I would like to cancel the plan and request a refund for this charge.")
            : L10n.string("I recently noticed a charge of \(charge) for my \(subscription.name) subscription that I no longer intend to use. I would like to cancel the plan and request a refund for this charge.")
        var paragraphs: [String] = [
            L10n.string("Hello \(subscription.name) Support,"),
            opening,
            L10n.string("Please confirm once the cancellation and refund have been processed."),
        ]
        if let email = accountEmail, !email.isEmpty {
            paragraphs.append(L10n.string("Account email: \(email)"))
        }
        if let method = subscription.paymentMethod?.trimmingCharacters(in: .whitespacesAndNewlines), !method.isEmpty {
            paragraphs.append(L10n.string("Billed to: \(method)"))
        }
        paragraphs.append(L10n.string("Thank you."))
        return Draft(subject: subject, body: paragraphs.joined(separator: "\n\n"))
    }
}
