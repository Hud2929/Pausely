//
//  NeonText.swift
//  Pausely
//
//  Reusable 3-layer neon glow modifier for high-impact marketing text
//

import SwiftUI

// MARK: - Neon Glow Modifier
struct NeonGlow: ViewModifier {
    let color: Color
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.9 * intensity), radius: 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.5 * intensity), radius: 8, x: 0, y: 0)
            .shadow(color: color.opacity(0.25 * intensity), radius: 20, x: 0, y: 0)
            .shadow(color: color.opacity(0.1 * intensity), radius: 40, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(_ color: Color, intensity: Double = 1.0) -> some View {
        modifier(NeonGlow(color: color, intensity: intensity))
    }
}

// MARK: - Flicker Modifier (organic neon tube flicker)
struct FlickerModifier: ViewModifier {
    @State private var opacity = 1.0
    @State private var timer: Timer?

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                startFlicker()
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    private func startFlicker() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let flicker = Double.random(in: 0.92...1.0)
            withAnimation(.linear(duration: 0.05)) {
                opacity = flicker
            }
        }
    }
}

extension View {
    func flicker() -> some View {
        modifier(FlickerModifier())
    }
}

// MARK: - Pulse Scale Modifier
struct PulseScaleModifier: ViewModifier {
    @State private var scale = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scale = 1.05
                }
            }
    }
}

extension View {
    func pulseScale() -> some View {
        modifier(PulseScaleModifier())
    }
}

// MARK: - Strobe Flash View
struct StrobeFlash: View {
    let trigger: AnyHashable
    let color: Color

    @State private var phase = 0

    var body: some View {
        ZStack {
            color
                .ignoresSafeArea()
                .opacity(phase == 1 ? 0.5 : 0)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _ in
            phase = 1
            withAnimation(.easeOut(duration: 0.15)) {
                phase = 0
            }
        }
    }
}

// MARK: - Scanner Sweep Effect
struct ScannerSweep: View {
    let color: Color
    @State private var offset: CGFloat = -400

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, color.opacity(0.7), color.opacity(0.9), color.opacity(0.7), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: geo.size.height)
            .offset(x: offset)
            .onAppear {
                offset = -120
                withAnimation(.easeInOut(duration: 1.0)) {
                    offset = geo.size.width + 120
                }
            }
        }
    }
}

// MARK: - Floating Particles
struct FloatingParticles: View {
    let count: Int
    let colors: [Color]

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<count, id: \.self) { i in
                Particle(
                    index: i,
                    width: geo.size.width,
                    height: geo.size.height,
                    colors: colors
                )
            }
        }
    }
}

struct Particle: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat
    let colors: [Color]

    @State private var y: CGFloat = 0
    @State private var x: CGFloat = 0
    @State private var opacity = 0.0

    private var color: Color {
        colors[index % colors.count]
    }

    private var size: CGFloat {
        CGFloat(2 + (index % 4))
    }

    private var duration: Double {
        3.0 + Double(index % 5)
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .opacity(opacity)
            .onAppear {
                x = CGFloat.random(in: 20...(width - 20))
                y = height + 20
                opacity = Double.random(in: 0.3...0.8)

                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    y = -20
                }
            }
    }
}

// MARK: - Color Cycling Background
struct ColorCycleBackground: View {
    @State private var hueRotation: Double = 0

    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "4F46E5"),
                Color(hex: "7C3AED"),
                Color(hex: "EC4899"),
                Color(hex: "06B6D4"),
                Color(hex: "4F46E5")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .hueRotation(.degrees(hueRotation))
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                hueRotation = 360
            }
        }
    }
}
