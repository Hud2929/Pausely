//
//  MVDashboardScene.swift
//  Pausely
//
//  Scene 3: Data-rich dashboard with real insights and category breakdown
//

import SwiftUI

struct MVDashboardScene: View {
    let isActive: Bool

    @State private var showSpend = false
    @State private var showYearly = false
    @State private var showBreakdown = false
    @State private var showInsight = false
    @State private var showRenewal = false
    @State private var animatedSpend: Double = 0
    @State private var animatedYearly: Double = 0
    @State private var float = false

    private let monthlySpend: Double = 287
    private let yearlySpend: Double = 3444

    var body: some View {
        ZStack {
            Color(hex: "0A0A14").ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(Color(hex: "7C3AED").opacity(0.1))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: float ? 60 : -60, y: float ? -40 : 40)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: float)

                Circle()
                    .fill(Color(hex: "EC4899").opacity(0.08))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(x: float ? -50 : 50, y: float ? 60 : -60)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: float)
            }

            VStack(spacing: 18) {
                Spacer()

                // Monthly + Yearly side by side
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Monthly")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1)

                        Text("$\(Int(animatedSpend))")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .neonGlow(.white, intensity: 0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "141428"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "7C3AED").opacity(0.25), lineWidth: 1)
                            )
                    )

                    VStack(spacing: 4) {
                        Text("Yearly")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1)

                        Text("$\(Int(animatedYearly))")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .neonGlow(.white, intensity: 0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "141428"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "EC4899").opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .opacity(showSpend ? 1 : 0)
                .scaleEffect(showSpend ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showSpend)

                // Category breakdown bars
                VStack(alignment: .leading, spacing: 10) {
                    Text("Where it goes")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))

                    VStack(spacing: 8) {
                        CategoryBar(label: "Streaming", amount: "$98", percent: 0.34, color: Color(hex: "8B5CF6"), icon: "tv.fill")
                        CategoryBar(label: "Productivity", amount: "$72", percent: 0.25, color: Color(hex: "06B6D4"), icon: "briefcase.fill")
                        CategoryBar(label: "Music", amount: "$58", percent: 0.20, color: Color(hex: "EC4899"), icon: "music.note")
                        CategoryBar(label: "Fitness", amount: "$35", percent: 0.12, color: Color(hex: "34D399"), icon: "figure.run")
                        CategoryBar(label: "Other", amount: "$24", percent: 0.09, color: Color(hex: "F59E0B"), icon: "ellipsis")
                    }
                }
                .padding(.horizontal, 20)
                .opacity(showBreakdown ? 1 : 0)
                .offset(y: showBreakdown ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: showBreakdown)

                // Real insight
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "FBBF24"))

                    Text("3 unused subs = ")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    +
                    Text("$42/mo wasted")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(Color(hex: "FBBF24"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "1E1B2E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "FBBF24").opacity(0.35), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .opacity(showInsight ? 1 : 0)
                .offset(y: showInsight ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15), value: showInsight)

                // Upcoming renewal
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "EF4444").opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "tv.fill")
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(Color(hex: "EF4444"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Netflix Standard")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(.white)
                        Text("Renews tomorrow · $15.49")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Text("$186/yr")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "141428"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "EF4444").opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .opacity(showRenewal ? 1 : 0)
                .offset(y: showRenewal ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2), value: showRenewal)

                Spacer()
            }
            .padding(.vertical, 20)
        }
        .onAppear {
            if isActive { startAnimations() }
        }
        .onChange(of: isActive) { active in
            if active {
                startAnimations()
            } else {
                float = false
            }
        }
    }

    private func startAnimations() {
        showSpend = false
        showYearly = false
        showBreakdown = false
        showInsight = false
        showRenewal = false
        animatedSpend = 0
        animatedYearly = 0
        float = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showSpend = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedSpend = monthlySpend
                animatedYearly = yearlySpend
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showYearly = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showBreakdown = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { showInsight = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showRenewal = true }
    }
}

struct CategoryBar: View {
    let label: String
    let amount: String
    let percent: Double
    let color: Color
    let icon: String

    @State private var width: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(color)
                .frame(width: 16)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1E1B2E"))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * width, height: 8)
                        .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                        width = percent
                    }
                }
            }
            .frame(height: 8)

            Text(amount)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "0A0A14").ignoresSafeArea()
        MVDashboardScene(isActive: true)
    }
}
