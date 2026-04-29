import SwiftUI

struct ReferralTermsSection: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Terms & Conditions")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.luxuryGold)

            Text("Rewards are granted when referred friends complete signup and verify their account. Free Pro access is permanent and non-transferable. Self-referrals are not allowed.")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 16)
    }
}
