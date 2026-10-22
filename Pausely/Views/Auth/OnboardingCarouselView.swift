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
                            .fill(currentPage == index ? Color.accentMint : Color.white.opacity(0.2))
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

                    DecisionPreviewPage(animate: animateContent || currentPage == 1)
                        .tag(1)

                    ReceiptPreviewPage(animate: animateContent || currentPage == 2)
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
        .onChange(of: currentPage) { _, _ in
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
                                        colors: [Color.accentMint, Color.accentMint],
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
                    .shadow(color: Color.accentMint.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .accessibilityIdentifier("getStartedButton")
            .pressEffect(scale: 0.97)

            Button(action: {
                HapticStyle.light.trigger()
                onSignIn()
            }) {
                Text("Already have an account? **Sign In**")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundColor(Color.obsidianTextSecondary)
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
                            .stroke(Color.accentMint.opacity(0.2), lineWidth: 1)
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
                                .foregroundColor(Color.obsidianTextSecondary)
                        }

                        Spacer()

                        Circle()
                            .fill(Color.accentMint.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "bell")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(Color.accentMint)
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
                            .foregroundColor(Color.obsidianTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentMint.opacity(0.3), Color.accentMint.opacity(0.1)],
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
                                        colors: [Color.accentMint.opacity(0.8), Color.accentMint.opacity(0.5)],
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

            OnboardingHeadline(
                title: "Know every renewal before it hits",
                subtitle: "Everything you subscribe to, what it costs, and the day each one charges you."
            )
            .padding(.horizontal, 32)
            .opacity(localAnimate ? 1 : 0)
            .offset(y: localAnimate ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: localAnimate)

            Spacer()
        }
        .onAppear { triggerAnimation() }
        .onChange(of: animate) { _, _ in triggerAnimation() }
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

// MARK: - Headline

/// Title and one line of explanation under each onboarding preview.
struct OnboardingHeadline: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.obsidianTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Page 2: Renewal Verdict Preview

struct DecisionPreviewPage: View {
    let animate: Bool
    @State private var localAnimate = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 14) {
                // The reminder
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentMint)
                        .frame(width: 38, height: 38)
                        .overlay(Image(systemName: "pause.fill").foregroundColor(.black).font(.system(size: 16, weight: .bold)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Netflix renews in 2 days")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(.white)
                        Text("$17.99 on Thursday. Keep it or cancel it?")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(Color.obsidianTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
                .offset(y: localAnimate ? 0 : -14)
                .opacity(localAnimate ? 1 : 0)
                .animation(UIAccessibility.isReduceMotionEnabled ? .none : .spring(response: 0.5, dampingFraction: 0.75), value: localAnimate)

                // The decision
                VStack(spacing: 12) {
                    Text("Keep Netflix?")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 8) {
                        previewFact("calendar", "That's $215.88 a year")
                        previewFact("hourglass", "Used 2 hours this month · $9.00 an hour")
                        previewFact("clock", "Cancel now and you keep it until Thursday")
                    }
                    HStack(spacing: 10) {
                        Text("Keep it")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentMint))
                        Text("Cancel it")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.15)))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.accentMint.opacity(0.2), lineWidth: 1))
                )
                .scaleEffect(localAnimate ? 1 : 0.94)
                .opacity(localAnimate ? 1 : 0)
                .animation(UIAccessibility.isReduceMotionEnabled ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: localAnimate)
            }
            .padding(.horizontal, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Example: a reminder that Netflix renews in 2 days, with Keep it and Cancel it buttons")

            OnboardingHeadline(
                title: "Keep it or cancel it, in one tap",
                subtitle: "Before every renewal Pausely asks, with the facts that help you decide."
            )
            .opacity(localAnimate ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: localAnimate)

            Spacer()
        }
        .onAppear { triggerAnimation() }
        .onChange(of: animate) { _, _ in triggerAnimation() }
    }

    private func previewFact(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.accentMint)
                .frame(width: 18)
            Text(text)
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.white)
            Spacer(minLength: 0)
        }
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

// MARK: - Page 3: Savings Receipt Preview

struct ReceiptPreviewPage: View {
    let animate: Bool
    @State private var localAnimate = false

    private let lines: [(name: String, detail: LocalizedStringKey, amount: String)] = [
        ("Hulu", "Cancelled · 12 charges avoided", "$227.88"),
        ("Gym app", "Free trial cancelled in time", "$29.99"),
        ("Cloud storage", "Duplicate cancelled · 4 charges", "$11.96")
    ]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("SAVED WITH PAUSELY")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .tracking(2)
                        .foregroundColor(Color.obsidianTextTertiary)
                    Text("$269.83")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(Color.accentMint)
                    Text("Pausely paid for itself 9×")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentMint.opacity(0.15)))
                }
                VStack(spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        if index > 0 { Divider().background(Color.white.opacity(0.08)) }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundColor(.white)
                                Text(line.detail)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(Color.obsidianTextSecondary)
                            }
                            Spacer()
                            Text(line.amount)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundColor(Color.accentMint)
                        }
                        .padding(.vertical, 10)
                        .opacity(localAnimate ? 1 : 0)
                        .offset(y: localAnimate ? 0 : 10)
                        .animation(UIAccessibility.isReduceMotionEnabled ? .none : .spring(response: 0.5, dampingFraction: 0.8).delay(0.15 + Double(index) * 0.08), value: localAnimate)
                    }
                }
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.accentMint.opacity(0.2), lineWidth: 1))
            )
            .padding(.horizontal, 24)
            .scaleEffect(localAnimate ? 1 : 0.94)
            .opacity(localAnimate ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: localAnimate)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Example Savings Receipt: $269.83 saved, Pausely paid for itself 9 times")

            OnboardingHeadline(
                title: "See exactly what you saved",
                subtitle: "Every cancellation lands on your Savings Receipt, with the charges it avoided."
            )
            .opacity(localAnimate ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: localAnimate)

            Spacer()
        }
        .onAppear { triggerAnimation() }
        .onChange(of: animate) { _, _ in triggerAnimation() }
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
