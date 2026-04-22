import SwiftUI

// MARK: - Screenshot 4: Subscription Detail
// Text overlay: "Track usage and find savings"
// Show: Subscription detail with usage chart, pause button
// Style: Clean detail view

struct Screenshot4View: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.obsidianBlack.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryPurple.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.8)
                        .offset(x: 40, y: -60)
                        .blur(radius: 60)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryTeal.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: -60, y: 250)
                        .blur(radius: 50)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with subscription info
                    ScreenshotDetailHeader()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Usage tracking section
                    ScreenshotDetailUsageSection()
                        .padding(.horizontal, 20)

                    // Quick actions
                    ScreenshotDetailActionsSection()
                        .padding(.horizontal, 20)

                    // Alternatives
                    ScreenshotDetailAlternativesSection()
                        .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }

            // Screenshot text overlay
            VStack {
                Spacer()
                Text("Track usage and find savings")
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
        }
    }
}

// MARK: - Components

struct ScreenshotDetailHeader: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text("N")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Netflix")
                .font(.title.bold())
                .foregroundColor(.primary)

            Text("$15.49/month")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Usage badge
            HStack {
                Image(systemName: "clock")
                Text("This month: 20h 40m")
                ScreenshotTrackedBadge()
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.2))
            .foregroundStyle(.green)
            .cornerRadius(8)

            // Cost per hour badge
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text("Cost per hour: $0.75")
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.2))
            .foregroundStyle(.green)
            .cornerRadius(8)

            // Difficulty badge
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Cancellation: Easy")
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.2))
            .foregroundColor(.green)
            .cornerRadius(8)
        }
        .padding(24)
        .glassCard(color: .red)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appear = true
            }
        }
    }
}

struct ScreenshotTrackedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
            Text("Tracked")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.green)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.2))
        .cornerRadius(4)
    }
}

struct ScreenshotDetailUsageSection: View {
    @State private var appear = false

    let dailyUsage: [Int] = [120, 90, 180, 60, 240, 150, 200]
    let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Usage Tracking")
                    .font(.system(size: 17, weight: .bold, design: .rounded))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption)
                    Text("Manual")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.secondary)
                .cornerRadius(8)
            }

            // Main usage display
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("This Month's Usage")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            ScreenshotTrackedBadge()
                        }

                        Text("20h 40m")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text("Updated 2 hours ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Usage indicator ring
                    ZStack {
                        Circle()
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: 0.69)
                            .stroke(.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("69%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            Text("of 30h")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                // Cost per hour section
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost Per Hour")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Text("$0.75")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Great Value!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)

                        Text("Excellent value!")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Usage bar chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        ForEach(0..<7) { day in
                            let minutes = dailyUsage[day]
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(minutes > 0 ? Color.green : Color.gray.opacity(0.2))
                                    .frame(height: max(CGFloat(minutes) / 240 * 40, 4))

                                Text(days[day])
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 50)
                }
            }
            .padding()
            .background(Color.obsidianElevated)
            .cornerRadius(16)
        }
        .padding(20)
        .background(Color.obsidianSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.obsidianBorder, lineWidth: 1)
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

struct ScreenshotDetailActionsSection: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                ScreenshotDetailActionButton(
                    title: "Cancel Subscription",
                    subtitle: "One-tap cancel link",
                    icon: "xmark.circle.fill",
                    color: .red
                )

                ScreenshotDetailActionButton(
                    title: "Pause Subscription",
                    subtitle: "Temporarily pause billing",
                    icon: "pause.circle.fill",
                    color: .orange
                )

                ScreenshotDetailActionButton(
                    title: "View Usage History",
                    subtitle: "See past months",
                    icon: "chart.bar.fill",
                    color: .blue
                )

                ScreenshotDetailActionButton(
                    title: "Edit Details",
                    subtitle: "Update amount or billing",
                    icon: "pencil.circle.fill",
                    color: .blue
                )
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                appear = true
            }
        }
    }
}

struct ScreenshotDetailActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.obsidianElevated)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ScreenshotDetailAlternativesSection: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Cheaper Alternatives")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 10) {
                ScreenshotAlternativeRow(
                    name: "Hulu",
                    description: "Ad-supported streaming",
                    rating: 4.2,
                    price: 7.99,
                    savings: 90.00
                )

                ScreenshotAlternativeRow(
                    name: "Disney+ Bundle",
                    description: "Disney+, Hulu, ESPN+",
                    rating: 4.5,
                    price: 14.99,
                    savings: 6.00
                )
            }
        }
        .padding(20)
        .background(Color.obsidianSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.obsidianBorder, lineWidth: 1)
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

struct ScreenshotAlternativeRow: View {
    let name: String
    let description: String
    let rating: Double
    let price: Double
    let savings: Double

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text(String(format: "$%.2f/mo", price))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if savings > 0 {
                    Text(String(format: "Save $%.0f", savings))
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.obsidianElevated)
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    Screenshot4View()
        .preferredColorScheme(.dark)
}
