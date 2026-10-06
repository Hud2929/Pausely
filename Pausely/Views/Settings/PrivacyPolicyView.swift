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

                    Text("Last updated: September 22, 2026")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        PolicySection(title: "1. Information We Collect") {
                            Text("We collect information you provide directly, including:\n\n• Email address (for account creation and authentication)\n• Subscription data you manually enter\n• Usage analytics and app performance data\n• Device information for push notifications")
                        }

                        PolicySection(title: "2. Gmail Integration (Optional)") {
                            Text("If you connect Gmail, Pausely uses read-only access to detect subscriptions from your receipts.\n\n• Email content is processed entirely on your device — it never reaches Pausely's servers\n• We only save the extracted subscription details (name, amount, billing date) to your account\n• We cannot send, delete, or modify any of your emails\n• You can disconnect at any time from Profile → Settings → Import from Gmail\n\nPausely's use of Gmail data adheres to Google's API Services User Data Policy, including Limited Use requirements.")
                        }

                        PolicySection(title: "3. How We Use Your Information") {
                            Text("We use collected information to:\n\n• Provide and maintain our subscription tracking services\n• Send you renewal reminders and notifications\n• Improve our app functionality and user experience\n• Communicate with you about your subscriptions")
                        }

                        PolicySection(title: "4. Data Storage and Security") {
                            Text("• All data is encrypted in transit and at rest\n• We use industry-standard security measures\n• Your data is stored securely in Supabase cloud infrastructure\n• You can request deletion of your data at any time")
                        }

                        PolicySection(title: "5. Information Sharing") {
                            Text("We do not sell, trade, or otherwise transfer your personal information to third parties, except:\n\n• With your explicit consent\n• To comply with legal obligations\n• To protect our rights and prevent fraud")
                        }

                        PolicySection(title: "6. Push Notifications") {
                            Text("With your permission, we may send push notifications for:\n\n• Upcoming subscription renewals\n• Free trial expirations\n• Price change alerts\n\nYou can disable notifications at any time in Settings.")
                        }

                        PolicySection(title: "7. Your Rights") {
                            Text("You have the right to:\n\n• Access your personal data\n• Correct inaccurate data\n• Delete your data\n• Opt out of notifications\n• Export your data\n\nContact us at pausely@proton.me to exercise these rights.")
                        }

                        PolicySection(title: "8. Children's Privacy") {
                            Text("Our app is not intended for anyone under 16 years of age. When you create an account we ask for your date of birth only to check you meet this minimum age. We do not store the date. We keep a record that you confirmed you are 16 or older, when you confirmed it, and which version of our policies applied. We do not knowingly collect information from anyone under 16.")
                        }

                        PolicySection(title: "9. Changes to This Policy") {
                            Text("We may update this privacy policy from time to time. We will notify you of any material changes by posting the new policy in the app and updating the 'Last updated' date.")
                        }

                        PolicySection(title: "10. Contact Us") {
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
