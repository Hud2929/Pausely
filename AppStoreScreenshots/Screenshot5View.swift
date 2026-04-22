import SwiftUI

// MARK: - Screenshot 5: Premium Paywall
// Text overlay: "Unlock premium features"
// Show: Feature checklist, trial CTA
// Style: Premium gradient background

struct Screenshot5View: View {
    @State private var appearAnimation = false
    @State private var animateChart = false

    var body: some View {
        ZStack {
            // Premium gradient background
            ScreenshotPaywallBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Spacer()

                        Button(action: {}) {
                            Image(systemName: "xmark.circle.fill")
                                .font(AppTypography.headlineLarge)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                    // Crown icon
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 12)
                                .frame(width: 140, height: 140)

                            Circle()
                                .trim(from: 0, to: animateChart ? 0.85 : 0)
                                .stroke(
                                    AngularGradient(
                                        colors: [.luxuryGold, .luxuryPink, .luxuryPurple],
                                        center: .center,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(270)
                                    ),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))

                            Image(systemName: "crown.fill")
                                .font(AppTypography.displayLarge)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.luxuryGold, .luxuryPink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .luxuryGold.opacity(0.5), radius: 20)
                        }

                        Text("3/2 subscriptions used")
                            .font(AppTypography.headlineMedium)
                            .foregroundStyle(.white)

                        Text("You've reached your free limit")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(.luxuryGold)
                    }
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // Title and subtitle
                    VStack(spacing: 12) {
                        Text("Unlock Unlimited\nSubscriptions")
                            .font(AppTypography.displayMedium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Text("Upgrade to Pro and take full control of your subscriptions")
                            .font(AppTypography.bodyLarge)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Text("Starting at $7.99/month")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(.luxuryGold)
                    }
                    .padding(.top, 32)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // Free trial toggle
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.luxuryGold.opacity(0.15))
                                    .frame(width: 48, height: 48)

                                Image(systemName: "gift.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.luxuryGold)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Free Trial")
                                    .font(AppTypography.headlineSmall)
                                    .foregroundStyle(.white)

                                Text("Start with a 7-day free trial, cancel anytime")
                                    .font(AppTypography.bodySmall)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer()

                            // Toggle visual
                            Capsule()
                                .fill(Color.luxuryGold)
                                .frame(width: 50, height: 30)
                                .overlay(
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 26, height: 26)
                                        .offset(x: 10)
                                )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.luxuryGold.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.luxuryGold.opacity(0.25), lineWidth: 1.5)
                            )
                    )
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // Plan selection
                    VStack(spacing: 16) {
                        // Annual Plan Card
                        ScreenshotPaywallPlanCard(
                            planTitle: "Annual",
                            badge: "BEST VALUE",
                            savings: "Save 27%",
                            price: "$69.99",
                            period: "/year",
                            isSelected: true
                        )

                        // Monthly Plan Card
                        ScreenshotPaywallPlanCard(
                            planTitle: "Monthly",
                            badge: nil,
                            savings: nil,
                            price: "$7.99",
                            period: "/month",
                            isSelected: false
                        )
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // Feature comparison
                    VStack(spacing: 20) {
                        Text("What you'll get")
                            .font(AppTypography.headlineLarge)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            ScreenshotPaywallFeatureRow(icon: "infinity", title: "Unlimited Subscriptions", subtitle: "Track as many subscriptions as you want")
                            ScreenshotPaywallFeatureRow(icon: "pause.circle.fill", title: "Smart Pause", subtitle: "Pause instead of canceling subscriptions")
                            ScreenshotPaywallFeatureRow(icon: "sparkles", title: "Subscription Genius AI", subtitle: "Your 24/7 AI subscription advisor")
                            ScreenshotPaywallFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Cost Per Hour", subtitle: "See the true value of each service")
                            ScreenshotPaywallFeatureRow(icon: "bell.badge.fill", title: "Price Alerts", subtitle: "Get notified before prices increase")
                            ScreenshotPaywallFeatureRow(icon: "arrow.left.arrow.right.circle.fill", title: "Smart Alternatives", subtitle: "AI finds cheaper substitutes automatically")
                        }
                    }
                    .padding(20)
                    .glass(intensity: 0.1, tint: .white)
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // CTA Section
                    VStack(spacing: 16) {
                        Button(action: {}) {
                            VStack(spacing: 4) {
                                HStack(spacing: 12) {
                                    Image(systemName: "gift.fill")
                                        .font(AppTypography.headlineLarge)

                                    Text("Start Free Trial")
                                        .font(AppTypography.headlineMedium)
                                }

                                Text("Then $69.99/year after 7 days")
                                    .font(AppTypography.labelMedium)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [.luxuryGold, .luxuryPink],
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
                            .shadow(color: Color.luxuryGold.opacity(0.5), radius: 20, x: 0, y: 10)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {}) {
                            Text("Restore Purchases")
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(.white.opacity(0.7))
                                .underline()
                        }

                        Text("Free for 7 days, then auto-renews. Cancel anytime in App Store Settings.")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                    .padding(.horizontal, 24)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                }
            }

            // Screenshot text overlay
            VStack {
                Spacer()
                Text("Unlock premium features")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.7), .black.opacity(0.4)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(20)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateChart = true
            }
        }
    }
}

// MARK: - Paywall Background

struct ScreenshotPaywallBackground: View {
    var body: some View {
        ZStack {
            Color.deepBlack.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryPurple.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.7
                            )
                        )
                        .frame(width: geo.size.width * 0.9)
                        .offset(x: -100, y: -200)
                        .blur(radius: 80)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryPink.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.7)
                        .offset(x: 120, y: 100)
                        .blur(radius: 70)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryGold.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: -80, y: 400)
                        .blur(radius: 60)
                }
            }
        }
    }
}

// MARK: - Paywall Components

struct ScreenshotPaywallPlanCard: View {
    let planTitle: String
    let badge: String?
    let savings: String?
    let price: String
    let period: String
    let isSelected: Bool

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.luxuryGold : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(Color.luxuryGold)
                            .frame(width: 18, height: 18)

                        Image(systemName: "checkmark")
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(.black)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(planTitle)
                            .font(AppTypography.headlineMedium)
                            .foregroundStyle(.white)

                        if let badge = badge {
                            Text(badge)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.luxuryGold)
                                .cornerRadius(6)
                        }
                    }

                    if let savings = savings {
                        Text(savings)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.white)

                    Text(period)
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.luxuryPurple.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isSelected ? Color.luxuryGold : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ScreenshotPaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.luxuryGold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(.luxuryGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(AppTypography.headlineMedium)
                .foregroundColor(.green)
        }
    }
}

// MARK: - Preview

#Preview {
    Screenshot5View()
        .preferredColorScheme(.dark)
}
