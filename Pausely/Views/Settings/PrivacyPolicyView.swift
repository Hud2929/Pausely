import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Privacy Policy")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Last updated: April 9, 2026")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        PolicySection(title: "1. Information We Collect") {
                            Text("We collect information you provide directly, including:\n\n• Email address (for account creation and authentication)\n• Subscription data you manually enter\n• Usage analytics and app performance data\n• Device information for push notifications")
                        }

                        PolicySection(title: "2. How We Use Your Information") {
                            Text("We use collected information to:\n\n• Provide and maintain our subscription tracking services\n• Send you renewal reminders and notifications\n• Improve our app functionality and user experience\n• Communicate with you about your subscriptions")
                        }

                        PolicySection(title: "3. Data Storage and Security") {
                            Text("• All data is encrypted in transit and at rest\n• We use industry-standard security measures\n• Your data is stored securely in Supabase cloud infrastructure\n• You can request deletion of your data at any time")
                        }

                        PolicySection(title: "4. Information Sharing") {
                            Text("We do not sell, trade, or otherwise transfer your personal information to third parties, except:\n\n• With your explicit consent\n• To comply with legal obligations\n• To protect our rights and prevent fraud")
                        }

                        PolicySection(title: "5. Push Notifications") {
                            Text("With your permission, we may send push notifications for:\n\n• Upcoming subscription renewals\n• Free trial expirations\n• Price change alerts\n\nYou can disable notifications at any time in Settings.")
                        }

                        PolicySection(title: "6. Your Rights") {
                            Text("You have the right to:\n\n• Access your personal data\n• Correct inaccurate data\n• Delete your data\n• Opt out of notifications\n• Export your data\n\nContact us at pausely@proton.me to exercise these rights.")
                        }

                        PolicySection(title: "7. Children's Privacy") {
                            Text("Our app is not intended for users under 13 years of age. We do not knowingly collect information from children under 13.")
                        }

                        PolicySection(title: "8. Changes to This Policy") {
                            Text("We may update this privacy policy from time to time. We will notify you of any material changes by posting the new policy in the app and updating the 'Last updated' date.")
                        }

                        PolicySection(title: "9. Contact Us") {
                            Text("If you have any questions about this Privacy Policy, please contact us:\n\nEmail: pausely@proton.me")
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PolicySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            content()
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PrivacyPolicyView()
}
