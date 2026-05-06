//
//  MVProblemScene.swift
//  Pausely
//
//  Scene 2: Problem — real money lost to forgotten subscriptions
//

import SwiftUI

struct MVProblemScene: View {
    let isActive: Bool

    @State private var showHeadline = false
    @State private var showCards = false
    @State private var cardsFaded = false
    @State private var showSolution = false
    @State private var showOrganized = false
    @State private var scanLine = false
    @State private var showScanner = false
    @State private var animatedCost: Double = 0
    @State private var bgPulse = false
    @State private var chaosShake = false
    @State private var floatDollars = false

    private let targetCost: Double = 219
    private let subs: [ProblemSub] = [
        ProblemSub(icon: "tv.fill", color: Color(hex: "8B5CF6")),
        ProblemSub(icon: "music.note", color: Color(hex: "EC4899")),
        ProblemSub(icon: "brain.head.profile", color: Color(hex: "06B6D4")),
        ProblemSub(icon: "figure.run", color: Color(hex: "34D399")),
        ProblemSub(icon: "cloud.fill", color: Color(hex: "F59E0B")),
        ProblemSub(icon: "newspaper.fill", color: Color(hex: "EF4444")),
    ]

    var body: some View {
        ZStack {
            ZStack {
                Color(hex: "0A0A14").ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "7C3AED").opacity(bgPulse ? 0.12 : 0.05))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(x: -100, y: -150)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: bgPulse)

                Circle()
                    .fill(Color(hex: "EC4899").opacity(bgPulse ? 0.08 : 0.03))
                    .frame(width: 450, height: 450)
                    .blur(radius: 100)
                    .offset(x: 120, y: 180)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: bgPulse)

                Circle()
                    .fill(Color(hex: "06B6D4").opacity(bgPulse ? 0.07 : 0.02))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: 50, y: -250)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: bgPulse)
            }

            if floatDollars {
                FloatingDollars()
                    .opacity(0.6)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 70)

                VStack(spacing: 10) {
                    Text("The average person wastes")
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "F87171"), Color(hex: "FB923C")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .neonGlow(Color(hex: "F87171"), intensity: 0.8)

                        Text("\(Int(animatedCost))")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "F87171"), Color(hex: "FB923C")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .neonGlow(Color(hex: "F87171"), intensity: 0.8)

                        Text("+/yr")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "F87171"), Color(hex: "FB923C")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    Text("on forgotten subscriptions")
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(showHeadline ? 1 : 0)
                .scaleEffect(showHeadline ? 1 : 0.9)
                .blur(radius: showHeadline ? 0 : 6)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: showHeadline)

                Spacer().frame(height: 40)

                ZStack {
                    ForEach(Array(subs.enumerated()), id: \.offset) { index, sub in
                        ProblemCard(
                            icon: sub.icon,
                            color: sub.color,
                            index: index,
                            isVisible: showCards,
                            isFaded: cardsFaded,
                            chaosShake: chaosShake
                        )
                    }

                    if showScanner {
                        ScannerSweep(color: Color(hex: "7C3AED"))
                    }
                }
                .frame(height: 200)

                Spacer().frame(height: 35)

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3)
                        .foregroundColor(Color(hex: "34D399"))
                        .neonGlow(Color(hex: "34D399"), intensity: 0.6)
                        .opacity(showSolution ? 1 : 0)
                        .scaleEffect(showSolution ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showSolution)

                    Text("Pausely tracks them all")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .opacity(showSolution ? 1 : 0)
                        .offset(y: showSolution ? 0 : 15)
                        .animation(.spring(response: 0.7, dampingFraction: 0.75), value: showSolution)
                }

                if showOrganized {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color(hex: "7C3AED").opacity(0.8), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: scanLine ? 260 : 0, height: 3)
                        .padding(.top, 16)
                        .animation(.easeOut(duration: 0.8), value: scanLine)
                }

                Spacer()
            }
        }
        .onAppear {
            if isActive { startAnimations() }
        }
        .onChange(of: isActive) { active in
            if active {
                startAnimations()
            } else {
                bgPulse = false
                floatDollars = false
                chaosShake = false
            }
        }
    }

    private func startAnimations() {
        showHeadline = false
        showCards = false
        cardsFaded = false
        showSolution = false
        showOrganized = false
        scanLine = false
        showScanner = false
        animatedCost = 0
        bgPulse = true
        chaosShake = false
        floatDollars = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showHeadline = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 1.5)) {
                animatedCost = targetCost
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showCards = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            chaosShake = true
            floatDollars = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            chaosShake = false
            cardsFaded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { showScanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { showSolution = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            showOrganized = true
            scanLine = true
            floatDollars = false
        }
    }
}

struct ProblemSub: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
}

struct ProblemCard: View {
    let icon: String
    let color: Color
    let index: Int
    let isVisible: Bool
    let isFaded: Bool
    let chaosShake: Bool

    private var messyOffset: CGPoint {
        let offsets: [CGPoint] = [
            CGPoint(x: -80, y: -50),
            CGPoint(x: 60, y: -60),
            CGPoint(x: -40, y: 40),
            CGPoint(x: 90, y: 30),
            CGPoint(x: 10, y: -80),
            CGPoint(x: -70, y: 20)
        ]
        return offsets[index % offsets.count]
    }

    private var messyRotation: Double {
        [-12.0, 8.0, -5.0, 15.0, -8.0, 10.0][index % 6]
    }

    private var shakeOffset: CGFloat {
        chaosShake ? CGFloat.random(in: -4...4) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(isFaded ? 0.08 : 0.25))
                .frame(width: 68, height: 68)
                .blur(radius: 12)
                .scaleEffect(isFaded ? 1.0 : 1.2)

            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(isFaded ? 0.12 : 0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(isFaded ? 0.15 : 0.5), lineWidth: 1.5)
                )
                .shadow(color: color.opacity(isFaded ? 0 : 0.3), radius: isFaded ? 0 : 10, x: 0, y: 4)

            Image(systemName: icon)
                .font(.system(.title2, design: .rounded))
                .foregroundColor(color.opacity(isFaded ? 0.3 : 1))
                .neonGlow(color, intensity: isFaded ? 0 : 0.8)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.5)
        .rotationEffect(.degrees(isFaded ? 0 : messyRotation))
        .offset(
            x: isFaded ? CGFloat(index - 3) * 60 : messyOffset.x + shakeOffset,
            y: isFaded ? 0 : messyOffset.y + shakeOffset
        )
        .animation(
            .spring(response: 0.7, dampingFraction: 0.6).delay(Double(index) * 0.08),
            value: isVisible
        )
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: isFaded)
        .animation(.linear(duration: 0.08).repeatCount(chaosShake ? 5 : 0, autoreverses: true), value: chaosShake)
    }
}

struct FloatingDollars: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<8, id: \.self) { i in
                DollarParticle(
                    index: i,
                    width: geo.size.width,
                    height: geo.size.height
                )
            }
        }
    }
}

struct DollarParticle: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat

    @State private var y: CGFloat = 0
    @State private var x: CGFloat = 0
    @State private var opacity = 0.0

    private var duration: Double {
        2.5 + Double(index % 4)
    }

    var body: some View {
        Text("$")
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundColor(Color(hex: "FBBF24"))
            .position(x: x, y: y)
            .opacity(opacity)
            .onAppear {
                x = CGFloat.random(in: 30...(width - 30))
                y = height + 20
                opacity = Double.random(in: 0.4...0.9)

                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    y = -20
                }
            }
    }
}

#Preview {
    MVProblemScene(isActive: true)
}
