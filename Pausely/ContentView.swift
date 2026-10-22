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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, resolvedLocale)
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
        scrolledAppearance.backgroundColor = UIColor(Color.obsidianBlack).withAlphaComponent(0.92)
        scrolledAppearance.shadowColor = .clear
        scrolledAppearance.titleTextAttributes = appearance.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = scrolledAppearance
        UINavigationBar.appearance().compactAppearance = scrolledAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.backgroundPrimary).withAlphaComponent(0.95)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

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
                    GmailImportView()
                        .onAppear { GmailSubscriptionScanner.shared.loadDemoResults() }
                    #endif
                } else if isDemoScreen("--demo-subscription") {
                    #if DEBUG
                    SubscriptionManagementView(subscription: SubscriptionStore.shared.subscriptions.first { $0.name == "Netflix" } ?? DemoSubscriptions.netflix)
                    #endif
                } else if isDemoScreen("--demo-subscription-edit") {
                    #if DEBUG
                    SubscriptionEditView(subscription: DemoSubscriptions.netflix)
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
                    // New user: show value-first onboarding BEFORE auth wall
                    OnboardingCarouselView(
                        onGetStarted: {
                            authStart = .signUp
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showAuth = true
                                hasCompletedOnboarding = true
                            }
                        },
                        onSignIn: {
                            authStart = .signIn
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showAuth = true
                                hasCompletedOnboarding = true
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
            splashWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
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
struct PremiumSplashScreen: View {
    @Binding var animation: Bool
    @State private var rotation = 0.0
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Animated Logo
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [BrandColors.primary, BrandColors.secondary, BrandColors.accent, BrandColors.primary],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(rotation))
                    
                    // Middle glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    BrandColors.primary.opacity(0.3),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(animation ? 1.1 : 0.9)
                    
                    // Icon container
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [BrandColors.primary, BrandColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: .brandPrimary.opacity(0.5), radius: 30, x: 0, y: 15)
                    
                    Image(systemName: "pause.circle.fill")
                        .font(.system(.largeTitle, design: .rounded).weight(.medium))
                        .foregroundColor(.white)
                }
                
                // Text
                VStack(spacing: 12) {
                    Text("Pausely")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(.white)

                    Text("Smart Subscription Manager")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundColor(Color.obsidianTextSecondary)
                }
                .opacity(opacity)
                
                Spacer()
                
                // Loading indicator
                PremiumLoadingIndicator()
                    .opacity(opacity)
                
                Spacer()
            }
        }
        .onAppear {
            if !UIAccessibility.isReduceMotionEnabled {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animation = true
                }
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                opacity = 1
            }
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
                PremiumBackground()
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
                            LinearGradient(
                                colors: [BrandColors.primary, BrandColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: BrandColors.primary.opacity(0.4), radius: 30, x: 0, y: 15)

                    Image(systemName: "pause.circle.fill")
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("Welcome to Pausely")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Take control of your subscriptions")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundColor(Color.obsidianTextSecondary)
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
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .accessibilityIdentifier("getStartedButton")

                Button(action: { showSignIn = true }) {
                    Text("I already have an account")
                }
                .buttonStyle(GhostButtonStyle())
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
                    .fill(BrandColors.primary.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                Image(systemName: icon)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundColor(BrandColors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(BackgroundColors.secondary)
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
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundColor(.white)

                            Text("Start your subscription journey")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Color.obsidianTextSecondary)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 20) {
                            // Name row
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name")
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .foregroundColor(Color.obsidianTextSecondary)
                                    PremiumTextField(placeholder: "Jane", text: $firstName)
                                        .accessibilityIdentifier("firstNameTextField")
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name")
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .foregroundColor(Color.obsidianTextSecondary)
                                    PremiumTextField(placeholder: "Smith", text: $lastName)
                                        .accessibilityIdentifier("lastNameTextField")
                                }
                            }

                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundColor(Color.obsidianTextSecondary)

                                PremiumTextField(
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
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundColor(Color.obsidianTextSecondary)

                                PremiumTextField(
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
                                    .foregroundColor(.error)
                                Text(errorMessage)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.error)
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
                                        .font(.system(.body, design: .rounded).weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: isLoading, isDisabled: !isValid))
                        .padding(.horizontal, 24)
                        .disabled(!isValid || isLoading)
                        .accessibilityIdentifier("createAccountButton")
                        .accessibilityHint(!isValid ? "Please fill in all required fields correctly" : isLoading ? "Please wait, creating account" : "")

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.system(.footnote, design: .rounded)).foregroundColor(.textTertiary).padding(.horizontal, 8)
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
                            .font(.system(.footnote, design: .rounded))
                            .foregroundColor(.textTertiary)
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
                        .foregroundColor(Color.obsidianTextSecondary)
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
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundColor(.white)

                            Text("Sign in to continue")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Color.obsidianTextSecondary)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundColor(Color.obsidianTextSecondary)

                                PremiumTextField(
                                    placeholder: "your@email.com",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never
                                )
                                .accessibilityIdentifier("signInEmailTextField")
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundColor(Color.obsidianTextSecondary)

                                PremiumTextField(
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
                                    .foregroundColor(.error)
                                Text(errorMessage)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.error)
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
                                        .font(.system(.body, design: .rounded).weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: isLoading, isDisabled: !isValid))
                        .padding(.horizontal, 24)
                        .disabled(!isValid || isLoading)
                        .accessibilityIdentifier("signInButton")
                        .accessibilityHint(!isValid ? "Please enter your email and password" : isLoading ? "Please wait, signing in" : "")

                        Button("Forgot Password?") {
                            showPasswordReset = true
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Color.obsidianTextSecondary)
                        .accessibilityIdentifier("forgotPasswordButton")

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.system(.footnote, design: .rounded)).foregroundColor(.textTertiary).padding(.horizontal, 8)
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
                        .foregroundColor(Color.obsidianTextSecondary)
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
