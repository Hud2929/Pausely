//
//  WasteScoreCard.swift
//  Pausely
//
//  Waste Score Visualization
//

import SwiftUI

struct WasteScoreCard: View {
    let subscription: Subscription
    let onTap: () -> Void
    
    private var score: Double {
        guard let wasteScore = subscription.wasteScore else { return 0 }
        return Double(truncating: wasteScore as NSNumber)
    }
    
    private var wasteLevel: WasteLevel {
        subscription.wasteLevel
    }
    
    private var recommendation: WasteRecommendation {
        subscription.wasteRecommendation
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: STSpacing.base) {
                // Header
                HStack {
                    Text("WASTE SCORE")
                        .font(STFont.labelSmall)
                        .foregroundStyle(Color.obsidianTextTertiary)
                    
                    Spacer()
                    
                    if subscription.wasteScore == nil {
                        Text("TRACK USAGE")
                            .font(STFont.labelSmall)
                            .foregroundStyle(Color.accentMint)
                    }
                }
                
                // Score gauge
                HStack(spacing: STSpacing.lg) {
                    // Circular gauge
                    ZStack {
                        Circle()
                            .stroke(Color.obsidianElevated, lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: score)
                            .stroke(
                                wasteLevel.color,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.0), value: score)
                        
                        VStack(spacing: 0) {
                            if let _ = subscription.wasteScore {
                                Text("\(Int(score * 100))")
                                    .font(STFont.headlineMedium)
                                    .foregroundStyle(Color.obsidianText)
                            } else {
                                Image(systemName: "questionmark")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.obsidianTextSecondary)
                            }
                        }
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: STSpacing.xs) {
                        if let costPerHour = subscription.costPerHour {
                            HStack {
                                Text("$")
                                    .font(STFont.bodySmall)
                                    .foregroundStyle(Color.obsidianTextSecondary)
                                Text(String(format: "%.2f", Double(truncating: costPerHour as NSNumber)))
                                    .font(STFont.monoMedium)
                                    .foregroundStyle(Color.obsidianText)
                                Text("/hour")
                                    .font(STFont.bodySmall)
                                    .foregroundStyle(Color.obsidianTextSecondary)
                            }
                        }
                        
                        if subscription.monthlyUsageMinutes > 0 {
                            let hours = subscription.monthlyUsageMinutes / 60
                            let mins = subscription.monthlyUsageMinutes % 60
                            Text("\(hours)h \(mins)m used this month")
                                .font(STFont.bodySmall)
                                .foregroundStyle(Color.obsidianTextSecondary)
                        }
                        
                        // Recommendation badge
                        Text(recommendation.title)
                            .font(STFont.labelSmall)
                            .foregroundStyle(wasteLevel.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(wasteLevel.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.lg)
                    .stroke(Color.obsidianBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overall Waste Score Card
struct OverallWasteScoreCard: View {
    let subscriptions: [Subscription]
    let onTap: () -> Void
    
    private var averageScore: Double {
        let scores = subscriptions.compactMap { $0.wasteScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0) { $0 + Double(truncating: $1 as NSNumber) } / Double(scores.count)
    }
    
    private var highWasteSubscriptions: [Subscription] {
        subscriptions.filter { sub in
            guard let score = sub.wasteScore else { return false }
            return Double(truncating: score as NSNumber) < 0.4
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: STSpacing.base) {
                // Header
                HStack {
                    Text("SPENDING EFFICIENCY")
                        .font(STFont.labelSmall)
                        .foregroundStyle(Color.obsidianTextTertiary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
                
                HStack(spacing: STSpacing.lg) {
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(Color.obsidianElevated, lineWidth: 10)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: averageScore)
                            .stroke(
                                scoreColor,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.0), value: averageScore)
                        
                        VStack(spacing: 0) {
                            Text("\(Int(averageScore * 100))")
                                .font(STFont.displaySmall)
                                .foregroundStyle(Color.obsidianText)
                            Text("/100")
                                .font(STFont.labelSmall)
                                .foregroundStyle(Color.obsidianTextTertiary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: STSpacing.xs) {
                        Text(scoreLabel)
                            .font(STFont.headlineSmall)
                            .foregroundStyle(scoreColor)
                        
                        if !highWasteSubscriptions.isEmpty {
                            Text("\(highWasteSubscriptions.count) subscriptions wasting money")
                                .font(STFont.bodySmall)
                                .foregroundStyle(Color.obsidianTextSecondary)
                        } else {
                            Text("Great job! All subscriptions are well-used.")
                                .font(STFont.bodySmall)
                                .foregroundStyle(Color.semanticSuccess)
                        }
                    }
                    
                    Spacer()
                }
                
                // High waste list preview
                if !highWasteSubscriptions.isEmpty {
                    Divider()
                        .background(Color.obsidianBorder)
                    
                    VStack(spacing: STSpacing.xs) {
                        ForEach(highWasteSubscriptions.prefix(3)) { sub in
                            HStack {
                                Text(sub.name)
                                    .font(STFont.bodyMedium)
                                    .foregroundStyle(Color.obsidianText)
                                
                                Spacer()
                                
                                if let score = sub.wasteScore {
                                    Text("\(Int(Double(truncating: score as NSNumber) * 100))%")
                                        .font(STFont.labelMedium)
                                        .foregroundStyle(Color.semanticDestructive)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: STRadius.lg)
                    .stroke(Color.obsidianBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var scoreColor: Color {
        switch averageScore {
        case 0.0..<0.3:   return .semanticDestructive
        case 0.3..<0.5:   return .semanticWarning
        case 0.5..<0.7:   return Color(hex: "#F59E0B")
        case 0.7..<0.9:   return .semanticSuccess.opacity(0.7)
        default:          return .semanticSuccess
        }
    }
    
    private var scoreLabel: String {
        switch averageScore {
        case 0.0..<0.3:   return "Needs Attention"
        case 0.3..<0.5:   return "Room to Improve"
        case 0.5..<0.7:   return "Getting There"
        case 0.7..<0.9:   return "Well Optimized"
        default:          return "Excellent!"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        WasteScoreCard(subscription: Subscription(
            name: "Netflix",
            price: 15.99,
            category: "Entertainment"
        )) {}
        
        OverallWasteScoreCard(subscriptions: []) {}
    }
    .padding()
    .background(Color.obsidianBlack)
}
