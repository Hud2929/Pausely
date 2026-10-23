//
//  RevolutionaryCancelButton.swift
//  Pausely
//
//  Opens the real cancel URL for the subscription service
//

import SwiftUI
import SafariServices


// MARK: - Cancel Flow Sheet
struct CancelSubscriptionFlow: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var isShowingSafari = false
    @State private var isDeleting = false
    @State private var errorMessage: String? = nil
    @State private var showingCelebration = false
    @State private var showingDifficultyRating = false

    private var annualSavingsFormatted: String {
        let converted = currencyManager.convertToSelected(subscription.annualCost, from: subscription.currency)
        return currencyManager.format(converted)
    }

    private var service: SubscriptionService? {
        SubscriptionActionManager.shared.getService(for: subscription.name)
    }

    private var cancelURL: URL? {
        SubscriptionActionManager.shared.generateCancelURL(for: subscription)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.semanticDestructive.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.semanticDestructive)
                        }

                        Text("Cancel \(subscription.name)")
                            .font(STFont.headlineLarge)
                            .foregroundStyle(Color.obsidianText)

                        Text("We'll take you to the official cancellation page")
                            .font(STFont.bodyMedium)
                            .foregroundStyle(Color.obsidianTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Savings
                    VStack(spacing: 8) {
                        Text("YOU'LL SAVE")
                            .font(STFont.labelSmall)
                            .foregroundStyle(Color.obsidianTextTertiary)
                        Text(annualSavingsFormatted)
                            .font(STFont.displayMedium)
                            .foregroundStyle(Color.semanticSuccess)
                        Text("per year")
                            .font(STFont.bodyMedium)
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.semanticSuccess.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))

                    // Steps
                    if let svc = service, !svc.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to cancel")
                                .font(STFont.labelLarge)
                                .foregroundStyle(Color.obsidianText)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(svc.instructions.prefix(4)) { step in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(step.order)")
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(Color.obsidianBlack)
                                            .frame(width: 22, height: 22)
                                            .background(Color.accentMint)
                                            .clipShape(Circle())

                                        Text(step.description)
                                            .font(STFont.bodySmall)
                                            .foregroundStyle(Color.obsidianText)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.obsidianSurface)
                        .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
                    }

                    // Open cancel page button
                    if cancelURL != nil {
                        Button(action: { isShowingSafari = true }) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Open Cancellation Page")
                                    .font(STFont.labelLarge)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                            }
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.semanticDestructive)
                            .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("No direct cancel link found. Search for \"cancel \(subscription.name)\" in your browser.")
                            .font(STFont.bodySmall)
                            .foregroundStyle(Color.obsidianTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    // Done: marks it cancelled (kept in the list, counted on the Savings Receipt)
                    Button(action: { Task { await markCancelled() } }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(isDeleting ? "Saving…" : "I cancelled it")
                                .font(STFont.labelLarge)
                            Spacer()
                        }
                        .foregroundStyle(Color.semanticSuccess)
                        .padding()
                        .background(Color.semanticSuccess.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: STRadius.md)
                                .stroke(Color.semanticSuccess.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                    .accessibilityIdentifier("iCancelledItButton")

                    Text("Pausely keeps it in your list as cancelled and adds the charges you avoid to your Savings Receipt.")
                        .font(STFont.bodySmall)
                        .foregroundStyle(Color.obsidianTextTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Cancel Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.accentMint)
                }
            }
            .sheet(isPresented: $isShowingSafari) {
                if let url = cancelURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .errorBanner($errorMessage)
            .fullScreenCover(isPresented: $showingCelebration) {
                CancelCelebrationView(subscription: subscription) {
                    showingCelebration = false
                    showingDifficultyRating = true
                }
                .readableWidth()
            }
            .sheet(isPresented: $showingDifficultyRating) {
                CancelDifficultyRatingView(serviceName: subscription.name) {
                    showingDifficultyRating = false
                    dismiss()
                }
            }
        }
    }

    private func markCancelled() async {
        isDeleting = true
        do {
            try await SubscriptionStore.shared.updateSubscriptionStatus(id: subscription.id, status: .cancelled)
            await MainActor.run {
                isDeleting = false
                Haptic.success()
                showingCelebration = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't save: \(error.localizedDescription)"
                isDeleting = false
                Haptic.error()
            }
        }
    }
}


// MARK: - Revolutionary Resume Button
struct RevolutionaryResumeButton: View {
    let subscription: Subscription
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Button(action: {
            Task { await performResume() }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.semanticSuccess)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Resume Subscription")
                        .font(STFont.labelLarge)

                    if let pausedUntil = subscription.pausedUntil {
                        Text("Resumes automatically on \(pausedUntil.formatted(date: .abbreviated, time: .omitted))")
                            .font(STFont.bodySmall)
                            .foregroundStyle(Color.obsidianTextSecondary)
                    } else {
                        Text("Reactivate your subscription")
                            .font(STFont.bodySmall)
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .tint(Color.semanticSuccess)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: STRadius.md)
                    .fill(Color.semanticSuccess.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: STRadius.md)
                            .stroke(Color.semanticSuccess.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .overlay {
            if showSuccess {
                ResumeSuccessOverlay(isPresented: $showSuccess)
            }
        }
        .errorBanner($errorMessage)
    }

    private func performResume() async {
        isProcessing = true
        errorMessage = nil

        do {
            try await SubscriptionStore.shared.resumeSubscription(id: subscription.id)
            NotificationManager.shared.cancelPauseReminder(for: subscription.id)

            await MainActor.run {
                self.isProcessing = false
                self.showSuccess = true
                Haptic.success()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Could not resume: \(error.localizedDescription)"
                self.isProcessing = false
                Haptic.error()
            }
        }
    }
}

// MARK: - Resume Success Overlay
struct ResumeSuccessOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.semanticSuccess)

                Text("Resumed!")
                    .font(STFont.headlineLarge)
                    .foregroundStyle(Color.obsidianText)

                Text("Your subscription is active again.")
                    .font(STFont.bodyMedium)
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))

            Spacer()
        }
        .background(Color.obsidianBlack.opacity(0.9))
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}

