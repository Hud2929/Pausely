//
//  PauseyButlerView.swift
//  Pausely
//
//  Your personal subscription butler
//

import SwiftUI

struct PauseyButlerView: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss

    @State private var pausey = PauseyButler.shared
    @State private var showingConfirm = false
    @State private var isLoading = false
    @State private var result: PauseyCancellationResult?
    @State private var showResult = false

    private var cancellationInfo: CancellationInfo {
        pausey.getCancellationInfo(for: subscription)
    }

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color.black, Color(hex: "1A1A2E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with Pausey
                headerSection

                ScrollView {
                    VStack(spacing: 24) {
                        // Subscription info card
                        subscriptionCard

                        // Action buttons
                        actionButtons

                        // Info text
                        infoSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .confirmationDialog("Confirm Cancellation", isPresented: $showingConfirm) {
            Button("Yes, Cancel \(subscription.name)", role: .destructive) {
                Task {
                    await performCancel()
                }
            }
            Button("Keep Subscription", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel \(subscription.name)? This action cannot be undone.")
        }
        .alert("Cancellation Initiated", isPresented: $showResult) {
            Button("Done") { dismiss() }
        } message: {
            if case .initiated(_) = result {
                Text("I've opened the cancellation page. You'll receive a confirmation email once processed.")
            } else if case .failed(let reason) = result {
                Text("Something went wrong: \(reason)")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Pausey character
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                // Pausey avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.luxuryPurple, .luxuryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                // Butler icon
                Image(systemName: "figure.butler")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .frame(height: 100)

            // Pausey's message
            VStack(spacing: 8) {
                Text("Pausey at your service")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)

                Text("How would you like to handle\n\(subscription.name)?")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.luxuryPurple.opacity(0.3), .luxuryPink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text(String(subscription.name.prefix(1)))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subscription.displayAmount + " / " + subscription.billingFrequency.shortDisplay)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.gray)
            }

            Spacer()

            // Difficulty badge
            HStack(spacing: 4) {
                Image(systemName: cancellationInfo.difficulty.icon)
                    .font(.caption)
                Text(cancellationInfo.difficulty == .easy ? "Easy" : cancellationInfo.difficulty == .medium ? "Medium" : "Hard")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(cancellationInfo.difficulty.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(cancellationInfo.difficulty.color.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            // CANCEL button - Primary action
            Button(action: { showingConfirm = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cancel Subscription")
                            .font(.system(size: 17, weight: .semibold))

                        Text(cancellationInfo.message)
                            .font(.system(size: 12))
                            .opacity(0.8)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "EF4444").opacity(0.4), radius: 15, y: 8)
            }

            // PAUSE button - Secondary action (if available)
            if cancellationInfo.canPause {
                Button(action: {
                    Task {
                        await performPause()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause Instead")
                                .font(.system(size: 17, weight: .semibold))

                            Text("Take a break without canceling")
                                .font(.system(size: 12))
                                .opacity(0.8)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.luxuryPurple, Color.luxuryPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 15, y: 8)
                }
            }

            // MANAGE SUBSCRIPTIONS button - Opens Apple subscription page
            if cancellationInfo.isStoreKit {
                Button(action: {
                    Task {
                        await pausey.openSubscriptionManagement()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage in App Store")
                                .font(.system(size: 17, weight: .semibold))

                            Text("View all your subscriptions")
                                .font(.system(size: 12))
                                .opacity(0.8)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.gray, Color.gray.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What happens next?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)

                Text("I'll open the cancellation page for you. You'll need to confirm the cancellation on the service's website. You'll receive a confirmation email once it's processed.")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.1))
            )
        }
        .padding(.top, 10)
    }

    // MARK: - Actions

    private func performCancel() async {
        isLoading = true
        result = await pausey.cancel(subscription: subscription)
        isLoading = false
        showResult = true
    }

    private func performPause() async {
        isLoading = true
        result = await pausey.pause(subscription: subscription)
        isLoading = false
        showResult = true
    }
}

// MARK: - Pausey Floating Button

/// A floating button to summon Pausey from anywhere
struct PauseyFloatingButton: View {
    let subscription: Subscription
    @State private var showingPausey = false

    var body: some View {
        Button(action: { showingPausey = true }) {
            Image(systemName: "figure.butler")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.luxuryPurple, .luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.luxuryPurple.opacity(0.5), radius: 10, y: 5)
        }
        .accessibilityLabel("Ask Pausey about \(subscription.name)")
        .sheet(isPresented: $showingPausey) {
            PauseyButlerView(subscription: subscription)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            PauseyFloatingButton(subscription: Subscription(
                name: "Netflix",
                price: 15.99,
                category: "Video",
                billingFrequency: .monthly
            ))
            .padding(.bottom, 100)
        }
    }
}
