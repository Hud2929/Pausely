import SwiftUI

// MARK: - Onboarding Carousel View (Delightful Phase)
/// Value-first onboarding: shows real app UI previews BEFORE the auth wall.
/// 3-page swipeable carousel with dot indicators and glass morphism design.
struct OnboardingCarouselView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    @State private var currentPage = 0
    @State private var animateContent = false
    private let totalPages = 3

    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 0) {
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
                .padding(.top, 16)

                // Carousel
                TabView(selection: $currentPage) {
                    DashboardPreviewPage(animate: animateContent || currentPage == 0)
                        .tag(0)

                    SmartDetectionPreviewPage(animate: animateContent || currentPage == 1)
                        .tag(1)

                    InsightsPreviewPage(animate: animateContent || currentPage == 2)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .padding(.top, 16)

                Spacer()

                // Bottom Action Bar
                bottomActionBar
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

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 16) {
            Button(action: {
                HapticStyle.medium.trigger()
                onGetStarted()
            }) {
                Text("Get Started")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
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
            .accessibilityLabel("Get started")
            .pressEffect(scale: 0.97)

            Button(action: {
                HapticStyle.light.trigger()
                onSignIn()
            }) {
                Text("Already have an account? **Sign In**")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundColor(TextColors.secondary)
            }
            .accessibilityLabel("Already have an account? Sign In")
        }
    }
}

// MARK: - Page 1: Dashboard Preview
struct DashboardPreviewPage: View {
    let animate: Bool
    @State private var localAnimate = false

    private let barHeights: [Double] = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.5]

    var body: some View {
        VStack(spacing: 24) {
            // Preview Card
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.luxuryPurple.opacity(0.2), lineWidth: 1)
                    )

                VStack(spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dashboard")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundColor(.white)

                            Text("Good morning")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundColor(TextColors.secondary)
                        }

                        Spacer()

                        Circle()
                            .fill(Color.luxuryPurple.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "bell")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(Color.luxuryPurple)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Hero spend card with glass effect
                    VStack(spacing: 8) {
                        Text("$247")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundColor(.white)

                        Text("/month")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundColor(TextColors.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.luxuryPurple.opacity(0.3), Color.luxuryPink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.3))
                        }
                    )
                    .padding(.horizontal, 20)

                    // Mini bar chart
                    HStack(spacing: 8) {
                        ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.luxuryPurple.opacity(0.8), Color.luxuryPink.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 24, height: localAnimate ? CGFloat(height * 60) : 0)
                                .animation(
                                    UIAccessibility.isReduceMotionEnabled
                                        ? .none
                                        : .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.05),
                                    value: localAnimate
                                )
                        }
                    }
                    .frame(height: 60)
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .frame(height: 340)
            .padding(.horizontal, 24)
            .scaleEffect(localAnimate ? 1 : 0.92)
            .opacity(localAnimate ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: localAnimate)

            // Text content
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.luxuryPurple, Color.luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Track all your subscriptions in one place")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .opacity(localAnimate ? 1 : 0)
            .offset(y: localAnimate ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: localAnimate)

            Spacer()
        }
        .onAppear { triggerAnimation() }
        .onChange(of: animate) { _ in triggerAnimation() }
    }

    private func triggerAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            localAnimate = true
            return
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            localAnimate = true
        }
    }
}

// MARK: - Page 2: Smart Detection Preview
struct SmartDetectionPreviewPage: View {
    let animate: Bool
    @State private var localAnimate = false

    private let subs = [
        (name: "Netflix", price: "$15.99", color: Color.red, icon: "play.rectangle.fill"),
        (name: "Spotify", price: "$10.99", color: Color.green, icon: "music.note"),
        (name: "Apple One", price: "$32.95", color: Color.blue, icon: "apple.logo"),
        (name: "Disney+", price: "$7.99", color: Color.cyan, icon: "star.fill")
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Preview Card
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.luxuryTeal.opacity(0.2), lineWidth: 1)
                    )

                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Text("Your Subscriptions")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)

                        Spacer()

                        Circle()
                            .fill(Color.luxuryTeal.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(Color.luxuryTeal)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Subscription rows
                    VStack(spacing: 10) {
                        ForEach(Array(subs.enumerated()), id: \.offset) { index, sub in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(sub.color.opacity(0.2))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: sub.icon)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(sub.color)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(sub.name)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundColor(.white)

                                        if index == 1 {
                                            // Smart Detect badge
                                            Text("Smart Detect")
                                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule()
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color.luxuryPurple, Color.luxuryPink],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                        )
                                                )
                                        }
                                    }

                                    Text("Monthly")
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .foregroundColor(TextColors.secondary)
                                }

                                Spacer()

                                Text(sub.price)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                index == 1
                                                    ? Color.luxuryPurple.opacity(0.3)
                                                    : Color.white.opacity(0.06),
                                                lineWidth: index == 1 ? 1.5 : 1
                                            )
                                    )
                            )
                            .offset(y: localAnimate ? 0 : CGFloat(15 - index * 3))
                            .opacity(localAnimate ? 1 : 0)
                            .animation(
                                UIAccessibility.isReduceMotionEnabled
                                    ? .none
                                    : .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.08),
                                value: localAnimate
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .frame(height: 340)
            .padding(.horizontal, 24)
            .scaleEffect(localAnimate ? 1 : 0.92)
            .opacity(localAnimate ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: localAnimate)

            // Text content
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.luxuryTeal, Color.luxuryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("We automatically find and categorize your subscriptions")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .opacity(localAnimate ? 1 : 0)
            .offset(y: localAnimate ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: localAnimate)

            Spacer()
        }
        .onAppear { triggerAnimation() }
        .onChange(of: animate) { _ in triggerAnimation() }
    }

    private func triggerAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            localAnimate = true
            return
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            localAnimate = true
        }
    }
}

// MARK: - Page 3: Insights Preview
struct InsightsPreviewPage: View {
    let animate: Bool
    @State private var localAnimate = false

    var body: some View {
        VStack(spacing: 24) {
            // Preview Card
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.luxuryGold.opacity(0.2), lineWidth: 1)
                    )

                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Smart Insights")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "sparkles")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(Color.luxuryGold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Waste score card with circular progress
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.luxuryTeal.opacity(0.2), lineWidth: 8)
                                .frame(width: 70, height: 70)

                            Circle()
                                .trim(from: 0, to: localAnimate ? 0.72 : 0)
                                .stroke(
                                    Color.luxuryTeal,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 70, height: 70)
                                .rotationEffect(.degrees(-90))
                                .animation(
                                    UIAccessibility.isReduceMotionEnabled
                                        ? .none
                                        : .easeOut(duration: 1.0).delay(0.3),
                                    value: localAnimate
                                )

                            Text("B+")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Waste Score")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundColor(.white)

                            Text("Great! You're actively managing your subscriptions.")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundColor(TextColors.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luxuryTeal.opacity(0.08))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.3))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.luxuryTeal.opacity(0.25), lineWidth: 1)
                        }
                    )
                    .padding(.horizontal, 20)
                    .opacity(localAnimate ? 1 : 0)
                    .offset(y: localAnimate ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: localAnimate)

                    // Savings insight card
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(.title2, design: .rounded))
                            .foregroundColor(Color.luxuryGold)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("You could save $42/month")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundColor(.white)

                            Text("Switch to annual billing for 3 subscriptions")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundColor(TextColors.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundColor(TextColors.secondary)
                    }
                    .padding(16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.luxuryGold.opacity(0.08))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.3))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.luxuryGold.opacity(0.25), lineWidth: 1)
                        }
                    )
                    .padding(.horizontal, 20)
                    .opacity(localAnimate ? 1 : 0)
                    .offset(y: localAnimate ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: localAnimate)

                    Spacer()
                }
            }
            .frame(height: 340)
            .padding(.horizontal, 24)
            .scaleEffect(localAnimate ? 1 : 0.92)
            .opacity(localAnimate ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: localAnimate)

            // Text content
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.luxuryGold, Color.luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Get personalized insights to save money")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .opacity(localAnimate ? 1 : 0)
            .offset(y: localAnimate ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: localAnimate)

            Spacer()
        }
        .onAppear { triggerAnimation() }
        .onChange(of: animate) { _ in triggerAnimation() }
    }

    private func triggerAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            localAnimate = true
            return
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            localAnimate = true
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingCarouselView(
        onGetStarted: {},
        onSignIn: {}
    )
}
