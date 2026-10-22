import SwiftUI


// MARK: - Confetti View
struct ConfettiView: View {
    @State private var confettiParticles: [ConfettiParticle] = []
    let colors: [Color] = [.accentMint, .accentMint, .accentMint, .accentMint, .white, .green]

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


