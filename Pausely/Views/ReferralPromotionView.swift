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
                AnimatedGradientBackground()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentMint.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "percent")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .foregroundColor(Color.accentMint)
                        }
                        
                        VStack(spacing: 8) {
                            Text("30% Off Your First Month!")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("Enter a referral code to get 30% off Pausely Pro")
                                .font(.system(.callout, design: .rounded).weight(.medium))
                                .foregroundColor(.white.opacity(0.7))
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
                            .foregroundColor(.white)
                            .keyboardType(.default)
                            .submitLabel(.go)
                            .padding()
                            .glass(intensity: 0.2, tint: .white)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(.footnote, design: .rounded).weight(.medium))
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
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentMint, Color.accentMint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.accentMint.opacity(0.4), radius: 15)
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
                    .foregroundColor(.white)
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
                    HapticStyle.success.trigger()
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

