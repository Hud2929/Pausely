import SwiftUI

@MainActor
struct BillingHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var transactions: [BillingTransaction] = []
    @State private var selectedFilter: TransactionFilter = .all
    @State private var isLoading = true
    @State private var showingPaywall = false
    
    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case payments = "Payments"
        case refunds = "Refunds"
        case credits = "Credits"
    }
    
    var filteredTransactions: [BillingTransaction] {
        switch selectedFilter {
        case .all: return transactions
        case .payments: return transactions.filter { $0.type == .payment }
        case .refunds: return transactions.filter { $0.type == .refund }
        case .credits: return transactions.filter { $0.type == .credit }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.luxuryGold)
                    
                    Text("Billing History")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    if !transactions.isEmpty {
                        // Total spent (only show if has transactions)
                        VStack(spacing: 4) {
                            Text("Total Spent")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text("$\(String(format: "%.2f", calculateTotal()))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 20)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.top, 60)
                } else if transactions.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("No Billing History")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Your transactions will appear here once you make a purchase or receive credits.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: { showingPaywall = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Upgrade to Pro")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.luxuryGold)
                            )
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                    }
                    .padding(.top, 60)
                } else {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TransactionFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.rawValue,
                                    isSelected: selectedFilter == filter,
                                    action: { selectedFilter = filter }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Transactions List
                    VStack(spacing: 12) {
                        ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { month in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(month)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.leading, 4)
                                
                                VStack(spacing: 8) {
                                    ForEach(groupedTransactions[month] ?? []) { transaction in
                                        TransactionRow(transaction: transaction)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Export Button
                    Button(action: { exportReceipts() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Export All Receipts")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color.luxuryGold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glass(intensity: 0.08, tint: Color.luxuryGold)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Billing History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: 0)
        }
        .onAppear {
            loadTransactions()
        }
    }
    
    private var groupedTransactions: [String: [BillingTransaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: transaction.date)
        }
    }
    
    private func calculateTotal() -> Double {
        transactions
            .filter { $0.type == .payment }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func loadTransactions() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // In production, load from backend
            // For new users, this starts empty
            transactions = [] // Start empty for new users
            isLoading = false
        }
    }
    
    private func exportReceipts() {
        // Export functionality
    }
}

struct BillingTransaction: Identifiable {
    let id: String
    let title: String
    let description: String
    let amount: Double
    let date: Date
    let type: TransactionType
    let status: TransactionStatus
    let paymentMethod: String
    let icon: String
    
    enum TransactionType {
        case payment, refund, credit
    }
    
    enum TransactionStatus {
        case completed, pending, failed
    }
}

struct TransactionRow: View {
    let transaction: BillingTransaction
    @State private var showingReceipt = false
    
    var body: some View {
        Button(action: { showingReceipt = true }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(backgroundColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: transaction.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(backgroundColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(transaction.description)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(transaction.paymentMethod)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatAmount(transaction.amount))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(amountColor)
                    
                    Text(formatDate(transaction.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    TransactionStatusBadge(status: transaction.status)
                        .padding(.top, 2)
                }
            }
            .padding()
            .glass(intensity: 0.08, tint: .white)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingReceipt) {
            ReceiptView(transaction: transaction)
        }
    }
    
    private var backgroundColor: Color {
        switch transaction.type {
        case .payment: return Color.luxuryPurple
        case .refund: return Color.orange
        case .credit: return Color.luxuryGold
        }
    }
    
    private var amountColor: Color {
        if transaction.amount < 0 {
            return Color.luxuryGold
        }
        return .white
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount < 0 {
            return "-$\(String(format: "%.2f", abs(amount)))"
        }
        return "+$\(String(format: "%.2f", amount))"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct TransactionStatusBadge: View {
    let status: BillingTransaction.TransactionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
    }
    
    private var statusColor: Color {
        switch status {
        case .completed: return Color.luxuryGold
        case .pending: return Color.orange
        case .failed: return Color.red
        }
    }
    
    private var statusText: String {
        switch status {
        case .completed: return "Done"
        case .pending: return "Pending"
        case .failed: return "Failed"
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.luxuryPurple : .white.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: BillingTransaction
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Receipt Header
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.luxuryGold)
                        
                        Text("Receipt")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text(transaction.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    // Amount
                    VStack(spacing: 8) {
                        Text("$\(String(format: "%.2f", abs(transaction.amount)))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Paid on \(formatFullDate(transaction.date))")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    // Details
                    VStack(spacing: 16) {
                        ReceiptRow(label: "Transaction ID", value: "#PAU-\(transaction.id)")
                        ReceiptRow(label: "Description", value: transaction.description)
                        ReceiptRow(label: "Payment Method", value: transaction.paymentMethod)
                        ReceiptRow(label: "Status", value: statusText(transaction.status), valueColor: statusColor(transaction.status))
                    }
                    .padding()
                    .glass(intensity: 0.08, tint: .white)
                    .padding(.horizontal, 20)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: { shareReceipt() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Share Receipt")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.luxuryPurple)
                            )
                        }
                        
                        Button(action: { downloadPDF() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Download PDF")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color.luxuryGold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glass(intensity: 0.08, tint: Color.luxuryGold)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.vertical, 32)
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func statusText(_ status: BillingTransaction.TransactionStatus) -> String {
        switch status {
        case .completed: return "Completed"
        case .pending: return "Pending"
        case .failed: return "Failed"
        }
    }
    
    private func statusColor(_ status: BillingTransaction.TransactionStatus) -> Color {
        switch status {
        case .completed: return Color.luxuryGold
        case .pending: return Color.orange
        case .failed: return Color.red
        }
    }
    
    private func shareReceipt() {
        // Share functionality
    }
    
    private func downloadPDF() {
        // PDF generation
    }
}

struct ReceiptRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct BillingHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        BillingHistoryView()
            .background(Color.black)
    }
}
