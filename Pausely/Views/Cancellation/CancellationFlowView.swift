//
//  CancellationFlowView.swift
//  Pausely
//
//  4-Step Cancellation Concierge
//

import SwiftUI
import SafariServices
import MessageUI

// MARK: - Cancellation Flow View
struct CancellationFlowView: View {
    let subscription: Subscription
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var currentStep: CancellationStep = .confirm
    @State private var selectedMethod: CancellationMethod?
    @State private var isShowingSafari = false
    @State private var isShowingMail = false
    @State private var cancellationURL: URL?
    @State private var emailDraft: CancellationEmail?
    @State private var estimatedSavings: Decimal = 0
    @Environment(\.dismiss) private var dismiss
    
    enum CancellationStep {
        case confirm
        case method
        case execute
        case success
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: stepProgress, total: 1.0)
                    .tint(.accentMint)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Step content
                ScrollView {
                    VStack(spacing: STSpacing.xl) {
                        switch currentStep {
                        case .confirm:
                            ConfirmCancellationStep(
                                subscription: subscription,
                                onContinue: { currentStep = .method },
                                onCancel: { dismiss() }
                            )
                        case .method:
                            CancellationMethodStep(
                                subscription: subscription,
                                onSelect: { method in
                                    selectedMethod = method
                                    prepareCancellation(method: method)
                                    currentStep = .execute
                                }
                            )
                        case .execute:
                            ExecuteCancellationStep(
                                subscription: subscription,
                                method: selectedMethod ?? .website,
                                onOpenLink: {
                                    if cancellationURL != nil {
                                        isShowingSafari = true
                                    }
                                },
                                onSendEmail: {
                                    isShowingMail = true
                                },
                                onCall: {
                                    if let phone = subscription.pauseUrl,
                                       let url = URL(string: "tel:\(phone)") {
                                        UIApplication.shared.open(url)
                                    }
                                },
                                onComplete: {
                                    currentStep = .success
                                }
                            )
                        case .success:
                            CancellationSuccessStep(
                                subscription: subscription,
                                savings: estimatedSavings,
                                onDone: {
                                    onComplete()
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Cancel Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentMint)
                }
            }
        }
        .sheet(isPresented: $isShowingSafari) {
            if let url = cancellationURL {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $isShowingMail) {
            if let email = emailDraft {
                MailView(email: email)
            }
        }
        .onAppear {
            calculateSavings()
        }
    }
    
    private var stepProgress: Double {
        switch currentStep {
        case .confirm:   return 0.25
        case .method:    return 0.5
        case .execute:   return 0.75
        case .success:   return 1.0
        }
    }
    
    private func calculateSavings() {
        estimatedSavings = subscription.annualCost
    }
    
    private func prepareCancellation(method: CancellationMethod) {
        switch method {
        case .website:
            cancellationURL = URL(string: subscription.pauseUrl ?? "https://google.com/search?q=how+to+cancel+\(subscription.name)")
        case .email:
            emailDraft = CancellationEmail(
                to: "support@\(subscription.name.lowercased().replacingOccurrences(of: " ", with: "")).com",
                subject: "Cancellation Request - \(subscription.name)",
                body: generateEmailBody()
            )
        case .phone:
            break
        case .inApp:
            cancellationURL = URL(string: "https://apps.apple.com")
        }
    }
    
    private func generateEmailBody() -> String {
        """
        Dear \(subscription.name) Support,
        
        I am writing to request the immediate cancellation of my subscription.
        
        Account Details:
        - Service: \(subscription.name)
        - Current Plan: \(subscription.billingFrequency.displayName)
        - Amount: \(subscription.displayAmount)
        
        Please confirm cancellation and ensure no further charges are made to my account.
        
        Thank you,
        [Your Name]
        """
    }
}

// MARK: - Step 1: Confirm Cancellation
struct ConfirmCancellationStep: View {
    let subscription: Subscription
    let onContinue: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: STSpacing.xxl) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.semanticDestructive.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.semanticDestructive)
            }
            
            // Title
            Text("Cancel \(subscription.name)?")
                .font(STFont.headlineLarge)
                .foregroundStyle(Color.obsidianText)
            
            // Cost breakdown
            VStack(spacing: STSpacing.base) {
                HStack {
                    Text("Monthly cost:")
                        .foregroundStyle(Color.obsidianTextSecondary)
                    Spacer()
                    Text(subscription.displayAmount)
                        .font(STFont.monoSmall)
                        .foregroundStyle(Color.obsidianText)
                }
                
                HStack {
                    Text("Annual cost:")
                        .foregroundStyle(Color.obsidianTextSecondary)
                    Spacer()
                    Text(subscription.displayAnnualCost)
                        .font(STFont.monoSmall)
                        .foregroundStyle(Color.obsidianText)
                }
                
                Divider()
                    .background(Color.obsidianBorder)
                
                HStack {
                    Text("You'll save:")
                        .font(STFont.labelLarge)
                        .foregroundStyle(Color.semanticSuccess)
                    Spacer()
                    Text(subscription.displayAnnualCost)
                        .font(STFont.monoMedium)
                        .foregroundStyle(Color.semanticSuccess)
                }
            }
            .padding()
            .background(Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
            
            Spacer()
            
            // Buttons
            VStack(spacing: STSpacing.base) {
                STButton("Yes, Help Me Cancel", style: .destructive, icon: "xmark") {
                    onContinue()
                }
                
                STButton("Keep Subscription", style: .secondary) {
                    onCancel()
                }
            }
        }
    }
}

// MARK: - Step 2: Cancellation Method
struct CancellationMethodStep: View {
    let subscription: Subscription
    let onSelect: (CancellationMethod) -> Void
    
    var body: some View {
        VStack(spacing: STSpacing.xl) {
            Text("How would you like to cancel?")
                .font(STFont.headlineMedium)
                .foregroundStyle(Color.obsidianText)
            
            Text("We'll guide you through the easiest method.")
                .font(STFont.bodyMedium)
                .foregroundStyle(Color.obsidianTextSecondary)
            
            VStack(spacing: STSpacing.base) {
                MethodButton(
                    icon: "globe",
                    title: "Cancel Online",
                    subtitle: "Fastest - takes 2 minutes",
                    isRecommended: true
                ) {
                    onSelect(.website)
                }
                
                MethodButton(
                    icon: "envelope",
                    title: "Send Email",
                    subtitle: "We'll draft it for you",
                    isRecommended: false
                ) {
                    onSelect(.email)
                }
                
                MethodButton(
                    icon: "phone",
                    title: "Call Support",
                    subtitle: "May require waiting",
                    isRecommended: false
                ) {
                    onSelect(.phone)
                }
            }
        }
    }
}

struct MethodButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: STSpacing.base) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentMint)
                    .frame(width: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(STFont.labelLarge)
                            .foregroundStyle(Color.obsidianText)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.obsidianBlack)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentMint)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(STFont.bodySmall)
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            .padding()
            .background(Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.md)
                    .stroke(isRecommended ? Color.accentMint : Color.obsidianBorder, lineWidth: isRecommended ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: Execute Cancellation
struct ExecuteCancellationStep: View {
    let subscription: Subscription
    let method: CancellationMethod
    let onOpenLink: () -> Void
    let onSendEmail: () -> Void
    let onCall: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: STSpacing.xl) {
            Text("Follow these steps")
                .font(STFont.headlineMedium)
                .foregroundStyle(Color.obsidianText)
            
            switch method {
            case .website:
                WebsiteCancellationView(onOpenLink: onOpenLink)
            case .email:
                EmailCancellationView(onSendEmail: onSendEmail)
            case .phone:
                PhoneCancellationView(onCall: onCall)
            case .inApp:
                InAppCancellationView()
            }
            
            Spacer()
            
            Text("Did you complete the cancellation?")
                .font(STFont.bodyMedium)
                .foregroundStyle(Color.obsidianTextSecondary)
            
            HStack(spacing: STSpacing.base) {
                STButton("Yes, Cancelled", style: .primary) {
                    onComplete()
                }
                
                STButton("Remind Me Later", style: .ghost) {
                    // Schedule reminder
                }
            }
        }
    }
}

struct WebsiteCancellationView: View {
    let onOpenLink: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: STSpacing.base) {
            CancellationStepRow(number: 1, text: "Click the button below to open the cancellation page")
            CancellationStepRow(number: 2, text: "Sign in to your account if required")
            CancellationStepRow(number: 3, text: "Follow the cancellation steps on their website")
            CancellationStepRow(number: 4, text: "Confirm the cancellation and save any confirmation")
            
            STButton("Open Cancellation Page", style: .primary, icon: "arrow.up.right") {
                onOpenLink()
            }
            .padding(.top)
        }
        .padding()
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
    }
}

struct EmailCancellationView: View {
    let onSendEmail: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: STSpacing.base) {
            CancellationStepRow(number: 1, text: "We've drafted a cancellation email for you")
            CancellationStepRow(number: 2, text: "Click below to open your email app")
            CancellationStepRow(number: 3, text: "Send the pre-filled email")
            CancellationStepRow(number: 4, text: "Wait for their confirmation reply")
            
            STButton("Open Email App", style: .primary, icon: "envelope") {
                onSendEmail()
            }
            .padding(.top)
        }
        .padding()
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
    }
}

struct PhoneCancellationView: View {
    let onCall: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: STSpacing.base) {
            CancellationStepRow(number: 1, text: "Call the support number below")
            CancellationStepRow(number: 2, text: "Ask to cancel your subscription")
            CancellationStepRow(number: 3, text: "Request a confirmation email")
            CancellationStepRow(number: 4, text: "Note the representative's name")
            
            STButton("Call Support", style: .primary, icon: "phone") {
                onCall()
            }
            .padding(.top)
        }
        .padding()
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
    }
}

struct InAppCancellationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: STSpacing.base) {
            CancellationStepRow(number: 1, text: "Open the app on your device")
            CancellationStepRow(number: 2, text: "Go to Settings or Account")
            CancellationStepRow(number: 3, text: "Look for 'Subscription' or 'Billing'")
            CancellationStepRow(number: 4, text: "Tap 'Cancel Subscription'")
        }
        .padding()
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
    }
}

struct CancellationStepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: STSpacing.base) {
            Text("\(number)")
                .font(STFont.labelMedium)
                .foregroundStyle(Color.obsidianBlack)
                .frame(width: 24, height: 24)
                .background(Color.accentMint)
                .clipShape(Circle())
            
            Text(text)
                .font(STFont.bodyMedium)
                .foregroundStyle(Color.obsidianText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Step 4: Success
struct CancellationSuccessStep: View {
    let subscription: Subscription
    let savings: Decimal
    let onDone: () -> Void
    
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: STSpacing.xxl) {
            // Confetti animation placeholder
            ZStack {
                Circle()
                    .fill(Color.semanticSuccess.opacity(0.2))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.semanticSuccess)
                    .scaleEffect(showConfetti ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showConfetti)
            }
            .onAppear {
                showConfetti = true
                STAnimation.success()
            }
            
            Text("Subscription Cancelled!")
                .font(STFont.displaySmall)
                .foregroundStyle(Color.obsidianText)
            
            Text("You've taken control of your spending.")
                .font(STFont.bodyLarge)
                .foregroundStyle(Color.obsidianTextSecondary)
            
            // Savings card
            VStack(spacing: STSpacing.base) {
                Text("YOUR ANNUAL SAVINGS")
                    .font(STFont.labelSmall)
                    .foregroundStyle(Color.obsidianTextTertiary)
                
                AnimatedCounter(
                    value: savings,
                    font: STFont.displayMedium,
                    color: .semanticSuccess
                )
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.semanticSuccess.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.lg)
                    .stroke(Color.semanticSuccess.opacity(0.3), lineWidth: 1)
            )
            
            Spacer()
            
            STButton("Done", style: .primary) {
                onDone()
            }
        }
    }
}

// MARK: - Supporting Types
enum CancellationMethod {
    case website
    case email
    case phone
    case inApp
}

struct CancellationEmail {
    let to: String
    let subject: String
    let body: String
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Mail View
struct MailView: UIViewControllerRepresentable {
    let email: CancellationEmail
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setToRecipients([email.to])
        composer.setSubject(email.subject)
        composer.setMessageBody(email.body, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
