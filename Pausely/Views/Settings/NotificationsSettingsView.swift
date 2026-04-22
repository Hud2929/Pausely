import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var renewalAlerts = true
    @State private var priceChangeAlerts = true
    @State private var usageReminders = false
    @State private var weeklyReports = true
    @State private var trialEndingAlerts = true
    @State private var savingsOpportunities = true
    
    var body: some View {
        ZStack {
            HolographicBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(CyberColors.cyan)
                                .accessibilityLabel("Back")
                        }
                        
                        Spacer()
                        
                        Text("Notifications")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .stroke(CyberColors.cyan, lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .shadow(color: CyberColors.cyan.opacity(0.5), radius: 20, x: 0, y: 0)
                        
                        Image(systemName: "bell.badge.fill")
                            .font(.title)
                            .foregroundColor(CyberColors.cyan)
                    }
                    .padding(.top, 20)
                    
                    // Settings List
                    VStack(spacing: 16) {
                        Text("ALERTS")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        FuturisticGlassCard(glowColor: CyberColors.cyan) {
                            VStack(spacing: 0) {
                                NotificationToggleRow(
                                    icon: "calendar.badge.exclamationmark",
                                    title: "Renewal Alerts",
                                    subtitle: "Get notified before subscriptions renew",
                                    isOn: $renewalAlerts,
                                    glowColor: CyberColors.cyan
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                NotificationToggleRow(
                                    icon: "tag.fill",
                                    title: "Price Change Alerts",
                                    subtitle: "Notify when subscription prices change",
                                    isOn: $priceChangeAlerts,
                                    glowColor: CyberColors.magenta
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                NotificationToggleRow(
                                    icon: "clock.fill",
                                    title: "Trial Ending Alerts",
                                    subtitle: "Remind before free trials expire",
                                    isOn: $trialEndingAlerts,
                                    glowColor: CyberColors.lime
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    VStack(spacing: 16) {
                        Text("INSIGHTS")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        FuturisticGlassCard(glowColor: CyberColors.magenta) {
                            VStack(spacing: 0) {
                                NotificationToggleRow(
                                    icon: "chart.pie.fill",
                                    title: "Weekly Reports",
                                    subtitle: "Summary of your spending each week",
                                    isOn: $weeklyReports,
                                    glowColor: CyberColors.magenta
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                NotificationToggleRow(
                                    icon: "dollarsign.circle.fill",
                                    title: "Savings Opportunities",
                                    subtitle: "Alert when we find ways to save",
                                    isOn: $savingsOpportunities,
                                    glowColor: CyberColors.hotPink
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                NotificationToggleRow(
                                    icon: "eye.fill",
                                    title: "Usage Reminders",
                                    subtitle: "Track subscriptions you don't use",
                                    isOn: $usageReminders,
                                    glowColor: CyberColors.electric
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
}

struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let glowColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(glowColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(glowColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            CyberToggle(isOn: $isOn, glowColor: glowColor)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    NotificationsSettingsView()
}
