import SwiftUI

/// Connects an inbox that uses an app password (iCloud, Yahoo, AOL, Gmail without Google sign-in, and any
/// IMAP server). The password is checked against the server before anything is saved, and then lives only
/// in this iPhone's Keychain.
struct IMAPConnectView: View {
    let preset: IMAPPreset?
    /// The address of an inbox being reconnected, filled in for the person.
    var startAddress: String = ""

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
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var portWidth: CGFloat = 88

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
        missing == nil && !connecting
    }

    private var passwordLabel: LocalizedStringKey {
        effectivePreset?.takesMainPassword == true ? "Password" : "App password"
    }

    /// The first thing the form still needs, said under the switched-off button.
    private var missing: String? {
        if !address.contains("@") { return L10n.string("Enter your email address to connect.") }
        if password.isEmpty {
            return effectivePreset?.takesMainPassword == true
                ? L10n.string("Enter your password to connect.") : L10n.string("Paste the app password to connect.")
        }
        if needsServer && serverHost.isEmpty { return L10n.string("Enter your provider's IMAP server to connect.") }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let preset = effectivePreset { steps(preset) }
                    fields
                    VStack(alignment: .leading, spacing: 12) {
                        if let error {
                            ProblemLine(message: error, identifier: "imapError")
                        }
                        Button(action: connect) {
                            if connecting { ProgressView().tint(Color.paperInk) } else { Text("Connect and search") }
                        }
                        .buttonStyle(.ink)
                        .disabled(!canConnect)
                        .accessibilityIdentifier("imapConnect")
                        .accessibilityHint(Text(verbatim: missing ?? ""))
                        // A switched-off button says what it waits for (the rating of 2026-11-22).
                        if let missing, !connecting {
                            Text(verbatim: missing)
                                .font(.footnote)
                                .foregroundStyle(Color.inkTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityHidden(true)
                        }
                        Group {
                            if effectivePreset?.takesMainPassword == true {
                                Text("Pausely only reads. It opens your mailbox read-only and never marks anything as read. The password stays in this iPhone's Keychain.")
                            } else {
                                Text("Pausely only reads. It opens your mailbox read-only and never marks anything as read. The app password stays in this iPhone's Keychain; you can remove it at your provider whenever you like.")
                            }
                        }
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.inkTextMuted)
                }
            }
            .onAppear {
                if address.isEmpty, !startAddress.isEmpty { address = startAddress }
                focused = startAddress.isEmpty ? .address : .password
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            (effectivePreset.map { Text("Connect \($0.name)") } ?? Text("Connect your email"))
                .font(.question(.title, weight: .bold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Group {
                if let preset = effectivePreset, preset.takesMainPassword {
                    Text("Sign in with your \(preset.name) password, or an app password if you use two-factor sign-in.")
                } else if effectivePreset == nil {
                    Text("Enter your email address, an app password and your provider's IMAP server.")
                } else {
                    Text("You'll need an app password: a separate password just for Pausely, so your main password stays private.")
                }
            }
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How to get the app password, before the field that asks for it.
    private func steps(_ preset: IMAPPreset) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(preset.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(index + 1, format: .number)
                        .font(.proof(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(minWidth: 16, alignment: .leading)
                    // An address in a step is never hyphenated: the person types it as written.
                    Text(verbatim: AddressText.inSentence(step))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(verbatim: step))
                }
                .accessibilityElement(children: .combine)
            }
            if let page = preset.passwordPage {
                let name = Self.pageName(page)
                Button(action: { openURL(page) }) {
                    Label("Open \(name.map(AddressText.breakable) ?? preset.name)", systemImage: "arrow.up.forward")
                }
                .buttonStyle(.ink(.quiet))
                .accessibilityLabel(Text("Open \(name ?? preset.name)"))
                .accessibilityIdentifier("imapOpenPasswordPage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Every field is named above its box, as on the account forms: a name written inside the box
    /// is gone the moment something is typed. The server and the port keep an example inside,
    /// because what it shows is what is used when the box is left empty.
    private var fields: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabelledField(label: "Email") {
                InkTextField(placeholder: "", text: $address, keyboardType: .emailAddress, autocapitalization: .never)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .address)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
                    .accessibilityLabel(Text("Email address"))
                    .accessibilityIdentifier("imapAddress")
            }
            LabelledField(label: passwordLabel) {
                HStack(spacing: 10) {
                    InkTextField(placeholder: "", text: $password, isSecure: true, autocapitalization: .never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { if canConnect { connect() } }
                        .accessibilityLabel(Text(passwordLabel))
                        .accessibilityIdentifier("imapPassword")
                    // The system's own paste control: one tap after copying the password, and no permission prompt.
                    PasteButton(payloadType: String.self) { strings in
                        if let pasted = strings.first { password = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.roundedRectangle(radius: Layout.tileRadius))
                    .tint(Color.inkLifted)
                    .accessibilityLabel(Text("Paste app password"))
                    .accessibilityIdentifier("imapPastePassword")
                }
            }
            if needsServer {
                // Side by side, or one above the other at accessibility text sizes, where "Port" no
                // longer fits above a box that narrow.
                let stacked = typeSize.isAccessibilitySize
                let row = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                                  : AnyLayout(HStackLayout(alignment: .bottom, spacing: 10))
                row {
                    LabelledField(label: "IMAP server") {
                        InkTextField(placeholder: suggestedHost ?? "imap.example.com", text: $customHost, keyboardType: .URL, autocapitalization: .never)
                            .autocorrectionDisabled()
                            .focused($focused, equals: .host)
                            .accessibilityLabel(Text("IMAP server"))
                            .accessibilityIdentifier("imapHost")
                    }
                    LabelledField(label: "Port") {
                        InkTextField(placeholder: "993", text: $customPort, keyboardType: .numberPad)
                            .focused($focused, equals: .port)
                            .accessibilityLabel(Text("Port"))
                            .accessibilityIdentifier("imapPort")
                    }
                    .frame(width: stacked ? nil : portWidth)
                }
                Text("Pausely only connects over an encrypted connection (IMAP with SSL/TLS, usually port 993).")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
