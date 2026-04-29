import SwiftUI

struct QuickDateButton: View {
    let title: String
    let days: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(BackgroundColors.tertiary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
