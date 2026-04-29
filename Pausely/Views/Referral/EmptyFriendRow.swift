import SwiftUI

struct EmptyFriendRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "person")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.3))
            }

            Text("Waiting...")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()
        }
        .padding()
        .glass(intensity: 0.04, tint: .white)
    }
}
