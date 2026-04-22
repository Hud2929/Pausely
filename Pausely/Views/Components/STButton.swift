//
//  STButton.swift
//  Pausely
//
//  Primary Button Component
//

import SwiftUI

struct STButton: View {
    enum Style {
        case primary    // accentMint bg, black text
        case secondary  // obsidianElevated bg, obsidianText
        case destructive // semanticDestructive bg, white text
        case ghost      // transparent bg, accentMint text
    }
    
    let title: String
    let style: Style
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        style: Style = .primary,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            STAnimation.impactLight()
            action()
        }) {
            HStack(spacing: STSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(textColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.callout.weight(.semibold))
                    }
                    Text(title)
                        .font(STFont.labelLarge)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(textColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1 : 0)
            )
        }
        .disabled(isLoading)
        .accessibilityHint(isLoading ? "Please wait, processing" : "")
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:     return .accentMint
        case .secondary:   return .obsidianElevated
        case .destructive: return .semanticDestructive
        case .ghost:       return .clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:     return .obsidianBlack
        case .secondary:   return .obsidianText
        case .destructive: return .white
        case .ghost:       return .accentMint
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .secondary: return .obsidianBorder
        default: return .clear
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        STButton("Continue", action: {})
        STButton("Cancel Subscription", style: .destructive, action: {})
        STButton("Skip for Now", style: .secondary, action: {})
        STButton("Learn More", style: .ghost, action: {})
        STButton("Loading...", isLoading: true, action: {})
    }
    .padding()
    .background(Color.obsidianBlack)
}
