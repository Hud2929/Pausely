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

struct SubscriptionRecord: Codable {
    var id: UUID?
    var user_id: UUID?
    var name: String
    var description: String?
    var logo_url: String?
    var category: String?
    var amount: Decimal
    var currency: String
    var billing_frequency: String
    var next_billing_date: String?
    var monthly_usage_minutes: Int
    var cost_per_hour: Decimal?
    var roi_score: Decimal?
    var waste_score: Decimal?
    var notify_before_days: Int?
    var trial_ends_at: String?
    var status: String
    var is_detected: Bool
    var can_pause: Bool
    var pause_url: String?
    var paused_until: String?
    var created_at: String?
    var updated_at: String?
    
    init(from subscription: Subscription) {
        self.id = subscription.id
        self.name = subscription.name
        self.description = subscription.description
        self.logo_url = subscription.logoUrl
        self.category = subscription.category
        self.amount = subscription.amount
        self.currency = subscription.currency
        self.billing_frequency = subscription.billingFrequency.rawValue
        self.monthly_usage_minutes = subscription.monthlyUsageMinutes
        self.cost_per_hour = subscription.costPerHour
        self.roi_score = subscription.roiScore
        self.waste_score = subscription.wasteScore
        self.notify_before_days = subscription.notifyBeforeDays
        self.trial_ends_at = subscription.trialEndsAt?.iso8601String
        self.next_billing_date = subscription.nextBillingDate?.iso8601String
        self.paused_until = subscription.pausedUntil?.iso8601String
        self.status = subscription.status.rawValue
        self.is_detected = subscription.isDetected
        self.can_pause = subscription.canPause
        self.pause_url = subscription.pauseUrl
    }

    /// Dates that can be cleared are always sent, as null when empty, so clearing one on this iPhone
    /// clears it on the server. Ids and timestamps the server owns are left out when empty.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(user_id, forKey: .user_id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(logo_url, forKey: .logo_url)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(amount, forKey: .amount)
        try c.encode(currency, forKey: .currency)
        try c.encode(billing_frequency, forKey: .billing_frequency)
        try c.encode(next_billing_date, forKey: .next_billing_date)
        try c.encode(monthly_usage_minutes, forKey: .monthly_usage_minutes)
        try c.encodeIfPresent(cost_per_hour, forKey: .cost_per_hour)
        try c.encodeIfPresent(roi_score, forKey: .roi_score)
        try c.encodeIfPresent(waste_score, forKey: .waste_score)
        try c.encodeIfPresent(notify_before_days, forKey: .notify_before_days)
        try c.encode(trial_ends_at, forKey: .trial_ends_at)
        try c.encode(status, forKey: .status)
        try c.encode(is_detected, forKey: .is_detected)
        try c.encode(can_pause, forKey: .can_pause)
        try c.encodeIfPresent(pause_url, forKey: .pause_url)
        try c.encode(paused_until, forKey: .paused_until)
        try c.encodeIfPresent(created_at, forKey: .created_at)
        try c.encodeIfPresent(updated_at, forKey: .updated_at)
    }
    
    func toSubscription() -> Subscription {
        var sub = Subscription(
            name: name,
            price: Double(truncating: amount as NSNumber),
            category: category ?? "Other",
            billingFrequency: BillingFrequency(rawValue: billing_frequency) ?? .monthly
        )
        sub.id = id ?? UUID()
        sub.description = description
        sub.logoUrl = logo_url
        sub.amount = amount
        sub.currency = currency
        sub.monthlyUsageMinutes = monthly_usage_minutes
        sub.costPerHour = cost_per_hour
        sub.roiScore = roi_score
        sub.wasteScore = waste_score
        sub.notifyBeforeDays = notify_before_days ?? 3
        sub.trialEndsAt = trial_ends_at?.iso8601Date
        sub.nextBillingDate = next_billing_date?.iso8601Date
        sub.pausedUntil = paused_until?.iso8601Date
        sub.status = SubscriptionStatus(rawValue: status) ?? .active
        sub.isDetected = is_detected
        sub.canPause = can_pause
        sub.pauseUrl = pause_url
        sub.createdAt = created_at?.iso8601Date ?? Date()
        sub.updatedAt = updated_at?.iso8601Date ?? Date()
        return sub
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
/// Pausely-specific authentication errors
/// Renamed from AuthError to avoid conflict with Supabase library
enum PauselyAuthError: LocalizedError {
    case emailNotConfirmed
    case invalidCredentials
    case sessionExpired
    case networkError
    case biometricFailed
    case invalidResponse
    case ageConsentRequired
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .emailNotConfirmed:
            return "Please verify your email before signing in. Check your inbox for the confirmation link."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .biometricFailed:
            return "Biometric authentication failed. Please use your password."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .ageConsentRequired:
            return "Please confirm your age before creating an account."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
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


