import SwiftUI

/// What Home, Subscriptions and Insights show where the list would be while there is nothing to
/// show (`SubscriptionStore.ListState`). One part each, so the three tabs say the same thing.

/// The list is being fetched for the first time: four grey rows where the subscriptions will be.
struct ListLoading: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                if index > 0 { Hairline() }
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous).fill(Color.inkRaised).frame(width: 36, height: 36)
                    RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous).fill(Color.inkRaised).frame(width: 140, height: 14)
                    Spacer()
                    RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous).fill(Color.inkRaised).frame(width: 56, height: 14)
                }
                .padding(.vertical, 12)
            }
        }
        // One stop for VoiceOver that says what the shapes mean. Without being made an element the
        // label was attached to nothing and nothing was read.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading"))
    }
}

/// The fetch failed and nothing is on this iPhone. The person may well have a list in their account,
/// so this never says the list is empty (it said "Nothing on your list yet." until 2026-11-12).
struct ListCouldNotLoad: View {
    @State private var isTrying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Couldn't load your list.")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Check your connection, then try again.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                guard !isTrying else { return }
                isTrying = true
                Task {
                    await SubscriptionStore.shared.fetchSubscriptions(force: true)
                    isTrying = false
                }
            } label: {
                if isTrying { ProgressView().tint(Color.paperInk) } else { Text("Try again") }
            }
            .buttonStyle(.ink)
            .disabled(isTrying)
            .padding(.top, 12)
            .accessibilityIdentifier("listTryAgainButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
