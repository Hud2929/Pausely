import SwiftUI

struct PrivacySecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(Color.obsidianTextSecondary)
                        }

                        Spacer()

                        Text("Privacy & Security")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)

                        Spacer()

                        Color.clear.frame(width: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentMint.opacity(0.12))
                            .frame(width: 80, height: 80)

                        Image(systemName: "lock.shield.fill")
                            .font(.title)
                            .foregroundColor(Color.accentMint)
                    }

                    // How data is kept: facts, not switches.
                    settingsGroup(title: "YOUR DATA") {
                        SettingsInfoRow(icon: "lock.icloud.fill", title: "Your subscription list",
                                        detail: "Synced to Pausely's servers over an encrypted connection and encrypted at rest. Other accounts can't read it.")
                        settingsDivider()
                        SettingsInfoRow(icon: "iphone", title: "History, receipt and Pause Plan",
                                        detail: "Stay on this iPhone, protected by iOS data protection.")
                        settingsDivider()
                        SettingsInfoRow(icon: "envelope.fill", title: "Gmail import",
                                        detail: "Emails are read on this iPhone. Only the subscriptions you choose are saved.")
                        settingsDivider()
                        SettingsInfoRow(icon: "hand.raised.fill", title: "No ads, no selling data",
                                        detail: "Pausely has no ad or tracking SDKs and never sells your data.")
                    }
                    .padding(.horizontal, 20)

                    // Privacy Section
                    settingsGroup(title: "PRIVACY") {
                        SettingsNavRow(icon: "doc.text.fill", title: "Privacy Policy") { showingPrivacyPolicy = true }
                        settingsDivider()
                        SettingsNavRow(icon: "doc.fill", title: "Terms of Service") { showingTermsOfService = true }
                    }
                    .padding(.horizontal, 20)

                    // Account Section
                    settingsGroup(title: "DANGER ZONE") {
                        Button(action: { showingDeleteAccountConfirmation = true }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.semanticDestructive.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "trash.fill")
                                        .font(.callout)
                                        .foregroundColor(Color.semanticDestructive)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isDeleting ? "Deleting…" : "Delete Account")
                                        .font(.callout.weight(.semibold))
                                        .foregroundColor(Color.semanticDestructive)
                                    Text("Permanently remove your account and all its data")
                                        .font(.footnote)
                                        .foregroundColor(Color.obsidianTextSecondary)
                                }
                                Spacer()
                                if isDeleting { ProgressView().tint(Color.semanticDestructive) }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isDeleting)
                        .accessibilityIdentifier("deleteAccountButton")
                        .alert("Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
                            Button("Cancel", role: .cancel) {}
                            Button("Delete", role: .destructive) { Task { await deleteAccount() } }
                        } message: {
                            Text("This permanently deletes your account, your subscription list and your history from Pausely's servers and this iPhone. It doesn't cancel any subscriptions, including Pausely Pro; Apple manages those in Settings → Apple ID → Subscriptions.")
                        }
                        .alert("Couldn't delete your account", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text(deleteError ?? "")
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 60)
                }
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await RevolutionaryAuthManager.shared.deleteAccount()
            HapticStyle.success.trigger()
            dismiss()
        } catch {
            HapticStyle.error.trigger()
            deleteError = "Check your connection and try again. If it keeps failing, email \(AppConfig.supportEmail) and we'll delete it within 30 days. (\(error.localizedDescription))"
        }
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(Color.obsidianTextTertiary)
                .tracking(1.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private func settingsDivider() -> some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.leading, 68)
    }
}

/// A fact about how data is handled (no switch, because nothing here is optional).
struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentMint.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(Color.accentMint)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(Color.obsidianTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsNavRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentMint.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundColor(Color.accentMint)
                }
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.obsidianTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


#Preview {
    PrivacySecurityView()
}
