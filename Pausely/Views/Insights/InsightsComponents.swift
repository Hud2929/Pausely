import SwiftUI

/// A ranked row on Insights: a name, an amount, and a bar showing its size against the largest.
struct BarRow: View {
    let title: String
    let value: String
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SideBySide(spacing: 12) {
                Text(verbatim: title)
                    .font(.body)
                    .foregroundStyle(Color.inkText)
            } trailing: {
                Text(verbatim: value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color.inkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track).frame(height: 3)
                    Capsule().fill(Color.inkText).frame(width: max(3, geo.size.width * share), height: 3)
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// Lists the subscriptions inside one overlap cluster so the person can inspect or cancel any of them.
struct OverlapDetailSheet: View {
    let group: OverlapDetector.Group
    let currency: String
    let onSelect: (UUID) -> Void
    var onRotateWithPausePlan: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: group.cluster.title)
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(L10n.string("Together these cost \(MoneyFormat.total(group.annualTotal, currency, converted: group.isConverted, locale: L10n.locale)) a year. Tap any service to review or cancel it."))
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    ForEach(Array(group.subscriptions.enumerated()), id: \.element.id) { index, sub in
                        if index > 0 { Hairline() }
                        Button {
                            Feel.selection()
                            onSelect(sub.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ServiceLogoView(name: sub.name, category: sub.category, size: 36)
                                LineOrStack(spacing: 8, lineSpacing: 2, spread: true, besideShare: 0.45) {
                                    Text(verbatim: sub.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.inkText)
                                        .multilineTextAlignment(.leading)
                                    Text(verbatim: sub.billingFrequency.priced(sub.chargeText))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(Color.inkTextMuted)
                                }
                                RowChevron()
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }

                    if let onRotateWithPausePlan {
                        Button {
                            Feel.selection()
                            onRotateWithPausePlan()
                            dismiss()
                        } label: {
                            Text("Rotate with Pause Plan")
                        }
                        .buttonStyle(.ink(.quiet))
                        .padding(.top, 24)
                        .accessibilityIdentifier("overlapRotatePausePlanButton")
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .readableScroll()
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.inkText)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
