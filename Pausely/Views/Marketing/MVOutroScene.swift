//
//  MVOutroScene.swift
//  Pausely
//
//  Scene 5: Color-cycling outro with Pausely app icon + CTA
//

import SwiftUI

struct MVOutroScene: View {
    let isActive: Bool

    @State private var logoDropped = false
    @State private var showText = false
    @State private var showTagline = false
    @State private var showCTA = false
    @State private var float = false
    @State private var ctaPulse = false

    var body: some View {
        ZStack {
            ColorCycleBackground()
                .ignoresSafeArea()

            FloatingParticles(count: 20, colors: [.white, Color(hex: "A855F7"), Color(hex: "EC4899"), Color(hex: "06B6D4")])
                .opacity(0.4)

            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -90, y: -220)
                    .scaleEffect(float ? 1.15 : 0.95)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: float)

                Circle()
                    .fill(Color(hex: "EC4899").opacity(0.12))
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(x: 100, y: 200)
                    .scaleEffect(float ? 0.95 : 1.15)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: float)
            }

            VStack(spacing: 28) {
                Spacer()

                // Pausely App Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 120, height: 120)
                        .blur(radius: 25)
                        .scaleEffect(float ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: float)

                    Image("PauselyLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: .white.opacity(0.25), radius: 20, x: 0, y: 4)
                }
                .offset(y: logoDropped ? 0 : -80)
                .scaleEffect(logoDropped ? 1 : 0.6)
                .animation(.spring(response: 1.2, dampingFraction: 0.6), value: logoDropped)
                .offset(y: float ? -3 : 3)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: float)

                Text("Pausely")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .neonGlow(.white, intensity: 0.8)
                    .opacity(showText ? 1 : 0)
                    .scaleEffect(showText ? 1 : 0.85)
                    .offset(y: showText ? 0 : 12)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15), value: showText)

                Text("Track. Cancel. Save.")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 12)
                    .blur(radius: showTagline ? 0 : 5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.3), value: showTagline)

                Spacer().frame(height: 55)

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.35))
                        .frame(width: 130, height: 46)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(ctaPulse ? 0.4 : 0.2), lineWidth: ctaPulse ? 2 : 1)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: ctaPulse)
                        )
                        .overlay(
                            HStack(spacing: 5) {
                                Image(systemName: "apple.logo")
                                    .font(.caption)
                                Text("App Store")
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                            }
                            .foregroundColor(.white)
                        )

                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .frame(width: 130, height: 46)
                        .shadow(color: .white.opacity(ctaPulse ? 0.4 : 0.15), radius: ctaPulse ? 20 : 10, x: 0, y: 5)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: ctaPulse)
                        .overlay(
                            Text("Get Started")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(.black)
                        )
                }
                .opacity(showCTA ? 1 : 0)
                .offset(y: showCTA ? 0 : 25)
                .scaleEffect(showCTA ? 1 : 0.9)
                .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1), value: showCTA)

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
                float = false
                ctaPulse = false
            }
        }
    }

    private func startAnimations() {
        logoDropped = false
        showText = false
        showTagline = false
        showCTA = false
        float = true
        ctaPulse = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { logoDropped = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showText = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showTagline = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showCTA = true }
    }
}

#Preview {
    MVOutroScene(isActive: true)
}
