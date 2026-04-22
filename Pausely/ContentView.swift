import SwiftUI
import AuthenticationServices
import os.log

@main
struct PauselyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Force iPad to use full screen
                    #if targetEnvironment(simulator)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        // iPad specific configuration
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .forEach { $0.sizeRestrictions?.minimumSize = CGSize(width: 768, height: 1024) }
                    }
                    #endif
                }
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
            .foregroundColor: UIColor.white
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.backgroundPrimary).withAlphaComponent(0.95)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

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
        _ = ReferralManager.shared.handleReferralDeepLink(url)
    }
}

// MARK: - Root View
struct RootView: View {
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @State private var supabaseManager = SupabaseManager.shared
    @State private var showSplash = true
    @State private var splashAnimation = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            Group {
                if authManager.isAuthenticated {
                    // Authenticated: show main app
                    VStack(spacing: 0) {
                        if supabaseManager.isUsingDemoMode {
                            DemoModeBanner()
                        }
                        PremiumMainTabView()
                    }
                    .transition(.opacity.combined(with: .scale(0.98)))
                } else if !hasCompletedOnboarding {
                    // New user: show value-first onboarding BEFORE auth wall
                    OnboardingCarouselView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // Onboarding completed but not authenticated: show auth
                    PremiumWelcomeFlow()
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
        .animation(.easeInOut(duration: 0.5), value: hasCompletedOnboarding)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
        .task {
            // Initialize StoreKit: starts the transaction listener and checks
            // existing entitlements so returning subscribers are recognized immediately.
            await StoreKitManager.shared.loadProducts()
        }
        .onOpenURL { url in
            // Handle deep links (referral codes, auth callbacks, etc.)
            #if DEBUG
            os_log("🔗 RootView received URL: %{public}@", log: .default, type: .info, url.absoluteString)
            #endif
            _ = ReferralManager.shared.handleReferralDeepLink(url)
            // Also handle auth deep links (email confirm, password reset)
            Task {
                _ = await authManager.handleDeepLink(url)
            }
        }
    }
}

// MARK: - Premium Splash Screen
struct PremiumSplashScreen: View {
    @Binding var animation: Bool
    @State private var rotation = 0.0
    @State private var scale = 0.8
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
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Text
                VStack(spacing: 12) {
                    Text("Pausely")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Smart Subscription Manager")
                        .font(.system(size: 17, weight: .medium, design: .default))
                        .foregroundColor(TextColors.secondary)
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

// MARK: - Onboarding Carousel Page
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let preview: AnyView
}

// MARK: - Premium Welcome Flow
struct PremiumWelcomeFlow: View {
    @State private var showSignUp = false
    @State private var showSignIn = false
    @State private var currentPage = 0
    @State private var showAuth = false
    private let totalPages = 3

    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()

                VStack(spacing: 0) {
                    if showAuth {
                        authWallContent
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        onboardingCarousel
                            .transition(.opacity)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignUp) {
                PremiumSignUpView()
            }
            .sheet(isPresented: $showSignIn) {
                PremiumSignInView()
            }
        }
    }

    // MARK: - Onboarding Carousel
    private var onboardingCarousel: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showAuth = true
                    }
                }) {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(TextColors.secondary)
                }
                .padding(.top, 16)
                .padding(.trailing, 24)
            }

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? BrandColors.primary : BrandColors.primary.opacity(0.2))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.top, 16)

            // Carousel
            TabView(selection: $currentPage) {
                OnboardingPreviewPage(
                    icon: "chart.pie.fill",
                    title: "Track Your Spending",
                    description: "See exactly where your money goes with a beautiful dashboard and spending breakdown.",
                    preview: AnyView(DashboardPreviewCard())
                )
                .tag(0)

                OnboardingPreviewPage(
                    icon: "list.bullet.rectangle.fill",
                    title: "Smart Detection",
                    description: "Automatically find and organize all your subscriptions in one place.",
                    preview: AnyView(SubscriptionListPreviewCard())
                )
                .tag(1)

                OnboardingPreviewPage(
                    icon: "sparkles",
                    title: "AI Insights",
                    description: "Get personalized recommendations to optimize your subscriptions and save money.",
                    preview: AnyView(InsightsPreviewCard())
                )
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .padding(.top, 24)

            Spacer()

            // Continue button
            VStack(spacing: 16) {
                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showAuth = true
                        }
                    }
                }) {
                    Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [BrandColors.primary, BrandColors.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: BrandColors.primary.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 24)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showAuth = true
                    }
                }) {
                    Text("I already have an account")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(TextColors.secondary)
                }
            }
            .padding(.bottom, 48)
            .padding(.top, 24)
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
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("Welcome to Pausely")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Take control of your subscriptions")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(TextColors.secondary)
                }
            }
            .padding(.bottom, 48)

            // Features
            VStack(spacing: 16) {
                PremiumFeatureRow(
                    icon: "chart.pie.fill",
                    title: "Track Everything",
                    description: "All your subscriptions in one beautiful place"
                )

                PremiumFeatureRow(
                    icon: "bell.badge.fill",
                    title: "Smart Reminders",
                    description: "Never miss a renewal or free trial ending"
                )

                PremiumFeatureRow(
                    icon: "dollarsign.circle.fill",
                    title: "Find Savings",
                    description: "Discover unused subscriptions and save money"
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

                Button(action: { showSignIn = true }) {
                    Text("I already have an account")
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Onboarding Preview Page
struct OnboardingPreviewPage: View {
    let icon: String
    let title: String
    let description: String
    let preview: AnyView

    var body: some View {
        VStack(spacing: 24) {
            // Preview card
            preview
                .frame(height: 360)
                .padding(.horizontal, 24)

            // Text content
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(BrandColors.primary)

                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text(description)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(TextColors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - Dashboard Preview Card
struct DashboardPreviewCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BrandColors.primary.opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Good morning")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TextColors.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(BrandColors.primary.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "bell")
                                .font(.system(size: 16))
                                .foregroundColor(BrandColors.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Hero spend card
                VStack(spacing: 8) {
                    Text("$247")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("/month")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(TextColors.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BrandColors.primary.opacity(0.3), BrandColors.secondary.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .padding(.horizontal, 20)

                // Mini chart
                HStack(spacing: 8) {
                    ForEach([0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.5], id: \.self) { height in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(BrandColors.primary.opacity(0.6))
                            .frame(width: 24, height: CGFloat(height * 60))
                    }
                }
                .frame(height: 60)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

// MARK: - Subscription List Preview Card
struct SubscriptionListPreviewCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BrandColors.primary.opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Your Subscriptions")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Circle()
                        .fill(BrandColors.primary.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 16))
                                .foregroundColor(BrandColors.primary)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Subscription rows
                VStack(spacing: 10) {
                    PreviewSubscriptionRow(name: "Netflix", price: "$15.99", color: .red)
                    PreviewSubscriptionRow(name: "Spotify", price: "$10.99", color: .green)
                    PreviewSubscriptionRow(name: "Apple One", price: "$32.95", color: .blue)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

struct PreviewSubscriptionRow: View {
    let name: String
    let price: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("Monthly")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(TextColors.secondary)
            }

            Spacer()

            Text(price)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Insights Preview Card
struct InsightsPreviewCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BrandColors.primary.opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Smart Insights")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(BrandColors.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Waste score card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.luxuryTeal.opacity(0.2), lineWidth: 8)
                            .frame(width: 70, height: 70)

                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(Color.luxuryTeal, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))

                        Text("72")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Score")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Great! You're actively managing your subscriptions.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TextColors.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.luxuryTeal.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.luxuryTeal.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                // Recommendation card
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.luxuryGold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save $48/year")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Switch to annual billing for Netflix")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TextColors.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(TextColors.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.luxuryGold.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.luxuryGold.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                Spacer()
            }
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
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(BrandColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 15, weight: .regular))
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

    var isValid: Bool {
        !firstName.isEmpty && !email.isEmpty && email.contains("@") && password.count >= 6
    }

    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("Start your subscription journey")
                                .font(.system(size: 17))
                                .foregroundColor(TextColors.secondary)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 20) {
                            // Name row
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(TextColors.secondary)
                                    PremiumTextField(placeholder: "Jane", text: $firstName)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(TextColors.secondary)
                                    PremiumTextField(placeholder: "Smith", text: $lastName)
                                }
                            }

                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(TextColors.secondary)

                                PremiumTextField(
                                    placeholder: "your@email.com",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never
                                )
                            }

                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(TextColors.secondary)

                                PremiumTextField(
                                    placeholder: "Min. 6 characters",
                                    text: $password,
                                    isSecure: true
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        // Error
                        if showError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.error)
                                Text(errorMessage)
                                    .font(.system(size: 15))
                                    .foregroundColor(.error)
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)

                        // Button
                        Button(action: performSignUp) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: isLoading, isDisabled: !isValid))
                        .padding(.horizontal, 24)
                        .disabled(!isValid || isLoading)
                        .accessibilityHint(!isValid ? "Please fill in all required fields correctly" : isLoading ? "Please wait, creating account" : "")

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.system(size: 13)).foregroundColor(.textTertiary).padding(.horizontal, 8)
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

                        // Terms
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                            .font(.system(size: 13))
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
                        .foregroundColor(TextColors.secondary)
                }
            }
            .sheet(isPresented: $showEmailConfirmation) {
                EmailConfirmationView(email: pendingEmail)
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
                try await authManager.signUp(
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
                        // Email confirmation required - show the confirmation view
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
        NavigationView {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("Sign in to continue")
                                .font(.system(size: 17))
                                .foregroundColor(TextColors.secondary)
                        }
                        .padding(.top, 20)

                        // Form
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(TextColors.secondary)

                                PremiumTextField(
                                    placeholder: "your@email.com",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    autocapitalization: .never
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(TextColors.secondary)

                                PremiumTextField(
                                    placeholder: "••••••••",
                                    text: $password,
                                    isSecure: true
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        if showError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.error)
                                Text(errorMessage)
                                    .font(.system(size: 15))
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
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: isLoading, isDisabled: !isValid))
                        .padding(.horizontal, 24)
                        .disabled(!isValid || isLoading)
                        .accessibilityHint(!isValid ? "Please enter your email and password" : isLoading ? "Please wait, signing in" : "")

                        Button("Forgot Password?") {
                            showPasswordReset = true
                        }
                        .font(.system(size: 15))
                        .foregroundColor(TextColors.secondary)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.system(size: 13)).foregroundColor(.textTertiary).padding(.horizontal, 8)
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
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(TextColors.secondary)
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
