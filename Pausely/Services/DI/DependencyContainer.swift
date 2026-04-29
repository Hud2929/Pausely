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

    /// Testing container
    @MainActor
    static func forTesting(
        authService: RevolutionaryAuthManager = RevolutionaryAuthManager.shared,
        subscriptionDataService: SubscriptionStore = SubscriptionStore.shared,
        paymentService: PaymentManager = PaymentManager.shared,
        currencyService: CurrencyManager = CurrencyManager.shared,
        referralService: ReferralManager = ReferralManager.shared,
        screenTimeService: ScreenTimeManager = ScreenTimeManager.shared
    ) -> DependencyContainer {
        DependencyContainer(
            authService: authService,
            subscriptionDataService: subscriptionDataService,
            paymentService: paymentService,
            currencyService: currencyService,
            referralService: referralService,
            screenTimeService: screenTimeService
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
