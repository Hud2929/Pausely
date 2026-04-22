import SwiftUI

// MARK: - Screenshot 3: Smart Alerts
// Text overlay: "Get alerts before renewals and price hikes"
// Show: Notification preview, renewal calendar
// Style: Alert cards with dates

struct Screenshot3View: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.obsidianBlack.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryGold.opacity(0.35), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.8)
                        .offset(x: -40, y: -80)
                        .blur(radius: 60)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryPink.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: 60, y: 220)
                        .blur(radius: 50)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smart Alerts")
                            .font(AppTypography.displayMedium)
                            .foregroundStyle(.white)

                        Text("Never miss a renewal or price change")
                            .font(AppTypography.bodyLarge)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Notification preview card
                    ScreenshotNotificationPreview()
                        .padding(.horizontal, 20)

                    // Renewal calendar
                    ScreenshotRenewalCalendar()
                        .padding(.horizontal, 20)

                    // Price hike alert
                    ScreenshotPriceHikeAlert()
                        .padding(.horizontal, 20)

                    // Alert settings
                    ScreenshotAlertSettings()
                        .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }

            // Screenshot text overlay
            VStack {
                Spacer()
                Text("Get alerts before renewals and price hikes")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
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
        }
    }
}

// MARK: - Components

struct ScreenshotNotificationPreview: View {
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(Color.luxuryGold)

                Text("Notification Preview")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.primary)

                Spacer()
            }

            // Simulated notification
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: "n.square.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pausely")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Now")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Text("Netflix renews in 2 days")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("$15.49 will be charged on Apr 24. Tap to review or pause.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.obsidianElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.luxuryGold.opacity(0.3), lineWidth: 1.5)
                    )
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appear = true
            }
        }
    }
}

struct ScreenshotRenewalCalendar: View {
    @State private var appear = false

    let renewals: [ScreenshotRenewalItem] = [
        ScreenshotRenewalItem(day: 22, weekday: "Tue", name: "Spotify", amount: "$10.99", isToday: true),
        ScreenshotRenewalItem(day: 24, weekday: "Thu", name: "Netflix", amount: "$15.49", isToday: false),
        ScreenshotRenewalItem(day: 28, weekday: "Mon", name: "Adobe CC", amount: "$54.99", isToday: false),
        ScreenshotRenewalItem(day: 2, weekday: "Sat", name: "Disney+", amount: "$7.99", isToday: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(Color.luxuryTeal)

                Text("Renewal Calendar")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.primary)

                Spacer()

                Text("April 2026")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(renewals) { item in
                    ScreenshotRenewalRow(item: item)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                appear = true
            }
        }
    }
}

struct ScreenshotRenewalItem: Identifiable {
    let id = UUID()
    let day: Int
    let weekday: String
    let name: String
    let amount: String
    let isToday: Bool
}

struct ScreenshotRenewalRow: View {
    let item: ScreenshotRenewalItem

    var body: some View {
        HStack(spacing: 14) {
            // Date pill
            VStack(spacing: 2) {
                Text(item.weekday)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(item.isToday ? .white : .secondary)

                Text("\(item.day)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(item.isToday ? .white : .primary)
            }
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.isToday ? Color.luxuryPurple : Color.obsidianElevated)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.primary)

                if item.isToday {
                    Text("Renews today")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(Color.luxuryPink)
                } else {
                    Text("Auto-renewal")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.amount)
                .font(AppTypography.headlineMedium)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.luxuryGold, .luxuryPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.obsidianElevated.opacity(0.5))
        )
    }
}

struct ScreenshotPriceHikeAlert: View {
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.orange)

                Text("Price Change Detected")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.primary)

                Spacer()

                Text("NEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.luxuryGold)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 48, height: 48)

                        Text("Y")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("YouTube Premium")
                            .font(AppTypography.headlineSmall)
                            .foregroundStyle(.primary)

                        Text("Price increasing next billing cycle")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.orange)
                    }

                    Spacer()
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.secondary)

                        Text("$11.99")
                            .font(AppTypography.headlineMedium)
                            .foregroundStyle(.primary)
                    }

                    Image(systemName: "arrow.right")
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("New")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.secondary)

                        Text("$13.99")
                            .font(AppTypography.headlineMedium)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("+17%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)

                        Text("+$24/yr")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: {}) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Find Cheaper Alternative")
                    }
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [.luxuryPurple, .luxuryPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                appear = true
            }
        }
    }
}

struct ScreenshotAlertSettings: View {
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.secondary)

                Text("Alert Settings")
                    .font(AppTypography.headlineMedium)
                    .foregroundStyle(.primary)

                Spacer()
            }

            VStack(spacing: 12) {
                ScreenshotAlertSettingRow(icon: "bell.fill", iconColor: .blue, title: "Renewal Reminders", subtitle: "3 days before", isOn: true)
                ScreenshotAlertSettingRow(icon: "dollarsign.circle.fill", iconColor: .green, title: "Price Change Alerts", subtitle: "Instant", isOn: true)
                ScreenshotAlertSettingRow(icon: "pause.circle.fill", iconColor: .orange, title: "Smart Pause Suggestions", subtitle: "Weekly", isOn: true)
                ScreenshotAlertSettingRow(icon: "gift.fill", iconColor: Color.luxuryGold, title: "Perk Alerts", subtitle: "When available", isOn: false)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                appear = true
            }
        }
    }
}

struct ScreenshotAlertSettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

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

            // Toggle visual
            Capsule()
                .fill(isOn ? Color.luxuryTeal : Color.obsidianElevated)
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 26, height: 26)
                        .offset(x: isOn ? 10 : -10)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    Screenshot3View()
        .preferredColorScheme(.dark)
}
