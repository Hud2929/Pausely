import SwiftUI
import CoreSpotlight

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
        // anything saved now could replace it (see `SavedData`). The app does not start: a person can't
        // be looking at it, because opening it takes an unlocked phone. Only a "Keep it" press is
        // written down, on its own, and the launch ends (`LockedLaunchDelegate`).
        if SavedData.lockedAtLaunch, UIApplication.shared.applicationState == .background {
            LockedLaunchDelegate.isActive = true
            return
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
            UserDefaults.standard.removeObject(forKey: "hasSeenFirstRunPaywall")
            UserDefaults.standard.removeObject(forKey: "pendingFirstRunPlan")
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
            if LockedLaunchDelegate.isActive {
                // Never on screen: this launch ends while the phone is still locked.
                Color.clear
            } else {
                RootView()
                    .environment(\.locale, resolvedLocale)
                    .modifier(ChosenDirection(direction: chosenDirection))
            }
        }
    }
}

/// The moment it takes to read an account's own answer to the age check from the server. An account that
/// had answered on another iPhone was shown the question for a second after signing in, until its answer
/// arrived and the question vanished (seen on 2026-11-28, signing in to an existing account on a fresh
/// install). The screen stays empty for that moment; a slow answer gets a spinner, and after four
/// seconds the question is put, as it is with no signal at all.
private struct AgeAnswerLookup: View {
    let userId: String
    let onRead: () -> Void
    @State private var isSlow = false

    var body: some View {
        ProgressView()
            .tint(Color.inkText)
            .opacity(isSlow ? 1 : 0)
            .accessibilityHidden(!isSlow)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .inkScreen()
            .task(id: userId) {
                // Whichever comes first: the account's row, or four seconds.
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await AuthManager.shared.syncRemoteProfileState(userId: userId) }
                    group.addTask { try? await Task.sleep(for: .seconds(4)) }
                    await group.next()
                    group.cancelAll()
                }
                onRead()
            }
            .task(id: userId) {
                try? await Task.sleep(for: .milliseconds(700))
                isSlow = !Task.isCancelled
            }
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
    /// The account whose own answer to the age check has been read from the server since it signed in.
    @State private var ageAnswerReadFor: String?
    @Environment(\.scenePhase) private var scenePhase

    // DEBUG only: a release build never reads a launch argument (see `LaunchFlag`).
    private var isUITesting: Bool { LaunchFlag.uiTesting.isSet }
    private var isDemoMode: Bool { LaunchFlag.demoMode.isSet }

    private var hasDebugDestination: Bool {
        #if DEBUG
        return DebugLaunchRouter.hasDestination
        #else
        return false
        #endif
    }

    /// Signed-in users (existing accounts, Apple sign-ins) who haven't confirmed their age yet.
    /// Local-only guest mode skips this gate; creating a cloud account runs it via `SignUpDoor`.
    private var needsAgeGate: Bool {
        guard !isDemoMode, !isUITesting, authManager.isAuthenticated, !authManager.isGuest,
              let uid = authManager.currentUser?.id else { return false }
        return ageConsent.needsConsent(userId: uid) && !ageConsent.hasPassedDeviceGate
    }

    var body: some View {
        ZStack {
            Group {
                if hasDebugDestination {
                    #if DEBUG
                    DebugLaunchRouter.screen()
                    #endif
                } else if authManager.needsNewPassword {
                    // A reset code or link was accepted: render directly at root (instead of a
                    // colliding fullScreenCover over SignInView) so choosing a new password always appears.
                    NewPasswordView()
                        .readableWidth()
                        .preferredColorScheme(.dark)
                        .transition(.opacity)
                } else if needsAgeGate, let uid = authManager.currentUser?.id, ageAnswerReadFor != uid {
                    AgeAnswerLookup(userId: uid) { ageAnswerReadFor = uid }
                        .transition(.opacity)
                } else if needsAgeGate, let uid = authManager.currentUser?.id {
                    AgeGateView(
                        onPassed: { Task { await ageConsent.recordConsent(userId: uid) } },
                        onCancel: { Task { await authManager.signOut() } },
                        cancelTitle: "Sign out"
                    )
                    .readableWidth()
                    .transition(.opacity)
                } else if isDemoMode || authManager.isAuthenticated {
                    // Authenticated: show main app
                    VStack(spacing: 0) {
                        if supabaseManager.isUsingDemoMode || LaunchFlag.isSet("--demo-banner") {
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
                        },
                        onContinueWithoutAccount: {
                            withAnimation(Motion.unlessReduced(Motion.arrive)) {
                                hasCompletedOnboarding = true
                                authManager.enterGuestMode()
                            }
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
            .accessibilityHidden(showSplash)
            // Opened from here, by the screen that is always on: a form opened by a screen as it
            // arrived (the welcome screen sliding in) was a second thing happening at once, and on
            // iPad "Keep my list" ended back on the total with no form.
            .signUpDoor(isOpen: $signingUp)
            .sheet(isPresented: $signingIn) { SignInView() }
            .onReceive(NotificationCenter.default.publisher(for: .openSignUpDoor)) { _ in signingUp = true }
            .onReceive(NotificationCenter.default.publisher(for: .openSignInSheet)) { _ in signingIn = true }
            .onChange(of: authManager.needsNewPassword) { _, needed in
                if needed {
                    signingIn = false
                    signingUp = false
                }
            }

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
            // anyone with an unsynced record retries the upload. Local-only guest mode never writes to cloud.
            guard !authManager.isGuest,
                  let uid = authManager.currentUser?.id,
                  uid != AuthManager.localTestUserID else { return }
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
            DebugLaunchRouter.applyDemoModifiers(authManager: authManager)
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // Time-driven changes (renewals passing, trials ending) and a fresh set of reminders
            // every time the app comes back to the foreground.
            if phase == .active {
                guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
                // The phone is unlocked now: anything a locked-screen action couldn't read can be.
                LifecycleEventLog.shared.loadIfNeeded()
                PausePlanStore.shared.loadIfNeeded()
                Task { await VerdictCenter.shared.keepPressedWhileLocked() }
                SubscriptionStore.shared.noticeTimeZone()
                Task {
                    await NotificationManager.shared.refreshStatus()
                    await CurrencyManager.shared.refreshRatesWhenDue()
                    await PaymentManager.shared.updateCurrentEntitlements()
                    guard authManager.isAuthenticated || isDemoMode else { return }
                    if authManager.isSignedIntoCloud {
                        if let uid = authManager.currentUser?.id {
                            await ageConsent.syncPendingConsent(userId: uid)
                        }
                        if SubscriptionStore.isFirstSync(for: authManager.currentUser?.id) {
                            await SubscriptionStore.shared.fetchSubscriptions(force: true)
                        } else {
                            await SubscriptionStore.shared.sync.drain(force: true)
                        }
                        await LifecycleSync.shared.sync()
                        await PausePlanSync.shared.sync()
                    }
                    await SubscriptionLifecycle.shared.run()
                }
            }
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

// MARK: - Welcome Flow
/// The sign-up / sign-in screen. The first-run tally already explained the app, so this goes
/// straight to the account step; `start` opens the form the customer asked for.
struct WelcomeFlow: View {
    enum Start { case welcome, signUp, signIn }
    var start: Start = .welcome

    @ObservedObject private var authManager = AuthManager.shared
    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var didApplyStart = false

    var body: some View {
        NavigationStack {
            WelcomeWallBody(
                onSignUp: { showSignUp = true },
                onSignIn: {
                    UserDefaults.standard.removeObject(forKey: "pendingFirstRunPlan")
                    showSignIn = true
                },
                onGuest: { authManager.enterGuestMode() }
            )
            .navigationBarHidden(true)
            .signUpDoor(isOpen: $showSignUp)
            .sheet(isPresented: $showSignIn) { SignInView() }
            .onChange(of: authManager.needsNewPassword) { _, needed in
                if needed {
                    showSignIn = false
                    showSignUp = false
                }
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
}
