import SwiftUI

/// Every subscription cancelled through Pausely, with the charges it avoided. Each number can be
/// checked: the dates come from the same renewal engine as the reminders.
struct SavingsReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        let summary = SavingsSummary.current()
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    totals(summary)
                    if summary.pauselyYearlyCost != nil || !summary.isEmpty {
                        PauselyPromiseCard()
                    }
                    if summary.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(summary.lines.reversed().enumerated()), id: \.element.id) { index, line in
                                if index > 0 { Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 16) }
                                lineRow(line)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
                    }
                    howWeCount
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Savings Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accentMint)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func totals(_ summary: SavingsSummary) -> some View {
        VStack(spacing: 6) {
            Text("SAVED WITH PAUSELY")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(2)
                .foregroundStyle(Color.obsidianTextTertiary)
            Text(summary.formatted(summary.savedSoFar))
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(Color.accentMint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(summary.isEmpty
                 ? String(localized: "Nothing yet")
                 : String(localized: "\(summary.formatted(summary.onTrack)) over the 12 months after each cancellation"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func lineRow(_ line: SavingsLedger.Line) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(MoneyFormat.string(line.savedSoFar, line.currency))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)
            }
            Text(String(localized: "Cancelled \(line.cancelledOn.formatted(.dateTime.month(.abbreviated).day().year())) · \(line.avoidedSoFar.count) of \(line.avoidedCharges.count) charges avoided so far"))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
            if let next = line.avoidedCharges.first(where: { !line.avoidedSoFar.contains($0) }) {
                Text(String(localized: "Next avoided charge: \(MoneyFormat.string(line.amountPerCharge, line.currency)) on \(next.formatted(.dateTime.month(.abbreviated).day()))"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            if let ended = line.endedOn {
                Text(String(localized: "Started again \(ended.formatted(.dateTime.month(.abbreviated).day())). Savings stop there."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.accentMint)
                .accessibilityHidden(true)
            Text("Your receipt starts with your first decision")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Before each renewal Pausely asks: keep it or cancel it? Every subscription you cancel shows up here with the charges it avoided.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
    }

    private var howWeCount: some View {
        Text("How we count: only charges that would really have happened, worked out from the payment date you entered, for 12 months after you cancel. If a subscription starts again, its savings stop that day. Pausely's own subscription never counts.")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.obsidianTextTertiary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
