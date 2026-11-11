import SwiftUI
import AuthenticationServices
import os.log
import TipKit
import UserNotifications

@main
struct PauselyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("app_language") private var appLanguage = "system"

    private var resolvedLocale: Locale {
        if appLanguage == "system" { return .current }
        return Locale(identifier: appLanguage)
    }

    init() {
        #if DEBUG
        // UI tests pass --reset-state to start from a first launch, whatever an earlier run left behind.
        if ProcessInfo.processInfo.arguments.contains("--reset-state") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            PendingTally.clear()
            TallyImporter.clearWaiting()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, resolvedLocale)
                .readableWidth()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        // Once content scrolls under the bar it gets a solid background, so text never runs
        // under the buttons; at the top it stays transparent.
        let scrolledAppearance = UINavigationBarAppearance()
        scrolledAppearance.configureWithDefaultBackground()
        scrolledAppearance.backgroundColor = UIColor(Color.ink).withAlphaComponent(0.92)
        scrolledAppearance.shadowColor = .clear
        scrolledAppearance.titleTextAttributes = appearance.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = scrolledAppearance
        UINavigationBar.appearance().compactAppearance = scrolledAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Switches: green would read as "money kept", so an "on" switch is a quiet grey.
        UISwitch.appearance().onTintColor = UIColor(Color.inkTextMuted)

        // iOS 26 draws the tab bar as Liquid Glass by itself. Earlier versions get a solid ink bar.
        if #unavailable(iOS 26) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(Color.ink)
            tabBarAppearance.shadowColor = UIColor.white.withAlphaComponent(0.08)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Configure TipKit for contextual tips
        TipKitConfiguration.configure()

        // Reminder taps and their Keep / Review buttons. Set before launch finishes so a tap that
        // launched the app is delivered.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        ReminderActions.registerCategories()

        // Handle URL if app was launched via deep link
        if let url = launchOptions?[.url] as? URL {
            handleDeepLink(url)
        }

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        handleDeepLink(url)
        return true
    }

    private func handleDeepLink(_ url: URL) {
        #if DEBUG
        os_log("🔗 AppDelegate handling URL: %{public}@", log: .default, type: .info, url.absoluteString)
        #endif
        DeepLinkManager.shared.process(url)
    }
}

// MARK: - Root View
struct RootView: View {
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var ageConsent = AgeConsentManager.shared
    @State private var supabaseManager = SupabaseManager.shared
    @State private var showSplash = true
    @State private var splashAnimation = false
    @State private var showAuth = false
    @State private var splashWorkItem: DispatchWorkItem?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var authStart: PremiumWelcomeFlow.Start = .welcome
    @Environment(\.scenePhase) private var scenePhase

    /// Detects if app was launched for UI testing
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    /// Detects if app should run in demo mode (no auth required)
    private var isDemoMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo-mode")
    }

    /// DEBUG only: open a single screen directly via launch argument.
    private func isDemoScreen(_ argument: String) -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(argument)
        #else
        return false
        #endif
    }

    /// DEBUG only: the value of `--demo-name=value`, or "" for a bare `--demo-name`. Nil when it isn't there.
    private func demoValue(_ name: String) -> String? {
        #if DEBUG
        for argument in ProcessInfo.processInfo.arguments {
            if argument == name { return "" }
            if argument.hasPrefix(name + "=") { return String(argument.dropFirst(name.count + 1)) }
        }
        #endif
        return nil
    }

    /// DEBUG only: `--demo-imap-connect` (iCloud) or `--demo-imap-connect=<preset id>`; `=other` for any server.
    private var demoIMAPPreset: String? {
        #if DEBUG
        for argument in ProcessInfo.processInfo.arguments {
            if argument == "--demo-imap-connect" { return "icloud" }
            if argument.hasPrefix("--demo-imap-connect=") { return String(argument.dropFirst("--demo-imap-connect=".count)) }
        }
        #endif
        return nil
    }

    /// DEBUG only: open the Gmail results screen with a synthetic mailbox (no Google sign-in needed).
    private var isDemoGmailResults: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--demo-gmail-results")
        #else
        return false
        #endif
    }


    /// Signed-in users (existing accounts, Apple sign-ins) who haven't confirmed their age yet.
    private var needsAgeGate: Bool {
        guard !isDemoMode, !isUITesting, authManager.isAuthenticated,
              let uid = authManager.currentUser?.id else { return false }
        return ageConsent.needsConsent(userId: uid) && !ageConsent.hasPassedDeviceGate
    }

    var body: some View {
        ZStack {
            Group {
                if isDemoGmailResults {
                    #if DEBUG
                    InboxImportView()
                        .onAppear { InboxScanner.shared.loadDemoResults() }
                    #endif
                } else if isDemoScreen("--demo-inbox") {
                    #if DEBUG
                    InboxImportView()
                        .task { if isDemoScreen("--reset-inbox") { await InboxScanner.shared.disconnectAll() } }
                    #endif
                } else if let presetID = demoIMAPPreset {
                    #if DEBUG
                    IMAPConnectView(preset: IMAPPreset.find(presetID))
                    #endif
                } else if let screen = demoValue("--demo-auth") {
                    #if DEBUG
                    switch screen {
                    case "verify": EmailConfirmationView(email: "jane@example.com")
                    case "reset": PasswordResetView(email: "")
                    case "newpassword": NewPasswordView()
                    case "signup": PremiumWelcomeFlow(start: .signUp)
                    case "signin": PremiumWelcomeFlow(start: .signIn)
                    default: PremiumWelcomeFlow(start: .welcome)
                    }
                    #endif
                } else if isDemoScreen("--demo-age-gate") {
                    #if DEBUG
                    AgeGateView(onPassed: {}, onCancel: {}, cancelTitle: "Sign Out")
                    #endif
                } else if let screen = demoValue("--demo-settings") {
                    #if DEBUG
                    NavigationStack {
                        switch screen {
                        case "privacy": PrivacySecurityView()
                        case "help": HelpSupportView()
                        case "currency": CurrencySettingsView()
                        case "export": ExportDataView()
                        case "language": LanguageSettingsView()
                        default: NotificationsSettingsView()
                        }
                    }
                    #endif
                } else if isDemoScreen("--demo-whats-new") {
                    #if DEBUG
                    WhatsNewSheet()
                    #endif
                } else if isDemoScreen("--demo-subscription") {
                    #if DEBUG
                    SubscriptionManagementView(subscription: SubscriptionStore.shared.subscriptions.first { $0.name == "Netflix" } ?? DemoSubscriptions.netflix)
                    #endif
                } else if isDemoScreen("--demo-subscription-edit") {
                    #if DEBUG
                    SubscriptionEditView(subscription: DemoSubscriptions.netflix)
                    #endif
                } else if isDemoScreen("--demo-first-run") || isDemoScreen("--demo-first-run=tally") || isDemoScreen("--demo-first-run=reveal") {
                    #if DEBUG
                    FirstRunView(startAt: isDemoScreen("--demo-first-run=reveal") ? .reveal
                                    : isDemoScreen("--demo-first-run=tally") ? .tally : .guess,
                                 tally: isDemoScreen("--demo-first-run") ? nil : DemoTally.make(),
                                 onKeepList: {}, onSignIn: {})
                    #endif
                } else if isDemoScreen("--demo-cancel") {
                    #if DEBUG
                    CancelSubscriptionFlow(subscription: DemoSubscriptions.netflix)
                    #endif
                } else if isDemoScreen("--demo-cancelled") || isDemoScreen("--demo-kept") {
                    #if DEBUG
                    ZStack {
                        Color.ink.ignoresSafeArea()
                        Group {
                            if isDemoScreen("--demo-kept") {
                                OutcomeSlip(name: "Netflix", category: "entertainment", stamp: L10n.string("Kept"), torn: false) {
                                    Text(L10n.string("No more reminders about this charge.")).font(.proof(.footnote))
                                }
                            } else {
                                CancelledSlip(subscription: DemoSubscriptions.netflix)
                            }
                        }
                        .padding(Layout.margin)
                    }
                    #endif
                } else if isDemoScreen("--demo-custom-add") {
                    #if DEBUG
                    LuxuryAddSubscriptionView()
                    #endif
                } else if isDemoScreen("--demo-tier") {
                    #if DEBUG
                    DemoTierSheet()
                    #endif
                } else if isDemoScreen("--demo-price-history") {
                    #if DEBUG
                    PriceHistoryView(subscription: DemoSubscriptions.netflix)
                    #endif
                } else if isDemoScreen("--demo-design") {
                    #if DEBUG
                    DesignGalleryView()
                    #endif
                } else if isDemoScreen("--demo-paywall") {
                    #if DEBUG
                    StoreKitUpgradeView(currentSubscriptionCount: 3)
                    #endif
                } else if isDemoScreen("--demo-wrapped") {
                    #if DEBUG
                    SubscriptionWrappedView(subscriptions: SubscriptionStore.makeDemoSubscriptions())
                    #endif
                } else if isDemoScreen("--demo-verdict") {
                    #if DEBUG
                    RenewalVerdictView(subscriptionId: SubscriptionStore.shared.subscriptions.first?.id ?? UUID())
                    #endif
                } else if isDemoScreen("--demo-pause-plan") {
                    #if DEBUG
                    PausePlanView()
                        .task {
                            guard isDemoScreen("--demo-plan-active"), PausePlanStore.shared.activePlan == nil else { return }
                            let eligible = SubscriptionStore.shared.subscriptions.filter(PausePlanSchedule.isEligible)
                            await PausePlanStore.shared.start(order: PausePlanSchedule.suggestedOrder(eligible, now: Date()))
                        }
                    #endif
                } else if isDemoScreen("--demo-receipt") {
                    #if DEBUG
                    SavingsReceiptView()
                    #endif
                } else if isDemoScreen("--demo-browser") {
                    #if DEBUG
                    SubscriptionBrowserView()
                    #endif
                } else if needsAgeGate, let uid = authManager.currentUser?.id {
                    AgeGateView(
                        onPassed: { Task { await ageConsent.recordConsent(userId: uid) } },
                        onCancel: { Task { await authManager.signOut() } },
                        cancelTitle: "Sign Out"
                    )
                    .transition(.opacity)
                } else if isDemoMode || authManager.isAuthenticated {
                    // Authenticated: show main app
                    VStack(spacing: 0) {
                        if supabaseManager.isUsingDemoMode {
                            DemoModeBanner()
                        }
                        PremiumMainTabView()
                    }
                    .transition(.opacity.combined(with: .scale(0.98)))
                } else if !showAuth && !hasCompletedOnboarding {
                    // New person: the guess, the tally and the reveal come before the account.
                    FirstRunView(
                        onKeepList: {
                            authStart = .signUp
                            withAnimation(Motion.unlessReduced(Motion.arrive)) {
                                showAuth = true
                                hasCompletedOnboarding = true
                            }
                        },
                        onSignIn: {
                            authStart = .signIn
                            withAnimation(Motion.unlessReduced(Motion.arrive)) {
                                showAuth = true
                                hasCompletedOnboarding = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else {
                    // Onboarding completed but not authenticated: show auth
                    PremiumWelcomeFlow(start: authStart)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .opacity(showSplash ? 0 : 1)

            if showSplash {
                PremiumSplashScreen(animation: $splashAnimation)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.5), value: showAuth)
        .onAppear {
            let workItem = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
            splashWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
        }
        .onDisappear {
            splashWorkItem?.cancel()
        }
        .task(id: authManager.currentUser?.id) {
            // Users who passed the age gate before sign-up get their consent recorded automatically;
            // anyone with an unsynced record retries the upload.
            guard let uid = authManager.currentUser?.id else { return }
            if ageConsent.needsConsent(userId: uid) && ageConsent.hasPassedDeviceGate {
                await ageConsent.recordConsent(userId: uid)
            } else {
                await ageConsent.syncPendingConsent(userId: uid)
            }
        }
        .task {
            // Initialize StoreKit: starts the transaction listener and checks
            // existing entitlements so returning subscribers are recognized immediately.
            await StoreKitManager.shared.loadProductsIfNeeded()
        }
        .onAppear {
            #if DEBUG
            if isDemoScreen("--demo-savings") || isDemoScreen("--demo-receipt") { DemoSavings.seed() }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // Time-driven changes (renewals passing, trials ending) and a fresh set of reminders
            // every time the app comes back to the foreground.
            if phase == .active {
                Task {
                    await NotificationManager.shared.refreshStatus()
                    await SubscriptionLifecycle.shared.run()
                }
            }
        }
        // A reset code or link was accepted: nothing else until the new password is chosen.
        .fullScreenCover(isPresented: $authManager.needsNewPassword) {
            NewPasswordView()
                .readableWidth()
                .preferredColorScheme(.dark)
        }
        .errorBanner($authManager.linkProblem)
        .onOpenURL { url in
            // Handle deep links (referral codes, auth callbacks, subscription management, etc.)
            #if DEBUG
            os_log("🔗 RootView received URL: %{public}@", log: .default, type: .info, url.absoluteString)
            #endif
            DeepLinkManager.shared.process(url)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Premium Splash Screen
/// The launch screen: the pause mark on ink, for a little over half a second. No tagline, no spinner.
struct PremiumSplashScreen: View {
    @Binding var animation: Bool

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            HStack(spacing: 10) {
                Capsule().frame(width: 12, height: 44)
                Capsule().frame(width: 12, height: 44)
            }
            .foregroundStyle(Color.paper)
            .accessibilityLabel(Text(verbatim: "Pausely"))
        }
    }
}


// MARK: - Premium Welcome Flow
/// The sign-up / sign-in screen. The carousel before it already explained the app, so this goes
/// straight to the account step; `start` opens the form the customer asked for.
struct PremiumWelcomeFlow: View {
    enum Start { case welcome, signUp, signIn }
    var start: Start = .welcome

    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var didApplyStart = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()
                authWallContent
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignUp) {
                PremiumSignUpView()
            }
            .sheet(isPresented: $showSignIn) {
                PremiumSignInView()
            }
        }
        .onAppear {
            guard !didApplyStart else { return }
            didApplyStart = true
            switch start {
            case .signUp: showSignUp = true
            case .signIn: showSignIn = true
            case .welcome: break
            }
        }
    }

    // MARK: - The door: create an account or sign in

    private var authWallContent: some View {
        ScrollView {
            authWallText
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { authWallButtons }
    }

    private var authWallText: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Capsule().frame(width: 8, height: 30)
                Capsule().frame(width: 8, height: 30)
            }
            .foregroundStyle(Color.paper)
            .accessibilityHidden(true)
            .padding(.top, 48)

            Text("Welcome to Pausely")
                .font(.question(.largeTitle, weight: .bold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 28)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 0) {
                promise("Every renewal, before it hits", "What each subscription costs and the day it charges you")
                Hairline()
                promise("Keep it or cancel it", "A reminder before each charge, with the facts to decide")
                Hairline()
                promise("Your Savings Receipt", "Exactly what your cancellations saved you")
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, Layout.margin)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authWallButtons: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Button(action: { showSignUp = true }) { Text("Get Started") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("getStartedButton")
                Button(action: { showSignIn = true }) { Text("I already have an account") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("signInButton")
                #if DEBUG
                // Debug builds only (never in the App Store build): the app without an account.
                if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    Button(action: { RevolutionaryAuthManager.shared.enterAsDebugUser() }) {
                        Text(verbatim: "Test without an account (debug build)")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                    }
                    .accessibilityIdentifier("debugTestUserButton")
                }
                #endif
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, Layout.margin)
        .padding(.top, 8)
        .background(Color.ink)
    }

    private func promise(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
/// `--demo-tier`: the plan sheet for Netflix, once the catalog has loaded.
private struct DemoTierSheet: View {
    @ObservedObject private var catalog = SubscriptionCatalogService.shared

    var body: some View {
        Group {
            if let entry = catalog.entry(named: "Netflix") {
                TierSelectionSheet(entry: entry) { _, _, _, _, _, _ in }
            } else {
                Color.ink.ignoresSafeArea()
            }
        }
        .task { await catalog.loadCatalog() }
    }
}
#endif
