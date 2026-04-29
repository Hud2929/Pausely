import Foundation

// MARK: - Family Plan Detector
/// Detects subscriptions that offer family/multi-user plans and suggests splitting.
@MainActor
final class FamilyPlanDetector: ObservableObject {
    static let shared = FamilyPlanDetector()

    private init() {}

    struct FamilyPlanSuggestion: Identifiable {
        let id = UUID()
        let subscriptionName: String
        let currentPlan: String
        let currentPrice: Decimal
        let familyPlanName: String
        let familyPlanPrice: Decimal
        let maxUsers: Int
        let savingsPerMonth: Decimal
        let perPersonCost: Decimal
    }

    /// Known family plan mappings: service name pattern -> (family plan name, price, max users)
    private let knownFamilyPlans: [(pattern: String, familyName: String, price: Decimal, users: Int)] = [
        ("spotify", "Spotify Family", Decimal(16.99), 6),
        ("apple music", "Apple Music Family", Decimal(16.99), 6),
        ("apple one", "Apple One Family", Decimal(25.95), 5),
        ("youtube premium", "YouTube Premium Family", Decimal(22.99), 6),
        ("netflix", "Netflix Standard", Decimal(15.49), 2),
        ("disney\\+", "Disney+ Bundle", Decimal(14.99), 4),
        ("hulu", "Hulu + Live TV", Decimal(76.99), 2),
        ("adobe creative", "Adobe Creative Cloud", Decimal(54.99), 2),
        ("microsoft 365", "Microsoft 365 Family", Decimal(9.99), 6),
        ("google one", "Google One 2TB", Decimal(9.99), 5),
        ("dropbox", "Dropbox Family", Decimal(19.99), 6),
        ("notion", "Notion Team", Decimal(10.00), 10),
        ("1password", "1Password Families", Decimal(4.99), 5),
        ("dashlane", "Dashlane Family", Decimal(7.49), 6),
        ("nordvpn", "NordVPN Plus", Decimal(13.99), 6),
        ("expressvpn", "ExpressVPN", Decimal(12.95), 5),
    ]

    func detectFamilyPlanOpportunities(in subscriptions: [Subscription]) -> [FamilyPlanSuggestion] {
        var suggestions: [FamilyPlanSuggestion] = []

        for sub in subscriptions where sub.status == .active {
            let lowerName = sub.name.lowercased()

            for plan in knownFamilyPlans {
                guard lowerName.contains(plan.pattern),
                      !lowerName.contains("family"),
                      !lowerName.contains("team"),
                      !lowerName.contains("bundle") else {
                    continue
                }

                let savings = sub.monthlyCost - plan.price
                guard savings > 0 else { continue }

                let perPerson = plan.price / Decimal(plan.users)

                suggestions.append(FamilyPlanSuggestion(
                    subscriptionName: sub.name,
                    currentPlan: sub.name,
                    currentPrice: sub.monthlyCost,
                    familyPlanName: plan.familyName,
                    familyPlanPrice: plan.price,
                    maxUsers: plan.users,
                    savingsPerMonth: savings,
                    perPersonCost: perPerson
                ))
            }
        }

        return suggestions.sorted { $0.savingsPerMonth > $1.savingsPerMonth }
    }
}
