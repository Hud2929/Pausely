//
//  PauselyDeviceActivityReport.swift
//  Pausely
//
//  REVOLUTIONARY Screen Time Report
//  Real-time visualization of subscription app usage
//

import DeviceActivity
import SwiftUI

// MARK: - Device Activity Report
// This is the view that displays Screen Time data

struct PauselyDeviceActivityReport: DeviceActivityReportScene {
    
    // Define the context our report will receive
    let context: DeviceActivityReport.Context = .pauselySubscriptionUsage
    
    // The body defines what UI to show
    var body: some DeviceActivityReportScene {
        DeviceActivityReportScene(context: context) { context in
            SubscriptionUsageReportView(context: context)
        }
    }
}

// MARK: - Report Context
// Custom context for our subscription tracking

extension DeviceActivityReport.Context {
    static let pauselySubscriptionUsage = Self("pauselySubscriptionUsage")
}

// MARK: - Report View
// The actual UI shown in the report

struct SubscriptionUsageReportView: View {
    let context: DeviceActivityReport.Context
    @State private var usageData: [AppUsageReportData] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Subscription Usage")
                    .font(.title2.bold())
                
                Spacer()
            }
            .padding(.horizontal)
            
            if isLoading {
                LoadingView()
            } else if usageData.isEmpty {
                EmptyUsageView()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Total usage summary
                        TotalUsageCard(data: usageData)
                        
                        // Individual app usage
                        ForEach(usageData.sorted(by: { $0.minutesUsed > $1.minutesUsed })) { app in
                            AppUsageRow(data: app)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadUsageData()
        }
    }
    
    private func loadUsageData() async {
        // This loads data from the DeviceActivity framework
        // In real implementation, this comes from the monitoring extension
        
        // For now, simulate with demo data structure
        // The actual implementation would read from context.data
        
        isLoading = false
    }
}

// MARK: - Report Data Models

struct AppUsageReportData: Identifiable {
    let id = UUID()
    let bundleId: String
    let appName: String
    let minutesUsed: Int
    let launches: Int
    let category: String
    let icon: String
    
    var hoursUsed: Double {
        Double(minutesUsed) / 60.0
    }
    
    var formattedTime: String {
        if minutesUsed < 60 {
            return "\(minutesUsed)m"
        } else {
            let hours = minutesUsed / 60
            let mins = minutesUsed % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - UI Components

struct TotalUsageCard: View {
    let data: [AppUsageReportData]
    
    var totalMinutes: Int {
        data.reduce(0) { $0 + $1.minutesUsed }
    }
    
    var totalLaunches: Int {
        data.reduce(0) { $0 + $1.launches }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                StatView(
                    value: formatMinutes(totalMinutes),
                    label: "Total Time",
                    icon: "clock.fill",
                    color: .blue
                )
                
                Divider()
                    .frame(height: 40)
                
                StatView(
                    value: "\(totalLaunches)",
                    label: "Opens",
                    icon: "arrow.up.forward.app.fill",
                    color: .green
                )
                
                Divider()
                    .frame(height: 40)
                
                StatView(
                    value: "\(data.count)",
                    label: "Apps",
                    icon: "app.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            return "\(hours)h"
        }
    }
}

struct AppUsageRow: View {
    let data: AppUsageReportData
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: data.icon)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }
            
            // App info
            VStack(alignment: .leading, spacing: 4) {
                Text(data.appName)
                    .font(.system(size: 16, weight: .semibold))
                
                Text("\(data.launches) opens")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Time used
            VStack(alignment: .trailing, spacing: 4) {
                Text(data.formattedTime)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(categoryColor)
                            .frame(width: geo.size.width * min(CGFloat(data.minutesUsed) / 120.0, 1.0), height: 4)
                    }
                }
                .frame(width: 60, height: 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var categoryColor: Color {
        switch data.category {
        case "Entertainment": return .purple
        case "Productivity": return .blue
        case "Health": return .green
        case "Education": return .orange
        case "Utilities": return .gray
        default: return .blue
        }
    }
}

struct StatView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Screen Time data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
}

struct EmptyUsageView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Usage Data Yet")
                .font(.headline)
            
            Text("Usage data will appear here once Screen Time monitoring is active")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - SwiftUI Preview

#Preview {
    SubscriptionUsageReportView(context: .pauselySubscriptionUsage)
}
