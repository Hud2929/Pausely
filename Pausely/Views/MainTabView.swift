import SwiftUI

// MARK: - The four tabs
struct MainTabView: View {
    @State private var selectedTab = MainTabView.launchTab

    /// DEBUG only: `--demo-tab=N` opens tab N (0 Dashboard, 1 Subscriptions, 2 Insights, 3 Profile) for screenshots.
    private static var launchTab: Int {
        LaunchFlag.value(of: "--demo-tab").flatMap(Int.init) ?? 0
    }
    @State private var deepLinkedSubscription: Subscription?
    @State private var showingFirstRunPaywall = false
    @AppStorage("hasSeenFirstRunPaywall") private var hasSeenFirstRunPaywall = false
    @AppStorage("pendingFirstRunPlan") private var pendingFirstRunPlan = false
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @ObservedObject private var verdictCenter = VerdictCenter.shared
    @ObservedObject private var paymentManager = PaymentManager.shared

    var body: some View {
        // The system tab bar: it translates, scales with text size, and is Liquid Glass on iOS 26.
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                NavigationStack { DashboardView().navigationBarHidden(true) }
            } label: {
                Label("Home", systemImage: "house")
            }
            .accessibilityIdentifier("tabHome")

            Tab(value: 1) {
                NavigationStack {
                    SubscriptionsView(deepLinkedSubscription: $deepLinkedSubscription)
                        .navigationBarHidden(true)
                }
            } label: {
                Label("Subscriptions", systemImage: "list.bullet")
            }
            .accessibilityIdentifier("tabSubscriptions")

            Tab(value: 2) {
                NavigationStack { AnalysisView().navigationBarHidden(true) }
            } label: {
                Label("Insights", systemImage: "chart.bar")
            }
            .accessibilityIdentifier("tabAnalysis")

            Tab(value: 3) {
                NavigationStack { ProfileView().navigationBarHidden(true) }
            } label: {
                Label("Profile", systemImage: "person")
            }
            .accessibilityIdentifier("tabProfile")
        }
        .tint(Color.inkText)
        .notice($subscriptionStore.lastErrorMessage)
        .onReceive(NotificationCenter.default.publisher(for: .switchToProfileTab)) { _ in
            withAnimation { selectedTab = 3 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAnalysisTab)) { _ in
            withAnimation { selectedTab = 2 }
        }
        // A tap on a widget, a Spotlight result or a link asked for one subscription. It may have come
        // before this screen existed (a tap that started the app), so the request is read on arrival too.
        .onChange(of: verdictCenter.subscriptionToShow, initial: true) { _, request in
            guard let request else { return }
            verdictCenter.subscriptionToShow = nil
            guard let subscription = subscriptionStore.subscriptions.first(where: { $0.id == request.subscriptionId }) else { return }
            withAnimation {
                selectedTab = 1
                deepLinkedSubscription = subscription
            }
        }
        .task(id: authManager.currentUser?.id) {
            // Unit tests host the app process without driving its screens; never let the live tab
            // hydrate the shared store while a unit test holds a StoreSandbox.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            // Someone else's history must never show up after a different account signs in.
            // Upgrading from guest mode adopts local data and queues it for cloud sync.
            await LocalUserData.claim(for: authManager.currentUser?.id)
            await NotificationManager.shared.refreshStatus()
            subscriptionStore.showList()
            await subscriptionStore.fetchSubscriptions()
            await LifecycleSync.shared.sync()
            await PausePlanSync.shared.sync()
            // The slip made before the account existed joins the list once it has loaded.
            let hadPendingTally = PendingTally.load() != nil
            await TallyImporter.importPending(into: subscriptionStore)
            // If Pro was started during RevealStep while the store was hidden, add Pausely's own
            // trial line now so its Day-5 reminder is scheduled immediately on Home.
            await PaymentManager.shared.autoAddPauselyProIfNeeded()
            // Present the quick 3-question curation + personalized Day 1–7 trial plan once right after
            // onboarding finishes (including users who tapped "None of these", never during UI tests/screenshots).
            let shouldPresentPlan = hadPendingTally || pendingFirstRunPlan
            if shouldPresentPlan {
                pendingFirstRunPlan = false
            }
            if shouldPresentPlan, !hasSeenFirstRunPaywall, !paymentManager.isPremium,
               !LaunchFlag.uiTesting.isSet, !LaunchFlag.demoMode.isSet, !LaunchFlag.screenshots.isSet {
                await StoreKitManager.shared.loadProducts()
                try? await Task.sleep(for: .milliseconds(350))
                if !Task.isCancelled, !paymentManager.isPremium {
                    hasSeenFirstRunPaywall = true
                    showingFirstRunPaywall = true
                }
            }
        }
        // A reminder tap (or "Review") opens the keep-or-cancel decision for that subscription.
        .sheet(item: $verdictCenter.presented, onDismiss: {
            ReviewPromptManager.shared.askAfterDecisionMade()
        }) { request in
            RenewalVerdictView(subscriptionId: request.subscriptionId)
        }
        .sheet(isPresented: $verdictCenter.showingPausePlan) {
            PausePlanView()
        }
        .sheet(isPresented: $verdictCenter.showingSavingsReceipt) {
            SavingsReceiptView()
        }
        .sheet(isPresented: $showingFirstRunPaywall) {
            FirstRunPlanFlow()
        }
        .whatsNewSheet()
    }
}

extension Notification.Name {
    static let switchToProfileTab = Notification.Name("switchToProfileTab")
    static let switchToAnalysisTab = Notification.Name("switchToAnalysisTab")
    static let openSignUpDoor = Notification.Name("openSignUpDoor")
    static let openSignInSheet = Notification.Name("openSignInSheet")
}

#Preview {
    MainTabView()
}
