import SwiftUI

/// Which inbox to connect: a row for each kind this build offers. A provider with its own sign-in is
/// opened from here; an inbox reached with an app password is handed to the screen, which opens the
/// form for it.
struct InboxProviderList: View {
    /// Called as a row is chosen, before its sign-in opens: a sheet showing this list closes on it.
    let onChoose: () -> Void
    /// An inbox reached with an app password: its preset, or nil for any other server.
    let onAppPassword: (IMAPPreset?) -> Void

    @ObservedObject private var scanner = InboxScanner.shared
    /// The provider whose sign-in is being opened: its row shows that it was heard until the web
    /// sheet arrives (nothing changed for a second or two, and a second tap started a second sign-in).
    @State private var connectingID: String?

    /// Gmail by app password is listed only where "Sign in with Google" isn't: two Gmail rows side by side
    /// asked people to choose between ways in they couldn't tell apart (A14, 2026-11-22). A gmail.com
    /// address typed under "Other email" still finds it (`IMAPPreset.forAddress`).
    private var googleSignIn: Bool { FeatureFlags.gmailImportEnabled && GmailMailboxProvider.isConfigured }

    var body: some View {
        VStack(spacing: 0) {
            if googleSignIn {
                row(Text(verbatim: "Gmail"), detail: Text("Sign in with Google"), icon: "Gmail", id: "connectGmail") {
                    onChoose()
                    connect("connectGmail") { await scanner.connectGmail() }
                }
            }
            if FeatureFlags.microsoftImportEnabled && MicrosoftGraphProvider.isConfigured {
                row(Text(verbatim: "Outlook, Hotmail, Live, MSN"), detail: Text("Sign in with Microsoft"), icon: "Outlook", id: "connectMicrosoft") {
                    onChoose()
                    connect("connectMicrosoft") { await scanner.connectMicrosoft() }
                }
            }
            if FeatureFlags.imapImportEnabled {
                ForEach(googleSignIn ? ["icloud", "yahoo", "aol"] : ["icloud", "yahoo", "aol", "gmail-imap"], id: \.self) { id in
                    if let preset = IMAPPreset.find(id) {
                        row(Text(verbatim: preset.name), detail: Text("With an app password"), icon: preset.name, id: "connect-\(id)") {
                            onAppPassword(preset)
                        }
                    }
                }
                row(Text("Other email"), detail: Text("GMX, WEB.DE, Zoho, Fastmail and more"), icon: "", id: "connect-other") {
                    onAppPassword(nil)
                }
            }
        }
    }

    /// Opens a provider's sign-in once: while it is on its way, its row shows a spinner and no
    /// row takes another tap.
    private func connect(_ id: String, _ signIn: @escaping () async -> Void) {
        guard connectingID == nil else { return }
        connectingID = id
        Task {
            await signIn()
            connectingID = nil
        }
    }

    private func row(_ title: Text, detail: Text, icon: String, id: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    // The mark is above its words at the accessibility text sizes, like every
                    // other mark: beside them it left "Other email" a column one word wide, and
                    // the envelope, drawn at the text's size in a box 36 points wide, ran out of
                    // the row and into the words (seen 2026-11-17).
                    MarkedWords(alignment: .center, spacing: 12) {
                        if icon.isEmpty {
                            Image(systemName: "envelope")
                                .font(.body)
                                .foregroundStyle(Color.inkTextMuted)
                                .frame(minWidth: 36, minHeight: 36)
                                .accessibilityHidden(true)
                        } else {
                            ServiceLogoView(name: icon, category: nil, size: 36)
                        }
                    } words: {
                        VStack(alignment: .leading, spacing: 2) {
                            title
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.inkText)
                                .multilineTextAlignment(.leading)
                            detail
                                .font(.subheadline)
                                .foregroundStyle(Color.inkTextMuted)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 8)
                    if connectingID == id {
                        ProgressView().tint(Color.inkTextMuted)
                    } else {
                        RowChevron()
                    }
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(connectingID != nil)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(id)
            Hairline()
        }
    }
}
