import SwiftUI

struct MainTabView: View {
    @StateObject private var subscriptionStore = SubscriptionStore.shared
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
            
            SubscriptionsListView()
                .tabItem {
                    Label("Subscriptions", systemImage: "list.bullet")
                }
            
            PerksView()
                .tabItem {
                    Label("Free Perks", systemImage: "gift.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .task {
            await subscriptionStore.fetchSubscriptions()
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @StateObject private var store = SubscriptionStore.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Total Spend Card
                    TotalSpendCard(
                        monthly: store.totalMonthlySpend,
                        annual: store.totalAnnualSpend
                    )
                    
                    // Insights Section
                    InsightsSection()
                    
                    // Quick Actions
                    QuickActionsSection()
                    
                    // Worst Value Subscriptions
                    if !store.worstValueSubscriptions.isEmpty {
                        WorstValueSection(subscriptions: store.worstValueSubscriptions)
                    }
                }
                .padding()
            }
            .navigationTitle("Pausely")
            .refreshable {
                await store.fetchSubscriptions()
            }
        }
    }
}

struct TotalSpendCard: View {
    let monthly: Decimal
    let annual: Decimal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Total Subscriptions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(monthly, format: .currency(code: "USD"))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yearly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(annual, format: .currency(code: "USD"))
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct InsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
            
            HStack(spacing: 12) {
                InsightCard(
                    icon: "pause.circle.fill",
                    title: "Pause subscriptions",
                    subtitle: "Save $50/mo",
                    color: .orange
                )
                
                InsightCard(
                    icon: "gift.fill",
                    title: "3 free perks",
                    subtitle: "Not activated",
                    color: .green
                )
            }
        }
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add",
                    color: .blue
                )
                
                QuickActionButton(
                    icon: "pause.circle.fill",
                    title: "Pause",
                    color: .orange
                )
                
                QuickActionButton(
                    icon: "arrow.up.arrow.down",
                    title: "Compare",
                    color: .purple
                )
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

struct WorstValueSection: View {
    let subscriptions: [Subscription]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Worst Value")
                .font(.headline)
            
            Text("These subscriptions cost the most per hour of use")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(subscriptions.prefix(3)) { subscription in
                SubscriptionRow(subscription: subscription)
            }
        }
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo placeholder
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(subscription.name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.primary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.headline)
                
                if let costPerHour = subscription.costPerHour {
                    Text("\(costPerHour, format: .currency(code: subscription.currency))/hour")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Text(subscription.displayAmount)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
