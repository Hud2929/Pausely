//
//  Currency.swift
//  Pausely
//
//  Currency model supporting 150+ world currencies
//

import Foundation
import SwiftUI

// Note: The main Currency model is in CurrencyManager.swift
// This file contains additional currency-related models and extensions

// MARK: - Currency Converter Helper
struct CurrencyConverter {
    static func format(amount: Double, currencyCode: String) -> String {
        guard let currency = CurrencyManager.shared.currency(for: currencyCode) else {
            return "\(currencyCode) \(String(format: "%.2f", amount))"
        }
        return currency.format(amount)
    }
}

// MARK: - Currency Amount

/// Represents an amount in a specific currency
struct CurrencyAmount: Codable, Identifiable, Equatable {
    let id = UUID()
    var amount: Double
    var currencyCode: String
    
    enum CodingKeys: String, CodingKey {
        case amount, currencyCode
    }
    
    /// The currency object for this amount
    var currency: Currency? {
        CurrencyManager.shared.currency(for: currencyCode)
    }
    
    /// Formatted string representation
    var formatted: String {
        CurrencyConverter.format(amount: amount, currencyCode: currencyCode)
    }
    
    /// Converts this amount to another currency
    func converted(to targetCode: String) -> CurrencyAmount? {
        guard let convertedAmount = try? CurrencyManager.shared.convert(
            amount,
            from: currencyCode,
            to: targetCode
        ) else {
            return nil
        }
        return CurrencyAmount(amount: convertedAmount, currencyCode: targetCode)
    }
    
    /// Converts to user's selected currency
    var inUserCurrency: CurrencyAmount {
        let targetCode = CurrencyManager.shared.currentCurrency.code
        return converted(to: targetCode) ?? self
    }
    
    static func == (lhs: CurrencyAmount, rhs: CurrencyAmount) -> Bool {
        lhs.amount == rhs.amount && lhs.currencyCode == rhs.currencyCode
    }
}

// MARK: - Currency Preference


// MARK: - Currency Region


// MARK: - Historical Rate

/// Represents a historical exchange rate data point
struct HistoricalRate: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
    
    /// Calculates rate change from previous data point
    func change(from previous: HistoricalRate?) -> Double? {
        guard let previous = previous else { return nil }
        return ((rate - previous.rate) / previous.rate) * 100
    }
    
    /// Formatted change string with arrow
    func formattedChange(from previous: HistoricalRate?) -> String? {
        guard let change = change(from: previous) else { return nil }
        let arrow = change >= 0 ? "↑" : "↓"
        return String(format: "%@ %.2f%%", arrow, abs(change))
    }
}

// MARK: - Currency Trend


// MARK: - Helper Extensions

extension Double {
    /// Rounds to specified decimal places for currency
    func roundedToCurrency(decimals: Int = 2) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (self * multiplier).rounded() / multiplier
    }
}

// MARK: - Sample Data


// MARK: - Subscription Currency Extension

extension Subscription {
    /// The currency object for this subscription
    var currencyObject: Currency? {
        CurrencyManager.shared.currency(for: currency)
    }
    
    /// Amount as CurrencyAmount
    var currencyAmount: CurrencyAmount {
        CurrencyAmount(amount: Double(truncating: amount as NSNumber), currencyCode: currency)
    }
    
    /// Amount converted to user's preferred currency
    var convertedAmount: CurrencyAmount {
        currencyAmount.inUserCurrency
    }
    
    /// Monthly cost in user's preferred currency
    var monthlyCostInUserCurrency: Double {
        let manager = CurrencyManager.shared
        let monthlyAmount = Double(truncating: monthlyCost as NSNumber)
        return (try? manager.convert(monthlyAmount, from: currency, to: manager.selectedCurrency)) ?? monthlyAmount
    }
    
    /// Yearly cost in user's preferred currency
    var yearlyCostInUserCurrency: Double {
        let manager = CurrencyManager.shared
        let yearlyAmount = Double(truncating: annualCost as NSNumber)
        return (try? manager.convert(yearlyAmount, from: currency, to: manager.selectedCurrency)) ?? yearlyAmount
    }
    
    
}
