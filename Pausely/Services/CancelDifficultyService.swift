//
//  CancelDifficultyService.swift
//  Pausely
//
//  Submits and fetches crowd-sourced cancel difficulty ratings from Supabase.
//

import Foundation

@MainActor
final class CancelDifficultyService: ObservableObject {
    static let shared = CancelDifficultyService()

    // Local cache: serviceName -> (avgScore, ratingCount, fetchedAt)
    private var cache: [String: (score: Double, count: Int, date: Date)] = [:]

    private init() {}

    // MARK: - Submit Rating

    func submitRating(serviceName: String, rating: Int) async {
        guard (1...5).contains(rating) else { return }
        guard !SupabaseManager.shared.isUsingDemoMode else { return }

        struct RatingInsert: Encodable {
            let service_name: String
            let difficulty_rating: Int
            let user_id: String?
        }

        let userId = try? await SupabaseManager.shared.client.auth.session.user.id.uuidString
        let payload = RatingInsert(
            service_name: serviceName,
            difficulty_rating: rating,
            user_id: userId
        )

        do {
            try await SupabaseManager.shared.client
                .from("cancel_difficulty_ratings")
                .insert(payload)
                .execute()
            // Invalidate cache so next fetch gets updated score
            cache.removeValue(forKey: serviceName)
        } catch {
            // Non-critical — silently discard
        }
    }

    // MARK: - Fetch Score
}
