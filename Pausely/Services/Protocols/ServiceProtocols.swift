import Foundation
import SwiftUI
import StoreKit

// MARK: - Auth Service Protocol

protocol AuthServiceProtocol: ObservableObject {
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }

    func signUp(email: String, password: String) async throws
    func signUpWithOTP(email: String, password: String) async throws
    func verifyEmailOTP(email: String, code: String) async throws
    func resendOTP(email: String) async throws
    func signIn(email: String, password: String) async throws
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws
    func signInWithMagicLink(email: String) async throws
    func signOut() async
    func sendPasswordReset(email: String) async throws
    func confirmPasswordReset(token: String, email: String, newPassword: String) async throws
    func checkSession() async
    func toggleBiometricAuthentication(enabled: Bool) async throws
}

// MARK: - Subscription Data Service Protocol

protocol SubscriptionDataServiceProtocol: ObservableObject {
    var subscriptions: [Subscription] { get }
    var isLoading: Bool { get }
    var error: Error? { get }

    func fetchSubscriptions(force: Bool) async
    func refresh() async
    func addSubscription(_ subscription: Subscription) async throws
    func updateSubscription(_ subscription: Subscription) async throws
    func deleteSubscription(id: UUID) async throws
    func updateSubscriptionStatus(id: UUID, status: SubscriptionStatus) async throws
    func pauseSubscription(id: UUID, until date: Date) async throws
    func resumeSubscription(id: UUID) async throws
    func processPendingSync() async
}

// MARK: - Payment Service Protocol

protocol PaymentServiceProtocol: ObservableObject {
    var isPro: Bool { get }
    var subscriptionTier: SubscriptionTier { get }

    func loadProducts() async
    func purchase(_ product: Product) async throws -> StoreKit.Transaction?
    func restorePurchases() async
    func canAddSubscription(currentCount: Int) -> Bool
    func hasReachedSubscriptionLimit(currentCount: Int) -> Bool
    func activatePremium(source: PaymentSource)
    func deactivatePremium()
}

// MARK: - Currency Service Protocol

protocol CurrencyServiceProtocol: ObservableObject {
    var selectedCurrency: String { get }
    var exchangeRates: [String: Decimal] { get }

    func format(_ amount: Decimal, currencyCode: String?) -> String
    func convert(_ amount: Decimal, from: String, to: String) -> Decimal
    func symbol(for currencyCode: String) -> String
}

// MARK: - Referral Service Protocol

protocol ReferralServiceProtocol: ObservableObject {
    var currentUserReferralCode: String? { get }
    var isLoading: Bool { get }
    var appliedReferralDiscount: Bool { get }

    func generateReferralCode(for userId: String) async throws -> String
    func validateReferralCode(_ code: String) async -> Bool
    func applyReferralCode(_ code: String, for userId: String, email: String?) async throws
    func markReferralDiscountAsUsed()
    func getDiscountedPrice(originalPrice: Decimal) -> Decimal
}

// MARK: - Screen Time Service Protocol

protocol ScreenTimeServiceProtocol: ObservableObject {
    var isAuthorized: Bool { get }
    var weeklyUsageMinutes: Int { get }

    func requestAuthorization() async throws
    func refreshUsage() async
}
