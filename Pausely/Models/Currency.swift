//
//  Currency.swift
//  Pausely
//
//  Currency model supporting 150+ world currencies
//

import Foundation
import SwiftUI

// The Currency model and CurrencyManager live in SupabaseManager.swift; formatting, conversion and
// totals live in Core/Money (MoneyFormat, CurrencyRates, MoneyMath).

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
    
}

// MARK: - Currency Trend


// MARK: - Helper Extensions

extension Double {
}

// MARK: - Sample Data
