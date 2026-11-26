import SwiftUI

/// Intro instructions and outcome slip for `ScreenshotImportView`.
struct ScreenshotImportReadyView: View {
    let canBatchImport: Bool
    var onSeeBatchPro: (() -> Void)? = nil
    /// How many screenshots Pausely Pro reads at once.
    static let proBatch = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Import from screenshots")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            Text("Take a screenshot of Apple Subscriptions or your bank's recurring charges. Pausely reads it on this iPhone and never uploads the image.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            // On ink between hairlines: paper is for money decided or proven, and these are instructions
            // (the rating of 2026-11-23).
            VStack(alignment: .leading, spacing: 0) {
                Hairline()
                VStack(alignment: .leading, spacing: 12) {
                    Text("How it works")
                        .font(.headline)
                        .foregroundStyle(Color.inkText)
                        .accessibilityAddTraits(.isHeader)
                    stepLine(1, L10n.string("Open Apple Subscriptions or your bank's recurring charges."))
                    stepLine(2, canBatchImport
                             ? L10n.string("Take one or more screenshots of your active list.")
                             : L10n.string("Take a screenshot of your active list."))
                    stepLine(3, canBatchImport
                             ? L10n.string("Pick the screenshots here to review and add them in seconds.")
                             : L10n.string("Pick the screenshot here to review and add them in seconds."))
                    Text("100% on-device. Photos are read in memory and never saved or sent anywhere.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.vertical, 16)
                Hairline()
            }
            .padding(.top, 24)

            if !canBatchImport {
                if let onSeeBatchPro {
                    Button {
                        Feel.selection()
                        onSeeBatchPro()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                LineOrStack(spacing: 8, lineSpacing: 4) {
                                    Text("Import up to \(Self.proBatch) screenshots at once")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.inkText)
                                    ProPill()
                                }
                                Text("The free plan imports one screenshot at a time. Pausely Pro reads up to \(Self.proBatch) screenshots in one batch.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.inkTextMuted)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            RowChevron()
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("batchScreenshotProRow")
                    .padding(.top, 8)
                    Hairline()
                } else {
                    Text("The free plan imports one screenshot at a time. Pausely Pro reads up to \(Self.proBatch) screenshots in one batch.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
            }
        }
    }

    private func stepLine(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: L10n.number(number))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.inkText)
            Text(verbatim: text)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ScreenshotImportOutcomeView: View {
    let result: TallyImporter.Outcome

    private var heading: String {
        if !result.added.isEmpty { return L10n.string("Added to your list") }
        if !result.pricesUpdated.isEmpty && !result.datesFilled.isEmpty { return L10n.string("Subscriptions updated") }
        if !result.pricesUpdated.isEmpty { return L10n.string("Prices updated") }
        if !result.datesFilled.isEmpty { return L10n.string("Renewal dates updated") }
        if !result.waiting.isEmpty { return L10n.string("Waiting for room") }
        return L10n.string("Already on your list")
    }

    var body: some View {
        let updatedNames = Set(result.datesFilled + result.pricesUpdated)
        let skippedAlreadyListed = result.alreadyListed.filter { !updatedNames.contains($0) }
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: heading)
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            // On ink: these are counts, not money, and paper is for money decided or proven (2026-11-23).
            VStack(alignment: .leading, spacing: 0) {
                Hairline()
                VStack(alignment: .leading, spacing: 10) {
                    if !result.added.isEmpty {
                        ProofLine(label: L10n.string("Added"), value: L10n.number(result.added.count), emphasised: true)
                        Text(verbatim: result.added.formatted(.list(type: .and).locale(L10n.locale)))
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !result.datesFilled.isEmpty {
                        if !result.added.isEmpty { Hairline() }
                        ProofLine(label: L10n.string("Renewal dates added"), value: L10n.number(result.datesFilled.count))
                    }
                    if !result.pricesUpdated.isEmpty {
                        if !result.added.isEmpty || !result.datesFilled.isEmpty { Hairline() }
                        ProofLine(label: L10n.string("Prices updated"), value: L10n.number(result.pricesUpdated.count))
                        Text(verbatim: result.pricesUpdated.formatted(.list(type: .and).locale(L10n.locale)))
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !result.waiting.isEmpty {
                        if !result.added.isEmpty || !result.datesFilled.isEmpty || !result.pricesUpdated.isEmpty { Hairline() }
                        ProofLine(label: L10n.string("Waiting for room"), value: L10n.number(result.waiting.count))
                        Text(L10n.string("Home shows the rest so you can choose which \(FreeTier.subscriptionLimit) to track or go Pro."))
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !skippedAlreadyListed.isEmpty {
                        if !result.added.isEmpty || !result.datesFilled.isEmpty || !result.pricesUpdated.isEmpty || !result.waiting.isEmpty { Hairline() }
                        ProofLine(label: L10n.string("Already on your list"), value: L10n.number(skippedAlreadyListed.count))
                        Text(verbatim: skippedAlreadyListed.formatted(.list(type: .and).locale(L10n.locale)))
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 14)
                .foregroundStyle(Color.inkText)
                Hairline()
            }
            .padding(.top, 20)
        }
    }
}

struct ScreenshotReadingView: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(count == 1 ? L10n.string("Reading your screenshot…")
                            : L10n.string("Reading \(count) screenshots…"))
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                ProgressView().tint(Color.inkTextMuted)
                Text("Recognizing services, prices, and renewal dates on this iPhone.")
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
    }
}

struct ScreenshotNothingFoundView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No subscriptions found in that image.")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            Text("Try a screenshot of Apple Settings › Subscriptions or a bank screen showing service names and prices.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ScreenshotInactiveRow: View {
    let item: ScreenshotParser.DetectedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: item.name)
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .strikethrough(true, color: Color.inkTextFaint)
            if let amount = item.amount {
                Text(verbatim: item.frequency.pricedShort(MoneyFormat.string(amount, item.currency, locale: L10n.locale)))
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .accessibilityLabel(Text(verbatim: item.frequency.priced(MoneyFormat.string(amount, item.currency, locale: L10n.locale))))
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Pure helpers keeping `ScreenshotImportView` compact while preserving rich paywall context and outcome refresh.
enum ScreenshotImportSupport {
    static func paywallContext(trigger: ProFeature,
                               chosenItems: [ScreenshotParser.DetectedItem],
                               existingCharging: [Subscription],
                               outcome: TallyImporter.Outcome?,
                               displayCurrency: String,
                               rates: CurrencyRates) -> PaywallContext {
        guard trigger == .unlimitedSubscriptions, outcome == nil else {
            return PaywallContext(trigger: trigger)
        }
        let newLines = chosenItems.compactMap { $0.tallyLine() }.filter { line in
            !existingCharging.contains { ServiceName.same($0.name, line.name) }
        }
        let room = FreeTier.room(in: existingCharging)
        let ranked = newLines.sorted {
            (rates.convert($0.yearlyCost, from: $0.currency, to: displayCurrency) ?? -1)
                > (rates.convert($1.yearlyCost, from: $1.currency, to: displayCurrency) ?? -1)
        }
        let overflow = Array(ranked.dropFirst(room))
        return PaywallContext(
            trigger: .unlimitedSubscriptions,
            pendingWaitingLines: overflow,
            pendingTotalCount: existingCharging.count + newLines.count,
            pendingCurrency: displayCurrency
        )
    }

    static func promotedOutcome(_ current: TallyImporter.Outcome) -> TallyImporter.Outcome {
        TallyImporter.Outcome(
            added: current.added + current.waiting,
            waiting: [],
            alreadyListed: current.alreadyListed,
            datesFilled: current.datesFilled,
            pricesUpdated: current.pricesUpdated
        )
    }
}
