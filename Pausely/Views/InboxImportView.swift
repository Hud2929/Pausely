//
//  InboxImportView.swift
//  Pausely
//
//  Connect email inboxes (Gmail, Outlook, iCloud, Yahoo, AOL and any IMAP inbox), find subscriptions in
//  their receipts on this iPhone, and import them.
//

import SwiftUI

struct InboxImportView: View {
    @ObservedObject private var scanner = InboxScanner.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSubscriptions: Set<UUID> = []
    @State private var importing = false
    @State private var importResult: (added: Int, duplicates: Int)?
    @State private var expandedIds: Set<UUID> = []
    @State private var didPreselect = false
    @State private var imapPreset: IMAPPreset?
    @State private var showingIMAP = false
    @State private var showingProviders = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !scanner.hasAccounts {
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
            .navigationTitle("Find in Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.inkText)
                }
                if scanner.hasAccounts && !scanner.isScanning {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingProviders = true } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.inkTextMuted)
                        }
                        .accessibilityLabel("Add another inbox")
                    }
                }
            }
            .sheet(isPresented: $showingIMAP) {
                IMAPConnectView(preset: imapPreset)
            }
            .sheet(isPresented: $showingProviders) {
                NavigationStack {
                    ScrollView {
                        providerButtons
                            .padding(20)
                    }
                    .background(Color.ink.ignoresSafeArea())
                    .navigationTitle("Add an inbox")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showingProviders = false }.foregroundStyle(Color.inkText)
                        }
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Connect Section

    private var connectSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 100, height: 100)
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.inkText)
            }
            .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Find subscriptions in your email")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.inkText)
                    .multilineTextAlignment(.center)
                Text("Pausely reads the receipts in your inbox and finds what you pay for, including trials and price changes.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            privacyNotice
            providerButtons

            if let error = scanner.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.due)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
    }

    private var privacyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(Color.inkText)
                Text("Your email never leaves your iPhone.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkText)
            }
            Text("Pausely connects straight to your email provider with read-only access, reads receipts on this iPhone and keeps only the name, amount and date of each charge. It can't send, change or delete email.")
                .font(.caption)
                .foregroundStyle(Color.inkTextMuted)
                .lineSpacing(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    private var providerButtons: some View {
        VStack(spacing: 10) {
            if FeatureFlags.gmailImportEnabled && GmailMailboxProvider.isConfigured {
                providerButton(Text(verbatim: "Gmail"), detail: Text("Sign in with Google"), icon: "envelope.fill", id: "connectGmail") {
                    showingProviders = false
                    Task { await scanner.connectGmail() }
                }
            }
            if FeatureFlags.microsoftImportEnabled && MicrosoftGraphProvider.isConfigured {
                providerButton(Text(verbatim: "Outlook, Hotmail, Live, MSN"), detail: Text("Sign in with Microsoft"), icon: "envelope.badge.fill", id: "connectMicrosoft") {
                    showingProviders = false
                    Task { await scanner.connectMicrosoft() }
                }
            }
            if FeatureFlags.imapImportEnabled {
                ForEach(["icloud", "yahoo", "aol", "gmail-imap"], id: \.self) { id in
                    if let preset = IMAPPreset.find(id) {
                        providerButton(Text(verbatim: preset.name), detail: Text("With an app password"), icon: "envelope", id: "connect-\(id)") {
                            openIMAP(preset)
                        }
                    }
                }
                providerButton(Text("Other email"), detail: Text("GMX, WEB.DE, Zoho, Fastmail and more"), icon: "tray.full", id: "connect-other") {
                    openIMAP(nil)
                }
            }
        }
    }

    private func openIMAP(_ preset: IMAPPreset?) {
        imapPreset = preset
        showingProviders = false
        showingIMAP = true
    }

    private func providerButton(_ title: Text, detail: Text, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                    detail
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(.caption).weight(.semibold))
                    .foregroundStyle(Color.inkTextFaint)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.inkRaised))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(id)
    }

    // MARK: - Scanning Section

    private var scanningSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.inkText)
                    .symbolEffect(.pulse)
            }

            (scanner.statusLine.isEmpty ? Text("Scanning your email…") : Text(verbatim: scanner.statusLine))
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.center)

            ProgressView(value: scanner.progress)
                .tint(Color.inkText)
                .padding(.horizontal, 40)

            Text(scanner.progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.inkTextMuted)

            Button("Stop") { scanner.cancelScan() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
        }
        .padding(32)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
    }

    // MARK: - Connected Section (ready to scan)

    private var connectedSection: some View {
        VStack(spacing: 16) {
            ForEach(scanner.accounts) { account in
                accountRow(account)
            }

            Button {
                Task { await scanner.scanAll() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    (scanner.accounts.count == 1 ? Text("Find subscriptions") : Text("Search \(scanner.accounts.count) inboxes"))
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.paper))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("scanInboxesButton")

            if let error = scanner.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.center)
            }
            privacyNotice
        }
    }

    private func accountRow(_ account: MailboxAccount) -> some View {
        HStack(spacing: 12) {
            Image(systemName: scanner.accountErrors[account.id] == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(.title3))
                .foregroundStyle(scanner.accountErrors[account.id] == nil ? Color.kept : Color.decide)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.address)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .lineLimit(1)
                Text(accountDetail(account))
                    .font(.caption)
                    .foregroundStyle(Color.inkTextMuted)
                    .lineLimit(2)
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    Task { await scanner.disconnect(account) }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .accessibilityIdentifier("disconnectInbox")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(.title3))
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(account.address)")
            .accessibilityIdentifier("inboxOptions")
        }
        .padding(16)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
    }

    private func accountDetail(_ account: MailboxAccount) -> String {
        if let error = scanner.accountErrors[account.id] { return error }
        if let stats = scanner.stats.perAccount[account.id] {
            return L10n.string("\(account.providerName) · checked \(stats.checked), read \(stats.read)")
        }
        if let last = account.lastScan {
            return L10n.string("\(account.providerName) · searched \(last.formatted(.relative(presentation: .named).locale(L10n.locale)))")
        }
        return account.providerName
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
        // In the display currency: a mailbox can have receipts in several currencies.
        let currency = CurrencyManager.shared.selectedCurrency
        let monthly = report?.monthlyTotal(in: currency) ?? 0
        let annual = monthly * 12
        let ignored = scanner.stats.purchasesIgnored

        return VStack(alignment: .leading, spacing: 10) {
            Text("We found \(count) subscriptions")
                .font(.headline)
                .foregroundStyle(Color.inkText)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(InboxImportView.money(monthly, currency))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.inkText)
                Text("per month")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
            }
            Text("\(InboxImportView.money(annual, currency)) a year")
                .font(.footnote)
                .foregroundStyle(Color.inkTextMuted)
            if ignored > 0 {
                Label("Ignored \(ignored) one-time purchases so your list stays clean", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(Color.inkTextFaint)
            }
            if scanner.stats.emailsChecked > 0 {
                let stats = scanner.stats
                Label("Emails checked: \(stats.emailsChecked) · read in full: \(stats.bodiesRead) · all on your phone", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(Color.inkTextFaint)
                if stats.aiAssisted > 0 {
                    Label("On-device AI helped with \(stats.aiAssisted) tricky receipts", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Color.inkTextFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.inkRaised))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var insightsCard: some View {
        let insights = Array((scanner.report?.insights ?? []).prefix(4))
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Worth knowing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: insight.kind))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(color(for: insight.kind))
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                            Text(insight.detail)
                                .font(.caption)
                                .foregroundStyle(Color.inkTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.inkRaised))
        }
    }

    private func icon(for kind: IntelligenceInsight.Kind) -> String {
        switch kind {
        case .priceIncrease, .priceChangeNotice: return "arrow.up.right.circle.fill"
        case .trialEnding: return "hourglass"
        case .renewalSoon: return "calendar.badge.clock"
        case .likelyEnded: return "questionmark.circle.fill"
        case .chargedAfterCancel: return "exclamationmark.triangle.fill"
        case .paymentFailed: return "creditcard.trianglebadge.exclamationmark"
        }
    }

    private func color(for kind: IntelligenceInsight.Kind) -> Color {
        switch kind {
        case .chargedAfterCancel, .paymentFailed: return .red
        case .priceIncrease, .priceChangeNotice, .trialEnding, .renewalSoon: return .orange
        case .likelyEnded: return Color.inkTextMuted
        }
    }

    private func listSection(title: LocalizedStringKey, subtitle: LocalizedStringKey, items: [SmartImportManager.ImportSubscription]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.inkText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                }
                Spacer()
                let allSelected = items.allSatisfy { selectedSubscriptions.contains($0.id) }
                Button {
                    if allSelected {
                        items.forEach { selectedSubscriptions.remove($0.id) }
                    } else {
                        items.forEach { selectedSubscriptions.insert($0.id) }
                    }
                } label: {
                    allSelected ? Text("Deselect all") : Text("Select all")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkText)
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
                        },
                        onReject: {
                            selectedSubscriptions.remove(sub.id)
                            withAnimation(.easeInOut(duration: 0.25)) { scanner.markNotSubscription(sub) }
                        }
                    )
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.inkRaised))
        }
    }

    @ViewBuilder
    private var importButton: some View {
        if !selectedSubscriptions.isEmpty {
            Button {
                Task { await importSelected() }
            } label: {
                HStack(spacing: 8) {
                    if importing {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text("Import \(selectedSubscriptions.count) subscriptions")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.paper))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(importing)
            .accessibilityIdentifier("importSelectedButton")
        }
    }

    static func money(_ amount: Decimal, _ currency: String) -> String {
        MoneyFormat.string(amount, currency)
    }

    // MARK: - Import Complete

    private func importCompleteSection(_ result: (added: Int, duplicates: Int)) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.kept.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.kept)
            }

            Text("Import complete")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.inkText)

            VStack(spacing: 6) {
                if result.added > 0 {
                    Text("\(result.added) subscriptions added")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkText)
                }
                if result.duplicates > 0 {
                    Text("\(result.duplicates) already tracked (skipped)")
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.paper)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("importDoneButton")
        }
        .padding(24)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
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
        Feel.landed()
    }
}

// MARK: - Subscription Row

private struct GmailSubscriptionRow: View {
    let subscription: SmartImportManager.ImportSubscription
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void
    let onReject: () -> Void

    private var proven: ProvenSubscription? { subscription.proven }

    private var frequencySuffix: String { subscription.billingFrequency.shortDisplay }

    private var statusBadge: (text: String, color: Color)? {
        switch proven?.status {
        case .priceIncreased: return (L10n.string("Price went up"), .orange)
        case .trial: return (L10n.string("Free trial"), Color.inkText)
        case .likelyEnded: return (L10n.string("May have ended"), Color.inkTextMuted)
        case .cancelled: return (L10n.string("Cancelled"), Color.inkTextMuted)
        default:
            return proven?.chargedAfterCancel == true ? (L10n.string("Charged after cancelling"), .red) : nil
        }
    }

    private var evidenceLine: String {
        guard let proven else { return subscription.source }
        let day: (Date) -> String = { $0.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale)) }
        if proven.status == .trial, let ends = proven.trialEndsOn { return L10n.string("Trial ends \(day(ends))") }
        let count = proven.evidence.count
        if let last = proven.lastChargeDate.map(day) {
            return count > 1 ? L10n.string("Charged \(count)× · last \(last)") : L10n.string("Charged once · \(last)")
        }
        return L10n.string("Detected from your emails")
    }

    private var accessibilitySummary: String {
        var parts = [subscription.name, InboxImportView.money(subscription.amount, subscription.currency) + " " + subscription.billingFrequency.billingPeriodLabel, evidenceLine]
        if let badge = statusBadge { parts.append(badge.text) }
        parts.append(isSelected ? L10n.string("selected") : L10n.string("not selected"))
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
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .lineLimit(1)
                            Text(evidenceLine)
                                .font(.caption2)
                                .foregroundStyle(Color.inkTextFaint)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if let badge = statusBadge {
                                Text(badge.text)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(badge.color)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(InboxImportView.money(subscription.amount, subscription.currency))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.inkText)
                            Text(frequencySuffix)
                                .font(.caption2)
                                .foregroundStyle(Color.inkTextFaint)
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
                            .foregroundStyle(Color.inkTextFaint)
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(isExpanded ? Text("Hide why") : Text("Show why we think this is a subscription"))
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
                .fill(isSelected ? Color.inkText : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.inkTextFaint, lineWidth: 1.5)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Why we think so")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkText)
            ForEach(Array(proven.reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkText)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !proven.evidence.isEmpty {
                Divider().overlay(Color.inkTextFaint.opacity(0.3))
                ForEach(proven.evidence.suffix(5).reversed()) { charge in
                    HStack {
                        Text(charge.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption2)
                            .foregroundStyle(Color.inkTextFaint)
                        Spacer()
                        Text(InboxImportView.money(charge.amount, charge.currency))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.inkTextMuted)
                    }
                }
            }
            Button(action: onReject) {
                Label("This isn't a subscription", systemImage: "hand.thumbsdown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkTextMuted)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Color.inkTextFaint.opacity(0.18)))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityHint("Removes it and Pausely will remember, so it won't appear again")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}
