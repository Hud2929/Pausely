import SwiftUI

struct PrivacySecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("biometricEnabled") private var biometricEnabled = true
    @AppStorage("faceIDEnabled") private var faceIDEnabled = true
    @AppStorage("dataEncryption") private var dataEncryption = true
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var changePasswordActive = false

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

                    // Security Section
                    settingsGroup(title: "SECURITY") {
                        SettingsToggleRow(icon: "touchid", title: "Biometric Authentication", subtitle: "Use Face ID or Touch ID", isOn: $biometricEnabled)
                        settingsDivider()
                        SettingsToggleRow(icon: "faceid", title: "Face ID", subtitle: "Enable Face ID for app access", isOn: $faceIDEnabled)
                        settingsDivider()
                        SettingsToggleRow(icon: "lock.fill", title: "End-to-End Encryption", subtitle: "Your data is always encrypted", isOn: $dataEncryption)
                    }
                    .padding(.horizontal, 20)

                    // Privacy Section
                    settingsGroup(title: "PRIVACY") {
                        SettingsToggleRow(icon: "chart.bar.fill", title: "Analytics", subtitle: "Help improve the app with usage data", isOn: $analyticsEnabled)
                        settingsDivider()
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
                                    Text("Delete Account")
                                        .font(.callout.weight(.semibold))
                                        .foregroundColor(Color.semanticDestructive)
                                    Text("Permanently remove all data")
                                        .font(.footnote)
                                        .foregroundColor(Color.obsidianTextSecondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .alert("Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
                            Button("Cancel", role: .cancel) {}
                            Button("Delete", role: .destructive) {}
                        } message: {
                            Text("This will permanently delete all your data. This action cannot be undone.")
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

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentMint.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(Color.accentMint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(Color.obsidianTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(Color.accentMint)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

// NavigationButton kept for backwards compatibility with any remaining legacy callers
struct NavigationButton: View {
    let icon: String
    let title: String
    let glowColor: Color
    let action: () -> Void

    var body: some View {
        SettingsNavRow(icon: icon, title: title, action: action)
    }
}

// SecurityToggleRow kept for backwards compatibility
struct SecurityToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let glowColor: Color
    var onToggle: ((Bool) -> Void)? = nil

    var body: some View {
        SettingsToggleRow(icon: icon, title: title, subtitle: subtitle, isOn: $isOn)
            .onChange(of: isOn) { _, newValue in onToggle?(newValue) }
    }
}

#Preview {
    PrivacySecurityView()
}
