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
        SettingsPage(title: "Privacy & security") {
            SettingsSection(title: "Your data") {
                SettingsRow(title: L10n.string("Your subscription list"),
                            detail: L10n.string("Synced to Pausely's servers over an encrypted connection and encrypted at rest. Other accounts can't read it."))
                SettingsRow(title: L10n.string("History, receipt and Pause Plan"),
                            detail: L10n.string("Stay on this iPhone, protected by iOS data protection."))
                if FeatureFlags.inboxImportEnabled {
                    SettingsRow(title: L10n.string("Find in Email"),
                                detail: L10n.string("Receipts are read on this iPhone. A few facts of each charge are kept (who charged, how much, when, how often), never the email itself."))
                }
                SettingsRow(title: L10n.string("No ads, no selling data"),
                            detail: L10n.string("Pausely has no ad or tracking SDKs and never sells your data."))
            }

            SettingsSection(title: "Terms and privacy") {
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
                    SettingsRow(title: L10n.string("Delete account"),
                                detail: L10n.string("Permanently remove your account and all its data"), titleColor: .due) {
                        if isDeleting { ProgressView().tint(Color.inkText) }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .accessibilityIdentifier("deleteAccountButton")
                .alert("Delete account?", isPresented: $showingDeleteAccountConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) { Task { await deleteAccount() } }
                } message: {
                    Text(deleteWarning)
                }
                .alert("Couldn't delete your account", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(deleteError ?? "")
                }
            }
        }
        // The policies have one copy, on the website. It opens here, without leaving the app.
        .sheet(isPresented: $showingPrivacyPolicy) { LegalPage.privacy.view }
        .sheet(isPresented: $showingTermsOfService) { LegalPage.terms.view }
    }

    /// What deleting does and does not do. An account that signs in with Apple is told Apple's sheet
    /// comes next, so it isn't a surprise.
    private var deleteWarning: String {
        let warning = L10n.string("This permanently deletes your account, your subscription list and your history from Pausely's servers and this iPhone. It doesn't cancel any subscriptions, including Pausely Pro. To cancel those, open Settings, tap your name, then Subscriptions.")
        guard AuthManager.shared.signsInWithApple else { return warning }
        return warning + "\n\n" + L10n.string("Apple will ask you to confirm first.")
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await AuthManager.shared.deleteAccount()
            Feel.landed()
            dismiss()
        } catch is CancellationError {
            // The person closed Apple's sheet: nothing was deleted and there is nothing to report.
        } catch {
            // The address is one the person may have to type: in the system's narrow alert it is
            // not hyphenated either.
            deleteError = AddressText.inSentence(L10n.string("Check your connection and try again. If it keeps failing, email \(AppConfig.supportEmail) and we'll delete it within 30 days."))
        }
    }

}
