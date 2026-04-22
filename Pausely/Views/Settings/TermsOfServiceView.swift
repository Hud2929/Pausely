import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Terms of Service")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Last updated: April 9, 2026")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        PolicySection(title: "1. Acceptance of Terms") {
                            Text("By downloading or using Pausely, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our app.")
                        }

                        PolicySection(title: "2. Description of Service") {
                            Text("Pausely is a subscription management application that helps you track, monitor, and manage your recurring subscriptions. Our service provides reminders, analytics, and insights about your subscriptions.")
                        }

                        PolicySection(title: "3. User Accounts") {
                            Text("• You must provide accurate information when creating an account\n• You are responsible for maintaining the security of your account\n• You must be at least 13 years old to use our service\n• You are responsible for all activity under your account")
                        }

                        PolicySection(title: "4. Subscription Management") {
                            Text("Pausely helps you track subscriptions but:\n\n• We are not responsible for actual subscription cancellations\n• You must manage cancellations directly with service providers\n• We do not guarantee accuracy of pricing information\n• Renewal dates may vary from actual billing dates")
                        }

                        PolicySection(title: "5. Push Notifications") {
                            Text("By enabling notifications, you agree to receive:\n\n• Renewal reminders\n• Free trial expiration alerts\n• Price change notifications\n\nYou can disable notifications at any time in your device settings.")
                        }

                        PolicySection(title: "6. Intellectual Property") {
                            Text("• All content and design of the app is property of Pausely\n• You retain ownership of data you input\n• You grant us license to use anonymized data for improvements")
                        }

                        PolicySection(title: "7. Limitation of Liability") {
                            Text("Pausely is provided 'as is' without warranties. We are not liable for:\n\n• Decisions made based on app information\n• Errors in third-party pricing data\n• Service interruptions\n• Loss of data due to third-party issues")
                        }

                        PolicySection(title: "8. Modifications to Service") {
                            Text("We reserve the right to:\n\n• Modify or discontinue features\n• Change pricing with notice\n• Update these terms periodically\n• Terminate accounts that violate our policies")
                        }

                        PolicySection(title: "9. Governing Law") {
                            Text("These terms shall be governed by applicable laws. Any disputes shall be resolved through binding arbitration or in courts of competent jurisdiction.")
                        }

                        PolicySection(title: "10. Contact") {
                            Text("For questions about these Terms of Service, contact us:\n\nEmail: pausely@proton.me")
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

#Preview {
    TermsOfServiceView()
}
