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
    @State private var expandedIds: Set<UUID> = []
    @State private var didPreselect = false

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

    private func isLive(_ sub: SmartImportManager.ImportSubscription) -> Bool {
        guard let status = sub.proven?.status else { return true }
        return status != .likelyEnded && status != .cancelled
    }

    private var resultsSection: some View {
        let subs = scanner.foundSubscriptions
        let confirmed = subs.filter { $0.proven?.tier == .confirmed && isLive($0) }
        let worthALook = subs.filter { $0.proven?.tier != .confirmed && isLive($0) }
        let ended = subs.filter { !isLive($0) }

        return VStack(spacing: 20) {
            summaryCard(count: confirmed.count + worthALook.count)
            insightsCard
            if !confirmed.isEmpty {
                listSection(title: "Confirmed", subtitle: "Proven by repeat charges", items: confirmed)
            }
            if !worthALook.isEmpty {
                listSection(title: "Worth a look", subtitle: "Check these before importing", items: worthALook)
            }
            if !ended.isEmpty {
                listSection(title: "May have ended", subtitle: "No recent charges found", items: ended)
            }
            importButton
        }
        .onAppear(perform: preselectConfirmed)
    }

    private func preselectConfirmed() {
        guard !didPreselect else { return }
        didPreselect = true
        selectedSubscriptions = Set(scanner.foundSubscriptions
            .filter { $0.proven?.tier == .confirmed && isLive($0) }
            .map(\.id))
    }

    private func summaryCard(count: Int) -> some View {
        let report = scanner.report
        let monthly = report?.monthlyTotal ?? 0
        let annual = report?.annualTotal ?? 0
        let currency = scanner.foundSubscriptions.first?.currency ?? CurrencyManager.shared.selectedCurrency
        let ignored = scanner.scanStats.purchasesIgnored

        return VStack(alignment: .leading, spacing: 10) {
            Text(count == 1 ? "We found 1 subscription" : "We found \(count) subscriptions")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(GmailImportView.money(monthly, currency))
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                    .foregroundStyle(Color.accentMint)
                Text("per month")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }
            Text("\(GmailImportView.money(annual, currency)) a year")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
            if ignored > 0 {
                Label("Ignored \(ignored) one-time purchase\(ignored == 1 ? "" : "s") so your list stays clean", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var insightsCard: some View {
        let insights = Array((scanner.report?.insights ?? []).prefix(4))
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Worth knowing")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: insight.kind))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(color(for: insight.kind))
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                            Text(insight.detail)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.obsidianTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
        }
    }

    private func icon(for kind: IntelligenceInsight.Kind) -> String {
        switch kind {
        case .priceIncrease, .priceChangeNotice: return "arrow.up.right.circle.fill"
        case .trialEnding: return "hourglass"
        case .renewalSoon: return "calendar.badge.clock"
        case .likelyEnded: return "questionmark.circle.fill"
        case .chargedAfterCancel: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for kind: IntelligenceInsight.Kind) -> Color {
        switch kind {
        case .chargedAfterCancel: return .red
        case .priceIncrease, .priceChangeNotice, .trialEnding, .renewalSoon: return .orange
        case .likelyEnded: return Color.obsidianTextSecondary
        }
    }

    private func listSection(title: String, subtitle: String, items: [SmartImportManager.ImportSubscription]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                Spacer()
                let allSelected = items.allSatisfy { selectedSubscriptions.contains($0.id) }
                Button(allSelected ? "Deselect all" : "Select all") {
                    if allSelected {
                        items.forEach { selectedSubscriptions.remove($0.id) }
                    } else {
                        items.forEach { selectedSubscriptions.insert($0.id) }
                    }
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.accentMint)
            }

            VStack(spacing: 1) {
                ForEach(items) { sub in
                    GmailSubscriptionRow(
                        subscription: sub,
                        isSelected: selectedSubscriptions.contains(sub.id),
                        isExpanded: expandedIds.contains(sub.id),
                        onToggle: {
                            if selectedSubscriptions.contains(sub.id) {
                                selectedSubscriptions.remove(sub.id)
                            } else {
                                selectedSubscriptions.insert(sub.id)
                            }
                        },
                        onExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedIds.contains(sub.id) { expandedIds.remove(sub.id) } else { expandedIds.insert(sub.id) }
                            }
                        }
                    )
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
        }
    }

    @ViewBuilder
    private var importButton: some View {
        if !selectedSubscriptions.isEmpty {
            Button {
                HapticStyle.medium.trigger()
                Task { await importSelected() }
            } label: {
                HStack(spacing: 8) {
                    if importing {
                        ProgressView().tint(.black)
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
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentMint))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(importing)
        }
    }

    static func money(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
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
        didPreselect = false
        expandedIds = []
        importing = false
        HapticStyle.success.trigger()
    }
}

// MARK: - Subscription Row

private struct GmailSubscriptionRow: View {
    let subscription: SmartImportManager.ImportSubscription
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void

    private var proven: ProvenSubscription? { subscription.proven }

    private var frequencySuffix: String {
        switch subscription.billingFrequency {
        case .weekly: return "/wk"
        case .biweekly: return "/2wk"
        case .monthly: return "/mo"
        case .quarterly: return "/qtr"
        case .semiannual: return "/6mo"
        case .yearly: return "/yr"
        }
    }

    private var statusBadge: (text: String, color: Color)? {
        switch proven?.status {
        case .priceIncreased: return ("Price went up", .orange)
        case .trial: return ("Free trial", Color.accentMint)
        case .likelyEnded: return ("May have ended", Color.obsidianTextSecondary)
        case .cancelled: return ("Cancelled", Color.obsidianTextSecondary)
        default:
            return proven?.chargedAfterCancel == true ? ("Charged after cancel", .red) : nil
        }
    }

    private var evidenceLine: String {
        guard let proven else { return subscription.source }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        if proven.status == .trial, let ends = proven.trialEndsOn { return "Trial ends \(formatter.string(from: ends))" }
        let count = proven.evidence.count
        let last = proven.lastChargeDate.map { formatter.string(from: $0) }
        if let last { return count > 1 ? "Charged \(count)× · last \(last)" : "Charged once · \(last)" }
        return "Detected from your emails"
    }

    private var accessibilitySummary: String {
        var parts = ["\(subscription.name)", GmailImportView.money(subscription.amount, subscription.currency) + " " + subscription.billingFrequency.displayName.lowercased(), evidenceLine]
        if let badge = statusBadge { parts.append(badge.text) }
        parts.append(isSelected ? "selected" : "not selected")
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    HStack(spacing: 14) {
                        checkbox
                        ServiceLogoView(name: subscription.name, category: nil, size: 36)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(subscription.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(evidenceLine)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color.obsidianTextTertiary)
                            if let badge = statusBadge {
                                Text(badge.text)
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(badge.color)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(GmailImportView.money(subscription.amount, subscription.currency))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.accentMint)
                            Text(frequencySuffix)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color.obsidianTextTertiary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint("Double tap to select or deselect for import")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

                if proven != nil {
                    Button(action: onExpand) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.obsidianTextTertiary)
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(isExpanded ? "Hide why" : "Show why we think this is a subscription")
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 12)

            if isExpanded, let proven {
                evidenceDetail(proven)
            }
        }
    }

    private var checkbox: some View {
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
    }

    private func evidenceDetail(_ proven: ProvenSubscription) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return VStack(alignment: .leading, spacing: 10) {
            Text("Why we think so")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            ForEach(Array(proven.reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accentMint)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    Text(reason)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !proven.evidence.isEmpty {
                Divider().overlay(Color.obsidianTextTertiary.opacity(0.3))
                ForEach(proven.evidence.suffix(5).reversed()) { charge in
                    HStack {
                        Text(formatter.string(from: charge.date))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                        Spacer()
                        Text(GmailImportView.money(charge.amount, charge.currency))
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}
