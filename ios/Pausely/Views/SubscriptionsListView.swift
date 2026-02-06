import SwiftUI

struct SubscriptionsListView: View {
    @StateObject private var store = SubscriptionStore.shared
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(store.subscriptions) { subscription in
                    SubscriptionDetailRow(subscription: subscription)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Subscriptions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSubscriptionView()
            }
            .refreshable {
                await store.fetchSubscriptions()
            }
        }
    }
}

struct SubscriptionDetailRow: View {
    let subscription: Subscription
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(subscription.name.prefix(1)))
                        .font(.headline)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    StatusBadge(status: subscription.status)
                    
                    if subscription.canPause {
                        Image(systemName: "pause.circle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                if let nextDate = subscription.nextBillingDate {
                    Text("Next: \(nextDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.displayAmount)
                    .font(.headline)
                
                Text("/\(subscription.billingFrequency.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: SubscriptionStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    var statusColor: Color {
        switch status {
        case .active: return .green
        case .paused: return .orange
        case .cancelled: return .red
        case .trial: return .blue
        }
    }
}

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: BillingFrequency = .monthly
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section("Billing") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(BillingFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}
