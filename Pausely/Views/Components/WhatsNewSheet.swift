import SwiftUI

// MARK: - What's New Sheet
/// Shows new features for the current app version. Only appears once per version.
struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let currentVersion = "1.05"

    var body: some View {
        ZStack {
            PremiumBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.luxuryGold.opacity(0.3), Color.luxuryPink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "sparkles")
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.luxuryGold)
                    }

                    Text("What's New in \(currentVersion)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Check out the latest improvements")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)

                // Feature list
                VStack(spacing: 16) {
                    WhatsNewFeatureRow(
                        icon: "arrow.down.circle.fill",
                        iconColor: Color.luxuryTeal,
                        title: "Pull to Refresh",
                        description: "Swipe down on your Dashboard to instantly refresh your subscription data."
                    )

                    WhatsNewFeatureRow(
                        icon: "gift.fill",
                        iconColor: Color.luxuryGold,
                        title: "First-Subscription Celebration",
                        description: "Enjoy a fun confetti animation when you add your very first subscription."
                    )

                    WhatsNewFeatureRow(
                        icon: "star.fill",
                        iconColor: Color.luxuryPink,
                        title: "What's New Updates",
                        description: "Stay in the loop with a quick summary of new features after every update."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)

                Spacer()

                // Continue button
                Button(action: {
                    HapticStyle.medium.trigger()
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.system(.body, design: .rounded).weight(.semibold))
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
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Feature Row
struct WhatsNewFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(.title2, design: .rounded))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(TextColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BackgroundColors.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - View Modifier
extension View {
    /// Presents the What's New sheet automatically when the app version changes.
    func whatsNewSheet() -> some View {
        modifier(WhatsNewSheetModifier())
    }
}

struct WhatsNewSheetModifier: ViewModifier {
    @AppStorage("lastSeenVersion") private var lastSeenVersion: String = ""
    @State private var showSheet = false

    private let currentVersion = "1.05"

    func body(content: Content) -> some View {
        content
            .onAppear {
                if lastSeenVersion != currentVersion {
                    // Small delay so it doesn't clash with splash/onboarding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showSheet = true
                    }
                }
            }
            .sheet(isPresented: $showSheet, onDismiss: {
                lastSeenVersion = currentVersion
            }) {
                WhatsNewSheet()
            }
    }
}

// MARK: - Preview
#Preview {
    WhatsNewSheet()
}
