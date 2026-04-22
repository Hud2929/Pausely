import SwiftUI

// MARK: - Referral Input View
/// For new users to enter referral code during signup
struct ReferralInputView: View {
    let onApply: (String) -> Void
    let onSkip: () -> Void
    
    @State private var referralCode = ""
    @State private var isValidating = false
    @State private var isValid: Bool?
    @State private var errorMessage: String?
    @State private var appear = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)
                    
                    // Header illustration
                    headerSection
                    
                    // Input section
                    inputSection
                    
                    Spacer()
                    
                    // Action buttons
                    actionButtons
                        .padding(.bottom, max(20, keyboardHeight - 20))
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appear = true
            }
            // Focus text field after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardHeight = frame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // Gift icon with animation
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.luxuryGold.opacity(0.3),
                                Color.luxuryPink.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                // Main icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.luxuryGold.opacity(0.3),
                                    Color.luxuryPurple.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.luxuryGold.opacity(0.6), .white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    Image(systemName: "gift.fill")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.luxuryGold, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Percent badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.luxuryPink, Color.luxuryPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.luxuryPink.opacity(0.5), radius: 10)
                            
                            Text("30%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 10, y: 10)
                    }
                }
                .frame(width: 110, height: 110)
                
                // Floating elements
                HStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.luxuryGold)
                        .offset(x: -60, y: -30)
                    
                    Spacer()
                    
                    Image(systemName: "sparkle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.luxuryPink)
                        .offset(x: 50, y: 20)
                }
                .frame(width: 180)
            }
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            
            // Text content
            VStack(spacing: 12) {
                Text("Have a Referral Code?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Enter it now to get 30% off Premium and help your friend earn rewards too!")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .offset(y: appear ? 0 : 20)
            .opacity(appear ? 1 : 0)
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Input field
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.luxuryGold)
                        .frame(width: 40)
                    
                    TextField("Enter referral code", text: $referralCode)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .keyboardType(.default)
                        .submitLabel(.go)
                        .onChange(of: referralCode) { _, _ in
                            // Clear validation state when typing
                            if isValid != nil {
                                isValid = nil
                                errorMessage = nil
                            }
                            // Limit to 10 characters
                            if referralCode.count > 10 {
                                referralCode = String(referralCode.prefix(10))
                            }
                        }
                        .onSubmit {
                            validateAndApply()
                        }
                    
                    // Validation indicator
                    if isValidating {
                        ProgressView()
                            .tint(Color.luxuryGold)
                    } else if let isValid = isValid {
                        Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isValid ? Color.luxuryTeal : .red)
                    }
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.1))
                        
                        // Border with validation state
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isValid == nil ? Color.luxuryGold.opacity(0.5) :
                                    (isValid == true ? Color.luxuryTeal : .red),
                                lineWidth: 2
                            )
                    }
                )
            }
            
            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Helper text
            Text("Codes are case-insensitive and can only be used once")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Apply button
            Button(action: validateAndApply) {
                HStack {
                    if isValidating {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    }
                    
                    Text("Apply Code")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: referralCode.isEmpty ?
                                        [Color.gray.opacity(0.5), Color.gray.opacity(0.3)] :
                                        [Color.luxuryPurple, Color.luxuryPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(color: referralCode.isEmpty ? Color.clear : Color.luxuryPurple.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .disabled(referralCode.isEmpty || isValidating)
            .buttonStyle(PlainButtonStyle())
            
            // Skip button
            Button(action: {
                HapticStyle.light.trigger()
                onSkip()
            }) {
                Text("I don't have a code")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ObservedObject private var referralManager = ReferralManager.shared
    
    private func validateAndApply() {
        guard !referralCode.isEmpty else { return }
        
        isTextFieldFocused = false
        isValidating = true
        errorMessage = nil
        
        // Real validation via ReferralManager
        Task {
            let isCodeValid = await referralManager.validateReferralCode(referralCode)
            
            await MainActor.run {
                isValidating = false
                
                if isCodeValid {
                    isValid = true
                    HapticStyle.success.trigger()
                    
                    // Small delay before calling onApply to show success state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onApply(referralCode.uppercased())
                    }
                } else {
                    isValid = false
                    errorMessage = "Invalid referral code. Please check and try again."
                    HapticStyle.error.trigger()
                }
            }
        }
    }
}

// MARK: - Referral Code Applied View
/// Shown after successfully applying a referral code
struct ReferralCodeAppliedView: View {
    let code: String
    let discount: String
    let onContinue: () -> Void
    
    @State private var appear = false
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.luxuryTeal.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                    
                    ZStack {
                        Circle()
                            .fill(Color.luxuryTeal.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(Color.luxuryTeal.opacity(0.5), lineWidth: 2)
                            )
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(Color.luxuryTeal)
                    }
                    .scaleEffect(scale)
                }
                
                // Text content
                VStack(spacing: 16) {
                    Text("Code Applied!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    VStack(spacing: 8) {
                        Text("Referral code \"\(code)\" has been applied")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text("You got \(discount) off!")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.luxuryGold)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
                
                // Benefits preview
                VStack(spacing: 12) {
                    BenefitPreviewRow(icon: "checkmark.circle.fill", text: "Discount applied to your account")
                    BenefitPreviewRow(icon: "checkmark.circle.fill", text: "Your friend gets referral credit too")
                    BenefitPreviewRow(icon: "crown.fill", text: "You can also earn free Pro by referring 3 friends")
                }
                .padding()
                .glass(intensity: 0.1, tint: Color.luxuryTeal)
                .offset(y: appear ? 0 : 30)
                .opacity(appear ? 1 : 0)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    HapticStyle.success.trigger()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.luxuryPurple, Color.luxuryPink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.5), .white.opacity(0)],
                                            startPoint: .top,
                                            endPoint: .center
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        )
                        .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                appear = true
            }
            HapticStyle.success.trigger()
        }
    }
}

struct BenefitPreviewRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(icon == "crown.fill" ? Color.luxuryGold : Color.luxuryTeal)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
}

// MARK: - Inline Referral Input
/// Compact inline version for use in forms
struct InlineReferralInput: View {
    @Binding var code: String
    let onApply: () -> Void
    
    @State private var isExpanded = false
    @State private var isValidating = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Header button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
                if isExpanded {
                    isFocused = true
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.luxuryGold.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "gift.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.luxuryGold)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Have a referral code?")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Get 30% off Premium")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.luxuryGold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded input section
            if isExpanded {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Enter code", text: $code)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .keyboardType(.default)
                            .submitLabel(.go)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.luxuryGold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        Button(action: {
                            HapticStyle.medium.trigger()
                            isValidating = true
                            // Simulate validation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isValidating = false
                                onApply()
                            }
                        }) {
                            if isValidating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Apply")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 70, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(code.isEmpty ? Color.gray.opacity(0.3) : Color.luxuryPurple)
                        )
                        .disabled(code.isEmpty || isValidating)
                    }
                    
                    Text("Both you and your friend will receive rewards")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .glass(intensity: 0.1, tint: Color.luxuryGold)
    }
}

// MARK: - Preview
#Preview {
    Group {
        ReferralInputView(
            onApply: { _ in },
            onSkip: {}
        )
    }
}

#Preview("Applied View") {
    ReferralCodeAppliedView(
        code: "PAUSELY2024",
        discount: "30%",
        onContinue: {}
    )
}

#Preview("Inline Input") {
    ZStack {
        AnimatedGradientBackground()
        
        InlineReferralInput(code: .constant(""), onApply: {})
            .padding(.horizontal, 20)
    }
}
