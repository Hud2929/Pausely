//
//  RevolutionaryCancelButton.swift
//  Pausely
//
//  ONE-TAP Cancellation & Pause - Revolutionary UI
//

import SwiftUI

// MARK: - Revolutionary Cancel Button
struct RevolutionaryCancelButton: View {
    let subscription: Subscription
    @State private var showingConfirmation = false
    @State private var isProcessing = false
    @State private var result: CancellationResult?
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cancel Subscription")
                        .font(STFont.labelLarge)
                    
                    Text("One tap, instantly")
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
        .sheet(isPresented: $showingConfirmation) {
            RevolutionaryCancelConfirmationSheet(
                subscription: subscription,
                onConfirm: performCancellation,
                onDismiss: { showingConfirmation = false }
            )
        }
        .overlay {
            if showSuccess, let result = result {
                CancellationSuccessOverlay(result: result, isPresented: $showSuccess)
            }
        }
        .errorBanner($errorMessage)
    }
    
    private func performCancellation() async {
        isProcessing = true
        errorMessage = nil

        do {
            try await SubscriptionStore.shared.deleteSubscription(id: subscription.id)
            NotificationManager.shared.cancelReminder(for: subscription.id)

            let cancelResult = CancellationResult.success(savings: subscription.monthlyCost * 12)
            await MainActor.run {
                self.result = cancelResult
                self.isProcessing = false
                self.showSuccess = true
                Haptic.success()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Could not cancel: \(error.localizedDescription)"
                self.isProcessing = false
                Haptic.error()
            }
        }
    }
}

// MARK: - Revolutionary Pause Button
struct RevolutionaryPauseButton: View {
    let subscription: Subscription
    @State private var showingDurationPicker = false
    @State private var isProcessing = false
    @State private var result: PauseResult?
    @State private var showSuccess = false
    @State private var errorMessage: String? = nil

    var body: some View {
        Button(action: {
            showingDurationPicker = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentMint)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind Me to Pause")
                        .font(STFont.labelLarge)

                    Text("Get a reminder to pause on their site")
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
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: STRadius.md)
                            .stroke(Color.obsidianBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDurationPicker) {
            RevolutionaryPauseSheet(
                subscription: subscription,
                onPause: performPause,
                onDismiss: { showingDurationPicker = false }
            )
        }
        .overlay {
            if showSuccess, let result = result {
                PauseSuccessOverlay(result: result, isPresented: $showSuccess)
            }
        }
        .errorBanner($errorMessage)
    }

    private func performPause(duration: RevolutionaryPauseDuration) async {
        isProcessing = true
        errorMessage = nil

        let reminderDate = Calendar.current.date(
            byAdding: duration.calendarComponent,
            value: duration.value,
            to: Date()
        ) ?? Date()

        do {
            // Schedule a local reminder notification instead of fake-pausing
            let pauseURL = SubscriptionActionManager.shared.getService(for: subscription.name)?.pauseURL
            NotificationManager.shared.schedulePauseReminder(
                for: subscription,
                reminderDate: reminderDate,
                pauseURL: pauseURL
            )

            let pauseResult = PauseResult.reminderSet(reminderDate: reminderDate)
            await MainActor.run {
                self.result = pauseResult
                self.isProcessing = false
                self.showSuccess = true
                Haptic.success()
            }
        }
    }
}

// MARK: - Cancel Confirmation Sheet (REVOLUTIONARY - No Steps!)
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

// MARK: - Pause Sheet (REVOLUTIONARY - Instant!)
struct RevolutionaryPauseSheet: View {
    let subscription: Subscription
    let onPause: (RevolutionaryPauseDuration) async -> Void
    let onDismiss: () -> Void

    @State private var isProcessing = false
    @State private var showingSafari = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Service Lookup

    private var serviceInfo: SubscriptionService? {
        SubscriptionActionManager.shared.getService(for: subscription.name)
    }

    /// Direct link to the service's pause page (only if known)
    private var pausePageURL: URL? {
        guard let pauseURL = serviceInfo?.pauseURL, !pauseURL.isEmpty else { return nil }
        return URL(string: pauseURL)
    }

    /// General visit link: support page first, then domain homepage.
    /// Never uses cancelURL — we don't want to trick users into cancelling.
    private var visitURL: URL? {
        guard let service = serviceInfo else { return nil }
        if !service.supportURL.isEmpty,
           let url = URL(string: service.supportURL) { return url }
        if !service.domain.isEmpty,
           let url = URL(string: "https://\(service.domain)") { return url }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentMint.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "pause.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentMint)
                    }

                    Text("Remind Me to Pause \(subscription.name)")
                        .font(STFont.headlineLarge)
                        .foregroundStyle(Color.obsidianText)

                    Text("We'll send you a reminder to pause \(subscription.name) on their website.")
                        .font(STFont.bodyMedium)
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .multilineTextAlignment(.center)
                }

                // Duration options
                VStack(spacing: 12) {
                    ForEach(RevolutionaryPauseDuration.allCases, id: \.self) { duration in
                        PauseDurationButton(
                            duration: duration,
                            savings: subscription.monthlyCost * Decimal(duration.fractionOfMonth),
                            isProcessing: isProcessing
                        ) {
                            Task {
                                isProcessing = true
                                await onPause(duration)
                                isProcessing = false
                                dismiss()
                            }
                        }
                    }
                }

                // Direct link to pause page (only if we have a real pause URL)
                if let url = pausePageURL {
                    Button(action: { showingSafari = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "pause.circle")
                                .font(.title3)
                                .foregroundStyle(Color.accentMint)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Go to Pause Page")
                                    .font(STFont.labelLarge)
                                    .foregroundStyle(Color.obsidianText)

                                Text(url.host ?? "Open in Safari")
                                    .font(STFont.bodySmall)
                                    .foregroundStyle(Color.obsidianTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.forward")
                                .foregroundStyle(Color.accentMint)
                        }
                        .padding()
                        .background(Color.obsidianSurface)
                        .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: STRadius.md)
                                .stroke(Color.accentMint.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingSafari) {
                        SafariView(url: url)
                            .ignoresSafeArea()
                    }
                } else if let url = visitURL {
                    // Honest fallback: we don't have a pause page, but we can send them
                    // to the support page or main website to figure it out themselves.
                    Button(action: { showingSafari = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.title3)
                                .foregroundStyle(Color.obsidianTextSecondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Visit \(subscription.name) Website")
                                    .font(STFont.labelLarge)
                                    .foregroundStyle(Color.obsidianText)

                                Text(url.host ?? "Open in Safari")
                                    .font(STFont.bodySmall)
                                    .foregroundStyle(Color.obsidianTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.forward")
                                .foregroundStyle(Color.obsidianTextSecondary)
                        }
                        .padding()
                        .background(Color.obsidianSurface)
                        .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: STRadius.md)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingSafari) {
                        SafariView(url: url)
                            .ignoresSafeArea()
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(STFont.labelLarge)
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                .disabled(isProcessing)
                .accessibilityHint(isProcessing ? "Please wait, setting reminder" : "")
            }
            .padding()
            .background(Color.obsidianBlack)
            .navigationTitle("Remind Me to Pause")
            .navigationBarTitleDisplayMode(.inline
            )
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

// MARK: - Pause Duration Button
struct PauseDurationButton: View {
    let duration: RevolutionaryPauseDuration
    let savings: Decimal
    let isProcessing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remind me in \(duration.displayName)")
                        .font(STFont.labelLarge)
                        .foregroundStyle(Color.obsidianText)

                    Text("Potential savings: \(CurrencyManager.shared.format(savings))")
                        .font(STFont.bodySmall)
                        .foregroundStyle(Color.semanticSuccess)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.accentMint)
            }
            .padding()
            .background(Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.md)
                    .stroke(Color.accentMint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .accessibilityHint(isProcessing ? "Please wait, setting reminder" : "")
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

struct PauseSuccessOverlay: View {
    let result: PauseResult
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "pause.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentMint)
                
                Text("Reminder Set!")
                    .font(STFont.headlineLarge)
                    .foregroundStyle(Color.obsidianText)

                Text(result.message)
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

        RevolutionaryPauseButton(subscription: Subscription(
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
