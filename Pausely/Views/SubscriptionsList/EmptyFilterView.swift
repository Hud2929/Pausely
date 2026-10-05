import SwiftUI

struct EmptyFilterView: View {
    let searchText: String
    let category: ServiceCategory?
    let onClearFilters: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 64, height: 64)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("No Results Found")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                if !searchText.isEmpty {
                    Text("No subscriptions match \"\(searchText)\".")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                } else if let category = category {
                    Text("You have no \(category.rawValue) subscriptions.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            Button(action: {
                HapticStyle.light.trigger()
                onClearFilters()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Clear Filters")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Color.accentMint)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentMint.opacity(0.12))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Clear filters")
            .padding(.top, 4)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: 20)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}
