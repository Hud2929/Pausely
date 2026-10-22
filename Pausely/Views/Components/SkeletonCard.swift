//
//  SkeletonCard.swift
//  Pausely
//
//  Reusable skeleton loading components using redacted placeholder + shimmer
//

import SwiftUI

// MARK: - Skeleton Modifier
struct SkeletonModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .shimmer(active: isLoading)
    }
}

extension View {
    func skeleton(isLoading: Bool) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading))
    }
}

// MARK: - Skeleton Card
struct SkeletonCard: View {
    let height: CGFloat
    var cornerRadius: CGFloat = 20
    var isLoading: Bool = true

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .frame(height: height)
            .skeleton(isLoading: isLoading)
    }
}


// MARK: - Shimmer Modifier (active flag)
extension View {
    @ViewBuilder
    func shimmer(active: Bool) -> some View {
        if active {
            self.shimmer()
        } else {
            self
        }
    }
}
