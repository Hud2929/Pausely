import Foundation
import Supabase

@MainActor
class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var totalMonthlySpend: Decimal = 0
    @Published var totalAnnualSpend: Decimal = 0
    @Published var isLoading = false
    @Published var error: Error?
    
    static let shared = SubscriptionStore()
    
    private init() {}
    
    func fetchSubscriptions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await SupabaseManager.shared.client
                .from("subscriptions")
                .select()
                .eq("status", value: "active")
                .order("amount", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            subscriptions = try decoder.decode([Subscription].self, from: response.data)
            
            calculateTotals()
        } catch {
            self.error = error
            print("Error fetching subscriptions: \(error)")
        }
    }
    
    func addSubscription(_ subscription: Subscription) async {
        do {
            try await SupabaseManager.shared.client
                .from("subscriptions")
                .insert(subscription)
                .execute()
            
            await fetchSubscriptions()
        } catch {
            self.error = error
        }
    }
    
    func updateSubscriptionStatus(id: UUID, status: SubscriptionStatus) async {
        do {
            try await SupabaseManager.shared.client
                .from("subscriptions")
                .update(["status": status.rawValue])
                .eq("id", value: id)
                .execute()
            
            await fetchSubscriptions()
        } catch {
            self.error = error
        }
    }
    
    func pauseSubscription(id: UUID, until date: Date) async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        do {
            try await SupabaseManager.shared.client
                .from("subscriptions")
                .update([
                    "status": SubscriptionStatus.paused.rawValue,
                    "paused_until": formatter.string(from: date)
                ])
                .eq("id", value: id)
                .execute()
            
            await fetchSubscriptions()
        } catch {
            self.error = error
        }
    }
    
    private func calculateTotals() {
        totalMonthlySpend = subscriptions
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.amount }
        
        totalAnnualSpend = subscriptions
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.annualCost }
    }
    
    // Get subscriptions sorted by cost per hour (worst value first)
    var worstValueSubscriptions: [Subscription] {
        subscriptions
            .filter { $0.costPerHour != nil }
            .sorted { ($0.costPerHour ?? 0) > ($1.costPerHour ?? 0) }
    }
    
    // Get subscriptions that can be paused
    var pausableSubscriptions: [Subscription] {
        subscriptions.filter { $0.canPause && $0.status == .active }
    }
    
    // Get high-value subscriptions (best ROI)
    var highValueSubscriptions: [Subscription] {
        subscriptions
            .filter { $0.roiScore != nil }
            .sorted { ($0.roiScore ?? 0) > ($1.roiScore ?? 0) }
            .prefix(5)
            .map { $0 }
    }
}
