import SwiftUI

struct EnhancedFormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            content
                .padding()
                .glass(intensity: 0.1, tint: .white)
        }
    }
}
