import Foundation
import XCTest
@testable import Pausely

// MARK: - Mock Data Factories

enum TestFactories {

    static func makeSubscription(
        id: UUID = UUID(),
        name: String = "Netflix",
        amount: Decimal = 15.49,
        currency: String = "USD",
        billingFrequency: BillingFrequency = .monthly,
        status: SubscriptionStatus = .active,
        nextBillingDate: Date? = nil,
        monthlyUsageMinutes: Int = 120,
        category: String = "Entertainment",
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        userPriceUSD: Decimal? = nil,
        isPriceOverridden: Bool = false,
        canPause: Bool = true,
        pausedUntil: Date? = nil
    ) -> Subscription {
        Subscription(
            id: id,
            name: name,
            category: category,
            amount: amount,
            currency: currency,
            billingFrequency: billingFrequency,
            nextBillingDate: nextBillingDate,
            monthlyUsageMinutes: monthlyUsageMinutes,
            status: status,
            canPause: canPause,
            pausedUntil: pausedUntil,
            createdAt: createdAt,
            updatedAt: createdAt,
            userPriceUSD: userPriceUSD,
            isPriceOverridden: isPriceOverridden
        )
    }


}

// MARK: - Async Test Helpers

extension XCTestCase {


}

// MARK: - Date Helpers

enum TestDates {
    static var calendar: Calendar { Calendar.current }

    static func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func addMonths(_ months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }
}

// MARK: - Currency Test Helpers

enum CurrencyTestHelpers {
    static func withRates(_ rates: [String: Double], body: () -> Void) {
        let manager = CurrencyManager.shared
        let originalRates = manager.exchangeRates
        manager.exchangeRates = rates
        body()
        manager.exchangeRates = originalRates
    }
}
