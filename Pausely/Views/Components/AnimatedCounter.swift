//
//  AnimatedCounter.swift
//  Pausely
//
//  Animated Number Counter
//

import SwiftUI

struct AnimatedCounter: View {
    let value: Decimal
    let currencyCode: String
    let font: Font
    let color: Color
    
    @State private var displayedValue: Double = 0
    
    init(
        value: Decimal,
        currencyCode: String = "USD",
        font: Font = STFont.monoMedium,
        color: Color = .obsidianText
    ) {
        self.value = value
        self.currencyCode = currencyCode
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Text(
            Decimal(displayedValue).formatted(
                .currency(code: currencyCode)
                .precision(.fractionLength(2))
            )
        )
        .font(font)
        .foregroundStyle(
            LinearGradient(
                colors: [.luxuryGold, .luxuryPink],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .contentTransition(.numericText(value: displayedValue))
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else {
                displayedValue = NSDecimalNumber(decimal: value).doubleValue
                return
            }
            withAnimation(.easeOut(duration: STAnimation.counterDuration)) {
                displayedValue = NSDecimalNumber(decimal: value).doubleValue
            }
        }
        .onChange(of: value) { _, newValue in
            guard !UIAccessibility.isReduceMotionEnabled else {
                displayedValue = NSDecimalNumber(decimal: newValue).doubleValue
                return
            }
            withAnimation(.easeOut(duration: 0.6)) {
                displayedValue = NSDecimalNumber(decimal: newValue).doubleValue
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AnimatedCounter(value: 847.50, font: STFont.displayMedium)
        AnimatedCounter(value: 1234.56, font: STFont.monoLarge, color: .accentMint)
    }
    .padding()
    .background(Color.obsidianBlack)
}
