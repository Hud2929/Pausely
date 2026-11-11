import SwiftUI
import StoreKit

/// Answers to what people ask most, and how to reach a person. Every answer describes the app as it
/// is: what is free is said to be free, and the steps name the screens they are on.
struct HelpSupportView: View {
    @State private var open: Int?

    private var questions: [(question: String, answer: String)] {
        [
            (L10n.string("How do I add a subscription?"),
             L10n.string("Tap + on Home, find the service or choose Custom, then enter what you pay and when it renews.")),
            (L10n.string("How many subscriptions can I track for free?"),
             L10n.string("Up to \(FreeTier.subscriptionLimit). Pausely Pro removes the limit.")),
            (L10n.string("How do I stop a subscription I no longer want?"),
             L10n.string("Open it and tap Cancel subscription. Pausely shows the steps and opens the service's own cancellation page; you always cancel with the service itself. Then tap \"I cancelled it\" so it moves to your Savings Receipt.")),
            (L10n.string("How do I change currency?"),
             L10n.string("Open Profile, then Currency. Totals change; each subscription keeps the currency it's charged in.")),
            (L10n.string("Is my data secure?"),
             L10n.string("Your subscriptions are stored in your account and sent over encrypted connections. We never sell your data. See the Privacy Policy for details.")),
            (L10n.string("How do I cancel Pausely Pro?"),
             L10n.string("Pausely Pro is billed by Apple. Open Settings on your iPhone, tap your name, then Subscriptions, and choose Pausely Pro."))
        ]
    }

    var body: some View {
        SettingsPage(title: "Help & Support") {
            SettingsSection(title: "Common questions") {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, item in
                    Button {
                        Feel.selection()
                        withAnimation(Motion.unlessReduced(Motion.touch)) { open = open == index ? nil : index }
                    } label: {
                        SettingsRow(title: item.question, detail: open == index ? item.answer : nil) {
                            Image(systemName: open == index ? "chevron.up" : "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.inkTextFaint)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(open == index ? Text("Double tap to hide the answer") : Text("Double tap to show the answer"))
                    .accessibilityIdentifier("faq-\(index)")
                }
            }

            SettingsSection(title: "Contact") {
                Button(action: openMail) {
                    SettingsRow(title: L10n.string("Email us"), detail: AppConfig.supportEmail) { RowChevron() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("emailSupportRow")
                Button(action: openSupportWebsite) {
                    SettingsRow(title: L10n.string("Support website")) { RowChevron() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("supportWebsiteRow")
                Button(action: openAppStoreReview) {
                    SettingsRow(title: L10n.string("Rate Pausely")) { RowChevron() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rateAppRow")
            }
        }
    }

    private func openMail() {
        if let url = URL(string: "mailto:\(AppConfig.supportEmail)") { UIApplication.shared.open(url) }
    }

    private func openSupportWebsite() {
        if let url = URL(string: AppConfig.supportURL) { UIApplication.shared.open(url) }
    }

    private func openAppStoreReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            AppStore.requestReview(in: windowScene)
        }
    }
}
