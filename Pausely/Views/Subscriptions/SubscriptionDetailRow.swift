import SwiftUI

struct SubscriptionDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(BrandColors.primary)
                .frame(width: 32)

            Text(title)
                .font(.body)
                .foregroundColor(TextColors.secondary)

            Spacer()

            Text(value)
                .font(.callout.weight(.medium))
                .foregroundColor(.white)
        }
        .padding(16)
        .background(BackgroundColors.secondary)
    }
}
