import Foundation

/// The paywall's argument, made from the person's own list: what their subscriptions cost, and how
/// little of that Pausely Pro is. Pure, so the numbers on the paywall are tested.
enum PaywallCase {
    /// What the paywall can say about prices. They are the App Store's: until it has answered there
    /// are none, and the page prints no sentence with a hole in it ("Pausely Pro is … a year.").
    enum Prices: Equatable {
        case known
        /// Asked for and not yet answered.
        case loading
        /// The App Store did not answer: no prices, no plans to pick, and a way to ask again.
        case unavailable
    }

    static func prices(loaded: Bool, isLoading: Bool) -> Prices {
        if loaded { return .known }
        return isLoading ? .loading : .unavailable
    }

    struct Comparison: Equatable {
        /// The person's most expensive subscription.
        let name: String
        /// A year of Pro costs less than this many months of it.
        let months: Int
    }

    /// Compares a year of Pro with the person's most expensive active subscription. Nil when there
    /// is nothing to compare with, when a currency can't be converted (no guessing), or when Pro
    /// would cost more than six months of it (not an argument worth making).
    static func comparison(proYearly: Decimal, proCurrency: String,
                           subscriptions: [Subscription], rates: CurrencyRates) -> Comparison? {
        guard proYearly > 0 else { return nil }
        let candidates: [(name: String, monthly: Decimal)] = subscriptions.compactMap { subscription in
            guard subscription.renewsAutomatically,
                  let monthly = rates.convert(subscription.monthlyCost, from: subscription.currency, to: proCurrency),
                  monthly > 0 else { return nil }
            return (subscription.name, monthly)
        }
        guard let top = candidates.max(by: { $0.monthly < $1.monthly }) else { return nil }
        // The smallest whole number of months that costs more than a year of Pro.
        var ratio = proYearly / top.monthly, floor = Decimal()
        NSDecimalRound(&floor, &ratio, 0, .down)
        let months = NSDecimalNumber(decimal: floor).intValue + 1
        return months <= 6 ? Comparison(name: top.name, months: months) : nil
    }
}
