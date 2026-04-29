import SwiftUI

// MARK: - Premium Main Tab View (Clean Apple TabView)
struct PremiumMainTabView: View {
    @State private var selectedTab = 0
    @State private var deepLinkedSubscription: Subscription?
    @State private var showingPaywall = false
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 3 && !paymentManager.isPro {
                    showingPaywall = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            // Home Tab
            NavigationStack {
                DashboardView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            .accessibilityIdentifier("tabHome")

            // Subscriptions Tab
            NavigationStack {
                PremiumSubscriptionsView(deepLinkedSubscription: $deepLinkedSubscription)
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Subscriptions", systemImage: "creditcard.fill")
            }
            .tag(1)
            .accessibilityIdentifier("tabSubscriptions")

            // Genius Tab
            NavigationStack {
                RevolutionaryGeniusView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Genius", systemImage: "sparkles")
            }
            .tag(2)
            .accessibilityIdentifier("tabGenius")

            // Insights Tab (Pro only)
            NavigationStack {
                RevolutionaryInsightsView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                if paymentManager.isPro {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                } else {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .tag(3)
            .accessibilityIdentifier("tabInsights")

            // Profile Tab
            NavigationStack {
                PremiumProfileView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(4)
            .accessibilityIdentifier("tabProfile")
        }
        .tint(Colors.primary)
        .onReceive(NotificationCenter.default.publisher(for: .switchToProfileTab)) { _ in
            withAnimation {
                selectedTab = 4
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSubscriptionManagement)) { notification in
            if let idString = notification.userInfo?["subscription_id"] as? String,
               let id = UUID(uuidString: idString),
               let subscription = subscriptionStore.subscriptions.first(where: { $0.id == id }) {
                withAnimation {
                    selectedTab = 1
                    deepLinkedSubscription = subscription
                }
            }
        }
        .task {
            await subscriptionStore.fetchSubscriptions()
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: subscriptionStore.subscriptions.count)
        }
        .whatsNewSheet()
    }
}

extension Notification.Name {
    static let switchToProfileTab = Notification.Name("switchToProfileTab")
}

#Preview {
    PremiumMainTabView()
}
