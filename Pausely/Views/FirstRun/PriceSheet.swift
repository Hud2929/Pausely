import SwiftUI

/// Correct one price on the slip.
struct PriceSheet: View {
    let name: String
    /// The price already on the slip, shown until the person types.
    let placeholder: Decimal?
    let currency: String
    var frequency: BillingFrequency = .monthly
    let onSave: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var text = ""
    @State private var formHeight: CGFloat = 0
    @FocusState private var focused: Bool

    private var amount: Decimal? { AmountText.parse(text, currency: currency) }

    private var questionTitle: String {
        switch frequency {
        case .monthly: return L10n.string("What do you pay for \(name) each month?")
        case .yearly: return L10n.string("What do you pay for \(name) each year?")
        case .weekly: return L10n.string("What do you pay for \(name) each week?")
        case .biweekly, .quarterly, .semiannual:
            return L10n.string("What do you pay for \(name) each time?")
        }
    }

    private var priceAccessibilityLabel: String {
        switch frequency {
        case .monthly: return L10n.string("Price each month")
        case .yearly: return L10n.string("Price each year")
        case .weekly: return L10n.string("Price each week")
        case .biweekly, .quarterly, .semiannual: return L10n.string("Price")
        }
    }

    /// How tall the short sheet is: as tall as its form, once that has been measured. Until then
    /// (the first frame) it is about as tall as the form is in English at the ordinary text size.
    nonisolated static func sheetHeight(forForm measured: CGFloat) -> CGFloat {
        measured > 0 ? measured.rounded(.up) : 280
    }

    var body: some View {
        // A short sheet, as tall as what it holds: a height written as a number fitted one text
        // size and one language (300 points cut the question's first line, and 344 left a band of
        // nothing under Save). At the accessibility
        // sizes the question alone is most of a screen, so the sheet is full height and scrolls.
        ScrollView {
            form
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { formHeight = $0 }
        }
        .readableScroll()
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(Self.sheetHeight(forForm: formHeight))])
        .presentationBackground(Color.inkRaised)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            // A way out that is not a swipe: the sheet had "Save" and nothing else.
            LeaveButton("Cancel") { dismiss() }
                .accessibilityIdentifier("priceCancelButton")
            Text(verbatim: questionTitle)
                .font(.question(.title3))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField(text: $text, prompt: placeholder.map { Hint.text(MoneyFormat.string($0, currency, locale: L10n.locale)) }) { EmptyView() }
                    .keyboardType(.decimalPad)
                    .font(.proof(.title2, weight: .medium))
                    .foregroundStyle(Color.inkText)
                    .focused($focused)
                    .accessibilityLabel(Text(verbatim: priceAccessibilityLabel))
                    .accessibilityIdentifier("priceField")
                Text(verbatim: currency)
                    .font(.proof(.subheadline))
                    .foregroundStyle(Color.inkTextMuted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(Color.inkLifted, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))

            Button {
                if let amount { onSave(amount) }
                dismiss()
            } label: { Text("Save") }
                .buttonStyle(.ink)
                .disabled(amount == nil)
                .accessibilityIdentifier("priceSaveButton")
        }
        .padding(.horizontal, Layout.margin)
        .padding(.bottom, Layout.margin)
        .padding(.top, 8)
        .onAppear { focused = true }
    }
}
