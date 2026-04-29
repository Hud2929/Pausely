import Foundation

// MARK: - Price Increase Monitor
/// Tracks subscription price changes and generates alerts for increases.
@MainActor
final class PriceIncreaseMonitor: ObservableObject {
    static let shared = PriceIncreaseMonitor()

    @Published var alerts: [PriceAlert] = []

    struct PriceAlert: Identifiable {
        let id = UUID()
        let subscriptionName: String
        let oldPrice: Decimal
        let newPrice: Decimal
        let currency: String
        let percentageIncrease: Double

        var formattedIncrease: String {
            let diff = newPrice - oldPrice
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            formatter.maximumFractionDigits = 2
            return formatter.string(from: diff as NSDecimalNumber) ?? "+\(diff)"
        }
    }

    private let priceHistoryKey = "subscription_price_history"

    private init() {}

    /// Call this after subscriptions are loaded to detect any price changes.
    func checkForPriceChanges(subscriptions: [Subscription]) {
        var history = loadPriceHistory()
        var newAlerts: [PriceAlert] = []

        for sub in subscriptions where sub.status == .active {
            let key = sub.id.uuidString
            if let previous = history[key] {
                if sub.amount > previous && previous > 0 {
                    let increase = Double(truncating: (sub.amount - previous) as NSDecimalNumber)
                    let percentage = (increase / Double(truncating: previous as NSDecimalNumber)) * 100
                    newAlerts.append(PriceAlert(
                        subscriptionName: sub.name,
                        oldPrice: previous,
                        newPrice: sub.amount,
                        currency: sub.currency,
                        percentageIncrease: percentage
                    ))
                }
            }
            history[key] = sub.amount
        }

        savePriceHistory(history)
        alerts = newAlerts
    }

    func dismissAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
    }

    func dismissAll() {
        alerts.removeAll()
    }

    private func loadPriceHistory() -> [String: Decimal] {
        guard let data = UserDefaults.standard.data(forKey: priceHistoryKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded.compactMapValues { Decimal(string: $0) }
    }

    private func savePriceHistory(_ history: [String: Decimal]) {
        let encoded = history.mapValues { NSDecimalNumber(decimal: $0).stringValue }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: priceHistoryKey)
        }
    }
}
