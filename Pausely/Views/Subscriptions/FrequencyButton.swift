import SwiftUI

struct FrequencyButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : TextColors.secondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(BrandColors.primary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? BrandColors.primary.opacity(0.15) : BackgroundColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? BrandColors.primary.opacity(0.5) : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
