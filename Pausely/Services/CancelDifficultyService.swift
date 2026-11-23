import Foundation
import Supabase
import os.log

/// Anonymous community cancellation difficulty averages (`public.service_difficulty_scores`) and
/// optional 1–5 post-cancellation feedback (`public.cancel_difficulty_ratings`).
@MainActor
final class CancelDifficultyService: ObservableObject {
    static let shared = CancelDifficultyService()

    struct Score: Codable, Equatable, Sendable {
        let serviceName: String
        let ratingCount: Int
        let avgDifficulty: Double

        enum CodingKeys: String, CodingKey {
            case serviceName = "service_name"
            case ratingCount = "rating_count"
            case avgDifficulty = "avg_difficulty"
        }
    }

    struct RatingInsert: Encodable, Equatable {
        let user_id: UUID
        let service_name: String
        let difficulty_rating: Int
    }

    @Published private(set) var scores: [String: Score] = [:]
    private var loaded = false

    private init() {}

    /// Canonical service key matching `ServiceDatabase.services` or normalized lowercased slug.
    nonisolated static func serviceKey(for name: String) -> String {
        if let known = CancelHelp.service(named: name) { return known.id }
        return ServiceMatcher.words(name).joined(separator: "-")
    }

    /// Plain factual heads-up only when at least 3 people have rated cancelling this service.
    nonisolated static func summaryLine(for score: Score, locale: Locale = L10n.locale) -> String? {
        guard score.ratingCount >= 3 else { return nil }
        let formatted = score.avgDifficulty.formatted(.number.precision(.fractionLength(1)).locale(locale))
        let count = L10n.number(score.ratingCount, locale: locale)
        if score.avgDifficulty >= 3.5 {
            return L10n.string("Often hard to cancel (\(formatted)/5 from \(count) ratings) — leave extra time.")
        }
        if score.avgDifficulty <= 2.2 {
            return L10n.string("Usually quick to cancel (\(formatted)/5 from \(count) ratings).")
        }
        return L10n.string("Moderate to cancel (\(formatted)/5 from \(count) ratings).")
    }

    /// Returns cached community score for a subscription name, if at least 3 ratings exist.
    func score(for serviceName: String) -> Score? {
        let key = Self.serviceKey(for: serviceName)
        guard let found = scores[key], found.ratingCount >= 3 else { return nil }
        return found
    }

    /// Loads aggregate scores once per launch when signed into a cloud account (never in guest mode).
    func loadIfNeeded() async {
        guard !loaded, SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        loaded = true
        do {
            let rows: [Score] = try await SupabaseManager.shared.client
                .from("service_difficulty_scores")
                .select()
                .execute()
                .value
            scores = Dictionary(
                rows.map { (Self.serviceKey(for: $0.serviceName), $0) },
                uniquingKeysWith: { a, b in a.ratingCount >= b.ratingCount ? a : b }
            )
        } catch {
            loaded = false
            os_log("CancelDifficultyService load failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }

    /// Clears cached community scores on sign-out or wipe so signed-in data never leaks into guest mode.
    func reset() {
        scores = [:]
        loaded = false
    }

    /// Submits an anonymous 1 (easy) to 5 (hard) cancellation difficulty rating.
    /// Gracefully no-ops in guest mode, offline, or tests.
    func submit(serviceName: String, difficulty: Int) async {
        let clamped = max(1, min(5, difficulty))
        guard SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        let client = SupabaseManager.shared.client
        guard let userId = client.auth.currentSession?.user.id else { return }

        let payload = RatingInsert(
            user_id: userId,
            service_name: Self.serviceKey(for: serviceName),
            difficulty_rating: clamped
        )
        do {
            _ = try await client
                .from("cancel_difficulty_ratings")
                .insert(payload)
                .execute()
        } catch {
            os_log("CancelDifficultyService submit failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }

    #if DEBUG
    func seedDemoScores() {
        let samples = [
            Score(serviceName: "netflix", ratingCount: 18, avgDifficulty: 4.2),
            Score(serviceName: "apple-one", ratingCount: 14, avgDifficulty: 1.8),
            Score(serviceName: "peloton", ratingCount: 11, avgDifficulty: 3.9),
            Score(serviceName: "adobe-creative-cloud", ratingCount: 27, avgDifficulty: 4.6),
        ]
        scores = Dictionary(samples.map { (Self.serviceKey(for: $0.serviceName), $0) }, uniquingKeysWith: { a, _ in a })
        loaded = true
    }
    #endif
}
