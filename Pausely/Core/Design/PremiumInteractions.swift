//
//  PremiumInteractions.swift
//  Pausely
//
//  Reusable premium interaction modifiers: haptics, animations, skeletons, empty states
//

import SwiftUI

// MARK: - Accessibility-aware animation helper
struct AccessibilityAnimation {
    static func animate(_ animation: Animation = .easeInOut, value: some Equatable) -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : animation
    }
}

// MARK: - Haptic Button Style
struct HapticButtonStyle: ButtonStyle {
    let style: HapticStyle
    let scale: CGFloat

    init(style: HapticStyle = .light, scale: CGFloat = 0.97) {
        self.style = style
        self.scale = scale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    style.trigger()
                }
            }
    }
}

// MARK: - Premium Press Effect (with haptic)
struct PremiumPressEffect: ViewModifier {
    let hapticStyle: HapticStyle
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1)
            .animation(.easeInOut(duration: 0.12), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            hapticStyle.trigger()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func premiumPress(haptic: HapticStyle = .light, scale: CGFloat = 0.97) -> some View {
        modifier(PremiumPressEffect(hapticStyle: haptic, scale: scale))
    }
}

// MARK: - Skeleton Card
struct SkeletonCard: View {
    let height: CGFloat
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Skeleton Row
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 56, height: 56)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 140, height: 18)
                    .shimmer()

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 90, height: 14)
                    .shimmer()
            }

            Spacer()

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 60, height: 22)
                .shimmer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Animated List Row Entrance
struct ListRowEntrance: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else {
                    appeared = true
                    return
                }
                withAnimation(.easeOut(duration: 0.4).delay(Double(index) * 0.05)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func listRowEntrance(index: Int) -> some View {
        modifier(ListRowEntrance(index: index))
    }
}

// MARK: - Delete Slide Animation
struct DeleteSlideAnimation: ViewModifier {
    @Binding var isDeleted: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: isDeleted ? UIScreen.main.bounds.width : 0)
            .opacity(isDeleted ? 0 : 1)
            .animation(.easeInOut(duration: 0.35), value: isDeleted)
    }
}

extension View {
    func deleteSlide(isDeleted: Binding<Bool>) -> some View {
        modifier(DeleteSlideAnimation(isDeleted: isDeleted))
    }
}

// MARK: - Success Checkmark Animation
struct SuccessCheckmark: View {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 80, height: 80)

            Circle()
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 80, height: 80)

            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.green)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                scale = 1
                opacity = 1
                return
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1
                opacity = 1
            }
        }
    }
}

// MARK: - Count-up Number Animation
struct CountUpNumber: View {
    let value: Double
    let formatter: (Double) -> String
    let font: Font
    let color: Color

    @State private var displayed: Double = 0

    init(
        value: Double,
        font: Font = .system(size: 32, weight: .bold, design: .rounded),
        color: Color = .white,
        formatter: @escaping (Double) -> String = { String(format: "%.0f", $0) }
    ) {
        self.value = value
        self.font = font
        self.color = color
        self.formatter = formatter
    }

    var body: some View {
        Text(formatter(displayed))
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else {
                    displayed = value
                    return
                }
                withAnimation(.easeOut(duration: 1.2)) {
                    displayed = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.6)) {
                    displayed = newValue
                }
            }
    }
}

// MARK: - Keyboard Dismiss Helper
struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

// MARK: - Category Chip with Spring Animation
struct AnimatedCategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Text(title)
                .font(AppTypography.labelMedium)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.luxuryPurple : Color.white.opacity(0.1))
                )
                .scaleEffect(pressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = false }
                }
        )
    }
}

// MARK: - Empty State View (Artistic)
struct ArtisticEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    @State private var animate = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.luxuryPurple.opacity(0.08 + Double(i) * 0.06), lineWidth: 1)
                        .frame(width: 140 + CGFloat(i * 35), height: 140 + CGFloat(i * 35))
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .animation(
                            .linear(duration: 12 + Double(i) * 6).repeatForever(autoreverses: false),
                            value: animate
                        )
                }

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.luxuryPurple, Color.luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: Color.luxuryPurple.opacity(0.35), radius: 25, x: 0, y: 12)

                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 240)

            VStack(spacing: 10) {
                Text(title)
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.white)

                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let action = action, let actionTitle = actionTitle {
                Button(action: {
                    HapticStyle.medium.trigger()
                    action()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text(actionTitle)
                    }
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color.luxuryPurple, Color.luxuryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.luxuryPurple.opacity(0.35), radius: 15, x: 0, y: 8)
                }
                .premiumPress(haptic: .medium, scale: 0.96)
                .padding(.horizontal, 40)
            }
        }
        .padding(.vertical, 32)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                animate = true
                return
            }
            animate = true
        }
    }
}

// MARK: - Pull-to-Refresh Spinner (custom feel)
struct PremiumRefreshSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "arrow.2.circlepath")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.luxuryPurple)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Toggle with Haptic
struct HapticToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .onChange(of: isOn) { _, _ in
                HapticStyle.light.trigger()
            }
    }
}

// MARK: - Form Field with Focus & Submit
struct PremiumFormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            content
                .padding()
                .glass(intensity: 0.1, tint: .white)
        }
    }
}
