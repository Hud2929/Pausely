import Foundation
import SwiftUI

// MARK: - Dependency Container

@MainActor
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    var authService: RevolutionaryAuthManager
    var subscriptionDataService: SubscriptionStore
    var paymentService: PaymentManager
    var currencyService: CurrencyManager
    var referralService: ReferralManager
    var screenTimeService: ScreenTimeManager

    private init(
        authService: RevolutionaryAuthManager,
        subscriptionDataService: SubscriptionStore,
        paymentService: PaymentManager,
        currencyService: CurrencyManager,
        referralService: ReferralManager,
        screenTimeService: ScreenTimeManager
    ) {
        self.authService = authService
        self.subscriptionDataService = subscriptionDataService
        self.paymentService = paymentService
        self.currencyService = currencyService
        self.referralService = referralService
        self.screenTimeService = screenTimeService
    }

    /// Production container wiring real singletons
    @MainActor
    convenience init() {
        self.init(
            authService: RevolutionaryAuthManager.shared,
            subscriptionDataService: SubscriptionStore.shared,
            paymentService: PaymentManager.shared,
            currencyService: CurrencyManager.shared,
            referralService: ReferralManager.shared,
            screenTimeService: ScreenTimeManager.shared
        )
    }

    /// Testing container — pass nil for any dependency to use the real singleton.
    @MainActor
    static func forTesting(
        authService: RevolutionaryAuthManager? = nil,
        subscriptionDataService: SubscriptionStore? = nil,
        paymentService: PaymentManager? = nil,
        currencyService: CurrencyManager? = nil,
        referralService: ReferralManager? = nil,
        screenTimeService: ScreenTimeManager? = nil
    ) -> DependencyContainer {
        DependencyContainer(
            authService: authService ?? RevolutionaryAuthManager.shared,
            subscriptionDataService: subscriptionDataService ?? SubscriptionStore.shared,
            paymentService: paymentService ?? PaymentManager.shared,
            currencyService: currencyService ?? CurrencyManager.shared,
            referralService: referralService ?? ReferralManager.shared,
            screenTimeService: screenTimeService ?? ScreenTimeManager.shared
        )
    }
}

// MARK: - Environment Key

private struct DIKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var di: DependencyContainer {
        get { self[DIKey.self] }
        set { self[DIKey.self] = newValue }
    }
}
