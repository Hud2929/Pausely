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
    }
    
    private func performCancellation() async {
        isProcessing = true

        // Stub: In a real app, this would call a cancellation API
        // For now, just simulate success
        let cancelResult = CancellationResult.success(savings: subscription.monthlyCost * 12)

        await MainActor.run {
            self.result = cancelResult
            self.isProcessing = false
            self.showSuccess = true

            // Haptic feedback
            Haptic.success()
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
    
    var body: some View {
        Button(action: {
            showingDurationPicker = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentMint)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause Instead")
                        .font(STFont.labelLarge)
                    
                    Text("Temporarily pause for later")
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
    }
    
    private func performPause(duration: RevolutionaryPauseDuration) async {
        isProcessing = true

        // Calculate pause end date
        let pauseEndDate = Calendar.current.date(
            byAdding: duration.calendarComponent,
            value: duration.value,
            to: Date()
        ) ?? Date()

        // Stub: In a real app, this would call a pause API
        let pauseResult = PauseResult.success(endDate: pauseEndDate)

        await MainActor.run {
            self.result = pauseResult
            self.isProcessing = false
            self.showSuccess = true
            Haptic.success()
        }
    }
}

// MARK: - Cancel Confirmation Sheet (REVOLUTIONARY - No Steps!)
struct RevolutionaryCancelConfirmationSheet: View {
    let subscription: Subscription
    let onConfirm: () async -> Void
    let onDismiss: () -> Void
    
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
                }
                
                // Savings display
                VStack(spacing: 8) {
                    Text("YOU'LL SAVE")
                        .font(STFont.labelSmall)
                        .foregroundStyle(Color.obsidianTextTertiary)
                    
                    Text(subscription.annualCost.formatted(.currency(code: "USD")))
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
    @Environment(\.dismiss) private var dismiss
    
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
                    
                    Text("Pause \(subscription.name)?")
                        .font(STFont.headlineLarge)
                        .foregroundStyle(Color.obsidianText)
                    
                    Text("Your subscription will resume automatically")
                        .font(STFont.bodyMedium)
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Duration options
                VStack(spacing: 12) {
                    ForEach(RevolutionaryPauseDuration.allCases, id: \.self) { duration in
                        PauseDurationButton(
                            duration: duration,
                            savings: subscription.monthlyCost * Decimal(duration.value),
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
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(STFont.labelLarge)
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                .disabled(isProcessing)
                .accessibilityHint(isProcessing ? "Please wait, pause in progress" : "")
            }
            .padding()
            .background(Color.obsidianBlack)
            .navigationTitle("Pause")
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
                    Text("Pause for \(duration.displayName)")
                        .font(STFont.labelLarge)
                        .foregroundStyle(Color.obsidianText)
                    
                    Text("Save \(savings.formatted(.currency(code: "USD")))")
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
        .accessibilityHint(isProcessing ? "Please wait, pause in progress" : "")
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
                
                Text("Paused!")
                    .font(STFont.headlineLarge)
                    .foregroundStyle(Color.obsidianText)
                
                Text(result.message)
                    .font(STFont.bodyMedium)
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
                
                if let savings = result.monthlySavings {
                    Label("Saving \(savings.formatted(.currency(code: "USD")))/month", 
                          systemImage: "dollarsign.circle")
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
    }
    .padding()
    .background(Color.obsidianBlack)
}
