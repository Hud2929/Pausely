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
                    item("12-month forecast & cut simulator", "Spot your heaviest renewal months ahead and test cancellations side by side in Insights.")
                    Hairline()
                    item("Smarter Pause Plan rotation", "Keep one streaming service on at a time, extend or switch turns live, and sync your plan across devices.")
                    Hairline()
                    item("Smarter on-device screenshot import", "Scan Apple Subscriptions or recurring charge screenshots in memory — nothing leaves your iPhone.")
                    Hairline()
                    item("Cancel & refund email drafts", "Preview and send ready-to-go cancellation or refund emails, and track every avoided charge on your Savings Receipt.")
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
                .fixedSize(horizontal: false, vertical: true)
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
    private let currentVersion = "1.12"

    func body(content: Content) -> some View {
        content
            .task {
                // UI tests and demo captures drive the app; release notes over the first screen would block them.
                if LaunchFlag.uiTesting.isSet || LaunchFlag.isDemoLaunch { return }
                if lastSeenVersion.isEmpty {
                    // Brand-new install: nothing is "new" yet, so do not greet a first-time
                    // customer with release notes before they have seen any value.
                    lastSeenVersion = currentVersion
                } else if lastSeenVersion != currentVersion {
                    try? await Task.sleep(for: .seconds(1))
                    let center = VerdictCenter.shared
                    guard !Task.isCancelled, center.presented == nil, !center.showingPausePlan,
                          !center.showingSavingsReceipt, center.subscriptionToShow == nil else { return }
                    showSheet = true
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
