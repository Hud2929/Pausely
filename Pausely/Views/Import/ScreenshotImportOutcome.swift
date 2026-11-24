import SwiftUI

/// Intro instructions and outcome slip for `ScreenshotImportView`.
struct ScreenshotImportReadyView: View {
    let canBatchImport: Bool
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
                // The number is formatted, so it has the digits of the rest of the screen (a typed "١٠" stood beside
                // steps numbered 1, 2, 3, the reach rating of 2026-11-23).
                Text("The free plan imports one screenshot at a time. Pausely Pro reads up to \(Self.proBatch) screenshots in one batch.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
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
        if !result.datesFilled.isEmpty { return L10n.string("Renewal dates updated") }
        if !result.waiting.isEmpty { return L10n.string("Waiting for room") }
        return L10n.string("Already on your list")
    }

    var body: some View {
        let skippedAlreadyListed = result.alreadyListed.filter { !result.datesFilled.contains($0) }
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: heading)
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 10) {
                    if !result.added.isEmpty {
                        ProofLine(label: L10n.string("Added"), value: L10n.number(result.added.count), emphasised: true)
                        Text(verbatim: result.added.formatted(.list(type: .and).locale(L10n.locale)))
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !result.datesFilled.isEmpty {
                        if !result.added.isEmpty { Perforation() }
                        ProofLine(label: L10n.string("Renewal dates added"), value: L10n.number(result.datesFilled.count))
                    }
                    if !result.waiting.isEmpty {
                        if !result.added.isEmpty || !result.datesFilled.isEmpty { Perforation() }
                        ProofLine(label: L10n.string("Waiting for room"), value: L10n.number(result.waiting.count))
                        Text(L10n.string("Home shows the rest so you can choose which \(FreeTier.subscriptionLimit) to track or go Pro."))
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !skippedAlreadyListed.isEmpty {
                        if !result.added.isEmpty || !result.datesFilled.isEmpty || !result.waiting.isEmpty { Perforation() }
                        ProofLine(label: L10n.string("Already on your list"), value: L10n.number(skippedAlreadyListed.count))
                        Text(verbatim: skippedAlreadyListed.formatted(.list(type: .and).locale(L10n.locale)))
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}
