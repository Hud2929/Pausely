//
//  View+Card.swift
//  Pausely
//
//  Card Style Modifier
//

import SwiftUI

// MARK: - Card Style Modifier
struct STCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? Color.obsidianSurface : Color.lightSurface)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.lg, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.obsidianBorder.opacity(0.5) : .clear, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                radius: 8, x: 0, y: 2
            )
    }
}

// MARK: - View Extension
extension View {
    func stCard() -> some View {
        modifier(STCardModifier())
    }
}
