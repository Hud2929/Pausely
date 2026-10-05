//
//  RevolutionaryCancelButton.swift
//  Pausely
//
//  Opens the real cancel URL for the subscription service
//

import SwiftUI
import SafariServices

// MARK: - Revolutionary Cancel Button
struct RevolutionaryCancelButton: View {
    let subscription: Subscription
    @State private var showingFlow = false

    var body: some View {
        Button(action: { showingFlow = true }) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cancel Subscription")
                        .font(STFont.labelLarge)

                    Text("Open cancel page in Safari")
                        .font(STFont.bodySmall)
                        .foregroundStyle(Color.obsidianTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: STRadius.md)
                    .fill(Color.semanticDestructive.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: STRadius.md)
                            .stroke(Color.semanticDestructive.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingFlow) {
            CancelSubscriptionFlow(subscription: subscription)
        }
    }
}

// MARK: - Cancel Flow Sheet
struct CancelSubscriptionFlow: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var isShowingSafari = false
    @State private var showConfirmDelete = false
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

                    // Done button
                    Button(action: { showConfirmDelete = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("I Cancelled — Remove from Tracking")
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
            .alert("Remove from tracking?", isPresented: $showConfirmDelete) {
                Button("Remove", role: .destructive) {
                    Task { await removeSubscription() }
                }
                Button("Keep", role: .cancel) { }
            } message: {
                Text("This will remove \(subscription.name) from your Pausely dashboard. Your actual subscription is managed by \(subscription.name).")
            }
            .errorBanner($errorMessage)
            .fullScreenCover(isPresented: $showingCelebration) {
                CancelCelebrationView(subscription: subscription) {
                    showingCelebration = false
                    showingDifficultyRating = true
                }
            }
            .sheet(isPresented: $showingDifficultyRating) {
                CancelDifficultyRatingView(serviceName: subscription.name) {
                    showingDifficultyRating = false
                    dismiss()
                }
            }
        }
    }

    private func removeSubscription() async {
        isDeleting = true
        do {
            try await SubscriptionStore.shared.deleteSubscription(id: subscription.id)
            NotificationManager.shared.cancelReminder(for: subscription.id)
            await MainActor.run {
                isDeleting = false
                Haptic.success()
                showingCelebration = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not remove: \(error.localizedDescription)"
                isDeleting = false
                Haptic.error()
            }
        }
    }
}


// MARK: - Cancel Confirmation Sheet
struct RevolutionaryCancelConfirmationSheet: View {
    let subscription: Subscription
    let onConfirm: () async -> Void
    let onDismiss: () -> Void

    @AccessibilityFocusState private var focusedElement: FocusElement?

    enum FocusElement {
        case confirmationMessage
    }

    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.semanticDestructive.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.semanticDestructive)
                    }
                    
                    Text("Cancel \(subscription.name)?")
                        .font(STFont.headlineLarge)
                        .foregroundStyle(Color.obsidianText)
                    
                    Text("This will cancel your subscription immediately")
                        .font(STFont.bodyMedium)
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .multilineTextAlignment(.center)
                        .accessibilityFocused($focusedElement, equals: .confirmationMessage)
                }
                
                // Savings display
                VStack(spacing: 8) {
                    Text("YOU'LL SAVE")
                        .font(STFont.labelSmall)
                        .foregroundStyle(Color.obsidianTextTertiary)
                    
                    Text(CurrencyManager.shared.format(subscription.annualCost))
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
                
                Spacer()
                
                // ONE TAP ACTION - Revolutionary!
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            isProcessing = true
                            await onConfirm()
                            isProcessing = false
                            dismiss()
                        }
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                Text("Yes, Cancel Now")
                                    .font(STFont.labelLarge)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.semanticDestructive)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
                    }
                    .disabled(isProcessing)
                    .accessibilityHint(isProcessing ? "Please wait, cancellation in progress" : "")

                    Button(action: {
                        dismiss()
                        onDismiss()
                    }) {
                        Text("Keep Subscription")
                            .font(STFont.labelLarge)
                            .foregroundStyle(Color.obsidianText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .disabled(isProcessing)
                    .accessibilityHint(isProcessing ? "Please wait, cancellation in progress" : "")
                }
            }
            .padding()
            .background(Color.obsidianBlack)
            .navigationTitle("Cancel")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                focusedElement = .confirmationMessage
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.obsidianText)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}


// MARK: - Success Overlays
struct CancellationSuccessOverlay: View {
    let result: CancellationResult
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.semanticSuccess)
                
                Text("Cancelled!")
                    .font(STFont.headlineLarge)
                    .foregroundStyle(Color.obsidianText)
                
                Text(result.message)
                    .font(STFont.bodyMedium)
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
                
                if result.refundEligible {
                    Label("Refund eligible", systemImage: "dollarsign.circle")
                        .font(STFont.labelMedium)
                        .foregroundStyle(Color.semanticSuccess)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.semanticSuccess.opacity(0.15))
                        .clipShape(Capsule())
                }
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

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        RevolutionaryCancelButton(subscription: Subscription(
            name: "Netflix",
            amount: 15.99,
            billingFrequency: .monthly
        ))

        RevolutionaryResumeButton(subscription: Subscription(
            name: "Netflix",
            amount: 15.99,
            billingFrequency: .monthly,
            status: .paused
        ))
    }
    .padding()
    .background(Color.obsidianBlack)
}
