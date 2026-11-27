//
//  SubscriptionExporter.swift
//  Pausely
//
//  Export subscription data for taxes, sharing, or backup
//

import Foundation
import UIKit
import os.log

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case pdf = "PDF"
    case json = "JSON"


}

struct ExportOptions {
    var includeCancelled: Bool = false
    var format: ExportFormat = .csv
}

@MainActor
final class SubscriptionExporter {
    static let shared = SubscriptionExporter()

    private init() {}

    func export(subscriptions: [Subscription], options: ExportOptions = ExportOptions()) -> URL? {
        let filtered = subscriptions.filter { options.includeCancelled || $0.status != .cancelled }

        switch options.format {
        case .csv:
            return exportCSV(subscriptions: filtered)
        case .pdf:
            return exportPDF(subscriptions: filtered)
        case .json:
            return exportJSON(subscriptions: filtered, includeCancelled: options.includeCancelled)
        }
    }

    // MARK: - CSV

    /// The spreadsheet file, as text: one row for each subscription, under headings in the reader's
    /// language. Amounts are plain numbers in the subscription's own currency (named in its own
    /// column), and days are written year-month-day, which every spreadsheet reads the same way
    /// ("11/12/26" is two different days depending on who opens it). No renewal day is an empty cell.
    static func csv(for subscriptions: [Subscription], now: Date = Date(), calendar: Calendar = .billing) -> String {
        let headings = [L10n.string("Name"), L10n.string("Category"), L10n.string("Amount"), L10n.string("Currency"),
                        L10n.string("Billing cycle"), L10n.string("Status"), L10n.string("Each month"), L10n.string("Each year"),
                        L10n.string("Next renewal"), L10n.string("Tracking since"),
                        L10n.string("Billed to"), L10n.string("Notes")]
        var lines = [headings.map(csvCell).joined(separator: ",")]
        for sub in subscriptions {
            // The next renewal, not the day that was typed in, which may be months ago.
            let next = sub.renewsAutomatically ? RenewalDecisions.upcomingCharge(for: sub, now: now, calendar: calendar)?.date : nil
            let cells = [sub.name,
                         SubscriptionCategory.localizedLabel(for: sub.category),
                         MoneyFormat.plainNumber(sub.amount, sub.currency),
                         sub.currency,
                         sub.billingFrequency.displayName,
                         sub.status.displayName,
                         MoneyFormat.plainNumber(sub.monthlyCost, sub.currency),
                         MoneyFormat.plainNumber(sub.annualCost, sub.currency),
                         next.map(calendar.dayStamp) ?? "",
                         calendar.dayStamp(sub.createdAt),
                         sub.paymentMethod ?? "",
                         sub.notes ?? ""]
            lines.append(cells.map(csvCell).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func exportCSV(subscriptions: [Subscription]) -> URL? {
        // UTF-8 BOM lets Excel open Arabic, Japanese and accented currencies without mojibake.
        let data = Data([0xEF, 0xBB, 0xBF]) + Data(Self.csv(for: subscriptions).utf8)
        return writeDataToFile(data: data, extension: "csv")
    }

    /// One text cell of the spreadsheet file.
    ///
    /// A name can come from a scanned email, so it is treated as untrusted: inspect leading Unicode
    /// scalars (avoiding Swift's `\r\n` grapheme-cluster bypass) and trimmed leading whitespace so
    /// formulas (`=`, `+`, `-`, `@`, `\t`, `\r`, `\n`) always render as plain text.
    nonisolated static func csvCell(_ value: String) -> String {
        var cell = value
        let leadingUnsafe: Set<UnicodeScalar> = ["=", "+", "-", "@", "\t", "\r", "\n"]
        let formulaStarters: Set<UnicodeScalar> = ["=", "+", "-", "@"]
        let firstScalar = cell.unicodeScalars.first
        let trimmedFirst = cell.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.first
        if (firstScalar.map { leadingUnsafe.contains($0) } ?? false)
            || (trimmedFirst.map { formulaStarters.contains($0) } ?? false) {
            cell = "'" + cell
        }
        let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.unicodeScalars.contains(where: { $0 == "," || $0 == "\n" || $0 == "\r" || $0 == "\"" }) {
            return "\"\(escaped)\""
        }
        return escaped
    }

    // MARK: - JSON

    /// Everything Pausely holds about the customer, including the history that only lives on the device.
    private struct FullExport: Encodable {
        let subscriptions: [Subscription]
        let history: [LifecycleEvent]
        let pausePlan: PausePlan?
    }

    /// The full file: the list, the history that lives only on this device, and the Pause Plan.
    /// Dates are ISO 8601 and keys are sorted, so the same data always makes the same file.
    static func json(for subscriptions: [Subscription], history: [LifecycleEvent], pausePlan: PausePlan?) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(FullExport(subscriptions: subscriptions, history: history, pausePlan: pausePlan))
    }

    private func exportJSON(subscriptions: [Subscription], includeCancelled: Bool) -> URL? {
        do {
            let exportedIDs = Set(subscriptions.map(\.id))
            let history = includeCancelled
                ? LifecycleEventLog.shared.events
                : LifecycleEventLog.shared.events.filter { exportedIDs.contains($0.subscriptionId) }
            let data = try Self.json(for: subscriptions, history: history,
                                     pausePlan: PausePlanStore.shared.plan)
            return writeDataToFile(data: data, extension: "json")
        } catch {
            os_log("JSON export failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
            return nil
        }
    }

    // MARK: - PDF

    /// The words on the printed page, in the reader's language.
    struct PageText: Equatable {
        let title: String
        let madeOn: String
        let eachMonth: String
        let eachYear: String
        let headings: [String]
    }

    static func pageText(for subscriptions: [Subscription], now: Date = Date(),
                         currency: String = CurrencyManager.shared.selectedCurrency) -> PageText {
        // Totals in the display currency, each subscription converted from its own currency.
        let active = subscriptions.charging
        let converted = active.isConverted(to: currency)
        let label: (String, String) -> String = { name, value in "\(name): \(value)" }
        return PageText(
            title: L10n.string("Your subscriptions"),
            madeOn: now.formatted(.dateTime.day().month(.wide).year().locale(L10n.locale)),
            eachMonth: label(L10n.string("Each month"), MoneyFormat.total(active.monthlyTotal(in: currency), currency, converted: converted)),
            eachYear: label(L10n.string("Each year"), MoneyFormat.total(active.annualTotal(in: currency), currency, converted: converted)),
            headings: [L10n.string("Name"), L10n.string("Category"), L10n.string("Amount"), L10n.string("Billing cycle"), L10n.string("Status")])
    }

    static func pageRow(for sub: Subscription) -> [String] {
        [sub.name, SubscriptionCategory.localizedLabel(for: sub.category), MoneyFormat.string(sub.amount, sub.currency),
         sub.billingFrequency.displayName, sub.status.displayName]
    }

    /// A page to print or send: black on white whatever the app's own colours (the app is dark, and a
    /// page drawn in its colours would be white text on white paper), columns right to left in a
    /// language written that way.
    private func exportPDF(subscriptions: [Subscription]) -> URL? {
        let text = Self.pageText(for: subscriptions)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextCreator: "Pausely", kCGPDFContextTitle: text.title] as [String: Any]

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        let rightToLeft = L10n.isRightToLeft ?? (UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = rightToLeft ? .right : .left
        paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        paragraph.lineBreakMode = .byTruncatingTail
        func style(_ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor = .black) -> [NSAttributedString.Key: Any] {
            [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph]
        }
        let width = pageWidth - margin * 2
        func line(_ string: String, _ attributes: [NSAttributedString.Key: Any], y: CGFloat, height: CGFloat) {
            NSAttributedString(string: string, attributes: attributes).draw(in: CGRect(x: margin, y: y, width: width, height: height))
        }

        // Five columns across the page; in a right-to-left language the first is on the right.
        let widths: [CGFloat] = [156, 98, 90, 102, 86]
        var edges: [CGFloat] = []
        var x = margin
        for columnWidth in widths { edges.append(x); x += columnWidth }
        func row(_ cells: [String], y: CGFloat, header: Bool, in context: UIGraphicsPDFRendererContext) {
            if header {
                UIColor(white: 0.2, alpha: 1).setFill()
                context.cgContext.fill(CGRect(x: margin - 5, y: y - 4, width: width + 10, height: 24))
            }
            let attributes = header ? style(11, .bold, .white) : style(10, .regular)
            for (index, cell) in cells.enumerated() {
                let left = rightToLeft ? pageWidth - edges[index] - widths[index] : edges[index]
                NSAttributedString(string: cell, attributes: attributes)
                    .draw(in: CGRect(x: left + 2, y: y, width: widths[index] - 6, height: 20))
            }
        }

        let data = renderer.pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            var y: CGFloat = margin
            line(text.title, style(26, .bold), y: y, height: 34)
            y += 44
            line(text.madeOn, style(12, .regular, UIColor(white: 0.35, alpha: 1)), y: y, height: 18)
            y += 34
            line(text.eachMonth, style(13, .semibold), y: y, height: 20)
            y += 22
            line(text.eachYear, style(13, .semibold), y: y, height: 20)
            y += 40

            row(text.headings, y: y, header: true, in: context)
            y += 30
            for sub in subscriptions {
                if y > pageHeight - 60 {
                    context.beginPage()
                    UIColor.white.setFill()
                    context.cgContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                    y = margin
                    row(text.headings, y: y, header: true, in: context)
                    y += 30
                }
                row(Self.pageRow(for: sub), y: y, header: false, in: context)
                y += 24
            }
        }

        return writeDataToFile(data: data, extension: "pdf")
    }

    // MARK: - Helpers

    func cleanPreviousExports() {
        let dir = FileManager.default.temporaryDirectory
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in urls where url.lastPathComponent.hasPrefix("pausely_export_") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func writeDataToFile(data: Data, extension ext: String) -> URL? {
        cleanPreviousExports()
        let filename = "pausely_export_\(Int(Date().timeIntervalSince1970)).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return url
        } catch {
            os_log("Export write failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
            return nil
        }
    }
}
