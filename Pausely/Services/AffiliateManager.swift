import Foundation
import SwiftUI
import Supabase
import os.log

// MARK: - Affiliate Manager

/// Previously managed influencer/affiliate attribution and revenue sharing.
/// Now disabled — kept for compilation compatibility.
@MainActor
class AffiliateManager: ObservableObject {
    static let shared = AffiliateManager()

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUserAffiliateCode: String? {
        didSet {
            UserDefaults.standard.set(currentUserAffiliateCode, forKey: Self.userAffiliateCodeKey)
        }
    }

    static let userAffiliateCodeKey = "user_affiliate_code"
    static let userAttributedAtKey = "user_attributed_at"

    private var client: SupabaseClient { SupabaseManager.shared.client }

    private init() {
        self.currentUserAffiliateCode = UserDefaults.standard.string(forKey: Self.userAffiliateCodeKey)
    }

    func syncAffiliateAttributionFromServer(userId: String) async {
        // Affiliate system disabled
    }

    func checkWaitlistAttribution(email: String) async -> String? {
        // Affiliate system disabled
        return nil
    }

    func applyAffiliateAttribution(userId: String, email: String) async {
        // Affiliate system disabled
    }

    func recordCommission(userId: String, revenueAmount: Decimal, conversionType: String) async {
        // Affiliate system disabled
    }

    func recordCommissionForTier(userId: String, tier: SubscriptionTier) async {
        // Affiliate system disabled
    }
}
