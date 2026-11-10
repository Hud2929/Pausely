#if DEBUG
import SwiftUI

/// DEBUG only (`--demo-design`): every piece of the Ink and Paper system on one screen, so a change
/// to a token can be checked at a glance in each language and text size.
struct DesignGalleryView: View {
    private let price = MoneyFormat.string(Decimal(string: "15.99")!, "USD")
    private let total = MoneyFormat.string(Decimal(string: "112.40")!, "USD")
    private let keptTotal = MoneyFormat.string(Decimal(string: "527.64")!, "USD")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "Each month you pay")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                    Text(verbatim: total)
                        .font(.question(.largeTitle, weight: .bold))
                        .foregroundStyle(Color.inkText)
                    Text(verbatim: "Kept with Pausely  \(keptTotal)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.kept)
                }

                PaperSlip {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(verbatim: "Keep Netflix?")
                            .font(.question(.title))
                        Text(verbatim: "It renews in 2 days. You opened it once this month.")
                            .font(.subheadline)
                            .foregroundStyle(Color.paperMuted)
                        Perforation()
                        ProofLine(label: "Next charge", value: price)
                        ProofLine(label: "A year of it", value: MoneyFormat.string(Decimal(string: "191.88")!, "USD"))
                        ProofLine(label: "Kept so far", value: keptTotal, emphasised: true)
                            .foregroundStyle(Color.paperKept)
                        Button { } label: { Text(verbatim: "I cancelled it") }
                            .buttonStyle(.ink(.onPaper))
                    }
                }

                VStack(spacing: 0) {
                    row("Needs a decision", .decide)
                    Hairline()
                    row("Charged tomorrow", .due)
                    Hairline()
                    row("Paused until March", .paused)
                    Hairline()
                    row("Cancelled, money kept", .kept)
                }

                VStack(spacing: 12) {
                    Button { } label: { Text(verbatim: "Show me the total") }.buttonStyle(.ink)
                    Button { } label: { Text(verbatim: "Keep it") }.buttonStyle(.ink(.keep))
                    Button { } label: { Text(verbatim: "Not now") }.buttonStyle(.ink(.quiet))
                    Button { } label: { Text(verbatim: "Remove") }.buttonStyle(.ink(.destructive))
                    Button { } label: { Text(verbatim: "Unavailable") }.buttonStyle(.ink).disabled(true)
                }
            }
            .padding(Layout.margin)
        }
        .background(Color.ink.ignoresSafeArea())
        .readableWidth()
    }

    private func row(_ title: String, _ state: MoneyState) -> some View {
        HStack(spacing: 12) {
            StateMark(state: state)
            Text(verbatim: title).font(.body).foregroundStyle(Color.inkText)
            Spacer(minLength: 8)
            Text(verbatim: price).font(.body.monospacedDigit()).foregroundStyle(Color.inkText)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
#endif
