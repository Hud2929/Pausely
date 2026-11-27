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

    /// Canonical service key matching `ServiceDatabase.services` or normalized lowercased ASCII slug (1–120 chars).
    nonisolated static func serviceKey(for name: String) -> String {
        if let known = CancelHelp.service(named: name) { return String(known.id.lowercased().prefix(120)) }
        let asciiWords = ServiceMatcher.words(name).map { word in
            String(word.unicodeScalars.filter { ($0.value >= 97 && $0.value <= 122) || ($0.value >= 48 && $0.value <= 57) })
        }.filter { !$0.isEmpty }
        let joined = asciiWords.joined(separator: "-")
        return String(joined.prefix(120))
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
            let pageSize = 1_000
            let maxRows = 5_000
            var rows: [Score] = []
            var offset = 0
            while rows.count < maxRows {
                let end = min(offset + pageSize - 1, maxRows - 1)
                let page: [Score] = try await SupabaseManager.shared.client
                    .from("service_difficulty_scores")
                    .select()
                    .order("service_name", ascending: true)
                    .range(from: offset, to: end)
                    .execute()
                    .value
                rows.append(contentsOf: page)
                if page.count < pageSize { break }
                offset += pageSize
            }
            scores = Dictionary(
                rows.compactMap { row -> (String, Score)? in
                    let key = Self.serviceKey(for: row.serviceName)
                    return key.isEmpty ? nil : (key, row)
                },
                uniquingKeysWith: { a, b in
                    let total = a.ratingCount + b.ratingCount
                    let weighted = total > 0
                        ? ((a.avgDifficulty * Double(a.ratingCount)) + (b.avgDifficulty * Double(b.ratingCount))) / Double(total)
                        : a.avgDifficulty
                    return Score(serviceName: a.serviceName, ratingCount: total, avgDifficulty: (weighted * 10).rounded() / 10)
                }
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

    private static let ratedKeysStorage = "rated_cancel_difficulty_keys"

    /// True when the signed-in customer can submit a rating for this service (never in guest mode,
    /// never for Pausely itself, never for unkeyable names, and at most once per service on this device).
    func canRate(serviceName: String) -> Bool {
        guard AuthManager.shared.isSignedIntoCloud, SubscriptionStore.cloudSyncEnabled else { return false }
        guard serviceName.caseInsensitiveCompare(PaymentManager.ownName) != .orderedSame else { return false }
        let key = Self.serviceKey(for: serviceName)
        guard !key.isEmpty else { return false }
        let rated = Set(UserDefaults.standard.stringArray(forKey: Self.ratedKeysStorage) ?? [])
        return !rated.contains(key)
    }

    private func markRatedLocally(_ key: String) {
        var rated = Set(UserDefaults.standard.stringArray(forKey: Self.ratedKeysStorage) ?? [])
        rated.insert(key)
        UserDefaults.standard.set(Array(rated), forKey: Self.ratedKeysStorage)
    }

    /// Submits an anonymous 1 (easy) to 5 (hard) cancellation difficulty rating.
    /// Returns true only when recorded (or already recorded on another device) so the UI never claims success offline or loops forever on 409.
    @discardableResult
    func submit(serviceName: String, difficulty: Int) async -> Bool {
        let clamped = max(1, min(5, difficulty))
        guard SubscriptionStore.cloudSyncEnabled, AuthManager.shared.isSignedIntoCloud else { return false }
        let client = SupabaseManager.shared.client
        guard client.auth.currentSession != nil else { return false }

        let key = Self.serviceKey(for: serviceName)
        guard !key.isEmpty else { return false }
        do {
            let session = try await client.auth.session
            guard !session.isExpired else { return false }
            let payload = RatingInsert(
                user_id: session.user.id,
                service_name: key,
                difficulty_rating: clamped
            )
            _ = try await client
                .from("cancel_difficulty_ratings")
                .insert(payload)
                .execute()
            markRatedLocally(key)
            return true
        } catch {
            let desc = String(describing: error).lowercased()
            if desc.contains("23505") || desc.contains("duplicate key") || desc.contains("409") {
                markRatedLocally(key)
                return true
            }
            os_log("CancelDifficultyService submit failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
            return false
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
