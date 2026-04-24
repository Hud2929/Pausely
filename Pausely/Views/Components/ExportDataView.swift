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
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDescription)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                Section("Include") {
                    Toggle("Paused Subscriptions", isOn: $includePaused)
                    Toggle("Cancelled Subscriptions", isOn: $includeCancelled)
                }

                Section {
                    HStack {
                        Text("Subscriptions to Export")
                        Spacer()
                        Text("\(filteredCount)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if filteredCount == 0 {
                        Text("No subscriptions match your filters")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        performExport()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export \(filteredCount) Subscriptions")
                            }
                            Spacer()
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .background(filteredCount > 0 ? Color.luxuryPurple : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(filteredCount == 0 || isExporting)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if let error = exportError {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.semanticDestructive)
                            Text(error)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.semanticDestructive)
                        }
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private var formatDescription: String {
        switch selectedFormat {
        case .csv:
            return "Spreadsheet format compatible with Excel, Numbers, and Google Sheets. Great for tax preparation."
        case .pdf:
            return "Formatted report with summary and table. Best for sharing or printing."
        case .json:
            return "Machine-readable format for backups or importing into other tools."
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
                    exportError = "Failed to generate export file. Please try again."
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
