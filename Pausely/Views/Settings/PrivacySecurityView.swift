import SwiftUI

/// Where a person's data lives, the two documents that govern it, and the way to delete all of it.
/// Every statement here describes what the build does; a row for a feature that is switched off is not shown.
struct PrivacySecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false

    var body: some View {
        SettingsPage(title: "Privacy & Security") {
            SettingsSection(title: "Your data") {
                SettingsRow(title: L10n.string("Your subscription list"),
                            detail: L10n.string("Synced to Pausely's servers over an encrypted connection and encrypted at rest. Other accounts can't read it."))
                SettingsRow(title: L10n.string("History, receipt and Pause Plan"),
                            detail: L10n.string("Stay on this iPhone, protected by iOS data protection."))
                if FeatureFlags.inboxImportEnabled {
                    SettingsRow(title: L10n.string("Find in Email"),
                                detail: L10n.string("Receipts are read on this iPhone. Only the name, amount and date of each charge are kept."))
                }
                SettingsRow(title: L10n.string("No ads, no selling data"),
                            detail: L10n.string("Pausely has no ad or tracking SDKs and never sells your data."))
            }

            SettingsSection(title: "The documents") {
                Button { showingPrivacyPolicy = true } label: {
                    SettingsRow(title: L10n.string("Privacy Policy")) { RowChevron() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("privacyPolicyRow")
                Button { showingTermsOfService = true } label: {
                    SettingsRow(title: L10n.string("Terms of Service")) { RowChevron() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("termsRow")
            }

            SettingsSection(title: "Your account") {
                Button { showingDeleteAccountConfirmation = true } label: {
                    SettingsRow(title: L10n.string("Delete Account"),
                                detail: L10n.string("Permanently remove your account and all its data"), titleColor: .due) {
                        if isDeleting { ProgressView().tint(Color.inkText) }
                    }
                }
                .buttonStyle(.plain)
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
            Feel.landed()
            dismiss()
        } catch {
            deleteError = L10n.string("Check your connection and try again. If it keeps failing, email \(AppConfig.supportEmail) and we'll delete it within 30 days.")
        }
    }

}
