import SwiftUI

// MARK: - Referral Promotion View (Dashboard Banner)


// MARK: - Referral Share Sheet


// MARK: - Referral Code Input View (for signup)


// MARK: - Apply Referral View (for existing users who received a code)

struct ApplyReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var referralManager = ReferralManager.shared
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @State private var code = ""
    @State private var isApplying = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "percent")
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(Color.inkText)
                        }
                        
                        VStack(spacing: 8) {
                            Text("30% Off Your First Month!")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.inkText)
                                .multilineTextAlignment(.center)

                            Text("Enter a referral code to get 30% off Pausely Pro")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(Color.inkTextMuted)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Code Input
                    VStack(spacing: 20) {
                        TextField("Enter referral code", text: $code)
                            .font(.system(.title2, design: .monospaced).weight(.bold))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.inkText)
                            .keyboardType(.default)
                            .submitLabel(.go)
                            .padding()
                            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote.weight(.medium))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: applyCode) {
                            HStack {
                                if isApplying {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 8)
                                }
                                
                                Text("Apply Code")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(Color.inkText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                Color.inkText
                            )
                            .cornerRadius(16)
                        }
                        .disabled(code.count < 6 || isApplying)
                        .accessibilityHint(code.count < 6 ? "Please enter a valid 6-character referral code" : isApplying ? "Please wait, applying code" : "")
                        .opacity(code.count < 6 || isApplying ? 0.6 : 1)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationTitle("Apply Referral")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.inkText)
                }
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Your referral code has been applied. You'll get 30% off your first month of Pro!")
            }
        }
    }
    
    private func applyCode() {
        guard let userId = authManager.currentUser?.id else { return }
        
        isApplying = true
        errorMessage = nil
        
        Task {
            do {
                try await referralManager.applyReferralCode(
                    code,
                    for: userId,
                    email: authManager.currentUser?.email
                )
                
                await MainActor.run {
                    isApplying = false
                    showSuccess = true
                    Feel.landed()
                }
            } catch let error as ReferralError {
                await MainActor.run {
                    isApplying = false
                    errorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    isApplying = false
                    errorMessage = "Something went wrong. Please try again."
                }
            }
        }
    }
}

// MARK: - Haptic Helper


// MARK: - Preview

