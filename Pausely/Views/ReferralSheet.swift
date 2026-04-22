import SwiftUI

// MARK: - Referral Sheet
/// Full-screen/bottom sheet view for the referral program
struct ReferralSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var referralManager = ReferralManager.shared
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var copiedToClipboard = false
    @State private var showCopiedToast = false
    @State private var appear = false
    @State private var selectedTab = 0
    @State private var isLoadingCode = true
    @State private var loadError: String?
    
    // Generate referral link
    private var referralLink: String {
        guard let code = referralManager.currentUserReferralCode else {
            return "https://pausely.app/download"
        }
        return "https://pausely.app/r/\(code)"
    }
    
    private var displayCode: String {
        referralManager.currentUserReferralCode ?? "Loading..."
    }
    
    private var progressCount: Int {
        referralManager.referralData?.conversions ?? 0
    }
    
    private var isEligibleForFreePro: Bool {
        referralManager.referralData?.isEligibleForFreePro ?? false
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero section with referral code
                        heroSection
                            .padding(.horizontal, 20)
                        
                        // Tab selector
                        tabSelector
                            .padding(.horizontal, 20)
                        
                        // Content based on selected tab
                        if selectedTab == 0 {
                            friendsSection
                                .padding(.horizontal, 20)
                        } else {
                            howItWorksSection
                                .padding(.horizontal, 20)
                        }
                        
                        // Share buttons
                        shareSection
                            .padding(.horizontal, 20)
                        
                        // Terms
                        termsSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
                
                // Toast notification
                if showCopiedToast {
                    copiedToast
                }
            }
            .navigationTitle("Refer Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.luxuryGold)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appear = true
            }
            
            // Check if code already exists from ReferralManager
            if let existingCode = referralManager.currentUserReferralCode, !existingCode.isEmpty {
                #if DEBUG
                print("DEBUG: Code already available from manager: \(existingCode)")
                #endif
                isLoadingCode = false
            } else {
                loadReferralCode()
            }
        }
    }
    
    // MARK: - Load Referral Code
    private func loadReferralCode() {
        #if DEBUG
        print("DEBUG: Loading referral code...")
        #endif
        
        // Check if we already have a code in memory
        if let existingCode = referralManager.currentUserReferralCode, !existingCode.isEmpty {
            #if DEBUG
            print("DEBUG: Code already exists in memory: \(existingCode)")
            #endif
            isLoadingCode = false
            return
        }
        
        // Try to load from local storage
        if let savedCode = UserDefaults.standard.string(forKey: "local_referral_code"), !savedCode.isEmpty {
            #if DEBUG
            print("DEBUG: Loaded from local storage: \(savedCode)")
            #endif
            referralManager.currentUserReferralCode = savedCode
            isLoadingCode = false
            return
        }
        
        // Generate a new code immediately
        generateAndSaveLocalCode()
        
        // Try to sync with server if user is logged in
        if let userId = authManager.currentUser?.id {
            Task {
                do {
                    let serverCode = try await referralManager.getOrCreateReferralCode(for: userId)
                    #if DEBUG
                    print("DEBUG: Synced with server: \(serverCode)")
                    #endif
                    await MainActor.run {
                        UserDefaults.standard.set(serverCode, forKey: "local_referral_code")
                        referralManager.currentUserReferralCode = serverCode
                    }
                } catch {
                    #if DEBUG
                    print("DEBUG: Could not sync with server: \(error)")
                    #endif
                    // Keep the local code we already generated
                }
            }
        }
    }
    
    private func generateAndSaveLocalCode() {
        // Generate a unique local code based on device/user
        let deviceId = String(UIDevice.current.identifierForVendor?.uuidString.prefix(8) ?? "USER")
        let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
        let localCode = "PAUSELY-\(deviceId)-\(randomSuffix)"
        
        #if DEBUG
        print("DEBUG: Generated new code: \(localCode)")
        #endif
        referralManager.currentUserReferralCode = localCode
        UserDefaults.standard.set(localCode, forKey: "local_referral_code")
        isLoadingCode = false
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 24) {
            // Celebration icon
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.luxuryGold.opacity(0.4),
                                Color.luxuryPink.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)
                
                // Icon background
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
                    .frame(width: 120, height: 120)
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
                
                Image(systemName: isEligibleForFreePro ? "crown.fill" : "gift.fill")
                    .font(.system(.largeTitle, design: .rounded).weight(.light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.luxuryGold, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Floating sparkles
                HStack {
                    Image(systemName: "sparkle")
                        .font(.title3)
                        .foregroundStyle(Color.luxuryGold)
                        .offset(x: -70, y: -40)

                    Spacer()

                    Image(systemName: "sparkle.fill")
                        .font(.callout)
                        .foregroundStyle(Color.luxuryPink)
                        .offset(x: 60, y: 30)
                }
                .frame(width: 180)
            }
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            
            // Title and description
            VStack(spacing: 12) {
                if isEligibleForFreePro {
                    Text("Pro Unlocked! 🎉")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("You've earned FREE Premium forever by referring 3 friends!")
                        .font(.system(.callout, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.luxuryTeal)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text("Get Pro FREE!")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("Refer 3 friends and unlock Premium forever. No subscription needed!")
                        .font(.system(.callout, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .offset(y: appear ? 0 : 20)
            .opacity(appear ? 1 : 0)
            
            // Referral code card
            referralCodeCard
        }
    }
    
    private var referralCodeCard: some View {
        VStack(spacing: 16) {
            Text("YOUR UNIQUE CODE")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(2)
            
            if isLoadingCode {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.luxuryGold)
                    Text("Loading your code...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .onAppear {
                    // Timeout - if still loading after 3 seconds, generate a code
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.isLoadingCode {
                            #if DEBUG
                            print("DEBUG: Loading timeout - generating emergency code")
                            #endif
                            self.generateAndSaveLocalCode()
                        }
                    }
                }
            } else if displayCode == "Loading..." || displayCode.isEmpty {
                // Error state - allow regeneration
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Couldn't load code")
                        .font(.headline)
                        .foregroundColor(.white)
                    Button("Generate Code") {
                        generateAndSaveLocalCode()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                // Code display
                HStack(spacing: 12) {
                    Text(displayCode)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .kerning(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Divider()
                        .frame(height: 30)
                        .background(.white.opacity(0.2))
                    
                    Button(action: copyToClipboard) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(copiedToClipboard ? Color.luxuryTeal : Color.luxuryGold)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.1))
                            )
                    }
                }
                
                // Progress indicator
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.1))
                                .frame(height: 20)
                            
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.luxuryGold, Color.luxuryPink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * (Double(min(progressCount, 3)) / 3.0), height: 20)
                                .animation(.easeOut(duration: 0.8), value: progressCount)
                        }
                    }
                    .frame(height: 20)
                    
                    HStack {
                        Text("\(progressCount) of 3 completed")
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        if progressCount < 3 {
                            Text("\(3 - progressCount) more to go!")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.luxuryGold)
                        } else {
                            Text("Completed! 🎉")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.luxuryTeal)
                        }
                    }

                    // Claim Free Pro Button (when eligible)
                    if isEligibleForFreePro && !paymentManager.isPremium {
                        Button(action: claimFreePro) {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Claim Free Pro")
                            }
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.luxuryGold, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.luxuryPurple.opacity(0.2),
                                Color.luxuryPink.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5))
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ReferralTabButton(
                title: "Friends",
                icon: "person.2",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                    HapticStyle.light.trigger()
                }
            }
            
            ReferralTabButton(
                title: "How It Works",
                icon: "info.circle",
                isSelected: selectedTab == 1
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                    HapticStyle.light.trigger()
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.1))
        )
    }
    
    // MARK: - Friends Section
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Referred Friends")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            
            if referralManager.conversions.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.3))

                    Text("No referrals yet")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Share your code to start earning!")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(referralManager.conversions.prefix(3), id: \.id) { conversion in
                        ConversionRow(conversion: conversion)
                    }
                    
                    // Empty slots
                    ForEach(0..<max(0, 3 - referralManager.conversions.count), id: \.self) { _ in
                        EmptyFriendRow()
                    }
                }
            }
        }
    }
    
    // MARK: - How It Works Section
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            
            VStack(spacing: 16) {
                ReferralStepRow(
                    number: 1,
                    icon: "square.and.arrow.up",
                    title: "Share Your Code",
                    description: "Send your unique referral code to friends via Messages, Email, or Social"
                )
                
                ReferralStepRow(
                    number: 2,
                    icon: "person.badge.plus",
                    title: "Friend Signs Up",
                    description: "They create an account using your code and get 30% off their first month"
                )
                
                ReferralStepRow(
                    number: 3,
                    icon: "crown.fill",
                    title: "Get Pro FREE",
                    description: "Earn $5 per referral + unlock Premium forever after 3 friends subscribe"
                )
            }
        }
    }
    
    // MARK: - Share Section
    private var shareSection: some View {
        VStack(spacing: 16) {
            Text("Share Via")
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            
            HStack(spacing: 20) {
                ShareButton(
                    icon: "message.fill",
                    color: .green,
                    action: { shareViaMessages() }
                )
                
                ShareButton(
                    icon: "envelope.fill",
                    color: .blue,
                    action: { shareViaEmail() }
                )
                
                ShareButton(
                    icon: "square.and.arrow.up",
                    color: Color.luxuryPurple,
                    action: { shareViaSystem() }
                )
                
                ShareButton(
                    icon: "link",
                    color: Color.luxuryPink,
                    action: { copyToClipboard() }
                )
            }
        }
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("Terms & Conditions")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.luxuryGold)

            Text("Rewards are granted when referred friends complete signup and verify their account. Free Pro access is permanent and non-transferable. Self-referrals are not allowed.")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Copied Toast
    private var copiedToast: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.luxuryTeal)

                Text("Copied to clipboard!")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.luxuryTeal.opacity(0.5), lineWidth: 1)
                    )
            )
            .shadow(radius: 20)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Actions
    private func copyToClipboard() {
        UIPasteboard.general.string = "Use my code \(displayCode) to get 30% off Pausely! \(referralLink)"
        copiedToClipboard = true
        showCopiedToast = true
        HapticStyle.success.trigger()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            copiedToClipboard = false
        }
    }
    
    private func shareViaMessages() {
        let code = displayCode
        let link = referralLink
        let message = "Get Pausely and manage your subscriptions smarter! Use my code \(code) for 30% off. Get Pro FREE when you refer 3 friends! \(link)"
        
        guard let encodedBody = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        guard let url = URL(string: "sms:&body=\(encodedBody)") else { return }
        
        UIApplication.shared.open(url) { success in
            if !success {
                // Fallback to share sheet if sms: fails
                fallbackShare()
            }
        }
    }
    
    private func shareViaEmail() {
        let code = displayCode
        let link = referralLink
        let subject = "Get 30% off Pausely - Subscription Manager"
        let body = "Hey!\n\nI've been using Pausely to track and manage my subscriptions. It's saved me hundreds!\n\nUse my referral code \(code) to get 30% off. Plus, if you refer 3 friends, you get Pro FREE forever!\n\n\(link)"
        
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") else {
            fallbackShare()
            return
        }
        
        UIApplication.shared.open(url) { success in
            if !success {
                fallbackShare()
            }
        }
    }
    
    private func fallbackShare() {
        // Copy to clipboard as fallback
        UIPasteboard.general.string = "Use my code \(displayCode) to get 30% off Pausely! \(referralLink)"
        
        // Show toast
        copiedToClipboard = true
        showCopiedToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            copiedToClipboard = false
        }
    }
    
    private func claimFreePro() {
        HapticStyle.success.trigger()
        
        // Grant free Pro through PaymentManager
        paymentManager.grantFreeProForReferrals()
        
        // Show success toast
        withAnimation {
            showCopiedToast = true
        }
        
        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            dismiss()
        }
    }
    
    private func shareViaSystem() {
        // Ensure we have a valid code
        let code = displayCode
        let link = referralLink
        
        let text = "Get Pausely and manage your subscriptions smarter! Use my code \(code) for 30% off. Get Pro FREE when you refer 3 friends!"
        
        // Create share items - use the link as a string if URL creation fails
        var shareItems: [Any] = [text]
        
        if let url = URL(string: link), link != "https://pausely.app/download" {
            shareItems.append(url)
        } else {
            // Fallback to just the code if URL isn't ready
            shareItems.append("Download at: https://pausely.app")
        }
        
        let activityVC = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        // Exclude some options for cleaner sharing
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .saveToCameraRoll
        ]
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // For iPad support
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Views
struct ReferralTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.luxuryPurple.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ConversionRow: View {
    let conversion: ReferralConversion
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: statusIcon)
                    .font(.callout)
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(conversion.referredUserEmail ?? "Anonymous")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text(statusText)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(statusColor)
            }
            
            Spacer()

            Text(formatDate(conversion.createdAt))
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }

    private var statusColor: Color {
        switch conversion.status {
        case .converted:
            return .green
        case .pending:
            return .orange
        case .cancelled:
            return .red
        }
    }
    
    private var statusIcon: String {
        switch conversion.status {
        case .converted:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    private var statusText: String {
        switch conversion.status {
        case .converted:
            return "Completed"
        case .pending:
            return "Pending"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyFriendRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "person")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            Text("Waiting...")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
            
            Spacer()
        }
        .padding()
        .glass(intensity: 0.04, tint: .white)
    }
}

struct ReferralStepRow: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.luxuryGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text("\(number)")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.luxuryGold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.footnote)
                        .foregroundStyle(Color.luxuryGold)

                    Text(title)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text(description)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(2)
            }
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }
}

struct ShareButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(color.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(color.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy Support
struct ReferredFriend: Identifiable {
    let id = UUID()
    let name: String
    let status: FriendStatus
    let date: Date?
    let avatar: String
}

enum FriendStatus {
    case completed, pending, empty
}

struct FriendRow: View {
    let friend: ReferredFriend
    
    var body: some View {
        HStack(spacing: 12) {
            Text(friend.avatar)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    Text(statusText)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            if let date = friend.date {
                Text(timeAgo(date))
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding()
        .glass(intensity: friend.status == .empty ? 0.04 : 0.08, tint: .white)
    }
    
    private var statusColor: Color {
        switch friend.status {
        case .completed:
            return .green
        case .pending:
            return .orange
        case .empty:
            return .white.opacity(0.3)
        }
    }
    
    private var statusText: String {
        switch friend.status {
        case .completed:
            return "Completed"
        case .pending:
            return "Pending"
        case .empty:
            return "Available slot"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
