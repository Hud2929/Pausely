import SwiftUI

struct ReferralStepRow: View {
    let number: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.luxuryGold.opacity(0.2))
                    .frame(width: 44, height: 44)

                Text("\(number)")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.luxuryGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.footnote)
                        .foregroundStyle(Color.luxuryGold)

                    Text(title)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text(description)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(2)
            }
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }
}
