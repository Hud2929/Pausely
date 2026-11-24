import SwiftUI

// MARK: - What's New Sheet
/// Shows new features for the current app version. Only appears once per version.
struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The version the customer is actually running (not the content id below).
    private let displayVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    var body: some View {
        // The words scroll and the button stays put (at the accessibility sizes it follows them).
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                Text(displayVersion.isEmpty ? "What's new" : "What's new in \(displayVersion)")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 32)
                    .accessibilityAddTraits(.isHeader)

                // Only what this build really does.
                VStack(alignment: .leading, spacing: 0) {
                    item("Import from screenshots", "Pick a screenshot of Apple Subscriptions or your recurring charges and read it on this iPhone.")
                    Hairline()
                    item("Try without an account", "Start locally on your device and sign in later if you want backup across devices.")
                    Hairline()
                    item("Shared plans, billing notes, and overlaps", "Split shared subscriptions, note which card or store bills them, and spot overlapping services in Insights.")
                    Hairline()
                    item("Cancel and refund email drafts", "Preview and send ready-to-go cancellation or refund emails, plus Savings Receipt and Pause Plan sync.")
                }
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The margin is inside the scroll view, which is as wide as the sheet: around it, the
            // words were cut at the margin as they scrolled.
            .padding(.horizontal, Layout.margin)
        } actions: {
            Button { dismiss() } label: { Text("Continue") }
                .buttonStyle(.ink)
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .inkScreen()
        .preferredColorScheme(.dark)
    }

    private func item(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
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
    private let currentVersion = "1.11"

    func body(content: Content) -> some View {
        content
            .onAppear {
                // UI tests drive the app; release notes over the first screen would block them.
                if LaunchFlag.uiTesting.isSet { return }
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
