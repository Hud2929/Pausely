//
//  CancelDifficultyRatingView.swift
//  Pausely
//
//  Shown after a user marks a subscription as cancelled.
//  Collects a 1–5 difficulty rating and submits it to Supabase.
//

import SwiftUI

struct CancelDifficultyRatingView: View {
    let serviceName: String
    let onDone: () -> Void

    @State private var selectedRating: Int? = nil
    @State private var isSubmitting = false
    @State private var submitted = false

    private let ratings: [(value: Int, label: String, icon: String)] = [
        (1, "Super Easy",   "hand.thumbsup.fill"),
        (2, "A Bit Annoying", "hand.thumbsdown"),
        (3, "Had to Search", "magnifyingglass"),
        (4, "Very Hard",    "exclamationmark.triangle"),
        (5, "Dark Pattern", "flame.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.obsidianTextTertiary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            if submitted {
                submittedView
            } else {
                ratingContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .background(Color.obsidianSurface)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var ratingContent: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.semanticSuccess)

                Text("You cancelled \(serviceName)!")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.obsidianText)

                Text("How hard was it to cancel?")
                    .font(.subheadline)
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            // Rating buttons
            VStack(spacing: 10) {
                ForEach(ratings, id: \.value) { option in
                    Button(action: { selectedRating = option.value }) {
                        HStack(spacing: 14) {
                            Image(systemName: option.icon)
                                .font(.body)
                                .foregroundStyle(selectedRating == option.value ? Color.obsidianBlack : ratingColor(option.value))
                                .frame(width: 24)

                            Text(option.label)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(selectedRating == option.value ? Color.obsidianBlack : Color.obsidianText)

                            Spacer()

                            if selectedRating == option.value {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.obsidianBlack)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedRating == option.value ? ratingColor(option.value) : Color.obsidianElevated)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Submit / Skip
            VStack(spacing: 10) {
                Button(action: submitRating) {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Text("Submit Rating")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.obsidianBlack)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(selectedRating != nil ? Color.accentMint : Color.obsidianElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedRating == nil || isSubmitting)

                Button(action: onDone) {
                    Text("Skip")
                        .font(.callout)
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
            }
        }
    }

    private var submittedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentMint)

            Text("Thanks for rating!")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.obsidianText)

            Text("Your feedback helps other users know what to expect.")
                .font(.subheadline)
                .foregroundStyle(Color.obsidianTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onDone() }
        }
    }

    private func submitRating() {
        guard let rating = selectedRating else { return }
        isSubmitting = true
        Task {
            await CancelDifficultyService.shared.submitRating(serviceName: serviceName, rating: rating)
            await MainActor.run {
                isSubmitting = false
                withAnimation { submitted = true }
            }
        }
    }

    private func ratingColor(_ value: Int) -> Color {
        switch value {
        case 1: return Color.accentMint
        case 2: return Color(hex: "6EE7B7")
        case 3: return Color.yellow
        case 4: return Color.orange
        case 5: return Color.red
        default: return Color.accentMint
        }
    }
}
