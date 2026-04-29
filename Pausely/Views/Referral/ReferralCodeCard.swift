import SwiftUI

struct ReferralCodeCard: View {
    let isLoadingCode: Bool
    let displayCode: String
    let progressCount: Int
    let isEligibleForFreePro: Bool
    let isPremium: Bool
    let appear: Bool
    let onGenerateCode: () -> Void
    let onCopy: () -> Void
    let onClaimFreePro: () -> Void

    @State private var copiedToClipboard = false

    var body: some View {
        VStack(spacing: 16) {
            Text("YOUR UNIQUE CODE")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)

            if isLoadingCode {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.luxuryGold)
                    Text("Loading your code...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.isLoadingCode {
                            self.onGenerateCode()
                        }
                    }
                }
            } else if displayCode == "Loading..." || displayCode.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Couldn't load code")
                        .font(.headline)
                        .foregroundColor(.white)
                    Button("Generate Code") {
                        onGenerateCode()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                HStack(spacing: 12) {
                    Text(displayCode)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .kerning(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Divider()
                        .frame(height: 30)
                        .background(.white.opacity(0.2))

                    Button(action: {
                        onCopy()
                        copiedToClipboard = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            copiedToClipboard = false
                        }
                    }) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(copiedToClipboard ? Color.luxuryTeal : Color.luxuryGold)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.1))
                            )
                    }
                    .accessibilityLabel(copiedToClipboard ? "Copied" : "Copy referral code")
                }

                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.1))
                                .frame(height: 20)

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.luxuryGold, Color.luxuryPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * (Double(min(progressCount, 3)) / 3.0), height: 20)
                                .animation(.easeOut(duration: 0.8), value: progressCount)
                        }
                    }
                    .frame(height: 20)

                    HStack {
                        Text("\(progressCount) of 3 completed")
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        if progressCount < 3 {
                            Text("\(3 - progressCount) more to go!")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.luxuryGold)
                        } else {
                            Text("Completed! 🎉")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.luxuryTeal)
                        }
                    }

                    if isEligibleForFreePro && !isPremium {
                        Button(action: onClaimFreePro) {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Claim Free Pro")
                            }
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.luxuryGold, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.luxuryPurple.opacity(0.2),
                                Color.luxuryPink.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5))

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
    }
}
