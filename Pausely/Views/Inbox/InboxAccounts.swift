import SwiftUI

/// The connected inboxes, each with its state and its menu, then the way to add another. Shown before a
/// search, after one that found nothing, and under the results.
struct InboxRows: View {
    @ObservedObject var scanner: InboxScanner
    /// Whether "Add another inbox" ends the list: not where the page's main button already says it.
    var showsAdd = true
    let onReconnect: (MailboxAccount) -> Void
    let onAdd: () -> Void
    /// Told the address once an inbox is disconnected, so the page can say it was.
    var onDisconnected: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(scanner.accounts) { account in
                // "searched 2 seconds ago" stood for minutes: the row is drawn again as time passes.
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    InboxAccountRow(account: account, error: scanner.accountErrors[account.id], now: context.date,
                                    onReconnect: { onReconnect(account) },
                                    onDisconnect: {
                                        Task {
                                            await scanner.disconnect(account)
                                            onDisconnected(account.address)
                                        }
                                    })
                }
                Hairline()
            }
            if showsAdd {
                Button(action: onAdd) {
                    Label("Add another inbox", systemImage: "plus")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.inkText)
                        .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addInboxButton")
            }
        }
    }
}

/// One connected inbox: its address, which provider and when it was searched (or why it failed), and a menu
/// to reconnect or disconnect it. Disconnecting waits for a yes: it signs out and forgets what was found there.
struct InboxAccountRow: View {
    let account: MailboxAccount
    let error: String?
    let now: Date
    let onReconnect: () -> Void
    let onDisconnect: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var asking = false

    /// Under the address: why the inbox failed, or its provider and when it was last searched. Under a
    /// minute that is "just now": counted in seconds, the row grew a line and shrank again as "searched 45
    /// seconds ago" came and went (the rating of 2026-11-23).
    static func detail(for account: MailboxAccount, error: String?, now: Date) -> String {
        if let error { return error }
        guard let last = account.lastScan else { return account.providerName }
        if now.timeIntervalSince(last) < 60 { return L10n.string("\(account.providerName) · searched just now") }
        let when = last.formatted(.relative(presentation: .named).locale(L10n.locale))
        return L10n.string("\(account.providerName) · searched \(when)")
    }

    var body: some View {
        let failed = error != nil
        let detail = Self.detail(for: account, error: error, now: now)
        let mark = Image(systemName: failed ? "exclamationmark.circle" : "envelope")
            .font(.body)
            .foregroundStyle(failed ? Color.due : Color.inkTextMuted)
            .accessibilityHidden(true)
        let words = VStack(alignment: .leading, spacing: 2) {
            // Whole, on as many lines as it needs: cut in the middle, two addresses at one
            // provider could not be told apart.
            Text(verbatim: AddressText.breakable(account.address))
                .font(.body.weight(.medium))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: account.address))
            Facts(detail)
                .font(.subheadline)
                .foregroundStyle(failed ? Color.due : Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        let options = Menu {
            if failed {
                Button(action: onReconnect) { Label("Reconnect", systemImage: "arrow.clockwise") }
                    .accessibilityIdentifier("reconnectInbox")
            }
            Button(role: .destructive) {
                asking = true
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
            }
            .accessibilityIdentifier("disconnectInbox")
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
                .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Options for \(account.address)")
        .accessibilityIdentifier("inboxOptions")

        return Group {
            if MarkPlacement.sitsAbove(largeText: typeSize.isAccessibilitySize) {
                // The mark and the options share a line and the address has the row: between
                // them at the largest text size it had half, the envelope lay over its first
                // letters, and "longer-company-name" was cut wherever the line ran out.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        mark
                        Spacer(minLength: 8)
                        options
                    }
                    words
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    mark.frame(width: 28)
                    words
                    Spacer(minLength: 8)
                    options
                }
            }
        }
        .padding(.vertical, 8)
        // One stop for VoiceOver, with what the menu does as its actions: the address, its state and
        // "Options for …" were three stops (the reach rating of 2026-11-22).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(account.address), \(detail)"))
        .accessibilityActions {
            if failed { Button("Reconnect", action: onReconnect) }
            Button("Disconnect") { asking = true }
        }
        .accessibilityIdentifier("inboxRow")
        .asksFirst(Text("Disconnect \(account.address)?"), isPresented: $asking,
                   // What stays is said: ones kept for later stayed on Home after "forgets what it found" (2026-11-23).
                   message: Text("Pausely signs out of this inbox and forgets what it found there. Subscriptions you added, or kept for when there's room, stay.")) {
            Button("Disconnect", role: .destructive, action: onDisconnect)
            Button("Cancel", role: .cancel) {}
        }
    }
}
