//
//  MVCardsScene.swift
//  Pausely
//
//  Scene 3: Subscription cards with neon glow icons + flowy slide
//

import SwiftUI

struct MVCardsScene: View {
    @State private var showTitle = false
    @State private var showCards = false
    @State private var showButton = false
    @State private var backgroundPulse = false
    @State private var flowyWave = false

    private let subscriptions: [DemoSubscription] = [
        DemoSubscription(name: "Netflix", category: "Entertainment", amount: 15.49, icon: "tv.fill", color: Color(hex: "8B5CF6")),
        DemoSubscription(name: "Spotify", category: "Music", amount: 10.99, icon: "music.note", color: Color(hex: "EC4899")),
        DemoSubscription(name: "ChatGPT Plus", category: "AI Tools", amount: 20.00, icon: "brain.head.profile", color: Color(hex: "06B6D4")),
        DemoSubscription(name: "Gym", category: "Fitness", amount: 49.99, icon: "figure.run", color: Color(hex: "34D399")),
    ]

    var body: some View {
        ZStack {
            Color(hex: "0A0A12").ignoresSafeArea()

            // Animated aurora background
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "7C3AED").opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 175
                            )
                        )
                        .frame(width: 350, height: 350)
                        .blur(radius: 60)
                        .offset(x: flowyWave ? 30 : -30, y: flowyWave ? -20 : 20)
                        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: flowyWave)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "EC4899").opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 50)
                        .offset(x: flowyWave ? -40 : 40, y: flowyWave ? 30 : -30)
                        .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: flowyWave)
                }
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 55)

                // Section title with glow
                VStack(spacing: 8) {
                    Text("Your Subscriptions")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 0)

                    Text("4 active — $96.47/mo")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : -30)
                .blur(radius: showTitle ? 0 : 6)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showTitle)

                Spacer().frame(height: 32)

                // Cards with neon glow
                VStack(spacing: 14) {
                    ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, sub in
                        NeonCardRow(
                            subscription: sub,
                            delay: Double(index) * 0.1
                        )
                    }
                }
                .padding(.horizontal, 20)
                .opacity(showCards ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showCards)

                Spacer().frame(height: 40)

                // Glowing CTA Button
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.headline)
                        Text("Add Subscription")
                            .font(.system(.headline, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "7C3AED"), Color(hex: "EC4899")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            // Button glow
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        }
                    )
                    .shadow(color: Color(hex: "7C3AED").opacity(0.5), radius: 25, x: 0, y: 12)
                }
                .padding(.horizontal, 20)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 40)
                .scaleEffect(showButton ? 1 : 0.85)
                .blur(radius: showButton ? 0 : 6)
                .animation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1), value: showButton)

                Spacer()
            }
        }
        .onAppear {
            backgroundPulse = true
            flowyWave = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showTitle = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showCards = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { showButton = true }
        }
    }
}

// MARK: - Demo Subscription Model
struct DemoSubscription: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let amount: Double
    let icon: String
    let color: Color
}

// MARK: - Neon Card Row
struct NeonCardRow: View {
    let subscription: DemoSubscription
    let delay: Double

    @State private var isVisible = false
    @State private var wiggle = false
    @State private var glowPulse = false

    var body: some View {
        HStack(spacing: 14) {
            // Neon icon with intense glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(subscription.color.opacity(0.25))
                    .frame(width: 56, height: 56)
                    .blur(radius: 12)
                    .scaleEffect(glowPulse ? 1.2 : 0.9)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: glowPulse)

                RoundedRectangle(cornerRadius: 14)
                    .fill(subscription.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(subscription.color.opacity(0.5), lineWidth: 1.5)
                    )

                Image(systemName: subscription.icon)
                    .font(.system(.title3, design: .rounded))
                    .foregroundColor(subscription.color)
                    .shadow(color: subscription.color.opacity(0.8), radius: 8, x: 0, y: 0)
                    .rotationEffect(.degrees(wiggle ? 10 : -10))
                    .animation(.easeInOut(duration: 0.2).repeatCount(5, autoreverses: true).delay(delay + 0.5), value: wiggle)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)

                Text(subscription.category)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Amount with glow
            Text("$\(String(format: "%.2f", subscription.amount))")
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "141428").opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [subscription.color.opacity(0.3), subscription.color.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .offset(y: isVisible ? 0 : 80)
        .opacity(isVisible ? 1 : 0)
        .rotation3DEffect(.degrees(isVisible ? 0 : 8), axis: (x: 1, y: 0, z: 0))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) {
                    isVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    wiggle = true
                    glowPulse = true
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "0A0A12").ignoresSafeArea()
        MVCardsScene()
    }
}
