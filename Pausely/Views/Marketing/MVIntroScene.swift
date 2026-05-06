//
//  MVIntroScene.swift
//  Pausely
//
//  Scene 1: TikTok-style snap-scroll hook with real subscription stats
//

import SwiftUI

struct MVIntroScene: View {
    let isActive: Bool

    @State private var currentCard = 0
    @State private var borderPulse = false
    @State private var showFinalLogo = false

    private let cards: [HookCard] = [
        HookCard(
            headline: "$219",
            subheadline: "wasted per year",
            body: "on subscriptions you forgot about",
            color: Color(hex: "EF4444"),
            bgAccent: Color(hex: "EF4444").opacity(0.08)
        ),
        HookCard(
            headline: "12",
            subheadline: "subscriptions",
            body: "the average person can't name half",
            color: Color(hex: "06B6D4"),
            bgAccent: Color(hex: "06B6D4").opacity(0.08)
        ),
        HookCard(
            headline: "$3,444",
            subheadline: "spent yearly",
            body: "on apps, streaming & services",
            color: Color(hex: "F59E0B"),
            bgAccent: Color(hex: "F59E0B").opacity(0.08)
        ),
        HookCard(
            headline: "Pausely",
            subheadline: "fixes that",
            body: "Track every subscription in one place",
            color: Color(hex: "A855F7"),
            bgAccent: Color(hex: "A855F7").opacity(0.08)
        ),
        HookCard(
            headline: "Track. Cancel.",
            subheadline: "Save.",
            body: "Take back control of your money",
            color: Color(hex: "FFFFFF"),
            bgAccent: Color(hex: "7C3AED").opacity(0.1)
        ),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "0A0A14").ignoresSafeArea()

                ZStack {
                    Circle()
                        .fill(Color(hex: "7C3AED").opacity(0.04))
                        .frame(width: 400, height: 400)
                        .blur(radius: 100)
                        .offset(x: -80, y: -100)

                    Circle()
                        .fill(Color(hex: "EC4899").opacity(0.03))
                        .frame(width: 350, height: 350)
                        .blur(radius: 100)
                        .offset(x: 100, y: 200)
                }

                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: "7C3AED"),
                                Color(hex: "EC4899"),
                                Color(hex: "06B6D4"),
                                Color(hex: "7C3AED")
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .padding(12)
                    .opacity(borderPulse ? 0.6 : 0.2)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: borderPulse)

                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    HookCardView(
                        card: card,
                        isActive: index == currentCard
                    )
                    .offset(y: CGFloat(index - currentCard) * geo.size.height)
                    .animation(.spring(response: 3.0, dampingFraction: 0.82), value: currentCard)
                }

                if currentCard == cards.count - 1 {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image("PauselyLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Text("Pausely")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .neonGlow(.white, intensity: 0.6)
                        }
                        .padding(.bottom, 50)
                        .opacity(showFinalLogo ? 1 : 0)
                        .offset(y: showFinalLogo ? 0 : 20)
                        .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.3), value: showFinalLogo)
                    }
                }
            }
        }
        .onAppear {
            if isActive { startAnimations() }
        }
        .onChange(of: isActive) { active in
            if active {
                startAnimations()
            } else {
                borderPulse = false
            }
        }
    }

    private func startAnimations() {
        currentCard = 0
        borderPulse = true
        showFinalLogo = false
        startAutoScroll()
    }

    private func startAutoScroll() {
        for i in 1..<cards.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 3.0) {
                currentCard = i
                if i == cards.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showFinalLogo = true
                    }
                }
            }
        }
    }
}

struct HookCard {
    let headline: String
    let subheadline: String
    let body: String
    let color: Color
    let bgAccent: Color
}

struct HookCardView: View {
    let card: HookCard
    let isActive: Bool

    @State private var showContent = false
    @State private var flash = false

    var body: some View {
        ZStack {
            card.color
                .opacity(flash ? 0.15 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.2), value: flash)

            VStack(spacing: 16) {
                Spacer()

                Text(card.headline)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(card.color)
                    .neonGlow(card.color, intensity: 1.2)
                    .scaleEffect(showContent ? 1 : 0.7)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: showContent)

                Text(card.subheadline)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 15)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showContent)

                Text(card.body)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4).delay(0.2), value: showContent)

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onChange(of: isActive) { active in
            if active {
                flash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showContent = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    flash = false
                }
            }
        }
    }
}

#Preview {
    MVIntroScene(isActive: true)
}
