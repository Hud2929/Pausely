import SwiftUI
import StoreKit

struct CancellationRequestView: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = CancellationService.shared
    @StateObject private var paymentManager = PaymentManager.shared
    @State private var accountEmail = ""
    @State private var selectedReason: CancellationReason = .tooExpensive
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var showPaymentSheet = false
    @State private var submittedRequest: CancellationRequest?
    @State private var showConfirmation = false

    private var isValid: Bool {
        !accountEmail.isEmpty && accountEmail.contains("@")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                            .padding(.horizontal, 20)

                        formSection
                            .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Cancel for Me")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.luxuryGold)
                }
            }
        }
        .sheet(isPresented: $showPaymentSheet) {
            CancellationPaymentSheet(
                subscriptionName: subscription.name,
                onComplete: {
                    if let request = submittedRequest {
                        service.markPaymentCompleted(for: request.id)
                    }
                    showPaymentSheet = false
                    showConfirmation = true
                },
                onCancel: { showPaymentSheet = false }
            )
        }
        .alert("Request Submitted", isPresented: $showConfirmation) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your cancellation request for \(subscription.name) is in progress. We'll handle it within 24 hours.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "xmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.luxuryPurple)
            }

            VStack(spacing: 6) {
                Text("Cancel \(subscription.name)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("We handle the cancellation for you")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(Color.luxuryTeal)

                Text("$5 one-time fee")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.luxuryTeal)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.luxuryTeal.opacity(0.15))
            .clipShape(Capsule())
        }
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Account Email")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))

                PremiumTextField(
                    placeholder: "your@email.com",
                    text: $accountEmail,
                    keyboardType: .emailAddress,
                    autocapitalization: .never
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reason")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))

                Picker("Reason", selection: $selectedReason) {
                    ForEach(CancellationReason.allCases, id: \.self) { reason in
                        Text(reason.rawValue).tag(reason)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PremiumRadius.md)
                        .fill(BackgroundColors.tertiary)
                )
                .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Additional Notes (Optional)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))

                TextEditor(text: $notes)
                    .font(PremiumTypography.body)
                    .foregroundColor(TextColors.primary)
                    .frame(minHeight: 100)
                    .padding(PremiumSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: PremiumRadius.md)
                            .fill(BackgroundColors.tertiary)
                    )
            }

            Button(action: submitRequest) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Submit Request — $5")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: PremiumRadius.md)
                        .fill(isValid ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(Color.gray.opacity(0.4)))
                )
            }
            .disabled(!isValid || isSubmitting)
            .padding(.top, 8)
        }
    }

    private func submitRequest() {
        guard isValid else { return }
        isSubmitting = true
        HapticStyle.medium.trigger()

        let request = service.submitRequest(
            subscriptionName: subscription.name,
            accountEmail: accountEmail,
            reason: selectedReason,
            notes: notes
        )
        submittedRequest = request
        isSubmitting = false
        showPaymentSheet = true
    }
}

struct CancellationPaymentSheet: View {
    let subscriptionName: String
    let onComplete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.luxuryGold.opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: "creditcard.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.luxuryGold)
                        }

                        Text("Complete Payment")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text("One-time $5 fee to cancel \(subscriptionName)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        HStack {
                            Text("Cancellation Service")
                                .font(.body)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("$5.00")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }

                        Divider()
                            .background(.white.opacity(0.1))

                        HStack {
                            Text("Total")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("$5.00")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.luxuryGold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(BackgroundColors.secondary)
                    )
                    .padding(.horizontal, 20)

                    Button(action: {
                        HapticStyle.success.trigger()
                        onComplete()
                    }) {
                        Text("Pay $5.00")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: PremiumRadius.md)
                                    .fill(Color.brandGradient)
                            )
                    }
                    .padding(.horizontal, 20)

                    Button("Cancel", role: .cancel, action: onCancel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { onCancel() }
                        .foregroundStyle(Color.luxuryGold)
                }
            }
        }
    }
}
