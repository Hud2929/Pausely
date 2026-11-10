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
                    .padding(.horizontal, Layout.margin)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
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

    /// Before any inbox is connected: what this does, what it never does, and which inbox.
    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Find subscriptions in your email")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Pausely reads the receipts in your inbox and finds what you pay for, including trials and price changes.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            privacyNotice.padding(.top, 24)

            providerButtons.padding(.top, 16)

            if let error = scanner.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color.due)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The promise, printed: it is the reason someone would let an app near their inbox.
    private var privacyNotice: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your email never leaves your iPhone.")
                    .font(.question(.title3))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pausely connects straight to your email provider with read-only access, reads receipts on this iPhone and keeps only the name, amount and date of each charge. It can't send, change or delete email.")
                    .font(.footnote)
                    .foregroundStyle(Color.paperMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var providerButtons: some View {
        VStack(spacing: 0) {
            if FeatureFlags.gmailImportEnabled && GmailMailboxProvider.isConfigured {
                providerButton(Text(verbatim: "Gmail"), detail: Text("Sign in with Google"), icon: "Gmail", id: "connectGmail") {
                    showingProviders = false
                    Task { await scanner.connectGmail() }
                }
            }
            if FeatureFlags.microsoftImportEnabled && MicrosoftGraphProvider.isConfigured {
                providerButton(Text(verbatim: "Outlook, Hotmail, Live, MSN"), detail: Text("Sign in with Microsoft"), icon: "Outlook", id: "connectMicrosoft") {
                    showingProviders = false
                    Task { await scanner.connectMicrosoft() }
                }
            }
            if FeatureFlags.imapImportEnabled {
                ForEach(["icloud", "yahoo", "aol", "gmail-imap"], id: \.self) { id in
                    if let preset = IMAPPreset.find(id) {
                        providerButton(Text(verbatim: preset.name), detail: Text("With an app password"), icon: preset.name, id: "connect-\(id)") {
                            openIMAP(preset)
                        }
                    }
                }
                providerButton(Text("Other email"), detail: Text("GMX, WEB.DE, Zoho, Fastmail and more"), icon: "", id: "connect-other") {
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
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    if icon.isEmpty {
                        Image(systemName: "envelope")
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(width: 36, height: 36)
                            .accessibilityHidden(true)
                    } else {
                        ServiceLogoView(name: icon, category: nil, size: 36)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        title
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        detail
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkTextFaint)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(id)
            Hairline()
        }
    }


    private var scanningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            (scanner.statusLine.isEmpty ? Text("Scanning your email…") : Text(verbatim: scanner.statusLine))
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            ProgressView(value: scanner.progress)
                .tint(Color.inkText)

            HStack {
                Text(scanner.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.proof(.subheadline))
                    .foregroundStyle(Color.inkTextMuted)
                Spacer()
                Button("Stop") { scanner.cancelScan() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(minHeight: Layout.tapTarget)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }


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
        .padding(.vertical, 10)
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

        return VStack(spacing: 28) {
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

    /// What the scan found, as a slip: the total first, then how it was worked out.
    private func summaryCard(count: Int) -> some View {
        let report = scanner.report
        let currency = CurrencyManager.shared.selectedCurrency
        let monthly = report?.monthlyTotal(in: currency) ?? 0
        let annual = monthly * 12
        let ignored = scanner.stats.purchasesIgnored

        return VStack(alignment: .leading, spacing: 16) {
            Text("We found \(count) subscriptions")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ProofLine(label: L10n.string("Each month"), value: InboxImportView.money(monthly, currency), emphasised: true)
                    ProofLine(label: L10n.string("Each year"), value: InboxImportView.money(annual, currency))
                    if ignored > 0 || scanner.stats.emailsChecked > 0 { Perforation() }
                    if ignored > 0 {
                        Text("Ignored \(ignored) one-time purchases so your list stays clean")
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if scanner.stats.emailsChecked > 0 {
                        let stats = scanner.stats
                        Text("Emails checked: \(stats.emailsChecked) · read in full: \(stats.bodiesRead) · all on your phone")
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        if stats.aiAssisted > 0 {
                            Text("On-device AI helped with \(stats.aiAssisted) tricky receipts")
                                .font(.proof(.caption))
                                .foregroundStyle(Color.paperMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var insightsCard: some View {
        let insights = Array((scanner.report?.insights ?? []).prefix(4))
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Worth knowing")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    if index > 0 { Hairline() }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: icon(for: insight.kind))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(color(for: insight.kind))
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                            Text(insight.detail)
                                .font(.subheadline)
                                .foregroundStyle(Color.inkTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        case .chargedAfterCancel, .paymentFailed: return .due
        case .priceIncrease, .priceChangeNotice, .trialEnding, .renewalSoon: return .decide
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
                        .font(.subheadline)
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

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, sub in
                    if index > 0 { Hairline() }
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
        }
    }

    @ViewBuilder
    private var importButton: some View {
        if !selectedSubscriptions.isEmpty {
            Button {
                Task { await importSelected() }
            } label: {
                if importing {
                    ProgressView().tint(Color.paperInk)
                } else {
                    Text("Import \(selectedSubscriptions.count) subscriptions")
                }
            }
            .buttonStyle(.ink)
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
        case .priceIncreased: return (L10n.string("Price went up"), Color.decide)
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
                                .font(.caption)
                                .foregroundStyle(Color.inkTextMuted)
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
            .padding(.vertical, 12)

            if isExpanded, let proven {
                evidenceDetail(proven)
            }
        }
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.paper : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.inkTextFaint, lineWidth: 1.5)
                )
                .frame(width: 22, height: 22)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.paperInk)
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
