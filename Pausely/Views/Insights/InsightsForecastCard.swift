import SwiftUI

/// Interactive 12-month renewal cash-flow forecast on the Insights tab.
/// Free users see Months 1–3 interactively plus their peak-month callout; Pro unlocks all 12 months
/// and tap-to-inspect charge lists for every month of the year.
struct InsightsForecastCard: View {
    let summary: InsightsEngine.ForecastSummary
    let currency: String
    let isUnlocked: Bool
    let onUnlock: (PaywallContext) -> Void
    let onAddDates: () -> Void
    let onSelectSubscription: (UUID) -> Void

    @State private var selectedOffset: Int = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    private let freePreviewMonths = 3

    private var selectedBucket: InsightsEngine.MonthBucket? {
        if selectedOffset == -1, let rem = summary.remainingThisMonth { return rem }
        return summary.months.first { $0.offset == selectedOffset } ?? summary.months.first
    }

    private var peakMonthName: String? {
        summary.peakMonth.map { Self.fullMonthName($0.monthStart) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if !summary.hasCharges {
                emptyForecast
            } else {
                if let peak = summary.peakMonth, let above = summary.peakAboveAverage, above > 0 {
                    peakCallout(peak: peak, above: above)
                }

                if let remaining = summary.remainingThisMonth {
                    remainingMonthChip(remaining)
                }

                barChart

                if !isUnlocked {
                    unlockBanner
                }

                if let bucket = selectedBucket, (isUnlocked || bucket.offset < freePreviewMonths) {
                    monthDetail(bucket)
                }

                if summary.undatedCount > 0 {
                    undatedNote
                }

                if summary.unconvertibleCount > 0 {
                    unconvertibleNote
                }
            }
        }
        .padding(.top, 10)
        .onAppear { pickInitialOffset() }
        .onChange(of: summary.hasCharges) { _, _ in pickInitialOffset() }
        .onChange(of: summary.peakMonth?.offset) { _, _ in pickInitialOffset() }
        .onChange(of: isUnlocked) { _, unlocked in
            if unlocked, let peak = summary.peakMonth {
                selectedOffset = peak.offset
            } else if !unlocked, selectedOffset >= freePreviewMonths {
                pickInitialOffset()
            }
        }
    }

    private func pickInitialOffset() {
        if isUnlocked, let peak = summary.peakMonth {
            selectedOffset = peak.offset
            return
        }
        if let firstActive = summary.months.first(where: {
            (isUnlocked || $0.offset < freePreviewMonths) && !$0.charges.isEmpty
        }) {
            selectedOffset = firstActive.offset
            return
        }
        if summary.remainingThisMonth != nil {
            selectedOffset = -1
            return
        }
        selectedOffset = 0
    }

    private var headerRow: some View {
        SideBySide(spacing: 12) {
            Text("12-month forecast")
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .accessibilityAddTraits(.isHeader)
        } trailing: {
            if !isUnlocked {
                ProPill()
            }
        }
    }

    private var emptyForecast: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add renewal dates to map out the next 12 months and spot heavy billing months early.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Feel.selection()
                onAddDates()
            } label: {
                Text("Add dates")
            }
            .buttonStyle(.ink(.quiet))
            .accessibilityIdentifier("forecastAddDatesButton")
        }
        .padding(.vertical, 6)
    }

    private func peakCallout(peak: InsightsEngine.MonthBucket, above: Decimal) -> some View {
        let monthName = Self.fullMonthName(peak.monthStart)
        let peakTotal = MoneyFormat.total(peak.total, currency, converted: peak.isConverted, locale: L10n.locale, wholeUnits: true)
        let extra = MoneyFormat.total(above, currency, converted: summary.isConverted, locale: L10n.locale, wholeUnits: true)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            StateMark(state: .due).accessibilityHidden(true)
            Text(L10n.string("Peak month: \(monthName) (\(peakTotal)) — about \(extra) above your monthly average."))
                .font(.subheadline)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("forecastPeakCallout")
    }

    private func remainingMonthChip(_ bucket: InsightsEngine.MonthBucket) -> some View {
        let isSelected = selectedOffset == -1
        let monthName = Self.fullMonthName(bucket.monthStart)
        let amountText = bucketTotalText(bucket)
        return Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { selectedOffset = -1 }
        } label: {
            SideBySide(spacing: 12) {
                Text(L10n.string("Still due in \(monthName)"))
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.inkText)
            } trailing: {
                Text(verbatim: amountText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.inkText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                .stroke(isSelected ? Color.paper : Color.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("forecastRemainingThisMonth")
    }

    private var barChart: some View {
        let maxTotal = summary.months.map(\.total).max() ?? 1
        let barAreaHeight: CGFloat = typeSize.isAccessibilitySize ? 104 : 88
        return Group {
            if typeSize.isAccessibilitySize {
                ScrollView(.horizontal, showsIndicators: false) {
                    barsStrip(maxTotal: maxTotal, barAreaHeight: barAreaHeight, scrollable: true)
                        .padding(12)
                }
            } else {
                barsStrip(maxTotal: maxTotal, barAreaHeight: barAreaHeight, scrollable: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
        }
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous).stroke(Color.line, lineWidth: 1))
    }

    private func barsStrip(maxTotal: Decimal, barAreaHeight: CGFloat, scrollable: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(summary.months) { bucket in
                if !isUnlocked && bucket.offset == freePreviewMonths {
                    Rectangle()
                        .fill(Color.outline)
                        .frame(width: 1, height: barAreaHeight)
                        .padding(.horizontal, 2)
                        .accessibilityHidden(true)
                }
                monthBar(bucket: bucket, maxTotal: maxTotal, barAreaHeight: barAreaHeight, scrollable: scrollable)
            }
        }
    }

    private func monthBar(bucket: InsightsEngine.MonthBucket,
                          maxTotal: Decimal,
                          barAreaHeight: CGFloat,
                          scrollable: Bool) -> some View {
        let locked = !isUnlocked && bucket.offset >= freePreviewMonths
        let isSelected = !locked && selectedOffset == bucket.offset
        let ratio = maxTotal > 0 ? NSDecimalNumber(decimal: bucket.total / maxTotal).doubleValue : 0
        let height = max(6, CGFloat(min(max(ratio, 0), 1)) * barAreaHeight)
        let label = Self.shortMonthLetter(bucket.monthStart)

        return Button {
            Feel.selection()
            if locked {
                triggerUnlock()
            } else {
                withAnimation(Motion.unlessReduced(Motion.touch)) { selectedOffset = bucket.offset }
            }
        } label: {
            VStack(spacing: 6) {
                Color.clear
                    .frame(height: barAreaHeight)
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                            .fill(barFill(bucket: bucket, isSelected: isSelected, locked: locked))
                            .frame(height: height)
                            .opacity(barOpacity(bucket: bucket, locked: locked))
                            .padding(.horizontal, 2)
                    }
                Text(verbatim: label)
                    .font(.caption2.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.inkText : Color.inkTextFaint)
                    .lineLimit(1)
            }
            .frame(minWidth: scrollable ? Layout.tapTarget : 0, maxWidth: scrollable ? nil : .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityMonthLabel(bucket, locked: locked)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("forecastMonth_\(bucket.offset)")
    }

    private func barFill(bucket: InsightsEngine.MonthBucket, isSelected: Bool, locked: Bool) -> Color {
        if locked { return bucket.isPeak ? Color.due : Color.inkTextFaint }
        if isSelected { return Color.paper }
        if bucket.isPeak { return Color.due }
        return Color.inkTextMuted
    }

    private func barOpacity(bucket: InsightsEngine.MonthBucket, locked: Bool) -> Double {
        guard locked else { return 1 }
        return bucket.isPeak ? 0.5 : 0.35
    }

    private var unlockBanner: some View {
        Button {
            Feel.selection()
            triggerUnlock()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("See all 12 months with Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                    Text("Tap any month ahead to see annual renewals before they hit.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                RowChevron()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous).stroke(Color.outline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("forecastUnlockButton")
    }

    private func monthDetail(_ bucket: InsightsEngine.MonthBucket) -> some View {
        let monthTitle = bucket.offset == -1
            ? L10n.string("Still due in \(Self.fullMonthName(bucket.monthStart))")
            : Self.fullMonthYear(bucket.monthStart)
        let totalText = bucketTotalText(bucket)
        return VStack(alignment: .leading, spacing: 0) {
            SideBySide(spacing: 12) {
                Text(verbatim: monthTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
            } trailing: {
                Text(verbatim: totalText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(bucket.isPeak ? Color.due : Color.inkText)
                    .contentTransition(.numericText())
            }
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)

            if bucket.charges.isEmpty {
                Text("No renewals due this month.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(bucket.charges.enumerated()), id: \.element.id) { index, charge in
                    if index > 0 { Hairline() }
                    Button {
                        Feel.selection()
                        onSelectSubscription(charge.subscriptionId)
                    } label: {
                        HStack(spacing: 10) {
                            AdaptiveRow {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: charge.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.inkText)
                                        .multilineTextAlignment(.leading)
                                    Text(verbatim: charge.isTrialEnd
                                         ? L10n.string("Trial ends \(DayText.date(charge.date, locale: L10n.locale))")
                                         : DayText.date(charge.date, locale: L10n.locale))
                                        .font(.footnote)
                                        .foregroundStyle(Color.inkTextMuted)
                                }
                            } value: {
                                Text(verbatim: MoneyFormat.string(charge.amount, charge.currency, locale: L10n.locale))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(Color.inkText)
                            }
                            RowChevron()
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.top, 4)
    }

    private func bucketTotalText(_ bucket: InsightsEngine.MonthBucket) -> String {
        if bucket.total == 0 && bucket.hasUnconvertibleCharges { return "—" }
        return MoneyFormat.total(bucket.total, currency, converted: bucket.isConverted, locale: L10n.locale)
    }

    private var undatedNote: some View {
        HStack(spacing: 8) {
            Text(summary.undatedCount == 1
                 ? L10n.string("1 subscription has no renewal date and isn't in this forecast.")
                 : L10n.string("\(summary.undatedCount) subscriptions have no renewal date and aren't in this forecast."))
                .font(.footnote)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button {
                Feel.selection()
                onAddDates()
            } label: {
                Text("Add dates")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .underline()
                    .tapArea(.trailing)
            }
            .buttonStyle(.plain)
        }
    }

    private var unconvertibleNote: some View {
        Text(summary.unconvertibleCount == 1
             ? L10n.string("1 subscription uses a currency without a conversion rate and isn't in the monthly totals.")
             : L10n.string("\(summary.unconvertibleCount) subscriptions use currencies without conversion rates and aren't in the monthly totals."))
            .font(.footnote)
            .foregroundStyle(Color.inkTextMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func triggerUnlock() {
        onUnlock(PaywallContext(
            trigger: .spendForecast,
            forecastPeakMonth: peakMonthName,
            forecastPeakAmount: summary.peakMonth?.total,
            forecastCurrency: currency,
            forecastIsConverted: summary.peakMonth?.isConverted ?? false
        ))
    }

    private func accessibilityMonthLabel(_ bucket: InsightsEngine.MonthBucket, locked: Bool) -> String {
        let month = Self.fullMonthYear(bucket.monthStart)
        if locked {
            return L10n.string("\(month), Pro")
        }
        return "\(month): \(bucketTotalText(bucket))"
    }

    private static func shortMonthLetter(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: L10n.locale, calendar: .billing).month(.narrow))
    }

    private static func fullMonthName(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: L10n.locale, calendar: .billing).month(.wide))
    }

    private static func fullMonthYear(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: L10n.locale, calendar: .billing).month(.abbreviated).year())
    }
}
