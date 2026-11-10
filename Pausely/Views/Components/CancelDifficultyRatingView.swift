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

    private let ratings: [(value: Int, label: LocalizedStringResource)] = [
        (1, "Super Easy"),
        (2, "A Bit Annoying"),
        (3, "Had to Search"),
        (4, "Very Hard"),
        (5, "Dark Pattern"),
    ]

    var body: some View {
        Group {
            if submitted { submittedView } else { ratingContent }
        }
        .padding(.horizontal, Layout.margin)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.inkRaised.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var ratingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How hard was it to cancel?")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Your feedback helps other users know what to expect.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 16)

            ForEach(ratings, id: \.value) { option in
                let isOn = selectedRating == option.value
                Button {
                    Feel.selection()
                    selectedRating = option.value
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                            .font(.title3)
                            .foregroundStyle(isOn ? Color.paper : Color.inkTextFaint)
                            .accessibilityHidden(true)
                        Text(option.label)
                            .font(.body)
                            .foregroundStyle(Color.inkText)
                        Spacer(minLength: 8)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
                Hairline()
            }

            Spacer(minLength: 16)

            Button(action: submitRating) {
                if isSubmitting { ProgressView().tint(Color.paperInk) } else { Text("Submit Rating") }
            }
            .buttonStyle(.ink)
            .disabled(selectedRating == nil || isSubmitting)

            Button(action: onDone) {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var submittedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Thanks for rating!")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
            Text("Your feedback helps other users know what to expect.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            onDone()
        }
    }

    private func submitRating() {
        guard let rating = selectedRating else { return }
        isSubmitting = true
        Task {
            await CancelDifficultyService.shared.submitRating(serviceName: serviceName, rating: rating)
            await MainActor.run {
                isSubmitting = false
                withAnimation(Motion.unlessReduced(Motion.arrive)) { submitted = true }
            }
        }
    }
}
