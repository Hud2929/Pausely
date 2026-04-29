import SwiftUI

struct AlternativeCard: View {
    let alternative: AlternativeService
    let savings: Double

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alternative.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(alternative.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(String(format: "%.1f", alternative.rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text("\(CurrencyManager.shared.format(Decimal(alternative.monthlyPrice)))/mo")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if savings > 0 {
                    Text("Save \(CurrencyManager.shared.format(Decimal(savings)))")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
