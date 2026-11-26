//
//  CancellationFlowView.swift
//  Pausely
//
//  4-Step Cancellation Concierge
//

import SwiftUI
import SafariServices
import MessageUI


// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Mail Compose Sheet
struct MailComposeSheet: UIViewControllerRepresentable {
    let subject: String
    let body: String
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            onDismiss()
        }
    }
}

// MARK: - Email Draft Preview Sheet

/// Shows the drafted cancellation or refund email on a paper slip so the user can review it before
/// opening their mail app, copying, or sharing. Works even when Apple Mail is not configured.
struct EmailDraftSheet: View {
    let draft: CancelConcierge.Draft
    var locked: Bool = false
    var paywallContext: PaywallContext = PaywallContext(trigger: .cancelConcierge)
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var showingMailCompose = false
    @State private var showingPaywall = false
    @State private var copied = false

    private var isLocked: Bool { locked && !paymentManager.isUnlocked(.cancelConcierge) }

    private var fullText: String {
        "\(draft.subject)\n\n\(draft.body)"
    }

    private var splitBody: (preview: String, rest: String) {
        let paragraphs = draft.body.components(separatedBy: "\n\n")
        guard paragraphs.count > 1 else { return (draft.body, "") }
        // Show only the personalized greeting unredacted so Free users see real tailoring without giving away the full draft.
        let lead = paragraphs.prefix(1).joined(separator: "\n\n")
        let rest = paragraphs.dropFirst(1).joined(separator: "\n\n")
        return (lead, rest)
    }

    var body: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Close") { dismiss() }
                        .accessibilityIdentifier("emailDraftCloseButton")
                    Spacer()
                }

                Text("Email draft")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                PaperSlip(tornTop: true, tornBottom: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subject")
                                .font(.proof(.caption, weight: .semibold))
                                .foregroundStyle(Color.paperMuted)
                            Text(verbatim: draft.subject)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.paperInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Perforation()

                        if isLocked {
                            let parts = splitBody
                            Text(verbatim: parts.preview)
                                .font(.subheadline)
                                .foregroundStyle(Color.paperInk)
                                .fixedSize(horizontal: false, vertical: true)
                            if !parts.rest.isEmpty {
                                Perforation()
                                Text(verbatim: parts.rest)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.paperMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .redacted(reason: .placeholder)
                                    .accessibilityHidden(true)
                                Text("Pre-filled with your plan, charge, and written confirmation request. Unlock with Pausely Pro to read, copy, or send.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.paperMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            Text(verbatim: draft.body)
                                .font(.subheadline)
                                .foregroundStyle(Color.paperInk)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.top, 16)

                if copied {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.kept)
                            .accessibilityHidden(true)
                        Text("Copied email to clipboard.")
                            .font(.footnote)
                            .foregroundStyle(Color.kept)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 16)
        } actions: {
            VStack(spacing: 10) {
                if isLocked {
                    Button {
                        Feel.selection()
                        showingPaywall = true
                    } label: {
                        Text("Unlock and send with Pro")
                    }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("unlockEmailDraftButton")
                } else {
                    Button {
                        Feel.selection()
                        if MFMailComposeViewController.canSendMail() {
                            showingMailCompose = true
                        } else if let mailto = CancelConcierge.mailtoURL(for: draft) {
                            openURL(mailto) { accepted in
                                if !accepted { copyDraft() }
                            }
                        } else {
                            copyDraft()
                        }
                    } label: {
                        Text("Open in mail")
                    }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("openInMailButton")

                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 10) { secondaryButtons }
                    } else {
                        HStack(spacing: 10) { secondaryButtons }
                    }
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .inkScreen()
        .presentationSizing(.page)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingMailCompose) {
            MailComposeSheet(subject: draft.subject, body: draft.body) {
                showingMailCompose = false
            }
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(context: paywallContext)
        }
    }

    @ViewBuilder
    private var secondaryButtons: some View {
        Button { copyDraft() } label: {
            Text(copied ? "Copied" : "Copy email")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.ink(.quiet))
        .accessibilityIdentifier("copyEmailDraftButton")

        ShareLink(item: fullText, subject: Text(verbatim: draft.subject)) {
            Text("Share")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.ink(.quiet))
        .accessibilityIdentifier("shareEmailDraftButton")
    }

    private func copyDraft() {
        UIPasteboard.general.string = fullText
        Feel.landed()
        copied = true
    }
}

