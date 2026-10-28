import Foundation
@preconcurrency import Network
@preconcurrency import Dispatch

/// A minimal, read-only IMAP client (RFC 3501) over TLS. It can sign in, list folders, open a folder
/// read-only (EXAMINE), search, and fetch with BODY.PEEK, so it never marks mail as read or changes anything.
/// Commands run one at a time. Passwords are never logged or included in errors.
actor IMAPClient {
    struct Configuration {
        var host: String
        var port: UInt16 = 993
        var commandTimeout: TimeInterval = 40
        /// DEBUG only: plain TCP to localhost, for the end-to-end test server. Ignored in release builds
        /// and for any other host.
        var allowsInsecureLocalhost = false

        var usesPlainTCP: Bool {
            #if DEBUG
            return allowsInsecureLocalhost && (host == "127.0.0.1" || host == "localhost")
            #else
            return false
            #endif
        }
    }

    let configuration: Configuration
    private var connection: NWConnection?
    private var buffer: [UInt8] = []
    private var tagCounter = 0
    private var busy = false
    private(set) var capabilities: Set<String> = []
    private(set) var selectedFolder: String?

    init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - Session

    func connect() async throws {
        let parameters: NWParameters
        if configuration.usesPlainTCP {
            parameters = .tcp
        } else {
            let tls = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
            parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        }
        guard let port = NWEndpoint.Port(rawValue: configuration.port) else { throw MailboxError.notConfigured("Invalid port") }
        let connection = NWConnection(host: NWEndpoint.Host(configuration.host), port: port, using: parameters)
        self.connection = connection
        try await Self.waitUntilReady(connection, timeout: configuration.commandTimeout)

        let greeting = try await readResponse()
        switch greeting.status {
        case "OK", "PREAUTH": break
        case "BYE": throw MailboxError.server(greeting.text.isEmpty ? "The server closed the connection." : greeting.text)
        default: throw MailboxError.server("Unexpected greeting from the mail server.")
        }
        if greeting.code.first?.uppercased() == "CAPABILITY" {
            capabilities = Set(greeting.code.dropFirst().map { $0.uppercased() })
        } else {
            try await refreshCapabilities()
        }
    }

    func refreshCapabilities() async throws {
        let result = try await run([.raw("CAPABILITY")])
        for response in result.untagged where response.status == "CAPABILITY" {
            capabilities = Set(response.tokens.compactMap { $0.text?.uppercased() })
        }
        updateCapabilities(from: result.tagged)
    }

    func login(user: String, password: String) async throws {
        do {
            if capabilities.contains("LOGINDISABLED") {
                guard capabilities.contains("AUTH=PLAIN"), capabilities.contains("SASL-IR") else {
                    throw MailboxError.insecure("This server doesn't allow a secure password sign-in.")
                }
                let token = Data("\u{0}\(user)\u{0}\(password)".utf8).base64EncodedString()
                let result = try await run([.raw("AUTHENTICATE PLAIN " + token)], sensitive: true)
                updateCapabilities(from: result.tagged)
            } else {
                let result = try await run([.raw("LOGIN"), .string(user), .string(password)], sensitive: true)
                updateCapabilities(from: result.tagged)
            }
        } catch MailboxError.server(let detail) {
            throw MailboxError.authFailed(Self.friendlyAuthMessage(detail))
        }
        if !capabilities.contains("IMAP4REV1") && !capabilities.contains("IMAP4REV2") {
            try await refreshCapabilities()
        }
    }

    func listFolders() async throws -> [IMAPParser.Folder] {
        let result = try await run([.raw("LIST"), .string(""), .string("*")])
        return result.untagged.compactMap(IMAPParser.folder)
    }

    struct FolderStatus: Equatable {
        var exists: Int = 0
        var uidValidity: UInt32?
        var uidNext: UInt32?
    }

    /// Opens a folder read-only.
    func examine(_ folder: String) async throws -> FolderStatus {
        let result = try await run([.raw("EXAMINE"), .string(folder)])
        var status = FolderStatus()
        for response in result.untagged {
            if response.status == "EXISTS", let count = response.number { status.exists = Int(count) }
            if response.code.count >= 2 {
                let value = UInt32(response.code[1])
                if response.code[0].uppercased() == "UIDVALIDITY" { status.uidValidity = value }
                if response.code[0].uppercased() == "UIDNEXT" { status.uidNext = value }
            }
        }
        selectedFolder = folder
        return status
    }

    func uidSearch(_ key: IMAPSearchKey) async throws -> [UInt32] {
        var arguments: [IMAPArgument] = [.raw("UID SEARCH")]
        if key.needsUTF8 { arguments.append(.raw("CHARSET UTF-8")) }
        arguments += key.arguments
        let result = try await run(arguments)
        return result.untagged.flatMap(IMAPParser.searchResults)
    }

    /// `items` is the FETCH attribute list, e.g. "(UID INTERNALDATE BODY.PEEK[HEADER.FIELDS (FROM SUBJECT)])".
    /// Only PEEK forms are allowed, so fetching never marks mail as read.
    func uidFetch(_ uids: [UInt32], items: String) async throws -> [IMAPParser.FetchItem] {
        guard !uids.isEmpty else { return [] }
        precondition(!items.uppercased().contains("BODY[") || items.uppercased().contains("BODY.PEEK["),
                     "Use BODY.PEEK so fetching never marks mail as read")
        let set = Self.sequenceSet(uids)
        let result = try await run([.raw("UID FETCH \(set) \(items)")])
        return result.untagged.compactMap(IMAPParser.fetchItem)
    }

    func logout() async {
        if connection != nil { _ = try? await run([.raw("LOGOUT")]) }
        cancel()
    }

    func cancel() {
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        selectedFolder = nil
    }

    // MARK: - Command loop

    private struct CommandResult {
        var untagged: [IMAPResponse]
        var tagged: IMAPResponse
    }

    private func run(_ arguments: [IMAPArgument], sensitive: Bool = false) async throws -> CommandResult {
        guard !busy else { throw MailboxError.server("Another command is still running.") }
        busy = true
        defer { busy = false }
        guard connection != nil else { throw MailboxError.network("Not connected.") }

        tagCounter += 1
        let tag = "P\(tagCounter)"
        var line = Data((tag + " ").utf8)
        let literalPlus = capabilities.contains("LITERAL+")

        for (index, argument) in arguments.enumerated() {
            if index > 0 { line.append(32) }
            switch argument {
            case .raw(let text):
                line.append(contentsOf: Array(text.utf8))
            case .string(let value):
                if IMAPArgument.needsLiteral(value) {
                    let bytes = Array(value.utf8)
                    line.append(contentsOf: Array("{\(bytes.count)\(literalPlus ? "+" : "")}\r\n".utf8))
                    if !literalPlus {
                        try await send(line)
                        line.removeAll()
                        let next = try await readResponse()
                        guard next.kind == .continuation else {
                            throw MailboxError.server(next.text.isEmpty ? "The server refused the request." : next.text)
                        }
                    }
                    line.append(contentsOf: bytes)
                } else {
                    line.append(contentsOf: Array(IMAPArgument.quoted(value).utf8))
                }
            }
        }
        line.append(contentsOf: [13, 10])
        try await send(line)

        var untagged: [IMAPResponse] = []
        while true {
            let response = try await readResponse()
            switch response.kind {
            case .untagged:
                if response.status == "BYE", !(arguments.first == .raw("LOGOUT")) {
                    throw MailboxError.server(response.text.isEmpty ? "The server closed the connection." : response.text)
                }
                untagged.append(response)
            case .continuation:
                continue
            case .tagged(let responseTag):
                guard responseTag == tag else { continue }
                if response.status == "OK" { return CommandResult(untagged: untagged, tagged: response) }
                if response.code.first?.uppercased() == "AUTHENTICATIONFAILED" || response.code.first?.uppercased() == "AUTHORIZATIONFAILED" {
                    throw MailboxError.server(response.text.isEmpty ? "Sign-in failed." : response.text)
                }
                if sensitive { throw MailboxError.server(response.text.isEmpty ? "Sign-in failed." : response.text) }
                throw MailboxError.server(response.text.isEmpty ? "The server refused the request." : response.text)
            }
        }
    }

    private func updateCapabilities(from response: IMAPResponse) {
        if response.code.first?.uppercased() == "CAPABILITY" {
            capabilities = Set(response.code.dropFirst().map { $0.uppercased() })
        }
    }

    // MARK: - Reading and writing

    private func readResponse() async throws -> IMAPResponse {
        while true {
            if let length = try IMAPFraming.completeResponseLength(in: buffer) {
                let bytes = Array(buffer[0..<length])
                buffer.removeFirst(length)
                return try IMAPParser.parseResponse(bytes)
            }
            guard let connection else { throw MailboxError.network("Not connected.") }
            let chunk = try await Self.receive(on: connection, timeout: configuration.commandTimeout)
            if chunk.isEmpty { throw MailboxError.network("The connection closed.") }
            buffer.append(contentsOf: chunk)
            if buffer.count > IMAPFraming.maxLiteral + 64 * 1024 {
                throw MailboxError.server("The server sent more data than expected.")
            }
        }
    }

    private func send(_ data: Data) async throws {
        guard let connection else { throw MailboxError.network("Not connected.") }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: MailboxError.network(error.localizedDescription)) }
                else { continuation.resume() }
            })
        }
    }

    private static func waitUntilReady(_ connection: NWConnection, timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = ResumeOnce()
            let timer = DispatchWorkItem {
                if once.claim() {
                    connection.cancel()
                    continuation.resume(throwing: MailboxError.network("Timed out connecting."))
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if once.claim() { timer.cancel(); continuation.resume() }
                case .failed(let error):
                    if once.claim() { timer.cancel(); continuation.resume(throwing: Self.describe(error)) }
                case .cancelled:
                    if once.claim() { timer.cancel(); continuation.resume(throwing: MailboxError.cancelled) }
                default:
                    break
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
            connection.start(queue: DispatchQueue(label: "pausely.imap.\(UUID().uuidString)"))
        }
    }

    private static func receive(on connection: NWConnection, timeout: TimeInterval) async throws -> [UInt8] {
        try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce()
            let timer = DispatchWorkItem {
                if once.claim() {
                    connection.cancel()
                    continuation.resume(throwing: MailboxError.network("The mail server stopped responding."))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { data, _, isComplete, error in
                guard once.claim() else { return }
                timer.cancel()
                if let error { continuation.resume(throwing: describe(error)); return }
                if let data, !data.isEmpty { continuation.resume(returning: Array(data)); return }
                if isComplete { continuation.resume(returning: []); return }
                continuation.resume(returning: [])
            }
        }
    }

    private static func describe(_ error: NWError) -> MailboxError {
        switch error {
        case .tls: return .insecure("The mail server's security certificate couldn't be verified.")
        case .dns: return .network("The mail server's address couldn't be found.")
        default: return .network(error.localizedDescription)
        }
    }

    private static func friendlyAuthMessage(_ detail: String) -> String {
        let lower = detail.lowercased()
        if lower.contains("application-specific") || lower.contains("app password") || lower.contains("web login required") {
            return "This provider needs an app password, not your regular password."
        }
        return "The email or app password wasn't accepted. Check both and try again."
    }

    /// "1:3,7,9:10" from UIDs.
    static func sequenceSet(_ uids: [UInt32]) -> String {
        let sorted = Array(Set(uids)).sorted()
        var parts: [String] = []
        var start = sorted.first ?? 0
        var previous = start
        for uid in sorted.dropFirst() {
            if uid == previous + 1 { previous = uid; continue }
            parts.append(start == previous ? "\(start)" : "\(start):\(previous)")
            start = uid
            previous = uid
        }
        if !sorted.isEmpty { parts.append(start == previous ? "\(start)" : "\(start):\(previous)") }
        return parts.joined(separator: ",")
    }
}

/// Makes sure a continuation is resumed exactly once when callbacks race a timer.
final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
