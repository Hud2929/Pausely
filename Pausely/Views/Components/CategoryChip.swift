import SwiftUI

struct CategoryChip: View {
    let category: ServiceCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(AppTypography.labelLarge)
                Text(category.rawValue)
                    .font(AppTypography.labelMedium)
            }
            .foregroundStyle(isSelected ? .white : category.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : category.color.opacity(0.15))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
