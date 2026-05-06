//
//  MVFeaturesScene.swift
//  Pausely
//
//  Scene 4: Action features with 3D rotation and neon flicker
//

import SwiftUI

struct MVFeaturesScene: View {
    let isActive: Bool

    @State private var showTitle = false
    @State private var showCards = false

    private let features: [FeatureItem] = [
        FeatureItem(
            icon: "sparkles",
            color: Color(hex: "A855F7"),
            title: "Genius Insights",
            subtitle: "AI-powered savings tips"
        ),
        FeatureItem(
            icon: "xmark.shield.fill",
            color: Color(hex: "EC4899"),
            title: "Cancel Assistant",
            subtitle: "Find cancel links fast"
        ),
        FeatureItem(
            icon: "chart.pie.fill",
            color: Color(hex: "34D399"),
            title: "Spending Breakdown",
            subtitle: "See where money goes"
        ),
        FeatureItem(
            icon: "arrow.up.forward.circle.fill",
            color: Color(hex: "F59E0B"),
            title: "Price Alerts",
            subtitle: "Know when prices go up"
        ),
        FeatureItem(
            icon: "heart.text.square.fill",
            color: Color(hex: "F472B6"),
            title: "Health Score",
            subtitle: "Track your sub wellness"
        ),
        FeatureItem(
            icon: "bell.badge.fill",
            color: Color(hex: "06B6D4"),
            title: "Renewal Reminders",
            subtitle: "Never miss a billing date"
        ),
    ]

    var body: some View {
        ZStack {
            Color(hex: "0A0A14").ignoresSafeArea()

            // Background gradient orbs
            ZStack {
                Circle()
                    .fill(Color(hex: "7C3AED").opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)

                Circle()
                    .fill(Color(hex: "EC4899").opacity(0.04))
                    .frame(width: 250, height: 250)
                    .blur(radius: 80)
                    .offset(x: 120, y: 250)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                // Title
                VStack(spacing: 8) {
                    Text("What you can do")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .neonGlow(.white, intensity: 0.3)

                    Text("Take control of your subscriptions")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : -20)
                .blur(radius: showTitle ? 0 : 5)
                .animation(.spring(response: 0.7, dampingFraction: 0.7), value: showTitle)

                Spacer().frame(height: 28)

                // Feature cards
                VStack(spacing: 10) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        FeatureCard(
                            feature: feature,
                            delay: Double(index) * 0.25
                        )
                    }
                }
                .padding(.horizontal, 20)
                .opacity(showCards ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showCards)

                Spacer()
            }
        }
        .onAppear {
            if isActive {
                startAnimations()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                startAnimations()
            }
        }
    }

    private func startAnimations() {
        showTitle = false
        showCards = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showTitle = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showCards = true }
    }
}

struct FeatureItem: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
}

struct FeatureCard: View {
    let feature: FeatureItem
    let delay: Double

    @State private var isVisible = false
    @State private var glow = false

    var body: some View {
        HStack(spacing: 14) {
            // Icon with glow and flicker
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .blur(radius: 8)
                    .scaleEffect(glow ? 1.15 : 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glow)

                RoundedRectangle(cornerRadius: 12)
                    .fill(feature.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(feature.color.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: feature.icon)
                    .font(.system(.title3, design: .rounded))
                    .foregroundColor(feature.color)
                    .neonGlow(feature.color, intensity: 0.6)
                    .flicker()
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)

                Text(feature.subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Arrow
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "141428"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [feature.color.opacity(0.2), feature.color.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .rotation3DEffect(
            .degrees(isVisible ? 0 : 12),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.3
        )
        .offset(x: isVisible ? 0 : 50)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) {
                    isVisible = true
                }
                glow = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "0A0A14").ignoresSafeArea()
        MVFeaturesScene(isActive: true)
    }
}
