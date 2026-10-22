import SwiftUI


// MARK: - Perk Engine
@MainActor
class PerkEngine: ObservableObject {
    static let shared = PerkEngine()
    
    @Published var discoveredPerks: [SmartPerk] = []
    @Published var activePerks: [ActivePerk] = []
    @Published var completedActions: [PerkAction] = []
    @Published var totalMoneySaved: Double = 0
    
    private init() { loadSavedData() }
    
    func analyzeSubscriptions(_ subscriptions: [Subscription]) {
        var newPerks: [SmartPerk] = []
        for subscription in subscriptions {
            newPerks.append(contentsOf: findPerks(for: subscription))
        }
        let activeIds = Set(activePerks.map { $0.sourceSubscriptionId })
        discoveredPerks = newPerks.filter { !activeIds.contains($0.sourceSubscriptionId) }
    }
    
    private func findPerks(for subscription: Subscription) -> [SmartPerk] {
        var perks: [SmartPerk] = []
        let name = subscription.name.lowercased()
        let monthlyCost = Double(truncating: subscription.amount as NSNumber)
        
        if name.contains("netflix") || name.contains("hulu") || name.contains("disney") {
            perks.append(SmartPerk(
                id: "\(subscription.id)-amex",
                title: "Amex: Streaming Credit",
                description: "Get $20/month credit for streaming",
                sourceSubscriptionId: subscription.id,
                sourceName: subscription.name,
                estimatedSavings: 240,
                difficulty: .easy,
                steps: ["Open Amex app", "Go to Benefits", "Link subscription"],
                provider: "American Express",
                icon: "creditcard.fill",
                color: "gold"
            ))
        }
        
        if monthlyCost > 5 {
            perks.append(SmartPerk(
                id: "\(subscription.id)-student",
                title: "Switch to Student Plan",
                description: "Save 50% with student verification",
                sourceSubscriptionId: subscription.id,
                sourceName: subscription.name,
                estimatedSavings: monthlyCost * 6,
                difficulty: .medium,
                steps: ["Go to settings", "Select Student Plan", "Verify email"],
                provider: subscription.name,
                icon: "graduationcap.fill",
                color: "blue"
            ))
        }
        
        if subscription.billingFrequency == .monthly && monthlyCost > 10 {
            perks.append(SmartPerk(
                id: "\(subscription.id)-annual",
                title: "Switch to Annual",
                description: "Save ~17% paying yearly",
                sourceSubscriptionId: subscription.id,
                sourceName: subscription.name,
                estimatedSavings: monthlyCost * 2,
                difficulty: .easy,
                steps: ["Go to Billing", "Select Annual", "Confirm"],
                provider: subscription.name,
                icon: "calendar.badge.clock",
                color: "green"
            ))
        }
        
        return perks
    }
    
    func activatePerk(_ perk: SmartPerk) {
        let active = ActivePerk(
            id: UUID(),
            perkId: perk.id,
            title: perk.title,
            sourceSubscriptionId: perk.sourceSubscriptionId,
            sourceName: perk.sourceName,
            estimatedAnnualSavings: perk.estimatedSavings,
            activatedDate: Date(),
            icon: perk.icon,
            color: perk.color
        )
        activePerks.append(active)
        discoveredPerks.removeAll { $0.id == perk.id }
        completeAction(title: "Activated: \(perk.title)", moneySaved: perk.estimatedSavings)
        saveData()
    }
    
    func completeAction(title: String, moneySaved: Double) {
        let action = PerkAction(id: UUID(), title: title, date: Date(), moneySaved: moneySaved)
        completedActions.insert(action, at: 0)
        totalMoneySaved += moneySaved
        saveData()
    }
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(activePerks) {
            AppSettings.shared.activePerks = encoded
        }
        if let encoded = try? JSONEncoder().encode(completedActions) {
            AppSettings.shared.completedActions = encoded
        }
        AppSettings.shared.totalMoneySaved = totalMoneySaved
    }

    private func loadSavedData() {
        let perksData = AppSettings.shared.activePerks
        if !perksData.isEmpty,
           let decoded = try? JSONDecoder().decode([ActivePerk].self, from: perksData) {
            activePerks = decoded
        }
        let actionsData = AppSettings.shared.completedActions
        if !actionsData.isEmpty,
           let decoded = try? JSONDecoder().decode([PerkAction].self, from: actionsData) {
            completedActions = decoded
        }
        totalMoneySaved = AppSettings.shared.totalMoneySaved
    }
}

// MARK: - Models
struct SmartPerk: Identifiable {
    let id: String
    let title: String
    let description: String
    let sourceSubscriptionId: UUID
    let sourceName: String
    let estimatedSavings: Double
    let difficulty: Difficulty
    let steps: [String]
    let provider: String
    let icon: String
    let color: String
    
    enum Difficulty: String { case easy = "Easy", medium = "Medium", hard = "Hard" }
}

struct ActivePerk: Identifiable, Codable {
    let id: UUID
    let perkId: String
    let title: String
    let sourceSubscriptionId: UUID
    let sourceName: String
    let estimatedAnnualSavings: Double
    let activatedDate: Date
    let icon: String
    let color: String
}

struct PerkAction: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
    let moneySaved: Double
}


