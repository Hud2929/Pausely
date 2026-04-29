import SwiftUI
import StoreKit

@MainActor
struct ForgottenSubscriptionsSection: View {
    @ObservedObject private var scanner = AppleSubscriptionScanner.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var forgotten: [AppleDetectedSubscription] = []
    @State private var isChecking = false
    @State private var appear = false

    var body: some View {
        Group {
            if !forgotten.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.semanticWarning)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Forgotten Subscriptions")
                                .font(AppTypography.headlineLarge)
                                .foregroundStyle(.primary)

                            Text("You pay for these through Apple but haven't tracked them")
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    VStack(spacing: 8) {
                        ForEach(forgotten.prefix(3)) { sub in
                            ForgottenRow(subscription: sub) {
                                addToTracked(sub)
                            }
                        }
                    }

                    if forgotten.count > 3 {
                        Text("+ \(forgotten.count - 3) more")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                        appear = true
                    }
                }
            }
        }
        .onAppear {
            checkForgotten()
        }
    }

    private func checkForgotten() {
        guard !isChecking else { return }
        isChecking = true
        Task {
            let result = await scanner.findForgottenSubscriptions(tracked: store.subscriptions)
            forgotten = result
            isChecking = false
        }
    }

    private func addToTracked(_ sub: AppleDetectedSubscription) {
        let newSub = sub.toSubscription()
        Task {
            _ = try? await store.addSubscription(newSub)
            // Refresh the forgotten list
            checkForgotten()
        }
    }
}

struct ForgottenRow: View {
    let subscription: AppleDetectedSubscription
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: subscription.iconName)
                .font(.system(size: 16))
                .foregroundStyle(Color.semanticWarning)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subscription.formattedPrice + "/" + subscription.billingDisplay.lowercased())
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Track")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.semanticWarning)
                .clipShape(Capsule())
            }
        }
        .padding(12)
        .glassBackground(cornerRadius: 14, strokeColor: Color.semanticWarning.opacity(0.2), strokeWidth: 1)
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        ScrollView {
            ForgottenSubscriptionsSection()
                .padding(.top, 40)
        }
    }
}
