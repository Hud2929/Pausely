import SwiftUI

/// Connects an inbox that uses an app password (iCloud, Yahoo, AOL, Gmail without Google sign-in, and any
/// IMAP server). The password is checked against the server before anything is saved, and then lives only
/// in this iPhone's Keychain.
struct IMAPConnectView: View {
    let preset: IMAPPreset?

    @ObservedObject private var scanner = InboxScanner.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var address = ""
    @State private var password = ""
    @State private var customHost = ""
    @State private var customPort = ""  // empty means the standard port, 993
    @State private var connecting = false
    @State private var error: String?
    @FocusState private var focused: Field?

    private enum Field { case address, password, host, port }

    /// The preset that applies: the one chosen, or the one matching the address's domain.
    private var effectivePreset: IMAPPreset? {
        preset ?? IMAPPreset.forAddress(address)
    }

    private var needsServer: Bool { effectivePreset == nil }

    /// Most providers name their server imap.<domain>, so that's offered (and used) until one is typed.
    private var suggestedHost: String? {
        let parts = address.trimmingCharacters(in: .whitespaces).lowercased().split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix(".") else { return nil }
        return "imap." + parts[1]
    }

    private var serverHost: String {
        let typed = customHost.trimmingCharacters(in: .whitespaces)
        return typed.isEmpty ? (suggestedHost ?? "") : typed
    }

    private var canConnect: Bool {
        address.contains("@") && !password.isEmpty && (!needsServer || !serverHost.isEmpty) && !connecting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    fields
                    if let preset = effectivePreset { steps(preset) }
                    if let error {
                        Text(error)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color.semanticDestructive)
                            .accessibilityIdentifier("imapError")
                    }
                    connectButton
                    Text("Pausely only reads. It opens your mail read-only, never marks anything as read, and can't send or delete email. The app password stays on this iPhone; remove it at your provider whenever you like.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle(effectivePreset.map { Text(verbatim: $0.name) } ?? Text("Other email"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.accentMint)
                }
            }
            .onAppear { focused = .address }
        }
    }

    private var header: some View {
        (effectivePreset == nil
             ? Text("Enter your email address, an app password and your provider's IMAP server.")
             : Text("Enter your email address and an app password. It's a separate password just for Pausely, so your main password stays private."))
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Color.obsidianTextSecondary)
    }

    private var fields: some View {
        VStack(spacing: 10) {
            TextField("Email address", text: $address, prompt: Text(verbatim: "you@example.com"))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .address)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.obsidianSurface))
                .accessibilityIdentifier("imapAddress")
            SecureField("App password", text: $password)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit { if canConnect { connect() } }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.obsidianSurface))
                .accessibilityIdentifier("imapPassword")
            if needsServer {
                HStack(spacing: 10) {
                    TextField("IMAP server", text: $customHost, prompt: Text(verbatim: suggestedHost ?? "imap.example.com"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .host)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.obsidianSurface))
                        .accessibilityIdentifier("imapHost")
                    TextField("Port", text: $customPort, prompt: Text(verbatim: "993"))
                        .keyboardType(.numberPad)
                        .focused($focused, equals: .port)
                        .frame(width: 70)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.obsidianSurface))
                        .accessibilityIdentifier("imapPort")
                }
                Text("Pausely only connects over an encrypted connection (IMAP with SSL/TLS, usually port 993).")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
        }
        .foregroundStyle(.white)
    }

    private func steps(_ preset: IMAPPreset) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create an app password")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            ForEach(Array(preset.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text(index + 1, format: .number)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.accentMint)
                        .frame(width: 18, alignment: .leading)
                    Text(step)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
            }
            if let page = preset.passwordPage {
                Button {
                    openURL(page)
                } label: {
                    Label("Open \(Self.pageName(page) ?? preset.name)", systemImage: "arrow.up.right.square")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.accentMint)
                }
                .accessibilityIdentifier("imapOpenPasswordPage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.obsidianSurface))
    }

    private var connectButton: some View {
        Button(action: connect) {
            HStack {
                if connecting { ProgressView().tint(.black) }
                (connecting ? Text("Checking…") : Text("Connect"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 16).fill(canConnect ? Color.accentMint : Color.accentMint.opacity(0.4)))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canConnect)
        .accessibilityIdentifier("imapConnect")
    }

    private func connect() {
        error = nil
        connecting = true
        let port = Int(customPort) ?? 993
        Task {
            do {
                _ = try await scanner.connectIMAP(address: address, password: password, preset: effectivePreset,
                                                  host: needsServer ? serverHost : nil,
                                                  port: needsServer ? port : nil)
                password = ""
                connecting = false
                dismiss()
            } catch {
                connecting = false
                self.error = error.localizedDescription
            }
        }
    }

    /// The page the link opens, as people see it in the address bar ("account.apple.com").
    static func pageName(_ url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
