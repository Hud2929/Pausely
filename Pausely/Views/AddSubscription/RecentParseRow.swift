import SwiftUI

struct RecentParseRow: View {
    let parse: ParsedSubscription

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: parse.category.icon)
                .font(AppTypography.headlineLarge)
                .foregroundStyle(parse.category.color)
                .frame(width: 40, height: 40)
                .background(parse.category.color.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(parse.name)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.white)

                Text(parse.url.host ?? "")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.labelLarge)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }
}
