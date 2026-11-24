import SwiftUI

/// Home when nothing is on the list yet: add manually, import from screenshots, or find in email.
struct HomeEmpty: View {
    let onAdd: () -> Void
    var onImportScreenshots: (() -> Void)? = nil
    /// Nil while finding subscriptions in email is switched off (`FeatureFlags`).
    var onFindInEmail: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing on your list yet.")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Add what you pay for. Pausely asks before each renewal whether it's still worth it.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                Button(action: onAdd) { Text("Add subscription") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("addSubscriptionButton")
                if let onImportScreenshots {
                    Button(action: onImportScreenshots) { Text("Import from screenshots") }
                        .buttonStyle(.ink(.quiet))
                        .accessibilityIdentifier("homeImportScreenshotsButton")
                }
                if let onFindInEmail {
                    Button(action: onFindInEmail) { Text("Find in Email") }
                        .buttonStyle(.ink(.quiet))
                        .accessibilityIdentifier("homeFindInEmailButton")
                }
            }
            .padding(.top, 12)
        }
    }
}
