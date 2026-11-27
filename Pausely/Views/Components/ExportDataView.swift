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

    private struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var selectedFormat: ExportFormat = .csv
    @State private var includeCancelled = false
    @State private var isExporting = false
    @State private var exportedFile: ExportFile?
    @State private var exportError: String?

    var filteredCount: Int {
        store.subscriptions.filter { includeCancelled || $0.status != .cancelled }.count
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
                SettingsRow(title: L10n.string("Cancelled subscriptions")) {
                    Toggle(isOn: $includeCancelled) { EmptyView() }.labelsHidden().tint(Color.inkTextMuted)
                }
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 12) {
                if let error = exportError {
                    ProblemLine(message: error, identifier: "exportProblem")
                }
                if filteredCount == 0 {
                    Text("Nothing on your list matches these choices.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                }
                Button(action: performExport) {
                    if isExporting {
                        ProgressView().tint(Color.paperInk)
                    } else if filteredCount == 0 {
                        // In words: the button read "Export 0 subscriptions".
                        Text("Nothing to export")
                    } else {
                        Text("Export \(filteredCount) subscriptions")
                    }
                }
                .buttonStyle(.ink)
                .disabled(filteredCount == 0 || isExporting)
                .accessibilityIdentifier("exportButton")
            }
        }
        .sheet(item: $exportedFile) { file in
            ShareSheet(items: [file.url])
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

        let options = ExportOptions(includeCancelled: includeCancelled, format: selectedFormat)

        // On the main thread, where the list, the history and the Pause Plan live: the export reads all
        // three. It is a few hundred rows at most; the pause lets the button show that it is working.
        Task { @MainActor in
            await Task.yield()
            let url = SubscriptionExporter.shared.export(subscriptions: store.subscriptions, options: options)
            isExporting = false
            if let url {
                exportedFile = ExportFile(url: url)
            } else {
                exportError = L10n.string("The file couldn't be made. Try again.")
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
