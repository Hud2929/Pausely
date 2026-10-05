import SwiftUI

struct SubscriptionCategoryButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.accentMint : Color.obsidianElevated)
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : Color.obsidianTextSecondary)
                }

                Text(label)
                    .font(.footnote.weight(isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : Color.obsidianTextSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
