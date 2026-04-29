import SwiftUI

// MARK: - Referral Promotion View (Dashboard Banner)

struct ReferralPromotionView: View {
    @ObservedObject private var referralManager = ReferralManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var showReferralSheet = false
    @State private var showApplySheet = false
    @State private var appear = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.white)

                        Text("REFER & EARN")
                            .font(.system(.caption2, design: .rounded).weight(.heavy))
                            .foregroundColor(.white)
                    }
                    
                    Text("Get Free Pro + Give 30% Off")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Animated gift icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "gift.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(appear ? 0 : -10))
                        .animation(
                            UIAccessibility.isReduceMotionEnabled
                                ? .none
                                : .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                            value: appear
                        )
                }
            }
            
            // Benefits
            HStack(spacing: 12) {
                BenefitItem(
                    icon: "person.2.fill",
                    text: "Refer 3 friends",
                    subtext: "Get FREE Pro"
                )
                
                BenefitItem(
                    icon: "percent",
                    text: "They get 30% off",
                    subtext: "First month"
                )
            }
            
            // CTA Button
            Button(action: {
                HapticStyle.medium.trigger()
                showReferralSheet = true
            }) {
                HStack {
                    Image(systemName: "share.fill")
                    Text(paymentManager.isPremium ? "Refer Friends" : "Get 30% Off")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                }
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.luxuryPurple,
                    Color.luxuryPink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 20, x: 0, y: 10)
        .sheet(isPresented: $showReferralSheet) {
            ReferralShareSheet()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                appear = true
            }
        }
    }
}

struct BenefitItem: View {
    let icon: String
    let text: String
    let subtext: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)

                Text(subtext)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Referral Share Sheet

struct ReferralShareSheet: View {
    @ObservedObject private var referralManager = ReferralManager.shared
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var showCopiedAlert = false
    @State private var referralCode: String?
    @State private var loadError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.luxuryPurple, Color.luxuryPink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: Color.luxuryPurple.opacity(0.5), radius: 20)
                                
                                Image(systemName: "gift.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Refer Friends, Earn Rewards")
                                    .font(.system(.title, design: .rounded).weight(.bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text("Share your code and both get rewarded")
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.top, 20)
                        
                        // Rewards Info
                        VStack(spacing: 16) {
                            RewardCard(
                                icon: "person.2.fill",
                                title: "You Get",
                                description: "FREE Pro when 3 friends subscribe",
                                color: Color.luxuryGold
                            )
                            
                            RewardCard(
                                icon: "percent",
                                title: "They Get",
                                description: "30% off their first month of Pro",
                                color: Color.luxuryTeal
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Referral Code Section
                        VStack(spacing: 20) {
                            if let code = referralCode {
                                // Code Display
                                VStack(spacing: 12) {
                                    Text("YOUR REFERRAL CODE")
                                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    HStack(spacing: 16) {
                                        Text(code)
                                            .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                                            .foregroundColor(.white)
                                            .tracking(4)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .glass(intensity: 0.2, tint: .white)
                                    
                                    // Copy & Share Buttons
                                    HStack(spacing: 12) {
                                        Button(action: copyCode) {
                                            HStack {
                                                Image(systemName: "doc.on.doc")
                                                Text("Copy")
                                            }
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .glass(intensity: 0.2, tint: .white)
                                            .cornerRadius(12)
                                        }
                                        
                                        Button(action: shareCode) {
                                            HStack {
                                                Image(systemName: "square.and.arrow.up")
                                                Text("Share")
                                            }
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundColor(.purple)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                            } else {
                                // Loading state
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .tint(.white)
                                    
                                    Text("Loading your referral code...")
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(40)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Stats (if available)
                        if let data = referralManager.referralData {
                            ReferralStatsView(data: data)
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Refer & Earn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Referral code copied to clipboard")
            }
            .task {
                await loadReferralCode()
            }
        }
        .errorBanner($loadError)
    }
    
    private func loadReferralCode() async {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let code = try await referralManager.getOrCreateReferralCode(for: userId)
            await MainActor.run {
                self.referralCode = code
            }
        } catch {
            await MainActor.run {
                self.loadError = "Unable to load referral code. Please try again."
            }
        }
    }
    
    private func copyCode() {
        guard let code = referralCode else { return }
        UIPasteboard.general.string = code
        HapticStyle.medium.trigger()
        showCopiedAlert = true
    }
    
    private func shareCode() {
        guard referralManager.getReferralShareURL() != nil else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [referralManager.getReferralShareText()],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct RewardCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(color)

                Text(description)
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .glass(intensity: 0.15, tint: .white)
    }
}

struct ReferralStatsView: View {
    let data: ReferralData
    
    var body: some View {
        VStack(spacing: 16) {
            Text("YOUR PROGRESS")
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                StatBox(
                    value: "\(data.conversions)",
                    label: "Conversions",
                    color: Color.luxuryGold
                )
                
                StatBox(
                    value: "\(data.pendingConversions)",
                    label: "Pending",
                    color: .orange
                )
                
                StatBox(
                    value: data.isEligibleForFreePro ? "✓" : "\(max(0, 3 - data.conversions))",
                    label: data.isEligibleForFreePro ? "Free Pro!" : "To Free Pro",
                    color: data.isEligibleForFreePro ? .green : Color.luxuryTeal
                )
            }
            
            // Progress bar
            if !data.isEligibleForFreePro {
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.luxuryGold, Color.luxuryPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * min(CGFloat(data.conversions) / 3.0, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("\(data.conversions) of 3 conversions for FREE Pro")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Color.luxuryGold)
                    Text("You've unlocked FREE Pro!")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(Color.luxuryGold)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .glass(intensity: 0.15, tint: .white)
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glass(intensity: 0.1, tint: .white)
    }
}

// MARK: - Referral Code Input View (for signup)

struct ReferralCodeInputView: View {
    @Binding var code: String
    @State private var isValidating = false
    @State private var isValid: Bool?
    @ObservedObject private var referralManager = ReferralManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift")
                    .foregroundColor(Color.luxuryGold)
                
                Text("Have a referral code?")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isValidating {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else if let valid = isValid {
                    Image(systemName: valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(valid ? .green : .red)
                }
            }
            
            HStack {
                TextField("Enter code (optional)", text: $code)
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
                    .padding()
                    .glass(intensity: 0.1, tint: .white)
                    .onChange(of: code) { oldValue, newValue in
                        validateCode(newValue)
                    }
                
                if !code.isEmpty {
                    Button(action: { code = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .accessibilityLabel("Clear referral code")
                }
            }
            
            if isValid == true {
                Text("✓ Valid code! You'll get 30% off your first month.")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundColor(.green)
            } else if isValid == false && code.count >= 6 {
                Text("✗ Invalid or expired code")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding()
        .glass(intensity: 0.1, tint: Color.luxuryGold)
    }
    
    private func validateCode(_ value: String) {
        let cleanCode = value.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanCode.count >= 6 else {
            isValid = nil
            return
        }
        
        isValidating = true
        
        Task {
            let valid = await referralManager.validateReferralCode(cleanCode)
            
            await MainActor.run {
                isValid = valid
                isValidating = false
                
                if valid {
                    referralManager.pendingReferralCode = cleanCode
                }
            }
        }
    }
}

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
                                .fill(Color.luxuryGold.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "percent")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .foregroundColor(Color.luxuryGold)
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
                                    colors: [Color.luxuryPurple, Color.luxuryPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 15)
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

extension HapticStyle {
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) -> HapticStyle {
        switch type {
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        default: return .success
        }
    }
}

// MARK: - Preview

#Preview {
    ReferralPromotionView()
        .padding()
        .background(Color.black)
}
