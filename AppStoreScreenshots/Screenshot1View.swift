import SwiftUI

// MARK: - Screenshot 1: Dashboard Hero
// Text overlay: "All your subscriptions in one place"
// Show: Dashboard with spend chart, subscription count, monthly total
// Style: Dark theme, glass morphism cards

struct Screenshot1View: View {
    @State private var appear = false
    @State private var animateChart = false

    var body: some View {
        ZStack {
            // Background
            Color.obsidianBlack.ignoresSafeArea()

            // Animated gradient orbs (subtle, screenshot-safe)
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryPurple.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.8)
                        .offset(x: -60, y: -120)
                        .blur(radius: 60)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryPink.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: 80, y: 180)
                        .blur(radius: 50)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero Header
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Good morning")
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(.secondary)

                            Text("Dashboard")
                                .font(AppTypography.displayLarge)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            // Currency selector
                            HStack(spacing: 6) {
                                Text("🇺🇸")
                                    .font(AppTypography.bodyMedium)
                                Text("USD")
                                    .font(AppTypography.labelLarge)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )

                            // Notifications
                            Image(systemName: "bell.fill")
                                .font(AppTypography.headlineMedium)
                                .foregroundStyle(Color.luxuryGold)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : -20)

                    // Total Spend Hero Card
                    ScreenshotHeroSpendCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Quick Actions
                    ScreenshotQuickActionsGrid()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Smart Insights
                    ScreenshotSmartInsightsSection()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Upcoming Renewals
                    ScreenshotUpcomingRenewalsCarousel()
                        .padding(.top, 24)

                    Spacer(minLength: 100)
                }
            }

            // Screenshot text overlay
            VStack {
                Spacer()
                Text("All your subscriptions in one place")
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
                appear = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animateChart = true
            }
        }
    }
}

// MARK: - Screenshot-Specific Components

struct ScreenshotHeroSpendCard: View {
    @State private var appear = false
    @State private var animateChart = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spending")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text("8 active subscriptions")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Timeframe selector
                HStack(spacing: 0) {
                    ForEach(["W", "M", "Y"], id: \.self) { tf in
                        Text(tf)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(tf == "M" ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(tf == "M" ? Color.luxuryPurple : Color.clear)
                            )
                    }
                }
                .padding(4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }

            // Chart + Amount
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.obsidianElevated, lineWidth: 12)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: animateChart ? 0.75 : 0)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.accentMint,
                                    Color.accentMint.opacity(0.6),
                                    Color.luxuryPurple,
                                    Color.luxuryPink,
                                    Color.luxuryGold,
                                    Color.accentMint
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("$")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.obsidianTextSecondary)

                        Text("142")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.obsidianText)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("$142.47")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.luxuryGold, .luxuryPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("per month")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Stats row
            HStack(spacing: 12) {
                ScreenshotHeroStatPill(title: "Monthly", value: "$142", color: Color.accentMint)
                ScreenshotHeroStatPill(title: "Yearly", value: "$1,710", color: Color.luxuryGold)
                ScreenshotHeroStatPill(title: "Weekly", value: "$33", color: Color.luxuryPurple)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
        .shadow(color: .luxuryPurple.opacity(0.15), radius: 30, x: 0, y: 15)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateChart = true
            }
        }
    }
}

struct ScreenshotHeroStatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ScreenshotQuickActionsGrid: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                ScreenshotQuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add",
                    subtitle: "New",
                    gradient: [.luxuryTeal, .luxuryPurple]
                )

                ScreenshotQuickActionButton(
                    icon: "pause.circle.fill",
                    title: "Pause",
                    subtitle: "3 avail",
                    gradient: [.luxuryPink, .orange]
                )

                ScreenshotQuickActionButton(
                    icon: "chart.pie.fill",
                    title: "Compare",
                    subtitle: "Analyze",
                    gradient: [.luxuryGold, .luxuryPink]
                )
            }
        }
    }
}

struct ScreenshotQuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: gradient[0].opacity(0.4), radius: 10, x: 0, y: 5)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassBackground(cornerRadius: 20, strokeColor: .white.opacity(0.2), strokeWidth: 0.5)
    }
}

struct ScreenshotSmartInsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Insights")
                .font(AppTypography.headlineLarge)
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                ScreenshotDashboardInsightCard(
                    icon: "leaf.fill",
                    iconColor: .green,
                    title: "Potential Savings",
                    subtitle: "From low-usage subscriptions",
                    value: "$24",
                    valueColor: .green
                )

                ScreenshotDashboardInsightCard(
                    icon: "gift.fill",
                    iconColor: Color.luxuryGold,
                    title: "Available Perks",
                    subtitle: "From your subscriptions",
                    value: "3",
                    valueColor: Color.luxuryGold
                )

                ScreenshotDashboardInsightCard(
                    icon: "checkmark.shield.fill",
                    iconColor: .green,
                    title: "Usage Tracking",
                    subtitle: "Data available",
                    value: "Active",
                    valueColor: .green
                )
            }
        }
    }
}

struct ScreenshotDashboardInsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(AppTypography.headlineMedium)
                .foregroundStyle(valueColor)
        }
        .padding(14)
        .glassBackground(cornerRadius: 16, strokeColor: .white.opacity(0.1), strokeWidth: 0.5)
    }
}

struct ScreenshotUpcomingRenewalsCarousel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Text("3 this week")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ScreenshotRenewalCard(name: "Netflix", days: 2, amount: "$15.49", color: .red)
                    ScreenshotRenewalCard(name: "Spotify", days: 4, amount: "$10.99", color: .green)
                    ScreenshotRenewalCard(name: "Adobe CC", days: 6, amount: "$54.99", color: .red)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ScreenshotRenewalCard: View {
    let name: String
    let days: Int
    let amount: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(days)d")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(Capsule())
            }

            Spacer()

            Text(name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(amount)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 120, height: 120)
        .glassBackground(cornerRadius: 20, strokeColor: color.opacity(0.3), strokeWidth: 1)
    }
}

// MARK: - Preview

#Preview {
    Screenshot1View()
        .preferredColorScheme(.dark)
}
