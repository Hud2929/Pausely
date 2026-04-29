import SwiftUI

struct StepProgressView: View {
    let steps: [String]
    let currentStep: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? BrandColors.primary : BackgroundColors.tertiary)
                            .frame(width: 32, height: 32)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.footnote.weight(.bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.footnote.weight(.bold))
                                .foregroundColor(index == currentStep ? .white : TextColors.tertiary)
                        }
                    }

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? BrandColors.primary : BackgroundColors.tertiary)
                            .frame(height: 2)
                    }
                }
            }
        }
    }
}
