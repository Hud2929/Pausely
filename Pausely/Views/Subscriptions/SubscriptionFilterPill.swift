import SwiftUI

struct SubscriptionFilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))

                Text("\(count)")
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? .white.opacity(0.2) : BackgroundColors.tertiary)
                    )
            }
            .foregroundColor(isSelected ? .white : TextColors.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? BrandColors.primary : BackgroundColors.secondary)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
