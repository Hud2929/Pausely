//
//  ExportDataView.swift
//  Pausely
//
//  Export subscription data for taxes, sharing, or backup
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportDataView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .csv
    @State private var includePaused = true
    @State private var includeCancelled = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var exportError: String?

    var filteredCount: Int {
        store.subscriptions.filter { sub in
            if sub.status == .paused && !includePaused { return false }
            if sub.status == .cancelled && !includeCancelled { return false }
            return true
        }.count
    }

    var body: some View {
        SettingsPage(title: "Export your list", detail: "A file of your subscriptions that you can save or send anywhere.") {
            SettingsSection(title: "Format") {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    ChoiceRow(title: format.rawValue, detail: description(of: format), isChosen: selectedFormat == format) {
                        selectedFormat = format
                    }
                    .accessibilityIdentifier("exportFormat-\(format.rawValue)")
                }
            }

            SettingsSection(title: "Include") {
                SettingsRow(title: L10n.string("Paused subscriptions")) {
                    Toggle("", isOn: $includePaused).labelsHidden().tint(Color.inkTextMuted)
                        .accessibilityLabel(Text("Paused subscriptions"))
                }
                SettingsRow(title: L10n.string("Cancelled subscriptions")) {
                    Toggle("", isOn: $includeCancelled).labelsHidden().tint(Color.inkTextMuted)
                        .accessibilityLabel(Text("Cancelled subscriptions"))
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                if let error = exportError {
                    Label {
                        Text(verbatim: error).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.due)
                }
                if filteredCount == 0 {
                    Text("Nothing on your list matches these choices.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                }
                Button(action: performExport) {
                    if isExporting { ProgressView().tint(Color.paperInk) } else { Text("Export \(filteredCount) subscriptions") }
                }
                .buttonStyle(.ink)
                .disabled(filteredCount == 0 || isExporting)
                .accessibilityIdentifier("exportButton")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
    }

    /// What each file is, said plainly.
    private func description(of format: ExportFormat) -> String {
        switch format {
        case .csv: return L10n.string("A spreadsheet file. Opens in Numbers, Excel and Google Sheets.")
        case .pdf: return L10n.string("A page with a summary and a table, for printing or sharing.")
        case .json: return L10n.string("Plain data, for a backup or another tool.")
        }
    }

    private func performExport() {
        guard filteredCount > 0 else { return }
        isExporting = true
        exportError = nil

        let options = ExportOptions(
            includePaused: includePaused,
            includeCancelled: includeCancelled,
            format: selectedFormat
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let url = SubscriptionExporter.shared.export(subscriptions: store.subscriptions, options: options)

            DispatchQueue.main.async {
                isExporting = false
                if let url = url {
                    exportURL = url
                    showingShareSheet = true
                } else {
                    exportError = L10n.string("The file couldn't be made. Try again.")
                }
            }
        }
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let activities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
