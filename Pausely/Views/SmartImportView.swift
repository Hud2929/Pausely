import SwiftUI

/// Smart Import View
/// Import subscriptions from bank statements and CSV files
struct SmartImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var importManager = SmartImportManager.shared
    @State private var showingCSVInput = false
    @State private var csvText = ""
    @State private var selectedResults: [SmartImportManager.ImportResult] = []
    @State private var showingBulkAdd = false
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                            .padding(.horizontal, 20)
                        
                        if importManager.isProcessing {
                            processingSection
                                .padding(.horizontal, 20)
                        } else if let results = importManager.lastImportResults {
                            resultsSection(results: results)
                                .padding(.horizontal, 20)
                        } else {
                            importOptionsSection
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingCSVInput) {
                CSVImportSheet(csvText: $csvText) { text in
                    Task {
                        let result = await importManager.importFromBankCSV(csvData: text)
                        selectedResults = [result]
                        await importManager.processImports(from: selectedResults)
                    }
                }
            }
            .sheet(isPresented: $showingBulkAdd) {
                BulkAddView()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color.luxuryPurple)
            }
            
            VStack(spacing: 8) {
                Text("Smart Import")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Import your subscriptions from multiple sources")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var importOptionsSection: some View {
        VStack(spacing: 16) {
            ImportOptionCard(
                icon: "plus.circle.fill",
                title: "Manual Bulk Add",
                description: "Quickly add multiple subscriptions at once",
                color: Color.luxuryPurple
            ) {
                showingBulkAdd = true
            }

            ImportOptionCard(
                icon: "doc.text",
                title: "Import from CSV",
                description: "Import subscriptions from a CSV file",
                color: Color.luxuryTeal
            ) {
                showingCSVInput = true
            }
        }
    }
    
    private var processingSection: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .stroke(Color.luxuryPurple.opacity(0.2), lineWidth: 8)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: importManager.importProgress)
                    .stroke(
                        Color.luxuryPurple,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: importManager.importProgress)
                
                VStack {
                    Text("\(Int(importManager.importProgress * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 180)
            
            VStack(spacing: 12) {
                Text(importManager.importPhase)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                HStack(spacing: 24) {
                    ImportStatItem(
                        value: "\(importManager.importedCount)",
                        label: "Imported",
                        color: .green
                    )
                    
                    ImportStatItem(
                        value: "\(importManager.duplicatesFound)",
                        label: "Duplicates",
                        color: .orange
                    )
                }
            }
            
            Button(action: { importManager.cancelImport() }) {
                Text("Cancel")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(16)
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .cornerRadius(24)
    }
    
    private func resultsSection(results: SmartImportManager.ImportResults) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                VStack(spacing: 8) {
                    Text("Import Complete!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Found \(results.imported) subscriptions worth \(formatCurrency(results.totalValue))")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            VStack(spacing: 12) {
                ResultRow(
                    icon: "checkmark.circle.fill",
                    title: "Successfully Imported",
                    value: "\(results.imported)",
                    color: .green
                )
                
                if results.duplicates > 0 {
                    ResultRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Duplicates Skipped",
                        value: "\(results.duplicates)",
                        color: .orange
                    )
                }
                
                if results.failed > 0 {
                    ResultRow(
                        icon: "xmark.circle.fill",
                        title: "Failed",
                        value: "\(results.failed)",
                        color: .red
                    )
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.luxuryGold)
                    .cornerRadius(16)
            }
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

struct ImportOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var isPro = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if isPro {
                            Text("PRO")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.luxuryGold)
                                .foregroundColor(.black)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CSVImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var csvText: String
    let onImport: (String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Paste your bank statement CSV")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextEditor(text: $csvText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .frame(maxHeight: 300)
                    
                    Text("Expected format: Date, Description, Amount")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Button(action: {
                        onImport(csvText)
                        dismiss()
                    }) {
                        Text("Import \(csvText.isEmpty ? 0 : csvText.components(separatedBy: .newlines).count - 1) Transactions")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(csvText.isEmpty ? Color.gray : Color.luxuryTeal)
                            .cornerRadius(16)
                    }
                    .disabled(csvText.isEmpty)
                }
                .padding(20)
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct ImportStatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct ResultRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
    }
}
