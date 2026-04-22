import SwiftUI

// MARK: - Screenshot 2: Cost Per Use
// Text overlay: "Know what each subscription costs per use"
// Show: Cost-per-use card with value score
// Style: Color-coded value badges

struct Screenshot2View: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.obsidianBlack.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryTeal.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.8)
                        .offset(x: 60, y: -100)
                        .blur(radius: 60)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.luxuryPurple.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: -80, y: 200)
                        .blur(radius: 50)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cost Per Hour")
                            .font(AppTypography.displayMedium)
                            .foregroundStyle(.white)

                        Text("See the true value of every subscription")
                            .font(AppTypography.bodyLarge)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Featured cost-per-hour card (Netflix - great value)
                    ScreenshotCostPerHourCard(
                        subscription: ScreenshotSubscription(
                            name: "Netflix",
                            category: "Entertainment",
                            monthlyCost: 15.49,
                            usageMinutes: 1240,
                            costPerHour: 0.75,
                            efficiency: .great
                        ),
                        isFeatured: true
                    )
                    .padding(.horizontal, 20)

                    // Other subscriptions
                    VStack(spacing: 12) {
                        ScreenshotCostPerHourCard(
                            subscription: ScreenshotSubscription(
                                name: "Spotify",
                                category: "Music",
                                monthlyCost: 10.99,
                                usageMinutes: 890,
                                costPerHour: 0.74,
                                efficiency: .great
                            ),
                            isFeatured: false
                        )

                        ScreenshotCostPerHourCard(
                            subscription: ScreenshotSubscription(
                                name: "Adobe CC",
                                category: "Productivity",
                                monthlyCost: 54.99,
                                usageMinutes: 180,
                                costPerHour: 18.33,
                                efficiency: .poor
                            ),
                            isFeatured: false
                        )

                        ScreenshotCostPerHourCard(
                            subscription: ScreenshotSubscription(
                                name: "Gym Membership",
                                category: "Health",
                                monthlyCost: 49.99,
                                usageMinutes: 320,
                                costPerHour: 9.37,
                                efficiency: .fair
                            ),
                            isFeatured: false
                        )
                    }
                    .padding(.horizontal, 20)

                    // Value legend
                    ScreenshotValueLegend()
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Spacer(minLength: 100)
                }
            }

            // Screenshot text overlay
            VStack {
                Spacer()
                Text("Know what each subscription costs per use")
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

// MARK: - Data Model

struct ScreenshotSubscription {
    let name: String
    let category: String
    let monthlyCost: Double
    let usageMinutes: Int
    let costPerHour: Double
    let efficiency: ScreenshotEfficiency
}

enum ScreenshotEfficiency {
    case great, good, fair, poor

    var label: String {
        switch self {
        case .great: return "Great Value!"
        case .good: return "Good Value"
        case .fair: return "Fair Value"
        case .poor: return "Poor Value"
        }
    }

    var color: Color {
        switch self {
        case .great: return .green
        case .good: return Color.accentMint
        case .fair: return .yellow
        case .poor: return .red
        }
    }

    var icon: String {
        switch self {
        case .great: return "checkmark.seal.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Components

struct ScreenshotCostPerHourCard: View {
    let subscription: ScreenshotSubscription
    let isFeatured: Bool
    @State private var appear = false

    var usageHours: String {
        let hours = subscription.usageMinutes / 60
        let mins = subscription.usageMinutes % 60
        if mins > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(hours)h"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [categoryColor.opacity(0.4), categoryColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Text(String(subscription.name.prefix(1)))
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name)
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(.primary)

                    Text(subscription.category)
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Value badge
                HStack(spacing: 4) {
                    Image(systemName: subscription.efficiency.icon)
                        .font(.caption2)
                    Text(subscription.efficiency.label)
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundStyle(subscription.efficiency.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(subscription.efficiency.color.opacity(0.15))
                .clipShape(Capsule())
            }

            Divider()
                .background(Color.white.opacity(0.08))

            HStack(spacing: 20) {
                // Monthly cost
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)

                    Text(String(format: "$%.2f", subscription.monthlyCost))
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.luxuryGold, .luxuryPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                // Usage
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)

                    Text(usageHours)
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Cost per hour (hero number)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Per Hour")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)

                    Text(String(format: "$%.2f", subscription.costPerHour))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(subscription.efficiency.color)
                }
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.obsidianElevated)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [subscription.efficiency.color, subscription.efficiency.color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(CGFloat(subscription.usageMinutes) / 1500, 1.0), height: 8)
                        .animation(.easeOut(duration: 1.0).delay(0.3), value: appear)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isFeatured ? subscription.efficiency.color.opacity(0.4) : Color.obsidianBorder, lineWidth: isFeatured ? 2 : 1)
                )
        )
        .shadow(color: isFeatured ? subscription.efficiency.color.opacity(0.15) : .clear, radius: 20, x: 0, y: 10)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(isFeatured ? 0.1 : 0.2)) {
                appear = true
            }
        }
    }

    var categoryColor: Color {
        switch subscription.category.lowercased() {
        case "entertainment": return .red
        case "music": return .pink
        case "productivity": return .green
        case "health": return Color.accentMint
        default: return .purple
        }
    }
}

struct ScreenshotValueLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Value Scale")
                .font(AppTypography.headlineSmall)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                ScreenshotLegendItem(color: .green, label: "<$5/hr", description: "Great")
                ScreenshotLegendItem(color: Color.accentMint, label: "$5-10", description: "Good")
                ScreenshotLegendItem(color: .yellow, label: "$10-20", description: "Fair")
                ScreenshotLegendItem(color: .red, label: ">$20/hr", description: "Poor")
            }
        }
        .padding(16)
        .glassBackground(cornerRadius: 20, strokeColor: .white.opacity(0.1), strokeWidth: 0.5)
    }
}

struct ScreenshotLegendItem: View {
    let color: Color
    let label: String
    let description: String

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(description)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    Screenshot2View()
        .preferredColorScheme(.dark)
}
