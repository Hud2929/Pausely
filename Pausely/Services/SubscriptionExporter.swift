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

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .pdf: return "pdf"
        case .json: return "json"
        }
    }

    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .pdf: return "application/pdf"
        case .json: return "application/json"
        }
    }
}

struct ExportOptions {
    var includePaused: Bool = true
    var includeCancelled: Bool = false
    var format: ExportFormat = .csv
}

@MainActor
final class SubscriptionExporter {
    static let shared = SubscriptionExporter()

    private init() {}

    func export(subscriptions: [Subscription], options: ExportOptions = ExportOptions()) -> URL? {
        let filtered = subscriptions.filter { sub in
            if sub.status == .paused && !options.includePaused { return false }
            if sub.status == .cancelled && !options.includeCancelled { return false }
            return true
        }

        switch options.format {
        case .csv:
            return exportCSV(subscriptions: filtered)
        case .pdf:
            return exportPDF(subscriptions: filtered)
        case .json:
            return exportJSON(subscriptions: filtered)
        }
    }

    // MARK: - CSV

    private func exportCSV(subscriptions: [Subscription]) -> URL? {
        var csv = "Name,Category,Amount,Currency,Frequency,Status,Monthly Cost,Annual Cost,Next Billing Date,Created At\n"

        let formatter = DateFormatter()
        formatter.dateStyle = .short

        for sub in subscriptions {
            let nextDate = sub.nextBillingDate.map { formatter.string(from: $0) } ?? "N/A"
            let createdDate = formatter.string(from: sub.createdAt)
            csv += "\(escapeCSV(sub.name)),\(escapeCSV(sub.category ?? "")),\(sub.amount),\(sub.currency),\(sub.billingFrequency.displayName),\(sub.status.displayName),\(sub.monthlyCost),\(sub.annualCost),\(nextDate),\(createdDate)\n"
        }

        return writeToFile(content: csv, extension: "csv")
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    // MARK: - JSON

    private func exportJSON(subscriptions: [Subscription]) -> URL? {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            guard let json = String(data: data, encoding: .utf8) else { return nil }
            return writeToFile(content: json, extension: "json")
        } catch {
            os_log("JSON export failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            return nil
        }
    }

    // MARK: - PDF

    private func exportPDF(subscriptions: [Subscription]) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Pausely",
            kCGPDFContextAuthor: "Pausely Subscription Tracker",
            kCGPDFContextTitle: "Subscription Report"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)

        let totalMonthly = subscriptions.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.monthlyCost }
        let totalAnnual = subscriptions.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.annualCost }

        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40

            // Title
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let title = NSAttributedString(string: "Subscription Report", attributes: titleAttr)
            title.draw(at: CGPoint(x: 40, y: y))
            y += 50

            // Date
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
            NSAttributedString(string: "Generated: \(dateStr)", attributes: dateAttr).draw(at: CGPoint(x: 40, y: y))
            y += 40

            // Summary
            let summaryAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            NSAttributedString(string: "Summary", attributes: summaryAttr).draw(at: CGPoint(x: 40, y: y))
            y += 25

            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            NSAttributedString(string: "Active Subscriptions: \(subscriptions.filter { $0.isActive }.count)", attributes: bodyAttr).draw(at: CGPoint(x: 40, y: y))
            y += 20
            NSAttributedString(string: "Total Monthly Spend: $\(totalMonthly)", attributes: bodyAttr).draw(at: CGPoint(x: 40, y: y))
            y += 20
            NSAttributedString(string: "Total Annual Spend: $\(totalAnnual)", attributes: bodyAttr).draw(at: CGPoint(x: 40, y: y))
            y += 40

            // Table header
            drawTableRow(context: context, y: y, columns: ["Name", "Category", "Amount", "Frequency", "Status"], isHeader: true)
            y += 30

            // Rows
            for sub in subscriptions {
                if y > pageHeight - 60 {
                    context.beginPage()
                    y = 40
                    drawTableRow(context: context, y: y, columns: ["Name", "Category", "Amount", "Frequency", "Status"], isHeader: true)
                    y += 30
                }
                drawTableRow(context: context, y: y, columns: [
                    sub.name,
                    sub.category ?? "—",
                    "\(sub.currency) \(sub.amount)",
                    sub.billingFrequency.shortDisplay,
                    sub.status.displayName
                ], isHeader: false)
                y += 24
            }
        }

        return writeDataToFile(data: data, extension: "pdf")
    }

    private func drawTableRow(context: UIGraphicsPDFRendererContext, y: CGFloat, columns: [String], isHeader: Bool) {
        let colWidths: [CGFloat] = [180, 100, 100, 80, 80]
        let xPositions: [CGFloat] = [40, 220, 320, 420, 500]
        let font = isHeader ? UIFont.systemFont(ofSize: 11, weight: .bold) : UIFont.systemFont(ofSize: 10)
        let color = isHeader ? UIColor.white : UIColor.label

        if isHeader {
            UIColor.darkGray.setFill()
            context.cgContext.fill(CGRect(x: 35, y: y - 4, width: 540, height: 24))
        }

        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        for (i, text) in columns.enumerated() {
            let rect = CGRect(x: xPositions[i], y: y, width: colWidths[i], height: 20)
            let str = NSAttributedString(string: text, attributes: attr)
            str.draw(in: rect)
        }
    }

    // MARK: - Helpers

    private func writeToFile(content: String, extension ext: String) -> URL? {
        let filename = "pausely_export_\(Int(Date().timeIntervalSince1970)).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            os_log("Export write failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            return nil
        }
    }

    private func writeDataToFile(data: Data, extension ext: String) -> URL? {
        let filename = "pausely_export_\(Int(Date().timeIntervalSince1970)).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            os_log("Export write failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            return nil
        }
    }
}
