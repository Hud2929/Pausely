//
//  PriceHistoryTracker.swift
//  Pausely
//
//  Track subscription price changes over time and alert users to increases
//

import Foundation
import os.log

struct PriceHistoryEntry: Codable, Identifiable {
    let id: UUID
    let subscriptionId: UUID
    let amount: Decimal
    let currency: String
    let billingFrequency: BillingFrequency
    let date: Date
    let source: PriceChangeSource

    init(subscriptionId: UUID, amount: Decimal, currency: String, billingFrequency: BillingFrequency, source: PriceChangeSource = .userEdit) {
        self.id = UUID()
        self.subscriptionId = subscriptionId
        self.amount = amount
        self.currency = currency
        self.billingFrequency = billingFrequency
        self.date = Date()
        self.source = source
    }
}

enum PriceChangeSource: String, Codable {
    case userEdit = "user_edit"
    case autoDetected = "auto_detected"
    case importData = "import"
    case manualLog = "manual_log"
}

struct PriceChangeAlert: Identifiable {
    let id = UUID()
    let subscriptionName: String
    let oldAmount: Decimal
    let newAmount: Decimal
    let currency: String
    let percentageChange: Double
    let date: Date

    var isIncrease: Bool { newAmount > oldAmount }
    var formattedChange: String {
        let sign = isIncrease ? "+" : ""
        return "\(sign)\(String(format: "%.1f", percentageChange))%"
    }
}

@MainActor
final class PriceHistoryTracker: ObservableObject {
    static let shared = PriceHistoryTracker()

    @Published var priceHistory: [PriceHistoryEntry] = []
    @Published var recentAlerts: [PriceChangeAlert] = []

    private let storageKey = "subscription_price_history"

    private init() {
        loadHistory()
    }

    // MARK: - Recording

    func recordPrice(_ subscription: Subscription, source: PriceChangeSource = .userEdit) {
        let entry = PriceHistoryEntry(
            subscriptionId: subscription.id,
            amount: subscription.amount,
            currency: subscription.currency,
            billingFrequency: subscription.billingFrequency,
            source: source
        )
        priceHistory.append(entry)
        saveHistory()
    }

    func recordPriceIfChanged(_ subscription: Subscription) {
        let history = history(for: subscription.id)
        guard let lastEntry = history.last else {
            // First time tracking this subscription
            recordPrice(subscription, source: .importData)
            return
        }

        if lastEntry.amount != subscription.amount || lastEntry.billingFrequency != subscription.billingFrequency {
            recordPrice(subscription, source: .userEdit)

            let change = calculateChange(old: lastEntry, new: subscription)
            if abs(change) >= 1.0 { // Alert on 1%+ changes
                let alert = PriceChangeAlert(
                    subscriptionName: subscription.name,
                    oldAmount: lastEntry.amount,
                    newAmount: subscription.amount,
                    currency: subscription.currency,
                    percentageChange: change,
                    date: Date()
                )
                recentAlerts.insert(alert, at: 0)

                // Trim to last 20 alerts
                if recentAlerts.count > 20 {
                    recentAlerts = Array(recentAlerts.prefix(20))
                }
            }
        }
    }

    // MARK: - Queries

    func history(for subscriptionId: UUID) -> [PriceHistoryEntry] {
        priceHistory
            .filter { $0.subscriptionId == subscriptionId }
            .sorted { $0.date < $1.date }
    }

    func priceTrend(for subscriptionId: UUID) -> PriceTrend {
        let history = history(for: subscriptionId)
        guard history.count >= 2 else { return .stable }

        guard let first = history.first?.amount, let last = history.last?.amount else { return .stable }

        if last > first { return .increasing }
        if last < first { return .decreasing }
        return .stable
    }

    func totalPriceIncrease(for subscriptionId: UUID) -> Decimal {
        let history = history(for: subscriptionId)
        guard let first = history.first, let last = history.last else { return 0 }
        return last.amount - first.amount
    }

    func percentageIncrease(for subscriptionId: UUID) -> Double {
        let history = history(for: subscriptionId)
        guard let first = history.first else { return 0 }
        let firstAmount = Double(truncating: first.amount as NSDecimalNumber)
        let total = Double(truncating: totalPriceIncrease(for: subscriptionId) as NSDecimalNumber)
        guard firstAmount > 0 else { return 0 }
        return (total / firstAmount) * 100
    }

    func averageAnnualIncrease(for subscriptionId: UUID) -> Double {
        let history = history(for: subscriptionId)
        guard history.count >= 2 else { return 0 }
        guard let firstDate = history.first?.date, let lastDate = history.last?.date else { return 0 }

        let years = Calendar.current.dateComponents([.year], from: firstDate, to: lastDate).year ?? 0
        guard years > 0 else { return percentageIncrease(for: subscriptionId) }

        return percentageIncrease(for: subscriptionId) / Double(years)
    }

    func yearlySpentOnIncreases(for subscriptions: [Subscription]) -> Decimal {
        subscriptions.reduce(0) { total, sub in
            let increase = totalPriceIncrease(for: sub.id)
            return total + (increase * sub.billingFrequency.multiplierToYearly)
        }
    }

    // MARK: - Projections

    func projectedAnnualCost(for subscription: Subscription) -> Decimal {
        let history = history(for: subscription.id)
        guard history.count >= 2 else { return subscription.annualCost }

        let avgIncrease = averageAnnualIncrease(for: subscription.id)
        let currentAnnual = subscription.annualCost
        let multiplier = 1 + (Decimal(avgIncrease) / 100)
        return currentAnnual * multiplier
    }

    // MARK: - Private

    private func calculateChange(old: PriceHistoryEntry, new: Subscription) -> Double {
        let oldAmount = Double(truncating: old.amount as NSDecimalNumber)
        let newAmount = Double(truncating: new.amount as NSDecimalNumber)
        guard oldAmount > 0 else { return 0 }
        return ((newAmount - oldAmount) / oldAmount) * 100
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(priceHistory)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            os_log("Failed to save price history: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            priceHistory = try JSONDecoder().decode([PriceHistoryEntry].self, from: data)
        } catch {
            os_log("Failed to load price history: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
}

enum PriceTrend: String {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"

    var icon: String {
        switch self {
        case .increasing: return "arrow.up.forward"
        case .decreasing: return "arrow.down.forward"
        case .stable: return "minus"
        }
    }

    var color: String {
        switch self {
        case .increasing: return "red"
        case .decreasing: return "green"
        case .stable: return "gray"
        }
    }
}
