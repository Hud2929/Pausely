import SwiftUI

// MARK: - Premium Main Tab View (Clean Apple TabView)
struct PremiumMainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                DashboardView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // Subscriptions Tab
            NavigationStack {
                PremiumSubscriptionsView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Subscriptions", systemImage: "creditcard.fill")
            }
            .tag(1)

            // Genius Tab
            NavigationStack {
                RevolutionaryGeniusView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Genius", systemImage: "sparkles")
            }
            .tag(2)

            // Insights Tab
            NavigationStack {
                RevolutionaryInsightsView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(3)

            // Profile Tab
            NavigationStack {
                PremiumProfileView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(4)
        }
        .tint(Colors.primary)
        .onReceive(NotificationCenter.default.publisher(for: .switchToProfileTab)) { _ in
            withAnimation {
                selectedTab = 4
            }
        }
        .task {
            await subscriptionStore.fetchSubscriptions()
        }
    }
}

extension Notification.Name {
    static let switchToProfileTab = Notification.Name("switchToProfileTab")
}

#Preview {
    PremiumMainTabView()
}
