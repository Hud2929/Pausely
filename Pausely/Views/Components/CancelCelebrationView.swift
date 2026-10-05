import SwiftUI

/// Full-screen celebration shown immediately after a user confirms cancellation.
/// Displays annual savings in a high-impact animated layout before transitioning
/// to the cancel difficulty rating sheet.
struct CancelCelebrationView: View {
    let subscription: Subscription
    let onContinue: () -> Void

    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0
    @State private var amountScale: CGFloat = 0.6
    @State private var particlesVisible = false
    @State private var autoAdvanceTriggered = false

    private var annualSavings: String {
        // annualCost handles all billing frequencies correctly (weekly, monthly, yearly, etc.)
        let converted = currencyManager.convertToSelected(subscription.annualCost, from: subscription.currency)
        return currencyManager.format(converted)
    }

    var body: some View {
        ZStack {
            Color.obsidianBlack.ignoresSafeArea()

            // Particle rings
            if particlesVisible {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .stroke(Color.semanticSuccess.opacity(0.15 - Double(i) * 0.03), lineWidth: 2)
                        .frame(width: CGFloat(180 + i * 60), height: CGFloat(180 + i * 60))
                        .scaleEffect(particlesVisible ? 1.2 : 0.6)
                        .opacity(particlesVisible ? 1 : 0)
                        .animation(
                            .easeOut(duration: 1.2).delay(Double(i) * 0.1),
                            value: particlesVisible
                        )
                }
            }

            VStack(spacing: 32) {
                Spacer()

                // Checkmark icon
                ZStack {
                    Circle()
                        .fill(Color.semanticSuccess.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Circle()
                        .fill(Color.semanticSuccess.opacity(0.25))
                        .frame(width: 90, height: 90)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.semanticSuccess)
                }
                .scaleEffect(scale)
                .opacity(opacity)

                // Main message
                VStack(spacing: 12) {
                    Text("You cancelled \(subscription.name)!")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(opacity)

                    Text("YOU'LL SAVE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .tracking(2)
                        .opacity(opacity)

                    Text(annualSavings)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.semanticSuccess, Color.accentMint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(amountScale)
                        .opacity(opacity)

                    Text("per year")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .opacity(opacity)
                }

                Spacer()

                // Continue button
                Button(action: onContinue) {
                    Text("Rate How Hard It Was →")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.obsidianBlack)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.accentMint)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .opacity(opacity)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.1)) {
                scale = 1
                opacity = 1
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.25)) {
                amountScale = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                particlesVisible = true
            }
            // Auto-advance after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                guard !autoAdvanceTriggered else { return }
                autoAdvanceTriggered = true
                onContinue()
            }
        }
    }
}
