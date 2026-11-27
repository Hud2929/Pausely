import SwiftUI
import SafariServices

/// Cancelling: the steps on a slip, the service's own cancellation page, pre-drafted cancellation and
/// refund emails, and "I cancelled it". Pausely never cancels anything itself; it records the
/// cancellation once the person confirms it.
struct CancelSubscriptionFlow: View {
    let subscription: Subscription
    /// False when the screen underneath shows the torn slip itself (the Renewal Verdict).
    var showsOutcome = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var difficulty = CancelDifficultyService.shared
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var safariLink: SafariLink?
    @State private var didOpenPage = false
    @State private var isSaving = false
    @State private var cancelled = false
    @State private var showingReceipt = false
    @State private var previewDraft: PresentedDraft?
    /// Asked when "I cancelled it" is tapped for a subscription with no renewal day: the receipt counts the
    /// charges avoided from that day, and without it a $14.95 cancellation was "$0.00" (2026-11-23).
    @State private var askingNextCharge = false
    @State private var nextCharge = Date()
    @Environment(\.openURL) private var openURL

    private struct PresentedDraft: Identifiable {
        let id = UUID()
        let draft: CancelConcierge.Draft
    }

    private struct SafariLink: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var current: Subscription {
        store.subscriptions.first(where: { $0.id == subscription.id }) ?? subscription
    }

    private var help: CancelHelp { CancelHelp.find(for: current) }
    private var conciergeUnlocked: Bool { paymentManager.isUnlocked(.cancelConcierge) }
    private var isStoreBilled: Bool {
        help.kind == .appleSubscription || help.kind == .googlePlay || help.kind == .amazonChannel
    }

    /// Apple's own steps for a subscription it bills, as published on 29 September 2026
    /// (support.apple.com/118428). The same for every Apple subscription, so they can be checked.
    private var appleSteps: [String] {
        [L10n.string("Open Settings and tap your name."),
         L10n.string("Tap Subscriptions."),
         L10n.string("Tap \(current.name)."),
         L10n.string("Tap Cancel Subscription. You may need to scroll down to find it.")]
    }

    var body: some View {
        ZStack {
            if cancelled && showsOutcome {
                outcome.transition(.opacity)
            } else {
                steps
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inkScreen()
        .preferredColorScheme(.dark)
        .sheet(item: $safariLink, onDismiss: { didOpenPage = true }) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
        .sheet(isPresented: $showingReceipt) { SavingsReceiptView() }
        .sheet(isPresented: $askingNextCharge) {
            NextChargeQuestion(name: current.name, isTrial: current.status == .trial, day: $nextCharge,
                               onSave: { askingNextCharge = false; Task { await markCancelled(nextCharge: nextCharge) } },
                               onUnknown: { askingNextCharge = false; Task { await markCancelled() } },
                               onCancel: { askingNextCharge = false })
                .presentationDetents([.large])
        }
        .sheet(item: $previewDraft) { item in
            EmailDraftSheet(draft: item.draft, locked: !conciergeUnlocked,
                            paywallContext: PaywallContext(
                                trigger: .cancelConcierge,
                                serviceName: current.name,
                                serviceChargeAmount: current.amount,
                                serviceChargeCurrency: current.currency
                            ),
                            onUsed: { didOpenPage = true })
        }
        .task { await difficulty.loadIfNeeded() }
    }

    private var steps: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Close") { dismiss() }
                    Spacer()
                }

                PaperSlip(tornTop: true, tornBottom: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        MarkedWords(alignment: .center) {
                            ServiceLogoView(name: current.name, category: current.category, size: 36)
                        } words: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.string("That's \(MoneyFormat.string(current.annualCost, current.currency)) a year"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.paperMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                if MoneyFormat.normalizedCode(current.currency) != MoneyFormat.normalizedCode(currencyManager.selectedCurrency),
                                   let converted = currencyManager.convertToSelected(current.annualCost, from: current.currency) {
                                    Text("About \(MoneyFormat.string(converted, currencyManager.selectedCurrency)) in your currency")
                                        .font(.footnote)
                                        .foregroundStyle(Color.paperMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        Text("Cancel \(current.name)")
                            .font(.question(.title))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        switch help.kind {
                        case .appleSubscription:
                            Perforation()
                            Text("How to cancel").font(.footnote.weight(.semibold))
                            ForEach(Array(appleSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(verbatim: L10n.number(index + 1))
                                        .font(.proof(.footnote, weight: .bold))
                                    Text(verbatim: step)
                                        .font(.footnote)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                            Text("If there's no Cancel button, it's already cancelled.")
                                .font(.footnote)
                                .foregroundStyle(Color.paperMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        case .googlePlay:
                            Perforation()
                            Text("You cancel in Google Play: sign in, then open Payments & subscriptions.")
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        case .amazonChannel:
                            Perforation()
                            Text("You cancel in Amazon Prime Video: sign in, then open Channels & Subscriptions.")
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        case .cancellationPage, .website:
                            Perforation()
                            Text(L10n.string("You cancel on \(current.name)'s own site: sign in, then look under account or billing."))
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        case .search:
                            EmptyView()
                        }

                        if let score = difficulty.score(for: current.name),
                           let summary = CancelDifficultyService.summaryLine(for: score) {
                            Perforation()
                            Text(verbatim: summary)
                                .font(.footnote)
                                .foregroundStyle(score.avgDifficulty >= 3.5 ? Color.paperDue : Color.paperMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 4)

                if help.kind != .googlePlay && help.kind != .amazonChannel {
                    conciergeSection.padding(.top, 20)
                }

                Text("Pausely keeps it in your list as cancelled and adds the charges you avoid to your Savings Receipt.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.bottom, 16)
        } actions: {
            VStack(spacing: 10) {
                // The button says what it opens: the service's cancellation page, its website, or a search.
                Button {
                    // Apple's link opens the person's subscriptions in Settings; the rest open here.
                    if help.kind == .appleSubscription, let link = help.link {
                        openURL(link)
                        didOpenPage = true
                    } else if let link = help.link {
                        safariLink = SafariLink(url: link)
                    }
                } label: { Text(openLabel) }
                    .buttonStyle(.ink(didOpenPage ? .quiet : .main))
                    .accessibilityIdentifier("openCancellationPageButton")

                // Once the person is back from the service's page, this becomes the main action.
                Button {
                    if current.status == .cancelled {
                        if showsOutcome {
                            withAnimation(Motion.unlessReduced(Motion.arrive)) { cancelled = true }
                        } else {
                            dismiss()
                        }
                    } else if current.renewsAutomatically && RenewalDecisions.upcomingCharge(for: current, now: Date()) == nil {
                        askingNextCharge = true
                    } else {
                        Task { await markCancelled() }
                    }
                } label: {
                    Text(isSaving ? "Saving…" : "I cancelled it")
                }
                .buttonStyle(.ink(didOpenPage ? .main : .quiet))
                .disabled(isSaving)
                .accessibilityIdentifier("iCancelledItButton")
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private var openLabel: String {
        switch help.kind {
        case .appleSubscription: return L10n.string("Open your subscriptions")
        case .googlePlay: return L10n.string("Open Google Play subscriptions")
        case .amazonChannel: return L10n.string("Open Amazon Channels")
        case .cancellationPage: return L10n.string("Open cancellation page")
        case .website: return L10n.string("Open website")
        case .search: return L10n.string("Search how to cancel")
        }
    }

    private var conciergeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isStoreBilled ? L10n.string("Refund help") : L10n.string("Email and refund help"))
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)

            if !isStoreBilled {
                conciergeRow(
                    icon: "envelope",
                    title: L10n.string("Draft cancellation email"),
                    detail: L10n.string("Ready-to-send cancellation notice with your plan details"),
                    isPro: !conciergeUnlocked,
                    id: "draftCancelEmailButton"
                ) {
                    openEmailDraft(CancelConcierge.cancellationDraft(for: current, accountEmail: authManager.currentUser?.email))
                }

                Hairline()
            }

            if help.kind == .appleSubscription {
                conciergeRow(
                    icon: "arrow.uturn.backward",
                    title: L10n.string("Request an Apple refund"),
                    detail: L10n.string("Opens Apple's official refund portal."),
                    isPro: false,
                    id: "requestRefundButton"
                ) {
                    if let url = CancelConcierge.appleRefundURL { openURL(url) }
                }
            } else if !isStoreBilled {
                conciergeRow(
                    icon: "arrow.uturn.backward",
                    title: L10n.string("Draft refund email"),
                    detail: L10n.string("Polite request for a recent unwanted charge"),
                    isPro: !conciergeUnlocked,
                    id: "requestRefundButton"
                ) {
                    openEmailDraft(CancelConcierge.refundDraft(for: current, accountEmail: authManager.currentUser?.email))
                }
            }
        }
    }

    private func conciergeRow(icon: String, title: String, detail: String, isPro: Bool, id: String,
                              action: @escaping () -> Void) -> some View {
        Button {
            Feel.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                MarkedWords(alignment: .center, spacing: 12) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .accessibilityHidden(true)
                } words: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: title)
                            .font(.body)
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: detail)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                        if isPro, typeSize.isAccessibilitySize {
                            ProPill().padding(.top, 4)
                        }
                    }
                }
                Spacer(minLength: 8)
                if isPro, !typeSize.isAccessibilitySize { ProPill() }
                RowChevron()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private func openEmailDraft(_ draft: CancelConcierge.Draft) {
        // Show the real personalized subject and opening lines first so Free users see the draft
        // before deciding whether to unlock sending/copying with Pro.
        previewDraft = PresentedDraft(draft: draft)
    }

    private var outcome: some View {
        OutcomeScreen {
            VStack(alignment: .leading, spacing: 20) {
                CancelledSlip(subscription: current)
                if !current.isPausely, difficulty.canRate(serviceName: current.name) {
                    CancelDifficultyPrompt(serviceName: current.name)
                }
            }
        } actions: {
            VStack(spacing: 10) {
                Button { showingReceipt = true } label: { Text("See your Savings Receipt") }
                    .buttonStyle(.ink)
                ShareCancelledButton(subscriptionId: current.id, identifier: "cancelShareSavingsButton")
                Button { dismiss() } label: { Text("Done") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("cancelDoneButton")
            }
        }
    }

    private func markCancelled(nextCharge: Date? = nil) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        if let nextCharge, var dated = store.subscriptions.first(where: { $0.id == subscription.id }) {
            let noon = Calendar.billing.noon(of: nextCharge)
            if dated.status == .trial {
                dated.trialEndsAt = noon
                dated.nextBillingDate = nil
            } else {
                dated.nextBillingDate = noon
            }
            await store.updateSubscription(dated)
        }
        await store.updateSubscriptionStatus(id: subscription.id, status: .cancelled)
        if showsOutcome {
            withAnimation(Motion.unlessReduced(Motion.arrive)) { cancelled = true }
        } else {
            dismiss()
        }
    }
}

/// Optional 1–5 anonymous post-cancellation rating prompt, shown only for signed-in accounts.
struct CancelDifficultyPrompt: View {
    let serviceName: String
    @State private var submittedRating: Int?
    @State private var isSubmitting = false
    @State private var submitFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("How hard was cancelling \(serviceName)?"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)

            if let rating = submittedRating {
                Text(L10n.string("Rated \(L10n.number(rating)) of \(L10n.number(5)) — thanks for helping others."))
                    .font(.footnote)
                    .foregroundStyle(Color.kept)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Facts(L10n.breakingAfterDots(L10n.string("Anonymous · \(L10n.number(1)) is quick · \(L10n.number(5)) is hard")))
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                LineOrStack(spacing: 8, lineSpacing: 8) {
                    ForEach(1...5, id: \.self) { level in
                        Button {
                            guard !isSubmitting else { return }
                            Feel.selection()
                            isSubmitting = true
                            submitFailed = false
                            Task {
                                let ok = await CancelDifficultyService.shared.submit(serviceName: serviceName, difficulty: level)
                                isSubmitting = false
                                if ok {
                                    submittedRating = level
                                } else {
                                    submitFailed = true
                                }
                            }
                        } label: {
                            Text(verbatim: L10n.number(level))
                                .font(.proof(.body, weight: .semibold))
                                .foregroundStyle(Color.inkText)
                                .tapArea()
                                .overlay(RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous).stroke(Color.outline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)
                        .accessibilityLabel(L10n.string("Difficulty \(level) of 5"))
                        .accessibilityIdentifier("difficultyRating_\(level)")
                    }
                }
                if submitFailed {
                    Text("Couldn't save your rating right now. Try again.")
                        .font(.footnote)
                        .foregroundStyle(Color.due)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "When would it have charged next?", asked once on cancelling a subscription that has no renewal day.
private struct NextChargeQuestion: View {
    let name: String
    var isTrial: Bool = false
    @Binding var day: Date
    let onSave: () -> Void
    let onUnknown: () -> Void
    let onCancel: () -> Void

    private var pickerRange: ClosedRange<Date> {
        let start = isTrial
            ? Calendar.billing.startOfDay(for: Date())
            : (Calendar.billing.date(byAdding: .month, value: -1, to: Date()) ?? Date())
        let end = Calendar.billing.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        return start...end
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    LeaveButton("Cancel") { onCancel() }
                    Spacer()
                }
                Text(isTrial
                     ? L10n.string("When would \(name)'s free trial have ended?")
                     : L10n.string("When would \(name) have charged next?"))
                    .font(.question(.title2))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Your Savings Receipt counts the charges you avoid from that day. It's on your bank statement or in the service's account.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                DatePicker(isTrial ? L10n.string("Trial ends") : L10n.string("Next charge"), selection: $day,
                           in: pickerRange,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, L10n.locale)
                    .tint(Color.inkText)
                    .accessibilityIdentifier("nextChargePicker")
                Button(action: onSave) { Text("Save and mark cancelled") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("saveNextChargeButton")
                Button(action: onUnknown) { Text("I don't know") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("unknownNextChargeButton")
            }
            .padding(Layout.margin)
        }
        .readableScroll()
        .inkScreen()
        .preferredColorScheme(.dark)
    }
}
