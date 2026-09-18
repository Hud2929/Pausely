import SwiftUI

// MARK: - Premium Main Tab View (Custom Floating Tab Bar)
struct PremiumMainTabView: View {
    @State private var selectedTab = 0
    @State private var deepLinkedSubscription: Subscription?
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @ObservedObject private var insightsEngine = RealInsightsEngine.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content — opacity-based so scroll/nav state persists across tab switches
            ZStack {
                NavigationStack {
                    DashboardView().navigationBarHidden(true)
                }
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

                NavigationStack {
                    PremiumSubscriptionsView(deepLinkedSubscription: $deepLinkedSubscription)
                        .navigationBarHidden(true)
                }
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

                NavigationStack {
                    AnalysisView().navigationBarHidden(true)
                }
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)

                NavigationStack {
                    PremiumProfileView().navigationBarHidden(true)
                }
                .opacity(selectedTab == 3 ? 1 : 0)
                .allowsHitTesting(selectedTab == 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // Custom floating tab bar
            PauselyTabBar(
                selectedTab: $selectedTab,
                badgeCounts: selectedTab == 2 ? [:] : [2: insightsEngine.wasteAlerts.count]
            )
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .switchToProfileTab)) { _ in
            withAnimation { selectedTab = 3 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAnalysisTab)) { _ in
            withAnimation { selectedTab = 2 }
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
        .whatsNewSheet()
    }
}

extension Notification.Name {
    static let switchToProfileTab = Notification.Name("switchToProfileTab")
    static let switchToAnalysisTab = Notification.Name("switchToAnalysisTab")
}

#Preview {
    PremiumMainTabView()
}
