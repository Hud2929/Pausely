import SwiftUI

// MARK: - What's New Sheet
/// Shows new features for the current app version. Only appears once per version.
struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The version the customer is actually running (not the content id below).
    private let displayVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(displayVersion.isEmpty ? "What's New" : "What's New in \(displayVersion)")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 32)
                .accessibilityAddTraits(.isHeader)

            // Only what this build really does.
            VStack(alignment: .leading, spacing: 0) {
                item("A new look", "Pausely is ink and paper now: your decisions and your savings are printed on slips.")
                Hairline()
                item("The next 30 days on one line", "Home shows every charge that's coming and what leaves by any day.")
                Hairline()
                item("Keep or cancel, on a slip", "Keeping stamps it. Cancelling tears it and adds it to your Savings Receipt.")
            }
            .padding(.top, 20)

            Spacer(minLength: 24)

            Button { dismiss() } label: { Text("Continue") }
                .buttonStyle(.ink)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, Layout.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func item(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
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
    private let currentVersion = "1.10"

    func body(content: Content) -> some View {
        content
            .onAppear {
                // UI tests drive the app; release notes over the first screen would block them.
                if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
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
