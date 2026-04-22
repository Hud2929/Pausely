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

// MARK: - Skeleton Row (for list items)
struct SkeletonRow: View {
    var isLoading: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 56, height: 56)
                .skeleton(isLoading: isLoading)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 140, height: 18)
                    .skeleton(isLoading: isLoading)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 90, height: 14)
                    .skeleton(isLoading: isLoading)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 60, height: 22)
                .skeleton(isLoading: isLoading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
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
