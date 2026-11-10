// This file is now merged into PauselyApp.swift
// Keeping this for reference, but the main OnboardingView is now in PauselyApp.swift

import SwiftUI
import LocalAuthentication

// Note: OnboardingView has been moved to PauselyApp.swift
// This file can be deleted after confirming the app compiles correctly

struct EmailConfirmationView: View {
    let email: String
    @StateObject private var authManager = RevolutionaryAuthManager.shared
    @State private var otpCode: [String] = Array(repeating: "", count: 6)
    @State private var resendTimer = 60
    @State private var timer: Timer?
    @State private var showResendSuccess = false
    @State private var isVerifying = false
    @State private var resendError: String?
    @State private var verificationError: String?
    @State private var focusedIndex = 0
    @Environment(\.dismiss) private var dismiss

    var isCodeComplete: Bool {
        otpCode.allSatisfy { $0.count == 1 }
    }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            Color.inkText
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)

                    Circle()
                        .fill(Color.inkRaised)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.inkText,
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: "envelope.badge.shield.fill")
                        .font(.largeTitle.weight(.light))
                        .foregroundStyle(
                            Color.inkText
                        )
                }

                // Text
                VStack(spacing: 16) {
                    Text("Verify Your Email")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.inkText)

                    Text("Enter the 6-digit code we sent to")
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)

                    Text(email)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                }

                // OTP Input
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPDigitBox(
                            index: index,
                            text: $otpCode[index],
                            isFocused: focusedIndex == index,
                            onBackspace: { handleBackspace(at: index) },
                            onFocus: { focusedIndex = index }
                        )
                        .onChange(of: otpCode[index]) { newValue in
                            handleDigitChange(at: index, newValue: newValue)
                        }
                    }
                }
                .padding(.horizontal, 20)

                if let error = verificationError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.due)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Color.due)
                    }
                    .padding(.horizontal, 32)
                }

                // Tips
                VStack(alignment: .leading, spacing: 12) {
                    TipRow(icon: "mail.stack", text: "Check your spam/junk folder")
                    TipRow(icon: "clock", text: "The code may take a minute to arrive")
                }
                .padding(.horizontal, 32)

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button(action: verifyCode) {
                        HStack {
                            if isVerifying {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text("Verify")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Color.inkText
                        )
                        .cornerRadius(16)
                    }
                    .disabled(!isCodeComplete || isVerifying)

                    Button(action: resendCode) {
                        HStack {
                            if resendTimer < 60 {
                                Text("Resend code in \(resendTimer)s")
                                    .foregroundStyle(Color.inkTextFaint)
                            } else {
                                Text("Resend Code")
                                    .foregroundStyle(Color.inkText)
                            }
                        }
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
                    }
                    .disabled(resendTimer < 60)

                    Button(action: goBackToSignIn) {
                        Text("Use Different Email")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkTextMuted)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .errorBanner($resendError)
        .alert("Code Sent!", isPresented: $showResendSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A new 6-digit verification code has been sent to \(email)")
        }
        .onAppear {
            startTimer()
            // Auto-focus first box
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedIndex = 0
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func handleDigitChange(at index: Int, newValue: String) {
        // Only keep the last character
        if newValue.count > 1 {
            otpCode[index] = String(newValue.suffix(1))
        }

        // Move to next field if a digit was entered
        if newValue.count == 1 && index < 5 {
            focusedIndex = index + 1
        }

        // Auto-verify when all 6 digits are entered
        if isCodeComplete && index == 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                verifyCode()
            }
        }
    }

    private func handleBackspace(at index: Int) {
        if otpCode[index].isEmpty && index > 0 {
            otpCode[index - 1] = ""
            focusedIndex = index - 1
        }
    }

    private func verifyCode() {
        guard isCodeComplete else { return }
        let code = otpCode.joined()
        isVerifying = true
        verificationError = nil

        Task {
            do {
                try await authManager.verifyEmailOTP(email: email, code: code)
                await MainActor.run {
                    isVerifying = false
                    Feel.landed()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    verificationError = "Invalid code. Please try again."
                    // Clear code for retry
                    otpCode = Array(repeating: "", count: 6)
                    focusedIndex = 0
                }
            }
        }
    }

    private func resendCode() {
        Task {
            do {
                try await authManager.resendOTP(email: email)
                await MainActor.run {
                    showResendSuccess = true
                    resendTimer = 60
                    startTimer()
                    otpCode = Array(repeating: "", count: 6)
                    focusedIndex = 0
                    verificationError = nil
                }
            } catch {
                await MainActor.run {
                    resendError = "Failed to resend code. Please try again."
                }
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendTimer > 0 {
                resendTimer -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func goBackToSignIn() {
        Task {
            await MainActor.run {
                authManager.state = .unauthenticated
            }
        }
        dismiss()
    }
}

// MARK: - OTP Digit Box

struct OTPDigitBox: View {
    let index: Int
    @Binding var text: String
    let isFocused: Bool
    let onBackspace: () -> Void
    let onFocus: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused ? Color.inkText : Color.white.opacity(0.15),
                            lineWidth: isFocused ? 2 : 1
                        )
                )

            Text(text)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.inkText)

            // Hidden text field for actual input
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundStyle(.clear)
                .accentColor(.clear)
                .background(Color.clear)
                .onTapGesture {
                    onFocus()
                }
        }
        .frame(width: 48, height: 56)
    }
}

struct EmailConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailConfirmationView(email: "user@example.com")
    }
}


struct EnhancedTextField: View {
    let title: String
    let icon: String
    @Binding var text: String
    let isSecure: Bool
    @State private var showPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.inkTextFaint)
                    .frame(width: 24)
                
                if isSecure && !showPassword {
                    SecureField("", text: $text)
                        .foregroundStyle(Color.inkText)
                } else {
                    TextField("", text: $text)
                        .foregroundStyle(Color.inkText)
                }
                
                if isSecure {
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(Color.inkTextFaint)
                    }
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
            }
            .padding()
            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.decide)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.inkText)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}


struct PasswordResetView: View {
    let email: String
    @State private var resetEmail: String = ""
    @State private var isLoading = false
    @State private var isSent = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = RevolutionaryAuthManager.shared
    
    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            
            VStack(spacing: 32) {
                if isSent {
                    successView
                } else {
                    formView
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var formView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "lock.rotation")
                .font(.largeTitle)
                .foregroundStyle(Color.inkText)

            VStack(spacing: 12) {
                Text("Reset Password")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.inkText)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.center)
            }
            
            EnhancedTextField(
                title: "Email",
                icon: "envelope",
                text: $resetEmail,
                isSecure: false
            )
            .accessibilityIdentifier("resetEmailTextField")

            if !errorMessage.isEmpty {
                ErrorMessageView(message: errorMessage)
            }

            Button(action: sendReset) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Send Reset Link")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Color.inkText)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Color.inkText
                )
                .cornerRadius(16)
            }
            .disabled(resetEmail.isEmpty || isLoading)
            .accessibilityIdentifier("sendResetLinkButton")
            .accessibilityHint(resetEmail.isEmpty ? "Please enter your email address" : isLoading ? "Please wait, sending reset link" : "")

            Button("Cancel") {
                dismiss()
            }
            .accessibilityIdentifier("cancelButton")
            .font(.body.weight(.medium))
            .foregroundStyle(Color.inkTextMuted)
            
            Spacer()
        }
    }
    
    private var successView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.inkText)

            VStack(spacing: 12) {
                Text("Check Your Email")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.inkText)

                Text("We've sent a password reset link to")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)

                Text(resetEmail)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)
            }
            
            Button("Done") {
                dismiss()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.inkText)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.inkTextMuted)
            .cornerRadius(16)
            
            Spacer()
        }
    }
    
    private func sendReset() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authManager.sendPasswordReset(email: resetEmail)
                await MainActor.run {
                    isLoading = false
                    isSent = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}


struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color(hex: "00F0FF"))
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.inkText)
            
            Spacer()
        }
    }
}
