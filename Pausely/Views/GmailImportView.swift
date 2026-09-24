//
//  GmailImportView.swift
//  Pausely
//
//  Connect Gmail to scan for subscription emails and auto-import.
//

import SwiftUI

struct GmailImportView: View {
    @ObservedObject private var scanner = GmailSubscriptionScanner.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSubscriptions: Set<UUID> = []
    @State private var importing = false
    @State private var importResult: (added: Int, duplicates: Int)?

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !scanner.isConnected {
                            connectSection
                        } else if scanner.isScanning {
                            scanningSection
                        } else if !scanner.foundSubscriptions.isEmpty {
                            resultsSection
                        } else if let result = importResult {
                            importCompleteSection(result)
                        } else {
                            connectedSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Gmail Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.accentMint)
                }
                if scanner.isConnected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                scanner.disconnect()
                            } label: {
                                Label("Disconnect Gmail", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.obsidianTextSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Connect Section

    private var connectSection: some View {
        VStack(spacing: 24) {
            // Hero icon
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.accentMint)
            }
            .padding(.top, 40)

            VStack(spacing: 8) {
                Text("Find Subscriptions in Gmail")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("We'll scan your email for subscription receipts and billing confirmations to automatically detect your services.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Privacy notice
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.accentMint)
                    Text("Your emails never leave your phone.")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.accentMint)
                }
                Text("Receipts are read and processed on-device. Only the subscription name, amount, and date are saved to your account — never the email content itself. Read-only access, we cannot send or delete emails.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .lineSpacing(2)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentMint.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentMint.opacity(0.15), lineWidth: 1)
                    )
            )

            // Connect button
            Button {
                HapticStyle.medium.trigger()
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first {
                    scanner.connect(from: window)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Connect Gmail")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentMint)
                )
            }
            .buttonStyle(PlainButtonStyle())

            if let error = scanner.error {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.semanticDestructive)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .surfaceCard(cornerRadius: 24)
    }

    // MARK: - Scanning Section

    private var scanningSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentMint)
                    .symbolEffect(.pulse)
            }

            Text("Scanning your emails...")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            ProgressView(value: scanner.scanProgress)
                .tint(Color.accentMint)
                .padding(.horizontal, 40)

            Text("\(Int(scanner.scanProgress * 100))%")
                .font(.system(.caption, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.obsidianTextSecondary)
        }
        .padding(32)
        .surfaceCard(cornerRadius: 24)
    }

    // MARK: - Connected Section (ready to scan)

    private var connectedSection: some View {
        VStack(spacing: 20) {
            // Connected status
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gmail Connected")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    if let email = scanner.connectedEmail {
                        Text(email)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .surfaceCard(cornerRadius: 16)

            // Scan button
            Button {
                HapticStyle.medium.trigger()
                Task { await scanner.scan() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Scan for Subscriptions")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentMint)
                )
            }
            .buttonStyle(PlainButtonStyle())

            if let error = scanner.error {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.semanticDestructive)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Found \(scanner.foundSubscriptions.count) Subscriptions")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Select which to import")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                Spacer()
                Button(selectedSubscriptions.count == scanner.foundSubscriptions.count ? "Deselect All" : "Select All") {
                    if selectedSubscriptions.count == scanner.foundSubscriptions.count {
                        selectedSubscriptions.removeAll()
                    } else {
                        selectedSubscriptions = Set(scanner.foundSubscriptions.map(\.id))
                    }
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.accentMint)
            }

            // Subscription list
            VStack(spacing: 1) {
                ForEach(scanner.foundSubscriptions) { sub in
                    GmailSubscriptionRow(
                        subscription: sub,
                        isSelected: selectedSubscriptions.contains(sub.id),
                        onToggle: {
                            if selectedSubscriptions.contains(sub.id) {
                                selectedSubscriptions.remove(sub.id)
                            } else {
                                selectedSubscriptions.insert(sub.id)
                            }
                        }
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.obsidianSurface)
            )

            // Import button
            if !selectedSubscriptions.isEmpty {
                Button {
                    HapticStyle.medium.trigger()
                    Task { await importSelected() }
                } label: {
                    HStack(spacing: 8) {
                        if importing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text("Import \(selectedSubscriptions.count) Subscription\(selectedSubscriptions.count == 1 ? "" : "s")")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentMint)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(importing)
            }
        }
    }

    // MARK: - Import Complete

    private func importCompleteSection(_ result: (added: Int, duplicates: Int)) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
            }

            Text("Import Complete!")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                if result.added > 0 {
                    Text("\(result.added) subscription\(result.added == 1 ? "" : "s") added")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.accentMint)
                }
                if result.duplicates > 0 {
                    Text("\(result.duplicates) already tracked (skipped)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentMint)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .surfaceCard(cornerRadius: 24)
    }

    // MARK: - Actions

    private func importSelected() async {
        importing = true
        let selected = scanner.foundSubscriptions.filter { selectedSubscriptions.contains($0.id) }
        let result = await scanner.importSubscriptions(selected)
        importResult = result
        scanner.foundSubscriptions = []
        importing = false
        HapticStyle.success.trigger()
    }
}

// MARK: - Subscription Row

private struct GmailSubscriptionRow: View {
    let subscription: SmartImportManager.ImportSubscription
    let isSelected: Bool
    let onToggle: () -> Void
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentMint : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isSelected ? Color.clear : Color.obsidianTextTertiary, lineWidth: 1.5)
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }

                // Service logo
                ServiceLogoView(name: subscription.name, category: nil, size: 36)

                // Name + confidence
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Text(subscription.source)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                        Text("·")
                            .foregroundStyle(Color.obsidianTextTertiary)
                        Text(subscription.confidence.rawValue)
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(subscription.confidence == .high ? .green : .orange)
                    }
                }

                Spacer()

                // Amount
                Text(currencyManager.format(subscription.amount))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)
                Text("/mo")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
