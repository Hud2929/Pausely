//
//  ScreenTimeConsentView.swift
//  Pausely
//
//  Screen Time API Authorization Request UI
//

import SwiftUI

struct ScreenTimeConsentView: View {
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    headerView
                        .padding(.top, 20)
                    
                    benefitsView
                    
                    privacyView
                    
                    Spacer()
                    
                    actionButtons
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
        .alert("Authorization Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Usage Insights")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Connect Screen Time for smarter subscription tracking")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var benefitsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What You'll Get")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            ScreenTimeBenefitRow(
                icon: "flame.fill",
                iconColor: .orange,
                title: "Track App Usage",
                description: "See how much time you spend in each subscription app"
            )
            
            ScreenTimeBenefitRow(
                icon: "lightbulb.fill",
                iconColor: .yellow,
                title: "Smart Suggestions",
                description: "Get recommendations based on your actual usage patterns"
            )
            
            ScreenTimeBenefitRow(
                icon: "dollarsign.circle.fill",
                iconColor: .green,
                title: "Find Savings",
                description: "Identify unused subscriptions to potentially cancel"
            )
            
            ScreenTimeBenefitRow(
                icon: "chart.pie.fill",
                iconColor: .cyan,
                title: "Visual Reports",
                description: "Beautiful charts showing your subscription ROI"
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var privacyView: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Data Stays Private")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Usage data never leaves your device. We only store insights to help you save money.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                requestAuthorization()
            } label: {
                HStack(spacing: 8) {
                    if screenTimeManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "link.circle.fill")
                    }
                    
                    Text(screenTimeManager.isLoading ? "Connecting..." : "Connect Screen Time")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(screenTimeManager.isLoading)
            .accessibilityHint(screenTimeManager.isLoading ? "Please wait, connecting to Screen Time" : "")

            Button {
                dismiss()
            } label: {
                Text("Not Now")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private func requestAuthorization() {
        Task {
            do {
                try await screenTimeManager.requestAuthorization()
                dismiss()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Screen Time Benefit Row

struct ScreenTimeBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}
