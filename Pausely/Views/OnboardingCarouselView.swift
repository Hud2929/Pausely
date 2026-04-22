import SwiftUI

// MARK: - Onboarding Carousel View
/// Value-first onboarding: shows app benefits BEFORE the auth wall.
/// 3-page swipeable carousel with animated illustrations.
struct OnboardingCarouselView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var showAuth = false
    @State private var animateContent = false
    @State private var skipButtonOpacity = 1.0

    private let totalPages = 3
    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            icon: "rectangle.stack.fill",
            title: "All your subscriptions in one place",
            description: "See exactly what you're paying for every month",
            colors: [.luxuryPurple, .luxuryPink],
            illustration: .subscriptions
        ),
        OnboardingPageData(
            icon: "chart.bar.fill",
            title: "Know what each subscription costs per use",
            description: "Discover which subscriptions are worth it",
            colors: [.luxuryTeal, .luxuryPurple],
            illustration: .costPerUse
        ),
        OnboardingPageData(
            icon: "bell.badge.fill",
            title: "Get alerts before renewals and price hikes",
            description: "Never be surprised by a subscription charge again",
            colors: [.luxuryGold, .luxuryPink],
            illustration: .alerts
        )
    ]

    var body: some View {
        ZStack {
            // Dark animated background
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: skipOnboarding) {
                        Text("Skip")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundColor(TextColors.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                    .opacity(skipButtonOpacity)
                    .accessibilityLabel("Skip onboarding")
                }

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.luxuryGold : Color.white.opacity(0.2))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                            .accessibilityLabel("Page \(index + 1) of \(totalPages)")
                            .accessibilityValue(currentPage == index ? "Selected" : "Not selected")
                    }
                }
                .padding(.top, 12)

                // Carousel
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, animate: animateContent || currentPage == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .padding(.top, 16)

                Spacer()

                // Bottom CTA area
                bottomCTA
                    .padding(.bottom, 48)
                    .padding(.horizontal, 24)
            }
        }
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                animateContent = true
                return
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateContent = true
            }
        }
        .onChange(of: currentPage) { _ in
            HapticStyle.light.trigger()
            withAnimation(.easeOut(duration: 0.4)) {
                animateContent = true
            }
        }
    }

    // MARK: - Bottom CTA
    private var bottomCTA: some View {
        VStack(spacing: 16) {
            Button(action: advancePage) {
                HStack(spacing: 8) {
                    Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                        .font(.system(.headline, design: .rounded).weight(.semibold))

                    Image(systemName: currentPage < totalPages - 1 ? "arrow.right" : "sparkles")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.luxuryPurple, Color.luxuryPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: Color.luxuryPurple.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .accessibilityLabel(currentPage < totalPages - 1 ? "Next page" : "Get started")
            .pressEffect(scale: 0.97)
            .animation(.spring(response: 0.3), value: currentPage)

            if currentPage < totalPages - 1 {
                Button(action: skipOnboarding) {
                    Text("I already have an account")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundColor(TextColors.secondary)
                }
                .accessibilityLabel("I already have an account")
            }
        }
    }

    // MARK: - Actions
    private func advancePage() {
        HapticStyle.medium.trigger()
        if currentPage < totalPages - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func skipOnboarding() {
        HapticStyle.light.trigger()
        withAnimation(.easeInOut(duration: 0.4)) {
            skipButtonOpacity = 0
        }
        completeOnboarding()
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.5)) {
            showAuth = true
        }
        // Trigger review prompt after onboarding completion
        ReviewPromptManager.shared.requestReviewIfAppropriate(after: .onboardingCompleted)
    }
}

// MARK: - Onboarding Page Data
struct OnboardingPageData: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let colors: [Color]
    let illustration: IllustrationType

    enum IllustrationType {
        case subscriptions
        case costPerUse
        case alerts
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPageData
    let animate: Bool
    @State private var localAnimate = false

    var body: some View {
        VStack(spacing: 32) {
            // Animated illustration
            illustrationView
                .frame(height: 320)
                .padding(.horizontal, 24)

            // Text content
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: page.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: page.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(page.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                Text(page.description)
                    .font(.system(.headline, design: .rounded).weight(.medium))
                    .foregroundColor(TextColors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(localAnimate ? 1 : 0)
            .offset(y: localAnimate ? 0 : 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(page.title), \(page.description)")

            Spacer()
        }
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                localAnimate = true
                return
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                localAnimate = true
            }
        }
        .onChange(of: animate) { newValue in
            if newValue {
                guard !UIAccessibility.isReduceMotionEnabled else {
                    localAnimate = true
                    return
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    localAnimate = true
                }
            }
        }
    }

    // MARK: - Illustration View
    @ViewBuilder
    private var illustrationView: some View {
        switch page.illustration {
        case .subscriptions:
            SubscriptionsIllustration(colors: page.colors, animate: localAnimate)
        case .costPerUse:
            CostPerUseIllustration(colors: page.colors, animate: localAnimate)
        case .alerts:
            AlertsIllustration(colors: page.colors, animate: localAnimate)
        }
    }
}

// MARK: - Subscriptions Illustration
struct SubscriptionsIllustration: View {
    let colors: [Color]
    let animate: Bool
    @State private var cardOffsets: [CGFloat] = [40, 20, 0]
    @State private var cardScales: [CGFloat] = [0.9, 0.95, 1.0]
    @State private var cardOpacities: [Double] = [0.5, 0.7, 1.0]

    private let subs = [
        (name: "Netflix", price: "$15.99", color: Color.red),
        (name: "Spotify", price: "$10.99", color: Color.green),
        (name: "Apple One", price: "$32.95", color: Color.blue)
    ]

    var body: some View {
        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(colors[0].opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Your Subscriptions")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)

                    Spacer()

                    Circle()
                        .fill(colors[0].opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(colors[0])
                                .accessibilityLabel("Add subscription")
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Total spend
                VStack(spacing: 4) {
                    Text("$247.83")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(.white)

                    Text("per month")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(TextColors.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [colors[0].opacity(0.2), colors[1].opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .padding(.horizontal, 20)

                // Subscription rows
                VStack(spacing: 8) {
                    ForEach(Array(subs.enumerated()), id: \.offset) { index, sub in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(sub.color.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(sub.name.prefix(1)))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(sub.color)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)

                                Text("Monthly")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(TextColors.secondary)
                            }

                            Spacer()

                            Text(sub.price)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .offset(y: animate ? 0 : CGFloat(20 - index * 5))
                        .opacity(animate ? 1 : 0)
                        .animation(UIAccessibility.isReduceMotionEnabled ? .none : .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animate)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .scaleEffect(animate ? 1 : 0.9)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animate)
    }
}

// MARK: - Cost Per Use Illustration
struct CostPerUseIllustration: View {
    let colors: [Color]
    let animate: Bool

    private let bars = [
        (label: "Netflix", value: 0.85, color: Color.red),
        (label: "Spotify", value: 0.6, color: Color.green),
        (label: "Gym", value: 0.25, color: Color.blue),
        (label: "Hulu", value: 0.4, color: Color.orange)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(colors[0].opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text(LocalizedStringKey("Cost Per Use"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chart.bar.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(colors[0])
                        .accessibilityLabel("Cost per use chart")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Chart
                HStack(alignment: .bottom, spacing: 16) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                        VStack(spacing: 8) {
                            // Value label
                            Text("$\(Int(bar.value * 10))")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .opacity(animate ? 1 : 0)
                                .animation(UIAccessibility.isReduceMotionEnabled ? .none : .easeOut(duration: 0.4).delay(0.3 + Double(index) * 0.1), value: animate)

                            // Bar
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [bar.color.opacity(0.8), bar.color.opacity(0.4)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 44, height: animate ? CGFloat(bar.value * 140) : 0)
                                .animation(UIAccessibility.isReduceMotionEnabled ? .none : .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1), value: animate)

                            // Label
                            Text(bar.label)
                                .font(.caption.weight(.medium))
                                .foregroundColor(TextColors.secondary)
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 20)

                // Insight badge
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundColor(Color.luxuryGold)

                    Text("Gym costs $8.50 per visit")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.luxuryGold.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.luxuryGold.opacity(0.25), lineWidth: 1)
                        )
                )
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 10)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animate)

                Spacer()
            }
        }
        .scaleEffect(animate ? 1 : 0.9)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animate)
    }
}

// MARK: - Alerts Illustration
struct AlertsIllustration: View {
    let colors: [Color]
    let animate: Bool
    @State private var badgeScale = 0.5

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(colors[0].opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text(LocalizedStringKey("Smart Alerts"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: 22, height: 22)
                            .scaleEffect(animate ? 1 : 0)
                            .animation(UIAccessibility.isReduceMotionEnabled ? .none : .spring(response: 0.4, dampingFraction: 0.6).delay(0.3), value: animate)

                        Text("3")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .opacity(animate ? 1 : 0)
                            .animation(UIAccessibility.isReduceMotionEnabled ? .none : .easeOut(duration: 0.2).delay(0.4), value: animate)
                    }
                    .accessibilityLabel("3 alerts")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Notification cards
                VStack(spacing: 10) {
                    NotificationCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Price Increase Alert",
                        message: "Netflix is increasing to $17.99/month",
                        time: "2h ago",
                        delay: 0.1,
                        animate: animate
                    )

                    NotificationCard(
                        icon: "calendar.badge.clock",
                        iconColor: colors[0],
                        title: "Renewal Reminder",
                        message: "Spotify renews in 3 days ($10.99)",
                        time: "1d ago",
                        delay: 0.2,
                        animate: animate
                    )

                    NotificationCard(
                        icon: "checkmark.shield.fill",
                        iconColor: .green,
                        title: "Free Trial Ending",
                        message: "Hulu trial ends tomorrow. Cancel?",
                        time: "Now",
                        delay: 0.3,
                        animate: animate
                    )
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .scaleEffect(animate ? 1 : 0.9)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animate)
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let time: String
    let delay: Double
    let animate: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundColor(TextColors.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(time)
                .font(.caption.weight(.medium))
                .foregroundColor(TextColors.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .opacity(animate ? 1 : 0)
        .offset(x: animate ? 0 : 30)
        .animation(UIAccessibility.isReduceMotionEnabled ? .none : .spring(response: 0.5, dampingFraction: 0.75).delay(delay), value: animate)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(message), \(time)")
    }
}

// MARK: - Preview
#Preview {
    OnboardingCarouselView()
}
