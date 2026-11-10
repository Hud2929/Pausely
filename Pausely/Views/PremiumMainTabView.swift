import SwiftUI

// MARK: - The four tabs
struct PremiumMainTabView: View {
    @State private var selectedTab = PremiumMainTabView.launchTab

    /// DEBUG only: `--demo-tab=N` opens tab N (0 Dashboard, 1 Subscriptions, 2 Insights, 3 Profile) for screenshots.
    private static var launchTab: Int {
        #if DEBUG
        for argument in ProcessInfo.processInfo.arguments where argument.hasPrefix("--demo-tab=") {
            if let index = Int(argument.dropFirst("--demo-tab=".count)) { return index }
        }
        #endif
        return 0
    }
    @State private var deepLinkedSubscription: Subscription?
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @ObservedObject private var verdictCenter = VerdictCenter.shared

    var body: some View {
        // The system tab bar: it translates, scales with text size, and is Liquid Glass on iOS 26.
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                NavigationStack { DashboardView().navigationBarHidden(true) }
            } label: {
                Label(L10n.string("Home"), systemImage: "house")
            }
            .accessibilityIdentifier("tabHome")

            Tab(value: 1) {
                NavigationStack {
                    PremiumSubscriptionsView(deepLinkedSubscription: $deepLinkedSubscription)
                        .navigationBarHidden(true)
                }
            } label: {
                Label(L10n.string("Subscriptions"), systemImage: "list.bullet")
            }
            .accessibilityIdentifier("tabSubscriptions")

            Tab(value: 2) {
                NavigationStack { AnalysisView().navigationBarHidden(true) }
            } label: {
                Label(L10n.string("Insights"), systemImage: "chart.bar")
            }
            .accessibilityIdentifier("tabAnalysis")

            Tab(value: 3) {
                NavigationStack { PremiumProfileView().navigationBarHidden(true) }
            } label: {
                Label(L10n.string("Profile"), systemImage: "person")
            }
            .accessibilityIdentifier("tabProfile")
        }
        .tint(Color.inkText)
        .errorToast(message: $subscriptionStore.lastErrorMessage)
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
            // Someone else's history must never show up after a different account signs in.
            await LocalUserData.claim(for: RevolutionaryAuthManager.shared.currentUser?.id)
            await NotificationManager.shared.refreshStatus()
            await subscriptionStore.fetchSubscriptions()
            // The slip made before the account existed joins the list once it has loaded.
            await TallyImporter.importPending(into: subscriptionStore)
        }
        // A reminder tap (or "Review") opens the keep-or-cancel decision for that subscription.
        .sheet(item: $verdictCenter.presented) { request in
            RenewalVerdictView(subscriptionId: request.subscriptionId)
        }
        .sheet(isPresented: $verdictCenter.showingPausePlan) {
            PausePlanView()
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
