import SwiftUI

struct ReferralHeroSection: View {
    let isEligibleForFreePro: Bool
    let isLoadingCode: Bool
    let displayCode: String
    let progressCount: Int
    let isPremium: Bool
    let appear: Bool
    let onGenerateCode: () -> Void
    let onCopy: () -> Void
    let onClaimFreePro: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.luxuryGold.opacity(0.4),
                                Color.luxuryPink.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.luxuryGold.opacity(0.3),
                                Color.luxuryPurple.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.luxuryGold.opacity(0.6), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )

                Image(systemName: isEligibleForFreePro ? "crown.fill" : "gift.fill")
                    .font(.system(.largeTitle, design: .rounded).weight(.light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.luxuryGold, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                HStack {
                    Image(systemName: "sparkle")
                        .font(.title3)
                        .foregroundStyle(Color.luxuryGold)
                        .offset(x: -70, y: -40)

                    Spacer()

                    Image(systemName: "sparkle.fill")
                        .font(.callout)
                        .foregroundStyle(Color.luxuryPink)
                        .offset(x: 60, y: 30)
                }
                .frame(width: 180)
            }
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 12) {
                if isEligibleForFreePro {
                    Text("Pro Unlocked! 🎉")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("You've earned FREE Premium forever by referring 3 friends!")
                        .font(.system(.callout, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.luxuryTeal)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text("Get Pro FREE!")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("Refer 3 friends and unlock Premium forever. No subscription needed!")
                        .font(.system(.callout, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .offset(y: appear ? 0 : 20)
            .opacity(appear ? 1 : 0)

            ReferralCodeCard(
                isLoadingCode: isLoadingCode,
                displayCode: displayCode,
                progressCount: progressCount,
                isEligibleForFreePro: isEligibleForFreePro,
                isPremium: isPremium,
                appear: appear,
                onGenerateCode: onGenerateCode,
                onCopy: onCopy,
                onClaimFreePro: onClaimFreePro
            )
        }
    }
}
