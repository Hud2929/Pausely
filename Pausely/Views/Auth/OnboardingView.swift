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
            AnimatedGradientBackground()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.luxuryGold.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: "envelope.badge.shield.fill")
                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.luxuryGold, .white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Text
                VStack(spacing: 16) {
                    Text("Verify Your Email")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("Enter the 6-digit code we sent to")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(email)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.luxuryGold)
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
                            .foregroundStyle(Color.semanticDestructive)
                        Text(error)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color.semanticDestructive)
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
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: isCodeComplete
                                    ? [Color.luxuryPurple, Color.luxuryPink]
                                    : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled(!isCodeComplete || isVerifying)

                    Button(action: resendCode) {
                        HStack {
                            if resendTimer < 60 {
                                Text("Resend code in \(resendTimer)s")
                                    .foregroundStyle(.white.opacity(0.5))
                            } else {
                                Text("Resend Code")
                                    .foregroundStyle(.white)
                            }
                        }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glass(intensity: 0.2, tint: .white)
                    }
                    .disabled(resendTimer < 60)

                    Button(action: goBackToSignIn) {
                        Text("Use Different Email")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
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
        HapticStyle.medium.trigger()

        Task {
            do {
                try await authManager.verifyEmailOTP(email: email, code: code)
                await MainActor.run {
                    isVerifying = false
                    HapticStyle.success.trigger()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    HapticStyle.error.trigger()
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
                            isFocused ? Color.luxuryGold : Color.white.opacity(0.15),
                            lineWidth: isFocused ? 2 : 1
                        )
                )

            Text(text)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

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

struct EnhancedLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isSignUp = false
    @State private var showEmailConfirmation = false
    @State private var showPasswordReset = false
    @State private var rememberMe = true
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = RevolutionaryAuthManager.shared
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }

    private var isPasswordValid: Bool {
        PasswordStrength.rulesMet(password) == 4
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && (!isSignUp || isPasswordValid)
    }

    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    formSection
                    
                    if !errorMessage.isEmpty {
                        ErrorMessageView(message: errorMessage)
                    }
                    
                    actionButton
                    
                    if !isSignUp {
                        biometricSection
                    }
                    
                    toggleButton
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showEmailConfirmation) {
            EmailConfirmationView(email: email)
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView(email: email)
        }
        .onReceive(NotificationCenter.default.publisher(for: .biometricAuthSuccess)) { notification in
            HapticStyle.success.trigger()
            if let email = notification.object as? String {
                self.email = email
                focusedField = .password
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .biometricAuthFailed)) { _ in
            HapticStyle.error.trigger()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.luxuryPurple, Color.luxuryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.luxuryPurple.opacity(0.5), radius: 20)
                
                Image(systemName: "pause.circle.fill")
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            Text(isSignUp ? "Start managing your subscriptions" : "Sign in to continue")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 40)
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            EnhancedTextField(
                title: "Email",
                icon: "envelope",
                text: $email,
                isSecure: false
            )
            .focused($focusedField, equals: .email)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }
            
            EnhancedTextField(
                title: "Password",
                icon: "lock",
                text: $password,
                isSecure: true
            )
            .focused($focusedField, equals: .password)
            .textContentType(isSignUp ? .newPassword : .password)
            .submitLabel(.go)
            .onSubmit {
                isSignUp ? signUp() : signIn()
            }

            if isSignUp && !password.isEmpty {
                PasswordStrengthMeter(password: password)
            }

            if !isSignUp {
                HStack {
                    Toggle("Remember me", isOn: $rememberMe)
                        .toggleStyle(RememberMeToggleStyle())
                    
                    Spacer()
                    
                    Button("Forgot Password?") {
                        showPasswordReset = true
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.luxuryGold)
                }
            }
        }
    }
    
    private var actionButton: some View {
        Button(action: isSignUp ? signUp : signIn) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.luxuryPurple, Color.luxuryPink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 15)
        }
        .disabled(!canSubmit || isLoading)
        .accessibilityHint(!canSubmit ? "Please enter your email and password" : isLoading ? "Please wait, signing in" : "")
        .opacity(!canSubmit ? 0.6 : 1)
    }
    
    private var biometricSection: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 1)
                
                Text("or")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 1)
            }
            
            Button(action: attemptBiometricAuth) {
                HStack(spacing: 12) {
                    Image(systemName: biometricIcon)
                        .font(.system(.body, design: .rounded))
                    Text("Sign in with \(biometricType)")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .glass(intensity: 0.2, tint: .white)
            }
        }
    }
    
    private var toggleButton: some View {
        Button(action: {
            withAnimation {
                isSignUp.toggle()
                errorMessage = ""
            }
        }) {
            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 8)
    }
    
    private var biometricType: String {
        let context = LAContext()
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometrics"
        }
    }
    
    private var biometricIcon: String {
        let context = LAContext()
        switch context.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.shield"
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        HapticStyle.medium.trigger()
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password, rememberMe: rememberMe)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch let error as PauselyAuthError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticStyle.error.trigger()

                    if case .emailNotConfirmed = error {
                        showEmailConfirmation = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticStyle.error.trigger()
                }
            }
        }
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = ""
        HapticStyle.medium.trigger()

        Task {
            do {
                try await authManager.signUpWithOTP(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    // OTP sent — show code entry screen
                    if !authManager.isAuthenticated {
                        showEmailConfirmation = true
                    }
                    // If already authenticated (edge case), the app will show MainTabView
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticStyle.error.trigger()
                }
            }
        }
    }

    private func attemptBiometricAuth() {
        Task {
            await authManager.attemptBiometricAuth()
        }
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
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24)
                
                if isSecure && !showPassword {
                    SecureField("", text: $text)
                        .foregroundStyle(.white)
                } else {
                    TextField("", text: $text)
                        .foregroundStyle(.white)
                }
                
                if isSecure {
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
            }
            .padding()
            .glass(intensity: 0.15, tint: .white)
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white)
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

struct RememberMeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? Color.luxuryGold : .white.opacity(0.5))
                .font(.system(.body, design: .rounded))

            Text("Remember me")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .onTapGesture {
            configuration.isOn.toggle()
        }
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
            AnimatedGradientBackground()
            
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
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(Color.luxuryGold)

            VStack(spacing: 12) {
                Text("Reset Password")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            EnhancedTextField(
                title: "Email",
                icon: "envelope",
                text: $resetEmail,
                isSecure: false
            )
            
            if !errorMessage.isEmpty {
                ErrorMessageView(message: errorMessage)
            }
            
            Button(action: sendReset) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Send Reset Link")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.luxuryPurple, Color.luxuryPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(resetEmail.isEmpty || isLoading)
            .accessibilityHint(resetEmail.isEmpty ? "Please enter your email address" : isLoading ? "Please wait, sending reset link" : "")

            Button("Cancel") {
                dismiss()
            }
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
        }
    }
    
    private var successView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(Color.luxuryTeal)

            VStack(spacing: 12) {
                Text("Check Your Email")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("We've sent a password reset link to")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Text(resetEmail)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.luxuryGold)
            }
            
            Button("Done") {
                dismiss()
            }
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.luxuryGold.opacity(0.3))
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
                    HapticStyle.warning.trigger()
                }
            }
        }
    }
}

struct EnhancedLoginView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedLoginView()
    }
}


struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Color(hex: "00F0FF"))
                .frame(width: 24)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}
