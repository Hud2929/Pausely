import SwiftUI

struct AlternativeCard: View {
    let alternative: AlternativeService
    let savings: Double

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alternative.name)
                    .font(.headline)
                    .foregroundStyle(Color.inkText)

                Text(alternative.description)
                    .font(.caption)
                    .foregroundStyle(Color.inkTextMuted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(String(format: "%.1f", alternative.rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.decide)

                    Text("\(alternative.monthlyPriceText)/mo")
                        .font(.caption)
                        .foregroundStyle(Color.kept)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if savings > 0 {
                    Text("Save \(CurrencyManager.shared.format(Decimal(savings)))")
                        .font(.caption.bold())
                        .foregroundStyle(Color.kept)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.kept.opacity(0.2))
                        .cornerRadius(8)
                }

                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.inkTextMuted)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
