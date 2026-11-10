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
    @State private var errorMessage: String?
    @State private var cancelled = false
    @State private var showingDifficultyRating = false
    @State private var showingReceipt = false

    private var service: SubscriptionService? {
        SubscriptionActionManager.shared.getService(for: subscription.name)
    }

    private var cancelURL: URL? {
        SubscriptionActionManager.shared.generateCancelURL(for: subscription)
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
            if let url = cancelURL { SafariView(url: url).ignoresSafeArea() }
        }
        .sheet(isPresented: $showingReceipt) { SavingsReceiptView() }
        .sheet(isPresented: $showingDifficultyRating, onDismiss: { dismiss() }) {
            CancelDifficultyRatingView(serviceName: subscription.name) {
                showingDifficultyRating = false
            }
        }
        .errorBanner($errorMessage)
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

                            if let service, !service.instructions.isEmpty {
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
                if cancelURL != nil {
                    Button { isShowingSafari = true } label: { Text("Open Cancellation Page") }
                        .buttonStyle(.ink(didOpenPage ? .quiet : .main))
                        .accessibilityIdentifier("openCancellationPageButton")
                } else {
                    Text("No direct cancel link found. Search for \"cancel \(subscription.name)\" in your browser.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Once the person is back from the service's page, this becomes the main action.
                Button { Task { await markCancelled() } } label: {
                    Text(isSaving ? "Saving…" : "I cancelled it")
                }
                .buttonStyle(.ink(didOpenPage || cancelURL == nil ? .main : .quiet))
                .disabled(isSaving)
                .accessibilityIdentifier("iCancelledItButton")
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.ink)
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
        do {
            try await SubscriptionStore.shared.updateSubscriptionStatus(id: subscription.id, status: .cancelled)
            if showsOutcome {
                withAnimation(Motion.unlessReduced(Motion.arrive)) { cancelled = true }
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

/// Puts a paused subscription back to active.
struct RevolutionaryResumeButton: View {
    let subscription: Subscription
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        Button { Task { await performResume() } } label: {
            HStack(spacing: 12) {
                StateMark(state: .paused)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resume Subscription")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                    Group {
                        if let pausedUntil = subscription.pausedUntil {
                            Text("Resumes automatically on \(pausedUntil.formatted(date: .abbreviated, time: .omitted))")
                        } else {
                            Text("Reactivate your subscription")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if isProcessing { ProgressView().tint(Color.inkText) }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .errorBanner($errorMessage)
    }

    private func performResume() async {
        isProcessing = true
        defer { isProcessing = false }
        errorMessage = nil
        do {
            try await SubscriptionStore.shared.resumeSubscription(id: subscription.id)
            NotificationManager.shared.cancelPauseReminder(for: subscription.id)
            Feel.landed()
        } catch {
            errorMessage = "Could not resume: \(error.localizedDescription)"
        }
    }
}
