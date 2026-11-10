import SwiftUI

// MARK: - What's New Sheet
/// Shows new features for the current app version. Only appears once per version.
struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The version the customer is actually running (not the content id below).
    private let displayVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                Color.inkText
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "sparkles")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                    }

                    Text(displayVersion.isEmpty ? "What's New" : "What's New in \(displayVersion)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.center)

                    Text("Check out the latest improvements")
                        .font(.body)
                        .foregroundColor(Color.inkTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)

                // Feature list
                VStack(spacing: 16) {
                    WhatsNewFeatureRow(
                        icon: "arrow.down.circle.fill",
                        iconColor: Color.inkText,
                        title: "Pull to Refresh",
                        description: "Swipe down on your Dashboard to instantly refresh your subscription data."
                    )

                    WhatsNewFeatureRow(
                        icon: "gift.fill",
                        iconColor: Color.inkText,
                        title: "First-Subscription Celebration",
                        description: "Enjoy a fun confetti animation when you add your very first subscription."
                    )

                    WhatsNewFeatureRow(
                        icon: "star.fill",
                        iconColor: Color.inkText,
                        title: "What's New Updates",
                        description: "Stay in the loop with a quick summary of new features after every update."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)

                Spacer()

                // Continue button
                Button(action: {
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    Color.inkText
                                )
                        )
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
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.inkText)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.inkRaised)
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

    /// Identifies the current What's New content. Bump it only when the sheet's content changes.
    private let currentVersion = "1.05"

    func body(content: Content) -> some View {
        content
            .onAppear {
                if lastSeenVersion.isEmpty {
                    // Brand-new install: nothing is "new" yet, so do not greet a first-time
                    // customer with release notes before they have seen any value.
                    lastSeenVersion = currentVersion
                } else if lastSeenVersion != currentVersion {
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
