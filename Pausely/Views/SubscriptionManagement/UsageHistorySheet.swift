import SwiftUI

struct UsageHistorySheet: View {
    let subscriptionName: String
    @Environment(\.dismiss) private var dismiss
    @State private var manager = ScreenTimeManager.shared
    @State private var history: [AppUsageStats] = []

    var body: some View {
        let _ = { history = manager.getUsageHistory(for: subscriptionName) }()
        NavigationStack {
            List {
                if history.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)

                            Text("No Usage History Yet")
                                .font(.headline)

                            Text("Usage data will appear here as you track your time with \(subscriptionName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section(header: Text("Past 6 Months")) {
                        ForEach(history, id: \.id) { stats in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stats.formattedDate)
                                        .font(.headline)

                                    HStack(spacing: 4) {
                                        Image(systemName: stats.source.icon)
                                            .font(.caption)
                                        Text(stats.source.description)
                                            .font(.caption)
                                        EstimateBadge(isEstimated: stats.source == .screenTime)
                                    }
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(stats.formattedUsage)
                                    .font(.title3.bold())
                                    .foregroundColor(stats.totalMinutes < 60 ? .red : .primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section(footer: Text("Note: Screen Time data is estimated from session counts. Manual entries are exact values you provided.")) {
                        HStack {
                            Text("Total Tracked Time")
                            Spacer()
                            Text(manager.formatMinutes(history.reduce(0) { $0 + $1.totalMinutes }))
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .navigationTitle("Usage History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
