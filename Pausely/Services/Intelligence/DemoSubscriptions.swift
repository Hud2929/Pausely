#if DEBUG
import Foundation

/// DEBUG only: sample data for opening screens directly with launch arguments such as
/// `--demo-subscription` and `--demo-subscription-edit`. Compiled out of release builds.
enum DemoSubscriptions {
    static var netflix: Subscription {
        var sub = Subscription(name: "Netflix", price: 16.49, category: "Entertainment", billingFrequency: .monthly)
        sub.currency = "CAD"
        sub.nextBillingDate = Calendar.current.date(byAdding: .day, value: 9, to: Date())
        sub.notifyBeforeDays = 3
        return sub
    }
}
#endif
