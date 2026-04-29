import SwiftUI

struct EmptyFilterView: View {
    let searchText: String
    let category: ServiceCategory?
    let onClearFilters: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.displayLarge)
                .foregroundStyle(.white.opacity(0.3))
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Text("No subscriptions found")
                .font(AppTypography.headlineMedium)
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            } else if let category = category {
                Text("No \(category.rawValue) subscriptions yet")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }

            Button(action: {
                HapticStyle.light.trigger()
                onClearFilters()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.bodyMedium)
                    Text("Clear Filters")
                        .font(AppTypography.headlineSmall)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .accessibilityLabel("Clear filters")
            .premiumPress(haptic: .light, scale: 0.97)
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .padding(.vertical, 40)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                appeared = true
                return
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }
}
