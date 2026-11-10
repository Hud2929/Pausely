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
                } else if isDemoScreen("--demo-usage") {
                    #if DEBUG
                    ScrollView { CostPerUseDetailSection(subscription: DemoSubscriptions.netflix).padding(Layout.margin) }
                        .background(Color.ink.ignoresSafeArea())
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

    // MARK: - Auth Wall Content
    private var authWallContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            Color.inkText
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "pause.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.inkText)
                }

                VStack(spacing: 8) {
                    Text("Welcome to Pausely")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.center)

                    Text("Take control of your subscriptions")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color.inkTextMuted)
                }
            }
            .padding(.bottom, 48)

            // Features
            VStack(spacing: 16) {
                PremiumFeatureRow(
                    icon: "calendar.badge.clock",
                    title: "Every renewal, before it hits",
                    description: "What each subscription costs and the day it charges you"
                )

                PremiumFeatureRow(
                    icon: "hand.tap.fill",
                    title: "Keep it or cancel it",
                    description: "A reminder before each charge, with the facts to decide"
                )

                PremiumFeatureRow(
                    icon: "doc.text.fill",
                    title: "Your Savings Receipt",
                    description: "Exactly what your cancellations saved you"
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)

            Spacer()

            // Actions
            VStack(spacing: 16) {
                Button(action: { showSignUp = true }) {
                    Text("Get Started")
                }
                .buttonStyle(InkButtonStyle())
                .padding(.horizontal, 24)
                .accessibilityIdentifier("getStartedButton")

                Button(action: { showSignIn = true }) {
                    Text("I already have an account")
                }
                .buttonStyle(InkButtonStyle(kind: .quiet))
                .accessibilityIdentifier("signInButton")
            }
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Premium Feature Row
struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.inkText.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(Color.inkText)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.inkTextMuted)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Premium Sign Up View
struct PremiumSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var ageConsent = AgeConsentManager.shared
    @State private var showAgeGate = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var appleNonce: String?
    @State private var showEmailConfirmation = false
    @State private var pendingEmail = ""

    var isPasswordValid: Bool {
        PasswordStrength.rulesMet(password) == 4
    }

    var isValid: Bool {
        !firstName.isEmpty && !email.isEmpty && email.contains("@") && isPasswordValid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.title.weight(.bold))
                                .foregroundStyle(Color.inkText)

                            Text("Start your subscription journey")
                                .font(.body)
                                .foregroundColor(Color.inkTextMuted)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 20) {
                            // Name row
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(Color.inkTextMuted)
                                    InkTextField(placeholder: "Jane", text: $firstName)
                                        .accessibilityIdentifier("firstNameTextField")
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(Color.inkTextMuted)
                                    InkTextField(placeholder: "Smith", text: $lastName)
                                        .accessibilityIdentifier("lastNameTextField")
                                }
                            }

                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(Color.inkTextMuted)

                                InkTextField(
                                    placeholder: "your@email.com",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never
                                )
                                .accessibilityIdentifier("emailTextField")
                            }

                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(Color.inkTextMuted)

                                InkTextField(
                                    placeholder: "Min. 8 characters",
                                    text: $password,
                                    isSecure: true
                                )
                                .accessibilityIdentifier("passwordTextField")

                                if !password.isEmpty {
                                    PasswordStrengthMeter(password: password)
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Error
                        if showError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.due)
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.due)
                            }
                            .padding(.horizontal, 24)
                        }

                        // Spacer removed — meter pushes button, keep it reachable on small screens
                        // Button
                        Button(action: performSignUp) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create Account")
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(.ink)
                        .padding(.horizontal, 24)
                        .disabled(!isValid || isLoading)
                        .accessibilityIdentifier("createAccountButton")
                        .accessibilityHint(!isValid ? "Please fill in all required fields correctly" : isLoading ? "Please wait, creating account" : "")

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.footnote).foregroundColor(.inkTextFaint).padding(.horizontal, 8)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                        .padding(.horizontal, 24)

                        // Sign in with Apple
                        SignInWithAppleButton(.signUp, onRequest: { request in
                            let nonce = AppleSignInCoordinator.generateNonce()
                            appleNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AppleSignInCoordinator.sha256(nonce)
                        }, onCompletion: { result in
                            handleAppleResult(result)
                        })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("appleSignUpButton")

                        // Terms
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                            .font(.footnote)
                            .foregroundColor(.inkTextFaint)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.inkTextMuted)
                        .accessibilityIdentifier("cancelButton")
                }
            }
            .sheet(isPresented: $showEmailConfirmation) {
                EmailConfirmationView(email: pendingEmail)
            }
            .fullScreenCover(isPresented: $showAgeGate) {
                AgeGateView(
                    onPassed: { showAgeGate = false },
                    onCancel: {
                        showAgeGate = false
                        dismiss()
                    }
                )
                .readableWidth()
            }
            .onAppear {
                // Age is confirmed BEFORE any account can be created.
                if !ageConsent.hasPassedDeviceGate { showAgeGate = true }
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else { return }
            isLoading = true
            Task {
                do {
                    try await authManager.signInWithApple(
                        idToken: idToken,
                        rawNonce: nonce,
                        fullName: credential.fullName
                    )
                    await MainActor.run {
                        isLoading = false
                        if authManager.isAuthenticated { dismiss() }
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        showError = true
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performSignUp() {
        guard isValid else { return }
        isLoading = true
        showError = false
        Task {
            do {
                try await authManager.signUpWithOTP(
                    email: email,
                    password: password,
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName
                )
                await MainActor.run {
                    isLoading = false
                    if authManager.isAuthenticated {
                        dismiss()
                    } else {
                        // OTP sent — show code entry view
                        pendingEmail = email
                        showEmailConfirmation = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Premium Sign In View
struct PremiumSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var appleNonce: String?
    @State private var showPasswordReset = false

    var isValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.title.weight(.bold))
                                .foregroundStyle(Color.inkText)

                            Text("Sign in to continue")
                                .font(.body)
                                .foregroundColor(Color.inkTextMuted)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(Color.inkTextMuted)

                                InkTextField(
                                    placeholder: "your@email.com",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never
                                )
                                .accessibilityIdentifier("signInEmailTextField")
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(Color.inkTextMuted)

                                InkTextField(
                                    placeholder: "••••••••",
                                    text: $password,
                                    isSecure: true
                                )
                                .accessibilityIdentifier("signInPasswordTextField")
                            }
                        }
                        .padding(.horizontal, 24)

                        if showError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.due)
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.due)
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)

                        Button(action: performSignIn) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(.ink)
                        .padding(.horizontal, 24)
                        .disabled(!isValid || isLoading)
                        .accessibilityIdentifier("signInButton")
                        .accessibilityHint(!isValid ? "Please enter your email and password" : isLoading ? "Please wait, signing in" : "")

                        Button("Forgot Password?") {
                            showPasswordReset = true
                        }
                        .font(.subheadline)
                        .foregroundColor(Color.inkTextMuted)
                        .accessibilityIdentifier("forgotPasswordButton")

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.footnote).foregroundColor(.inkTextFaint).padding(.horizontal, 8)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                        .padding(.horizontal, 24)

                        // Sign in with Apple
                        SignInWithAppleButton(.signIn, onRequest: { request in
                            let nonce = AppleSignInCoordinator.generateNonce()
                            appleNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AppleSignInCoordinator.sha256(nonce)
                        }, onCompletion: { result in
                            handleAppleResult(result)
                        })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .accessibilityIdentifier("appleSignInButton")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.inkTextMuted)
                        .accessibilityIdentifier("signInCancelButton")
                }
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView(email: email)
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else { return }
            isLoading = true
            Task {
                do {
                    try await authManager.signInWithApple(
                        idToken: idToken,
                        rawNonce: nonce,
                        fullName: credential.fullName
                    )
                    await MainActor.run {
                        isLoading = false
                        if authManager.isAuthenticated { dismiss() }
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        showError = true
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performSignIn() {
        guard isValid else { return }

        isLoading = true
        showError = false

        Task {
            do {
                try await authManager.signIn(email: email, password: password)

                await MainActor.run {
                    isLoading = false
                    if authManager.isAuthenticated {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError = true
                    // Show the actual error message from the auth system
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    RootView()
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
