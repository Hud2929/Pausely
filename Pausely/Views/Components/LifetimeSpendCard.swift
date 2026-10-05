import SwiftUI

struct LifetimeSpendCard: View {
    let lifetimeSpend: Decimal
    let currencyManager: CurrencyManager

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(Color.accentMint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Lifetime Spend")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))

                Text(currencyManager.format(lifetimeSpend))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20)
    }
}
