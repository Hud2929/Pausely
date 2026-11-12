#if DEBUG
import Foundation

/// DEBUG only: sample data for opening screens directly with launch arguments such as
/// `--demo-subscription` and `--demo-subscription-edit`. Compiled out of release builds.
enum DemoSubscriptions {
    static var netflix: Subscription {
        var sub = Subscription(name: "Netflix", price: 15.49, category: "Entertainment", billingFrequency: .monthly)
        sub.currency = "USD"
        sub.nextBillingDate = Calendar.billing.date(byAdding: .day, value: 9, to: Date())
        sub.notifyBeforeDays = 3
        return sub
    }

    /// `--quiet-demo-data`: one yearly subscription that renews five months from now, so Home's
    /// "Nothing is due in the next month." can be opened and looked at.
    static func quiet(now: Date = Date(), currency home: String = CurrencyManager.shared.selectedCurrency) -> [Subscription] {
        [Subscription(name: "Duolingo", category: SubscriptionCategory.education.displayName,
                      amount: Decimal(string: "59.99")!, currency: home, billingFrequency: .yearly,
                      nextBillingDate: Calendar.billing.date(byAdding: .month, value: 5, to: now))]
    }

    /// `--varied-demo-data`: a list with one of everything a list can hold, so every row and state
    /// that depends on what is in the list can be opened and looked at. The plain demo list is seven
    /// monthly subscriptions in one currency, which leaves most of those states unseen.
    ///
    /// What is in it: a charge tomorrow and one waiting for a decision; a free trial about to charge;
    /// one with no renewal date; one in another currency, yearly; a quarterly one; a cancelled one;
    /// four video services (Pause Plan); more than eight entries (the search field) and more than six
    /// charges inside thirty days ("and N more").
    static func varied(now: Date = Date(), currency home: String = CurrencyManager.shared.selectedCurrency) -> [Subscription] {
        let calendar = Calendar.billing
        func inDays(_ days: Int) -> Date? { calendar.date(byAdding: .day, value: days, to: now) }
        func monthly(_ name: String, _ category: SubscriptionCategory, _ amount: Decimal, in days: Int?) -> Subscription {
            Subscription(name: name, category: category.displayName, amount: amount, currency: home,
                         billingFrequency: .monthly, nextBillingDate: days.flatMap(inDays))
        }
        let abroad = home == "EUR" ? "GBP" : "EUR"
        return [
            monthly("iCloud+", .cloudStorage, Decimal(string: "2.99")!, in: 1),
            monthly("Apple One", .productivity, Decimal(string: "32.95")!, in: 2),
            Subscription(name: "Disney+", category: SubscriptionCategory.entertainment.displayName,
                         amount: Decimal(string: "7.99")!, currency: home, billingFrequency: .monthly,
                         nextBillingDate: inDays(3), trialEndsAt: inDays(3), status: .trial),
            monthly("Netflix", .entertainment, Decimal(string: "15.99")!, in: 5),
            monthly("Notion", .productivity, 10, in: 8),
            monthly("Spotify", .music, Decimal(string: "10.99")!, in: 12),
            monthly("Peloton", .healthFitness, 44, in: 15),
            monthly("ChatGPT Plus", .aiTools, 20, in: 18),
            Subscription(name: "Audible", category: SubscriptionCategory.entertainment.displayName,
                         amount: Decimal(string: "44.85")!, currency: home, billingFrequency: .quarterly,
                         nextBillingDate: inDays(20)),
            monthly("YouTube Premium", .entertainment, Decimal(string: "13.99")!, in: 24),
            monthly("Max", .entertainment, Decimal(string: "9.99")!, in: 27),
            Subscription(name: "Duolingo", category: SubscriptionCategory.education.displayName,
                         amount: Decimal(string: "59.99")!, currency: abroad, billingFrequency: .yearly,
                         nextBillingDate: inDays(40)),
            monthly("Adobe Creative Cloud", .productivity, Decimal(string: "54.99")!, in: nil),
            Subscription(name: "Hulu", category: SubscriptionCategory.entertainment.displayName,
                         amount: Decimal(string: "18.99")!, currency: home, billingFrequency: .monthly,
                         nextBillingDate: inDays(-9), status: .cancelled),
        ]
    }

    /// The history that goes with `varied`: Spotify went up three months ago, Hulu was cancelled
    /// twenty days ago (so the charge nine days ago is one it avoided), Max was cancelled and then
    /// started again (the receipt says where its savings stop), and Netflix was watched for a couple
    /// of hours this month.
    static func variedEvents(for list: [Subscription], now: Date = Date()) -> [LifecycleEvent] {
        let calendar = Calendar.billing
        func ago(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now) ?? now }
        var events: [LifecycleEvent] = []
        if let spotify = list.first(where: { $0.name == "Spotify" }) {
            events.append(LifecycleEvent(kind: .priceChanged, subscription: spotify,
                                         date: calendar.date(byAdding: .month, value: -3, to: now) ?? now,
                                         previousAmount: spotify.amount - 1, renewalDate: nil))
        }
        if let max = list.first(where: { $0.name == "Max" }) {
            // As it was when it was cancelled: its next charge was five days away.
            var then = max
            then.nextBillingDate = ago(75)
            events.append(LifecycleEvent(kind: .cancelled, subscription: then, date: ago(80), previousAmount: nil, renewalDate: ago(75)))
            events.append(LifecycleEvent(kind: .reactivated, subscription: max, date: ago(40), previousAmount: nil, renewalDate: nil))
        }
        if let hulu = list.first(where: { $0.name == "Hulu" }) {
            events.append(LifecycleEvent(kind: .cancelled, subscription: hulu, date: ago(20), previousAmount: nil,
                                         renewalDate: hulu.nextBillingDate))
        }
        return events
    }

    @MainActor
    static func seedVariedHistory(for list: [Subscription], now: Date = Date()) {
        LifecycleEventLog.shared.restore(variedEvents(for: list, now: now))
        if let netflix = list.first(where: { $0.name == "Netflix" }) {
            UsageLog.shared.setMonthlyUsage(minutes: 140, for: netflix.name)
        }
    }
}
#endif
