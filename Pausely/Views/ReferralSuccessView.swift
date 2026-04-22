import SwiftUI

// MARK: - Referral Success View
/// Celebration animation when someone signs up using referral code
struct ReferralSuccessView: View {
    let referralCount: Int
    let maxReferrals: Int
    let friendName: String?
    let onDismiss: () -> Void
    let onShareMore: (() -> Void)?
    
    @State private var appear = false
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = -10
    @State private var showConfetti = false
    @State private var bounceCount = 0
    
    var remaining: Int {
        max(0, maxReferrals - referralCount)
    }
    
    var isCompleted: Bool {
        referralCount >= maxReferrals
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            AnimatedGradientBackground()
                .opacity(0.7)
            
            // Confetti effect
            if showConfetti {
                ConfettiView()
            }
            
            // Main content
            VStack(spacing: 32) {
                Spacer()
                
                // Celebration content
                VStack(spacing: 24) {
                    // Trophy/Gift icon with animation
                    celebrationIcon
                    
                    // Success text
                    successText
                    
                    // Progress indicator
                    if !isCompleted {
                        progressSection
                    } else {
                        completionSection
                    }
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            triggerAnimations()
        }
    }
    
    private var celebrationIcon: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        isCompleted ? 
                            LinearGradient(colors: [Color.luxuryGold, Color.luxuryPink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.luxuryTeal, Color.luxuryPurple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                    .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                    .opacity(appear ? 0.3 : 0)
                    .scaleEffect(appear ? 1.2 : 0.8)
                    .animation(.easeOut(duration: 1).delay(Double(i) * 0.15), value: appear)
            }
            
            // Main icon container
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isCompleted ?
                                [Color.luxuryGold.opacity(0.4), Color.luxuryPink.opacity(0.3)] :
                                [Color.luxuryTeal.opacity(0.4), Color.luxuryPurple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(
                        color: isCompleted ? Color.luxuryGold.opacity(0.5) : Color.luxuryTeal.opacity(0.5),
                        radius: 30
                    )
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                // Icon
                Image(systemName: isCompleted ? "crown.fill" : "gift.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isCompleted ?
                                [Color.luxuryGold, .white] :
                                [Color.luxuryTeal, Color.luxuryPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
            }
            
            // Floating sparkles
            sparkleElements
        }
    }
    
    private var sparkleElements: some View {
        Group {
            Image(systemName: "sparkle")
                .font(.system(size: 30))
                .foregroundStyle(Color.luxuryGold)
                .offset(x: -100, y: -80)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: appear)
            
            Image(systemName: "sparkle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.luxuryPink)
                .offset(x: 100, y: -60)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.4), value: appear)
            
            Image(systemName: "star.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.luxuryTeal)
                .offset(x: 90, y: 70)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.5), value: appear)
            
            Image(systemName: "star")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .offset(x: -90, y: 60)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.6), value: appear)
        }
    }
    
    private var successText: some View {
        VStack(spacing: 12) {
            // Main headline
            Text(isCompleted ? "Premium Unlocked!" : "Referral Complete!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
            
            // Friend info
            if let friendName = friendName {
                Text("\(friendName) joined using your code!")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.luxuryGold)
                    .offset(y: appear ? 0 : 20)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)
            }
            
            // Status message
            Text(statusMessage)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)
        }
    }
    
    private var statusMessage: String {
        if isCompleted {
            return "You've unlocked unlimited access to all Premium features forever!"
        } else if remaining == 1 {
            return "You got 1 referral! Just 1 more for free Pro!"
        } else {
            return "You got 1 referral! \(remaining) more for free Pro!"
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Progress dots
            HStack(spacing: 16) {
                ForEach(0..<maxReferrals, id: \.self) { index in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(index < referralCount ? Color.luxuryGold : .white.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            if index < referralCount {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .transition(.scale)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        
                        Text(milestoneReward(for: index))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(index < referralCount ? Color.luxuryGold : .white.opacity(0.4))
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.luxuryGold, Color.luxuryPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (Double(referralCount) / Double(maxReferrals)), height: 16)
                        .animation(.easeOut(duration: 1).delay(0.5), value: referralCount)
                }
            }
            .frame(width: 200, height: 16)
        }
        .padding()
        .glass(intensity: 0.1, tint: .white)
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.4), value: appear)
    }
    
    private var completionSection: some View {
        VStack(spacing: 20) {
            // Crown badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.luxuryGold.opacity(0.3), Color.luxuryPink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.luxuryGold.opacity(0.5), radius: 20)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.luxuryGold, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            // Benefits list
            VStack(alignment: .leading, spacing: 12) {
                ReferralBenefitRow(icon: "infinity", text: "Unlimited Subscriptions")
                ReferralBenefitRow(icon: "pause.circle.fill", text: "Smart Pause Feature")
                ReferralBenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced Analytics")
                ReferralBenefitRow(icon: "headset", text: "Priority Support")
            }
        }
        .padding()
        .glass(intensity: 0.15, tint: Color.luxuryGold)
        .offset(y: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.4), value: appear)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary action
            if !isCompleted {
                Button(action: {
                    HapticStyle.success.trigger()
                    onShareMore?()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Share Again")
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
            }
            
            // Dismiss button
            Button(action: {
                HapticStyle.light.trigger()
                onDismiss()
            }) {
                Text(isCompleted ? "Start Using Pro" : "Awesome!")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(isCompleted ? Color.luxuryGold : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isCompleted ? Color.luxuryGold.opacity(0.15) : .white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isCompleted ? Color.luxuryGold.opacity(0.4) : .white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func triggerAnimations() {
        showConfetti = true
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            appear = true
            scale = 1
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.2)) {
            rotation = 0
        }
        
        HapticStyle.success.trigger()
    }
    
    private func milestoneReward(for index: Int) -> String {
        switch index {
        case 0: return "10% Off"
        case 1: return "25% Off"
        case 2: return "FREE Pro"
        default: return ""
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var confettiParticles: [ConfettiParticle] = []
    let colors: [Color] = [.luxuryGold, .luxuryPink, .luxuryPurple, .luxuryTeal, .white, .green]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiParticles) { particle in
                    ConfettiPiece(particle: particle, colors: colors)
                }
            }
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                spawnConfetti(in: geometry.size)
            }
        }
    }

    private func spawnConfetti(in size: CGSize) {
        for _ in 0..<50 {
            let particle = ConfettiParticle(
                x: Double.random(in: 0...size.width),
                y: Double.random(in: -100...0),
                rotation: Double.random(in: 0...360),
                colorIndex: Int.random(in: 0..<colors.count),
                size: Double.random(in: 8...16),
                speed: Double.random(in: 2...5),
                rotationSpeed: Double.random(in: -5...5)
            )
            confettiParticles.append(particle)
        }
    }
}

// MARK: - Confetti Models
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var rotation: Double
    var colorIndex: Int
    var size: Double
    var speed: Double
    var rotationSpeed: Double
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let colors: [Color]
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        Rectangle()
            .fill(colors[particle.colorIndex])
            .frame(width: particle.size, height: particle.size * 0.6)
            .cornerRadius(2)
            .position(x: particle.x, y: particle.y + yOffset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                withAnimation(.linear(duration: particle.speed)) {
                    yOffset = UIScreen.main.bounds.height + 200
                }
                withAnimation(.linear(duration: particle.speed)) {
                    rotation = particle.rotation + (particle.rotationSpeed * particle.speed)
                }
                withAnimation(.easeIn(duration: particle.speed * 0.3).delay(particle.speed * 0.7)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Benefit Row
struct ReferralBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.luxuryGold)
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.luxuryTeal)
        }
    }
}

// MARK: - Mini Success Banner
/// Compact banner to show when a new referral comes in
struct ReferralMiniSuccessBanner: View {
    let friendName: String
    let onDismiss: () -> Void
    
    @State private var appear = false
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.luxuryGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "gift.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.luxuryGold)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("New Referral!")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("\(friendName) joined using your code")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                HapticStyle.light.trigger()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                    )
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.luxuryGold.opacity(0.2),
                                Color.luxuryPurple.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5))
                
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.luxuryGold.opacity(0.4), lineWidth: 1.5)
            }
        )
        .offset(y: offset)
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appear = true
            }
            
            // Auto dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            offset = -100
            appear = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    Group {
        // Full success view - progress state
        ReferralSuccessView(
            referralCount: 2,
            maxReferrals: 3,
            friendName: "Sarah M.",
            onDismiss: {},
            onShareMore: {}
        )
        
        // Full success view - completed state
        ReferralSuccessView(
            referralCount: 3,
            maxReferrals: 3,
            friendName: "Mike T.",
            onDismiss: {},
            onShareMore: {}
        )
    }
}

#Preview("Mini Banner") {
    ZStack {
        AnimatedGradientBackground()
        
        VStack {
            ReferralMiniSuccessBanner(
                friendName: "Sarah M.",
                onDismiss: {}
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 60)
    }
}
