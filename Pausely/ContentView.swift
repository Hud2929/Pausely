import SwiftUI
import AuthenticationServices
import CoreSpotlight
import TipKit
import UserNotifications

@main
struct PauselyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("app_language") private var appLanguage = "system"

    /// The language chosen in the app, with the iPhone's region (`L10n.locale`). Read through
    /// `appLanguage` so the whole app redraws when it changes.
    private var resolvedLocale: Locale {
        appLanguage == "system" ? .current : L10n.locale(language: appLanguage, onDevice: .current)
    }

    /// Right to left for Arabic chosen in the app, left to right for the others. Nil when the app
    /// follows the iPhone: iOS then sets the direction of the language the app is actually shown in.
    private var chosenDirection: LayoutDirection? {
        guard appLanguage != "system" else { return nil }
        return Locale.Language(identifier: appLanguage).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }

    init() {
        // Started in the background before the phone's first unlock, nothing saved can be read, and
        // anything saved now could replace it (see `SavedData`). The launch ends here; a person can't
        // be looking at the app, because opening it takes an unlocked phone.
        if SavedData.lockedAtLaunch, UIApplication.shared.applicationState == .background {
            exit(0)
        }
        // Has to be read before anything is saved in this launch (see `InstallState`).
        _ = InstallState.firstLaunch
        // Two earlier price trackers wrote different things under this one key and overwrote each
        // other. The event log is the price history now, and what they left is removed.
        UserDefaults.standard.removeObject(forKey: "subscription_price_history")
        #if DEBUG
        // UI tests pass --reset-state to start from a first launch, whatever an earlier run left behind.
        if LaunchFlag.isSet("--reset-state") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            PendingTally.clear()
            TallyImporter.clearWaiting()
        }
        // A launch that starts from a set list (the demo one, or none) takes in nothing an earlier
        // run left waiting: an "empty" capture once opened on a Netflix from a first-run test.
        if LaunchFlag.isSet("--fresh-demo-data") || LaunchFlag.isSet("--empty-demo-data") || LaunchFlag.isSet("--varied-demo-data")
            || LaunchFlag.isSet("--quiet-demo-data") || LaunchFlag.isSet("--large-demo-data") {
            PendingTally.clear()
            TallyImporter.clearWaiting()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, resolvedLocale)
                .modifier(ChosenDirection(direction: chosenDirection))
                .readableWidth()
        }
    }
}

/// Sets the layout direction only when a language was chosen in the app.
private struct ChosenDirection: ViewModifier {
    let direction: LayoutDirection?

    func body(content: Content) -> some View {
        if let direction {
            content.environment(\.layoutDirection, direction)
        } else {
            content
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
            tabBarAppearance.shadowColor = UIColor(Color.line)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Configure TipKit for contextual tips
        TipKitConfiguration.configure()

        // The app switcher shows the app's name, not what someone pays for.
        PrivacyCover.install()

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
        DeepLinkManager.shared.process(url)
    }
}

// MARK: - Root View
struct RootView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var ageConsent = AgeConsentManager.shared
    @State private var supabaseManager = SupabaseManager.shared
    @State private var showSplash = true
    @State private var showAuth = false
    @State private var splashWorkItem: DispatchWorkItem?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    /// "Create your account" and "Sign in", when the first run asks for them.
    @State private var signingUp = false
    @State private var signingIn = false
    @Environment(\.scenePhase) private var scenePhase

    // DEBUG only, all three: a release build never reads a launch argument (see `LaunchFlag`).
    private var isUITesting: Bool { LaunchFlag.uiTesting.isSet }
    private var isDemoMode: Bool { LaunchFlag.demoMode.isSet }
    private func isDemoScreen(_ argument: String) -> Bool { LaunchFlag.isSet(argument) }

    /// DEBUG only: the value of `--demo-name=value`, or "" for a bare `--demo-name`. Nil when it isn't there.
    private func demoValue(_ name: String) -> String? { LaunchFlag.value(of: name) }

    #if DEBUG
    /// The subscription a `--demo-…=Name` argument names, from the list in use ("--demo-subscription=Hulu"
    /// with `--varied-demo-data` opens the cancelled one). Netflix when it names none.
    private func demoSubscription(_ name: String) -> Subscription {
        let list = SubscriptionStore.shared.subscriptions
        if !name.isEmpty, let named = list.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return named }
        return list.first { $0.name == "Netflix" } ?? DemoSubscriptions.netflix
    }
    #endif

    /// DEBUG only: `--demo-imap-connect` (iCloud) or `--demo-imap-connect=<preset id>`; `=other` for any server.
    private var demoIMAPPreset: String? {
        LaunchFlag.value(of: "--demo-imap-connect").map { $0.isEmpty ? "icloud" : $0 }
    }

    /// DEBUG only: open the Gmail results screen with a synthetic mailbox (no Google sign-in needed).
    private var isDemoGmailResults: Bool { LaunchFlag.isSet("--demo-gmail-results") }


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
                    case "signup": WelcomeFlow(start: .signUp)
                    case "signin": WelcomeFlow(start: .signIn)
                    default: WelcomeFlow(start: .welcome)
                    }
                    #endif
                } else if demoValue("--demo-age-gate") != nil {
                    #if DEBUG
                    AgeGateView(onPassed: {}, onCancel: {}, cancelTitle: "Sign out")
                    #endif
                } else if let screen = demoValue("--demo-settings") {
                    #if DEBUG
                    switch screen {
                    case "privacy": PrivacySecurityView()
                    case "help": HelpSupportView()
                    case "currency": CurrencySettingsView()
                    case "export": ExportDataView()
                    case "language": LanguageSettingsView()
                    default: NotificationsSettingsView()
                    }
                    #endif
                } else if isDemoScreen("--demo-whats-new") {
                    #if DEBUG
                    WhatsNewSheet()
                    #endif
                } else if let name = demoValue("--demo-subscription") {
                    #if DEBUG
                    SubscriptionManagementView(subscription: demoSubscription(name))
                    #endif
                } else if let name = demoValue("--demo-subscription-edit") {
                    #if DEBUG
                    SubscriptionEditView(subscription: name.isEmpty ? DemoSubscriptions.netflix : demoSubscription(name))
                    #endif
                } else if isDemoScreen("--demo-first-run") || isDemoScreen("--demo-first-run=tally") || isDemoScreen("--demo-first-run=reveal") {
                    #if DEBUG
                    FirstRunView(startAt: isDemoScreen("--demo-first-run=reveal") ? .reveal
                                    : isDemoScreen("--demo-first-run=tally") ? .tally : .guess,
                                 tally: isDemoScreen("--demo-first-run") ? nil : DemoTally.make(),
                                 onKeepList: {}, onSignIn: {})
                    #endif
                } else if let name = demoValue("--demo-cancel") {
                    #if DEBUG
                    CancelSubscriptionFlow(subscription: name.isEmpty ? DemoSubscriptions.netflix : demoSubscription(name))
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
                    AddSubscriptionView()
                    #endif
                } else if isDemoScreen("--demo-tier") {
                    #if DEBUG
                    DemoTierSheet()
                    #endif
                } else if let name = demoValue("--demo-price-history") {
                    #if DEBUG
                    PriceHistoryView(subscription: name.isEmpty ? DemoSubscriptions.netflix : demoSubscription(name))
                    #endif
                } else if isDemoScreen("--demo-design") {
                    #if DEBUG
                    DesignGalleryView()
                    #endif
                } else if isDemoScreen("--demo-paywall") {
                    #if DEBUG
                    StoreKitUpgradeView()
                    #endif
                } else if let list = demoValue("--demo-wrapped") {
                    #if DEBUG
                    // `--demo-wrapped=list` shows the year of the list in use (empty, or the varied one).
                    SubscriptionWrappedView(subscriptions: list == "list" ? SubscriptionStore.shared.subscriptions
                                                                          : SubscriptionStore.makeDemoSubscriptions())
                    #endif
                } else if let name = demoValue("--demo-verdict") {
                    #if DEBUG
                    RenewalVerdictView(subscriptionId: name.isEmpty ? SubscriptionStore.shared.subscriptions.first?.id ?? UUID()
                                                                    : demoSubscription(name).id)
                    #endif
                } else if isDemoScreen("--demo-pause-plan") {
                    #if DEBUG
                    PausePlanView()
                    #endif
                } else if isDemoScreen("--demo-dates") {
                    #if DEBUG
                    // Several subscriptions with no renewal date, as a first-run list arrives.
                    RenewalDatesSheet(subscriptions: SubscriptionStore.makeDemoSubscriptions().prefix(3).map { subscription in
                        var undated = subscription
                        undated.nextBillingDate = nil
                        return undated
                    })
                    #endif
                } else if demoValue("--demo-receipt") != nil {
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
                        cancelTitle: "Sign out"
                    )
                    .transition(.opacity)
                } else if isDemoMode || authManager.isAuthenticated {
                    // Authenticated: show main app
                    VStack(spacing: 0) {
                        if supabaseManager.isUsingDemoMode || isDemoScreen("--demo-banner") {
                            DemoModeBanner()
                        }
                        MainTabView()
                    }
                    .transition(.arriving(.scale(scale: 0.98)))
                } else if !showAuth && (!hasCompletedOnboarding || PendingTally.load() != nil) {
                    // New person: the guess, the tally and the reveal come before the account.
                    // Someone who made a list and then backed out of creating an account (or closed the
                    // app there) comes back to their own reveal, not to a welcome screen that starts over.
                    FirstRunView(
                        startAt: PendingTally.load() == nil ? .guess : .reveal,
                        tally: PendingTally.load(),
                        onKeepList: {
                            // The account form rises over the total, which stays where it is:
                            // closing the form leaves the person on their own list. (With nothing
                            // on the list there is no total to keep, and the welcome screen is
                            // what is underneath.)
                            withAnimation(Motion.unlessReduced(Motion.arrive)) { hasCompletedOnboarding = true }
                            signingUp = true
                        },
                        onSignIn: {
                            withAnimation(Motion.unlessReduced(Motion.arrive)) {
                                showAuth = true
                                hasCompletedOnboarding = true
                            }
                            signingIn = true
                        }
                    )
                    .transition(.opacity)
                } else {
                    // Onboarding completed but not authenticated: show auth
                    WelcomeFlow()
                        .transition(.arriving(.move(edge: .bottom)))
                }
            }
            .opacity(showSplash ? 0 : 1)
            // Opened from here, by the screen that is always on: a form opened by a screen as it
            // arrived (the welcome screen sliding in) was a second thing happening at once, and on
            // iPad "Keep my list" ended back on the total with no form.
            .signUpDoor(isOpen: $signingUp)
            .sheet(isPresented: $signingIn) { SignInView() }

            if showSplash {
                SplashScreen()
                    .transition(.opacity)
            }
        }
        .animation(Motion.unlessReduced(Motion.arrive), value: authManager.isAuthenticated)
        .animation(Motion.unlessReduced(Motion.arrive), value: showAuth)
        .onAppear {
            #if DEBUG
            // `--demo-splash` holds the launch mark so the tour can capture it (it is gone in 0.6 s).
            if LaunchFlag.isSet("--demo-splash") { return }
            #endif
            let workItem = DispatchWorkItem {
                withAnimation(Motion.fade) {
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
            // Starts listening for App Store transactions and fetches the plans' prices.
            await StoreKitManager.shared.loadProducts()
        }
        .onAppear {
            #if DEBUG
            if isDemoScreen("--demo-savings") || isDemoScreen("--demo-receipt") { DemoSavings.seed() }
            // The two messages that appear without being asked for, so they can be looked at.
            if isDemoScreen("--demo-link-problem") {
                authManager.linkProblem = L10n.string("That link has expired or was already used. Ask for a new one.")
            }
            // A Pause Plan already running, on whichever screen is opened: Home's row, the Insights
            // card and the subscription's own row all change when one is.
            if isDemoScreen("--demo-plan-active") {
                Task {
                    guard PausePlanStore.shared.activePlan == nil else { return }
                    let rotating = SubscriptionStore.shared.subscriptions.filter { PausePlanSchedule.isEligible($0) && $0.status != .cancelled }
                    await PausePlanStore.shared.start(order: PausePlanSchedule.suggestedOrder(rotating, now: Date()))
                }
            }
            // What the first-run slip could not fit under the free limit, waiting for a place.
            if isDemoScreen("--demo-waiting") { TallyImporter.keepWaitingForDemo() }
            if isDemoScreen("--demo-notice") {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    SubscriptionStore.shared.lastErrorMessage = L10n.string("Saved on this iPhone. It hasn't reached your account yet. Pausely will keep trying.")
                }
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // Time-driven changes (renewals passing, trials ending) and a fresh set of reminders
            // every time the app comes back to the foreground.
            if phase == .active {
                // The phone is unlocked now: anything a locked-screen action couldn't read can be.
                LifecycleEventLog.shared.loadIfNeeded()
                PausePlanStore.shared.loadIfNeeded()
                // Landed somewhere else: every renewal is still on its day.
                SubscriptionStore.shared.noticeTimeZone()
                Task {
                    await NotificationManager.shared.refreshStatus()
                    await SubscriptionLifecycle.shared.run()
                    // Changes that couldn't be sent earlier go now, without waiting for a pull to refresh.
                    await SubscriptionStore.shared.sync.drain(force: true)
                    // An app left open for days still converts at today's rates (asks at most hourly).
                    await CurrencyManager.shared.refreshRatesWhenDue()
                    // A subscription that ended or was refunded while the app was in the background stops
                    // unlocking Pro now, not at the next cold launch.
                    await PaymentManager.shared.updateCurrentEntitlements()
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
            // Account links and links to a subscription. Never logged: an account link carries a code.
            DeepLinkManager.shared.process(url)
        }
        // A subscription found in the iPhone's search opens that subscription.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let id = SpotlightManager.subscriptionId(in: activity) { VerdictCenter.shared.showSubscription(id) }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Premium Splash Screen
/// The launch screen: the pause mark on ink, for a little over half a second. No tagline, no spinner.
struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            PauseMark(height: 44)
                .foregroundStyle(Color.paper)
        }
    }
}


// MARK: - Premium Welcome Flow
/// The sign-up / sign-in screen. The carousel before it already explained the app, so this goes
/// straight to the account step; `start` opens the form the customer asked for.
struct WelcomeFlow: View {
    enum Start { case welcome, signUp, signIn }
    /// Which form is open on arrival. Only the captures of the forms themselves ask for one
    /// (`--demo-auth`); the first run opens its forms from the root (`RootView`).
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
            .signUpDoor(isOpen: $showSignUp)
            .sheet(isPresented: $showSignIn) {
                SignInView()
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
        ActionScreen {
            authWallText
        } actions: {
            authWallButtons
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var authWallText: some View {
        VStack(alignment: .leading, spacing: 0) {
            PauseMark(height: 30)
                .foregroundStyle(Color.paper)
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
                Button(action: { showSignUp = true }) { Text("Get started") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("getStartedButton")
                Button(action: { showSignIn = true }) { Text("I already have an account") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("signInButton")
                #if DEBUG
                // Debug builds only (never in the App Store build): the app without an account.
                if !LaunchFlag.uiTesting.isSet {
                    Button(action: { AuthManager.shared.enterAsDebugUser() }) {
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
        VStack(alignment: .leading, spacing: 4) {
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
/// `--demo-tier`: the plan sheet for Netflix.
private struct DemoTierSheet: View {
    var body: some View {
        if let entry = SubscriptionCatalogService.shared.entry(named: "Netflix") {
            CatalogAddSheet(entry: entry) { _, _, _, _ in }
        }
    }
}
#endif
