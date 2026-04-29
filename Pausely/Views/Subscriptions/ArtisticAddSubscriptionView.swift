import SwiftUI

struct ArtisticAddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared

    @State private var name = ""
    @State private var amount = ""
    @State private var selectedFrequency: BillingFrequency = .monthly
    @State private var selectedCategory: NeuralSubscriptionCategory = .entertainment
    @State private var nextRenewalDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

    @State private var currentStep = 0
    @State private var isSaving = false
    @State private var showConfetti = false

    let steps = ["Name", "Amount", "Schedule"]

    var canProceed: Bool {
        switch currentStep {
        case 0: return !name.isEmpty
        case 1: return !amount.isEmpty && Double(amount) != nil
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                // Confetti overlay for first subscription celebration
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // Progress
                    StepProgressView(steps: steps, currentStep: currentStep)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Content
                    TabView(selection: $currentStep) {
                        // Step 1: Name
                        NameStepView(name: $name, selectedCategory: $selectedCategory)
                            .tag(0)

                        // Step 2: Amount
                        AmountStepView(amount: $amount, selectedFrequency: $selectedFrequency)
                            .tag(1)

                        // Step 3: Schedule
                        ScheduleStepView(nextRenewalDate: $nextRenewalDate)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                    // Navigation Buttons
                    HStack(spacing: 16) {
                        if currentStep > 0 {
                            Button(action: { currentStep -= 1 }) {
                                Image(systemName: "arrow.left")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(BackgroundColors.tertiary)
                                    )
                            }
                            .accessibilityLabel("Previous step")
                        }

                        Button(action: {
                            if currentStep < steps.count - 1 {
                                currentStep += 1
                            } else {
                                saveSubscription()
                            }
                        }) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(currentStep == steps.count - 1 ? "Save" : "Continue")
                                        .font(.callout.weight(.semibold))

                                    if currentStep < steps.count - 1 {
                                        Image(systemName: "arrow.right")
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.brandGradient)
                            )
                        }
                        .disabled(!canProceed || isSaving)
                        .accessibilityHint(!canProceed ? "Please complete the current step" : isSaving ? "Please wait, saving subscription" : "")
                        .opacity(canProceed ? 1 : 0.6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(TextColors.secondary)
                }
            }
        }
    }

    private func saveSubscription() {
        isSaving = true

        Task {
            guard let amountValue = Decimal(string: amount) else {
                isSaving = false
                return
            }

            let subscription = Subscription(
                name: name,
                category: selectedCategory.rawValue,
                amount: amountValue,
                currency: "USD",
                billingFrequency: selectedFrequency,
                nextBillingDate: nextRenewalDate
            )

            do {
                let wasFirstSubscription = store.subscriptions.isEmpty
                _ = try await store.addSubscription(subscription)

                await MainActor.run {
                    isSaving = false
                    if wasFirstSubscription {
                        showConfetti = true
                        HapticStyle.success.trigger()
                        // Dismiss after confetti plays
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            dismiss()
                        }
                    } else {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}
