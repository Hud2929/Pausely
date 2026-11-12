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
    @State private var showingDifficultyRating = false
    @State private var showingReceipt = false

    private var help: CancelHelp { SubscriptionActionManager.shared.cancelHelp(for: subscription) }

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
        .sheet(isPresented: $showingDifficultyRating, onDismiss: { dismiss() }) {
            CancelDifficultyRatingView(serviceName: subscription.name) {
                showingDifficultyRating = false
            }
        }
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

                            if let service = help.service, !service.instructions.isEmpty {
                                Perforation()
                                Text("How to cancel").font(.footnote.weight(.semibold))
                                ForEach(service.instructions.prefix(4)) { step in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(verbatim: "\(step.order)")
                                            .font(.proof(.footnote, weight: .bold))
                                        Text(step.description)
                                            .font(.footnote)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            } else if help.kind == .website {
                                Perforation()
                                Text("Sign in there and cancel from your account or billing settings.")
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
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
                Button { isShowingSafari = true } label: { Text(openLabel) }
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
                Button { showingDifficultyRating = true } label: { Text("Done") }
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
