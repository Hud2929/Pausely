import SwiftUI

struct AlternativePreviewBlurred: View {
    let alternatives: [AlternativeService]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(alternatives.prefix(2)) { alt in
                HStack {
                    Text(alt.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .blur(radius: 8)
            }
        }
    }
}
