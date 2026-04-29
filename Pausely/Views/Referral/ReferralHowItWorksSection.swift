import SwiftUI

struct ReferralHowItWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            VStack(spacing: 16) {
                ReferralStepRow(
                    number: 1,
                    icon: "square.and.arrow.up",
                    title: "Share Your Code",
                    description: "Send your unique referral code to friends via Messages, Email, or Social"
                )

                ReferralStepRow(
                    number: 2,
                    icon: "person.badge.plus",
                    title: "Friend Signs Up",
                    description: "They create an account using your code and get 30% off their first month"
                )

                ReferralStepRow(
                    number: 3,
                    icon: "crown.fill",
                    title: "Get Pro FREE",
                    description: "Earn $5 per referral + unlock Premium forever after 3 friends subscribe"
                )
            }
        }
    }
}
