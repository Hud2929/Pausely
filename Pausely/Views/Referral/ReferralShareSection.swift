import SwiftUI

struct ReferralShareSection: View {
    let onShareMessages: () -> Void
    let onShareEmail: () -> Void
    let onShareSystem: () -> Void
    let onCopyLink: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Share Via")
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 20) {
                ShareButton(
                    icon: "message.fill",
                    color: .green,
                    action: onShareMessages,
                    label: "Share via Messages"
                )

                ShareButton(
                    icon: "envelope.fill",
                    color: .blue,
                    action: onShareEmail,
                    label: "Share via Email"
                )

                ShareButton(
                    icon: "square.and.arrow.up",
                    color: Color.luxuryPurple,
                    action: onShareSystem,
                    label: "Share"
                )

                ShareButton(
                    icon: "link",
                    color: Color.luxuryPink,
                    action: onCopyLink,
                    label: "Copy link"
                )
            }
        }
    }
}
