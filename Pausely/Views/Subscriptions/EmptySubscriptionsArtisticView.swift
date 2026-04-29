import SwiftUI

struct EmptySubscriptionsArtisticView: View {
    let onAdd: () -> Void
    @State private var animate = false

    var body: some View {
        VStack(spacing: 20) {
            // Animated illustration
            ZStack {
                // Orbit rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(BrandColors.primary.opacity(0.1 + Double(i) * 0.1), lineWidth: 1)
                        .frame(width: 120 + CGFloat(i * 30), height: 120 + CGFloat(i * 30))
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .animation(
                            UIAccessibility.isReduceMotionEnabled
                                ? .none
                                : .linear(duration: 10 + Double(i) * 5).repeatForever(autoreverses: false),
                            value: animate
                        )
                }

                // Center icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [BrandColors.primary, BrandColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: BrandColors.primary.opacity(0.4), radius: 20, x: 0, y: 10)

                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 200)

            VStack(spacing: 8) {
                Text("No subscriptions yet")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                Text("Add your first subscription to start tracking")
                    .font(.subheadline)
                    .foregroundColor(TextColors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Subscription")
                }
                .font(.callout.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.brandGradient)
                )
                .shadow(color: BrandColors.primary.opacity(0.4), radius: 20, x: 0, y: 10)
            }
        }
        .padding(.bottom, 80)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            animate = true
        }
    }
}
