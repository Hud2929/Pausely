import Foundation
import SwiftUI
import Supabase

// MARK: - Age Consent
/// Enforces Pausely's minimum age (16) and keeps a minimal consent record.
///
/// Privacy by design: the date of birth is used only in memory to compute eligibility and is
/// never stored or sent anywhere. We persist only "minimum age confirmed" + timestamp + versions.
@MainActor
final class AgeConsentManager: ObservableObject {
    static let shared = AgeConsentManager()

    /// Minimum age to use Pausely. Change here (and in the policies) if the requirement changes.
    nonisolated static let minimumAge = 16
    /// Bump when the age/consent wording in the Terms or Privacy Policy changes materially.
    nonisolated static let policyVersion = "2026-10-05"
    /// How long an under-age attempt locks the age gate on this device.
    nonisolated static let lockoutDuration: TimeInterval = 24 * 60 * 60

    // MARK: Keys
    private enum Key {
        static let devicePassed = "age_gate_device_passed"
        static let blockedAt = "age_gate_blocked_at"
        static func user(_ id: String) -> String { "age_consent_user_\(id)" }
        static func pendingSync(_ id: String) -> String { "age_consent_pending_sync_\(id)" }
    }

    /// Bumped whenever consent state changes so SwiftUI views re-evaluate.
    @Published private(set) var stateVersion = 0

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Pure eligibility logic (unit tested)

    /// Whole years between `birthDate` and `now`, or nil when the date is in the future.
    nonisolated static func age(on now: Date, birthDate: Date, calendar: Calendar = .current) -> Int? {
        guard birthDate <= now else { return nil }
        return calendar.dateComponents([.year], from: birthDate, to: now).year
    }

    nonisolated static func isOldEnough(birthDate: Date,
                                        now: Date = Date(),
                                        calendar: Calendar = .current,
                                        minimumAge: Int = AgeConsentManager.minimumAge) -> Bool {
        guard let years = age(on: now, birthDate: birthDate, calendar: calendar) else { return false }
        return years >= minimumAge
    }

    // MARK: - Device-level gate (runs BEFORE any account exists)

    /// True when this device has passed the gate (needed before sign-up screens).
    var hasPassedDeviceGate: Bool { defaults.bool(forKey: Key.devicePassed) }

    /// Remaining lockout after an under-age attempt, or nil when not locked.
    func lockoutRemaining(now: Date = Date()) -> TimeInterval? {
        guard let blockedAt = defaults.object(forKey: Key.blockedAt) as? Date else { return nil }
        let remaining = blockedAt.addingTimeInterval(Self.lockoutDuration).timeIntervalSince(now)
        if remaining <= 0 {
            defaults.removeObject(forKey: Key.blockedAt)
            return nil
        }
        return remaining
    }

    enum Outcome: Equatable {
        case allowed
        case underAge
        case lockedOut
        case invalidDate
    }

    /// Evaluates a submitted birth date. The date itself is never stored.
    func evaluate(birthDate: Date, now: Date = Date()) -> Outcome {
        if lockoutRemaining(now: now) != nil { return .lockedOut }
        guard Self.age(on: now, birthDate: birthDate) != nil else { return .invalidDate }
        if Self.isOldEnough(birthDate: birthDate, now: now) {
            defaults.set(true, forKey: Key.devicePassed)
            defaults.removeObject(forKey: Key.blockedAt)
            stateVersion += 1
            return .allowed
        }
        defaults.set(false, forKey: Key.devicePassed)
        defaults.set(now, forKey: Key.blockedAt)
        stateVersion += 1
        return .underAge
    }

    // MARK: - Per-user consent record

    /// True when this user has a confirmed consent record on this device.
    func hasConsent(userId: String) -> Bool {
        defaults.object(forKey: Key.user(userId)) as? Date != nil
    }

    /// Records consent for a signed-in user: locally first (so the app never blocks on network),
    /// then syncs to the user's `profiles` row. A failed sync is retried by `syncPendingConsent`.
    func recordConsent(userId: String, now: Date = Date()) async {
        defaults.set(now, forKey: Key.user(userId))
        defaults.set(true, forKey: Key.pendingSync(userId))
        stateVersion += 1
        await syncPendingConsent(userId: userId)
    }

    func syncPendingConsent(userId: String) async {
        guard defaults.bool(forKey: Key.pendingSync(userId)),
              let confirmedAt = defaults.object(forKey: Key.user(userId)) as? Date else { return }

        struct ConsentRow: Encodable {
            let id: String
            let age_confirmed_at: Date
            let age_minimum_met: Bool
            let age_minimum_required: Int
            let consent_policy_version: String
            let consent_app_version: String
        }

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let row = ConsentRow(id: userId,
                             age_confirmed_at: confirmedAt,
                             age_minimum_met: true,
                             age_minimum_required: Self.minimumAge,
                             consent_policy_version: Self.policyVersion,
                             consent_app_version: appVersion)
        do {
            try await SupabaseManager.shared.client
                .from("profiles")
                .upsert(row)
                .execute()
            defaults.set(false, forKey: Key.pendingSync(userId))
        } catch {
            // Keep the pending flag; retried on next launch / sign-in.
            PauselyLogger.info("Age consent sync deferred: \(error.localizedDescription)", category: "auth")
        }
    }

    /// Existing/returning users who have no consent record must confirm before continuing.
    func needsConsent(userId: String) -> Bool { !hasConsent(userId: userId) }
}
