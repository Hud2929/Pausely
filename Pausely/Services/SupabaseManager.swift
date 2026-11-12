import Foundation
import LocalAuthentication
import SwiftUI
import Supabase
import Auth
import PostgREST
import os.log

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    @Published var isConfigured: Bool = false
    private(set) var isDemoMode = false

    /// Returns true if the app is running in demo mode (no real Supabase credentials configured)
    var isUsingDemoMode: Bool {
        return isDemoMode
    }


    private init() {
        // Use EnvironmentConfig for secure credential management
        // Credentials MUST be set via environment variables or XCConfig files
        guard let supabaseURL = URL(string: EnvironmentConfig.supabaseURL) else {
            os_log("⚠️ Invalid Supabase URL. Running in offline mode.", log: .default, type: .error)
            guard let demoURL = URL(string: "https://demo.supabase.co") else {
                // Ultimate fallback: create a dummy URL that won't crash
                var components = URLComponents()
                components.scheme = "https"
                components.host = "demo.supabase.co"
                let fallbackURL = components.url ?? URL(fileURLWithPath: "/dev/null")
                client = SupabaseClient(supabaseURL: fallbackURL, supabaseKey: "INVALID_DEMO_KEY_NOT_REAL")
                isConfigured = false
                isDemoMode = true
                return
            }
            client = SupabaseClient(supabaseURL: demoURL, supabaseKey: "INVALID_DEMO_KEY_NOT_REAL")
            isConfigured = false
            isDemoMode = true
            return
        }

        let supabaseKey = EnvironmentConfig.supabaseAnonKey

        // Validate credentials are not using placeholders
        if supabaseKey.isEmpty || supabaseKey == "YOUR_SUPABASE_ANON_KEY" {
            os_log("⚠️ Supabase Anon Key not configured. Running in offline mode.", log: .default, type: .error)
            client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: "INVALID_DEMO_KEY_NOT_REAL")
            isConfigured = false
            isDemoMode = true
            return
        }

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        isConfigured = true
        isDemoMode = false

        // Log configuration status (debug only)
        #if DEBUG
        _ = EnvironmentConfig.validate()
        #endif
    }
}

// MARK: - Subscription Record

/// A subscription as the `subscriptions` table holds it: the fields the app has, nothing more. The
/// table still has columns from earlier versions; they are neither sent nor read.
struct SubscriptionRecord: Codable {
    var id: UUID?
    var user_id: UUID?
    var name: String
    var category: String?
    var amount: Decimal
    var currency: String
    var billing_frequency: String
    var next_billing_date: String?
    var notify_before_days: Int?
    var trial_ends_at: String?
    var status: String
    var created_at: String?

    init(from subscription: Subscription) {
        self.id = subscription.id
        self.name = subscription.name
        self.category = subscription.category
        self.amount = subscription.amount
        self.currency = subscription.currency
        self.billing_frequency = subscription.billingFrequency.rawValue
        self.notify_before_days = subscription.notifyBeforeDays
        // Days go up in their saved form: noon UTC on the day, the same day wherever it is read.
        self.trial_ends_at = subscription.trialEndsAt.map { BillingDay.stored($0).iso8601String }
        self.next_billing_date = subscription.nextBillingDate.map { BillingDay.stored($0).iso8601String }
        self.status = subscription.status.rawValue
    }

    /// Dates that can be cleared are always sent, as null when empty, so clearing one on this iPhone
    /// clears it on the server. Ids and timestamps the server owns are left out when empty.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(user_id, forKey: .user_id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(amount, forKey: .amount)
        try c.encode(currency, forKey: .currency)
        try c.encode(billing_frequency, forKey: .billing_frequency)
        try c.encode(next_billing_date, forKey: .next_billing_date)
        try c.encodeIfPresent(notify_before_days, forKey: .notify_before_days)
        try c.encode(trial_ends_at, forKey: .trial_ends_at)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(created_at, forKey: .created_at)
    }

    /// True when a day in this row was saved by an earlier version (as noon where it was typed). Read on
    /// the phone it was typed on it is right; sent back once in the saved form, it is right everywhere.
    var hasADayInTheOldForm: Bool {
        [next_billing_date, trial_ends_at].contains { text in
            guard let date = text?.iso8601Date else { return false }
            return !BillingDay.isStoredForm(date)
        }
    }

    func toSubscription() -> Subscription {
        Subscription(
            id: id ?? UUID(),
            name: name,
            category: category ?? "Other",
            amount: amount,
            currency: currency,
            billingFrequency: BillingFrequency(rawValue: billing_frequency) ?? .monthly,
            nextBillingDate: next_billing_date?.iso8601Date.map { BillingDay.local(fromStored: $0) },
            notifyBeforeDays: notify_before_days ?? 3,
            trialEndsAt: trial_ends_at?.iso8601Date.map { BillingDay.local(fromStored: $0) },
            status: SubscriptionStatus(saved: status),
            createdAt: created_at?.iso8601Date ?? Date()
        )
    }
}

// MARK: - Date Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

extension String {
    /// Timestamps as the database returns them, with or without fractional seconds
    /// ("2026-03-04T17:30:00+00:00", "2026-03-04T17:30:00.123456+00:00").
    var iso8601Date: Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: self) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: self)
    }
}

// MARK: - Auth Errors

/// What can stop a sign-up or sign-in. The words a person reads are chosen by the screen
/// (`AccountProblem`, `CodeProblem`), in their language; this only says which kind it was.
enum PauselyAuthError: Error {
    /// The age check hasn't been passed on this iPhone.
    case ageConsentRequired
    /// Anything the account service or the network said.
    case unknown(Error)
}

// MARK: - Auth State
/// Pausely-specific authentication state
/// Renamed from AuthState to avoid conflict with Supabase library
enum PauselyAuthState {
    case initial
    case loading
    case authenticated(User)
    case emailConfirmationRequired(String)
    case unauthenticated
    case error(PauselyAuthError)
}


// MARK: - Additional Database Models


// MARK: - Waitlist Model


