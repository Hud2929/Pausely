import SwiftUI
import SafariServices

/// Cancelling: the steps on a slip, the service's own cancellation page, and "I cancelled it".
/// Pausely never cancels anything itself; it records the cancellation once the person confirms it.
struct CancelSubscriptionFlow: View {
    let subscription: Subscription
    /// False when the screen underneath shows the torn slip itself (the Renewal Verdict).
    var showsOutcome = true

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingSafari = false
    @State private var didOpenPage = false
    @State private var isSaving = false
    @State private var cancelled = false
    @State private var showingReceipt = false
    @Environment(\.openURL) private var openURL

    private var help: CancelHelp { CancelHelp.find(for: subscription) }

    /// Apple's own steps for a subscription it bills, as published on 29 September 2026
    /// (support.apple.com/118428). The same for every Apple subscription, so they can be checked.
    private var appleSteps: [String] {
        [L10n.string("Open Settings and tap your name."),
         L10n.string("Tap Subscriptions."),
         L10n.string("Tap \(subscription.name)."),
         L10n.string("Tap Cancel Subscription. You may need to scroll down to find it.")]
    }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            if cancelled && showsOutcome {
                outcome.transition(.opacity)
            } else {
                steps
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingSafari, onDismiss: { didOpenPage = true }) {
            if let url = help.link { SafariView(url: url).ignoresSafeArea() }
        }
        .sheet(isPresented: $showingReceipt) { SavingsReceiptView() }
    }

    private var steps: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Text("Close")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkTextMuted)
                                .frame(minHeight: Layout.tapTarget)
                                .contentShape(Rectangle())
                        }
                        Spacer()
                    }

                    PaperSlip(tornTop: true, tornBottom: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ServiceLogoView(name: subscription.name, category: subscription.category, size: 36)
                                Text(L10n.string("That's \(MoneyFormat.string(subscription.annualCost, subscription.currency)) a year"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.paperMuted)
                            }
                            Text("Cancel \(subscription.name)")
                                .font(.question(.title))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)

                            switch help.kind {
                            case .appleSubscription:
                                Perforation()
                                Text("How to cancel").font(.footnote.weight(.semibold))
                                ForEach(Array(appleSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(verbatim: "\(index + 1)")
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
                            case .cancellationPage, .website:
                                Perforation()
                                Text(L10n.string("You cancel on \(subscription.name)'s own site: sign in, then look under account or billing."))
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            case .search:
                                EmptyView()
                            }
                        }
                    }
                    .padding(.top, 4)

                    Text("Pausely keeps it in your list as cancelled and adds the charges you avoid to your Savings Receipt.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                // The button says what it opens: the service's cancellation page, its website, or a search.
                Button {
                    // Apple's link opens the person's subscriptions in Settings; the rest open here.
                    if help.kind == .appleSubscription, let link = help.link {
                        openURL(link)
                        didOpenPage = true
                    } else {
                        isShowingSafari = true
                    }
                } label: { Text(openLabel) }
                    .buttonStyle(.ink(didOpenPage ? .quiet : .main))
                    .accessibilityIdentifier("openCancellationPageButton")

                // Once the person is back from the service's page, this becomes the main action.
                Button { Task { await markCancelled() } } label: {
                    Text(isSaving ? "Saving…" : "I cancelled it")
                }
                .buttonStyle(.ink(didOpenPage ? .main : .quiet))
                .disabled(isSaving)
                .accessibilityIdentifier("iCancelledItButton")
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.ink)
        }
    }

    private var openLabel: String {
        switch help.kind {
        case .appleSubscription: return L10n.string("Open Your Subscriptions")
        case .cancellationPage: return L10n.string("Open Cancellation Page")
        case .website: return L10n.string("Open Website")
        case .search: return L10n.string("Search How to Cancel")
        }
    }

    private var outcome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            CancelledSlip(subscription: subscription)
            Spacer(minLength: 24)
            VStack(spacing: 10) {
                Button { showingReceipt = true } label: { Text("See your Savings Receipt") }
                    .buttonStyle(.ink)
                Button { dismiss() } label: { Text("Done") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("cancelDoneButton")
            }
        }
        .padding(.horizontal, Layout.margin)
        .padding(.bottom, 12)
    }

    private func markCancelled() async {
        isSaving = true
        defer { isSaving = false }
        await SubscriptionStore.shared.updateSubscriptionStatus(id: subscription.id, status: .cancelled)
        if showsOutcome {
            withAnimation(Motion.unlessReduced(Motion.arrive)) { cancelled = true }
        } else {
            dismiss()
        }
    }
}
