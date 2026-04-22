//
//  AutoDetectView.swift
//  Pausely
//
//  Apple subscription auto-detection using StoreKit 2
//

import SwiftUI
import StoreKit

// MARK: - Auto Detect View
struct AutoDetectView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appleScanner = AppleSubscriptionScanner.shared
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared

    @State private var detectedSubscriptions: [AppleDetectedSubscription] = []
    @State private var isScanning = false
    @State private var scanComplete = false
    @State private var errorMessage: String?
    @State private var selectedForImport: Set<UUID> = []
    @State private var showError = false

    var body: some View {
        NavigationView {
            ZStack {
                PremiumBackground()

                if isScanning {
                    scanningView
                } else if scanComplete && detectedSubscriptions.isEmpty {
                    noSubscriptionsView
                } else if scanComplete {
                    resultsView
                } else if !detectedSubscriptions.isEmpty {
                    reviewView
                } else {
                    startView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Start View
    private var startView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "apple.logo")
                    .font(.system(size: 50))
                    .foregroundColor(Color.luxuryPurple)
            }

            VStack(spacing: 12) {
                Text("Apple Subscriptions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Scan your Apple ID for active subscriptions")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Info cards
            VStack(alignment: .leading, spacing: 16) {
                InfoRow(icon: "checkmark.shield", text: "Uses StoreKit 2 (no receipt parsing)")
                InfoRow(icon: "lock.shield", text: "All data stays on your device")
                InfoRow(icon: "creditcard", text: "Reads active subscriptions only")
            }
            .padding(24)
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            .padding(.horizontal, 20)

            Spacer()

            // Scan button
            Button(action: runDetection) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                    Text("Scan Apple ID")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.luxuryPurple)
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Scanning View
    private var scanningView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.luxuryPurple.opacity(0.2), lineWidth: 8)
                    .frame(width: 140, height: 140)

                ProgressView()
                    .scaleEffect(2)
                    .tint(Color.luxuryPurple)
            }
            .frame(height: 180)

            VStack(spacing: 12) {
                Text("Scanning...")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Checking your Apple subscriptions")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
    }

    // MARK: - No Subscriptions View
    private var noSubscriptionsView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "tray")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 12) {
                Text("No Subscriptions Found")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("No active App Store subscriptions were found on this Apple ID")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.luxuryPurple)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Review View
    private var reviewView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Found \(detectedSubscriptions.count) Subscription\(detectedSubscriptions.count == 1 ? "" : "s")")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)

                // Subscriptions
                VStack(spacing: 12) {
                    ForEach(detectedSubscriptions) { subscription in
                        AppleDetectedSubscriptionRow(
                            subscription: subscription,
                            isSelected: selectedForImport.contains(subscription.id)
                        ) {
                            toggleSelection(subscription.id)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Actions
                VStack(spacing: 12) {
                    if selectedForImport.count > 0 {
                        Button(action: importSelected) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add \(selectedForImport.count) Subscription\(selectedForImport.count == 1 ? "" : "s")")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.luxuryPurple)
                            .cornerRadius(16)
                        }
                    }

                    Button(action: { dismiss() }) {
                        Text(selectedForImport.count > 0 ? "Done" : "Skip")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.green)
            }

            VStack(spacing: 12) {
                Text("Import Complete!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("\(selectedForImport.count) subscription\(selectedForImport.count == 1 ? "" : "s") added")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.luxuryPurple)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func runDetection() {
        isScanning = true
        errorMessage = nil

        Task {
            await appleScanner.scanSubscriptions()

            await MainActor.run {
                isScanning = false
                detectedSubscriptions = appleScanner.detectedSubscriptions

                if !appleScanner.detectedSubscriptions.isEmpty {
                    // Select all by default
                    selectedForImport = Set(appleScanner.detectedSubscriptions.map { $0.id })
                } else {
                    scanComplete = true
                }

                if let error = appleScanner.scanError {
                    errorMessage = error
                    showError = true
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedForImport.contains(id) {
            selectedForImport.remove(id)
        } else {
            selectedForImport.insert(id)
        }
    }

    private func importSelected() {
        let toImport = detectedSubscriptions.filter { selectedForImport.contains($0.id) }

        Task {
            for detected in toImport {
                let subscription = detected.toSubscription()
                _ = try? await subscriptionStore.addSubscription(subscription)
            }

            await MainActor.run {
                scanComplete = true
            }
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.luxuryPurple)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
    }
}

// MARK: - Apple Detected Subscription Row
struct AppleDetectedSubscriptionRow: View {
    let subscription: AppleDetectedSubscription
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            iconView
            infoView
            Spacer()
            priceView
            checkboxView
        }
        .padding(16)
        .background(cardBackground)
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(categoryColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: subscription.iconName)
                .font(.system(size: 22))
                .foregroundColor(categoryColor)
        }
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subscription.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Text(subscription.billingDisplay)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                if subscription.isInTrial {
                    trialBadge
                }

                if subscription.status == .expired {
                    expiredBadge
                }
            }
        }
    }

    private var trialBadge: some View {
        Text("TRIAL")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .cornerRadius(4)
    }

    private var expiredBadge: some View {
        Text("EXPIRED")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.2))
            .cornerRadius(4)
    }

    private var priceView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(subscription.formattedPrice)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text(statusText)
                .font(.system(size: 11))
                .foregroundColor(statusColor)
        }
    }

    private var statusText: String {
        switch subscription.status {
        case .active: return "Active"
        case .trial: return "Trial"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        case .paused: return "Paused"
        }
    }

    private var checkboxView: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundColor(isSelected ? Color.luxuryPurple : .white.opacity(0.4))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.luxuryPurple.opacity(0.5) : Color.clear, lineWidth: 2)
            )
    }

    private var categoryColor: Color {
        switch subscription.category {
        case .entertainment: return .purple
        case .music: return .pink
        case .productivity: return .blue
        case .healthFitness: return .green
        case .cloudStorage: return .cyan
        case .education: return .orange
        case .news: return .brown
        case .utilities: return .gray
        case .social: return .teal
        case .shopping: return .red
        case .food: return .yellow
        case .sports: return .indigo
        case .finance: return .mint
        case .other: return .secondary
        }
    }

    private var statusColor: Color {
        switch subscription.status {
        case .active: return .green
        case .trial: return .orange
        case .expired: return .red
        case .cancelled: return .gray
        case .paused: return .yellow
        }
    }
}

#Preview {
    NavigationView {
        AutoDetectView()
    }
}
