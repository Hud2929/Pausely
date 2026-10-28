import Foundation

/// Turns a raw email (RFC 5322 + MIME), as IMAP, Microsoft Graph's `$value` and Gmail's `format=raw` all
/// return it, into a `RawEmail`: decoded headers, the plain-text and HTML bodies in the right character set,
/// and the date. Pure and bounded: no network, no disk, capped in size, parts and depth.
enum MIMEParser {
    /// Receipts are small; anything past this is attachments, which are never needed.
    static let maxMessageBytes = 6 * 1024 * 1024
    static let maxParts = 60
    static let maxDepth = 8

    // MARK: - Public

    /// - Parameters:
    ///   - receivedDate: when the provider received the message (IMAP INTERNALDATE, Graph receivedDateTime,
    ///     Gmail internalDate). Preferred over the Date header, which the sender controls.
    static func parse(_ data: Data, id: String, receivedDate: Date? = nil, labelIds: [String] = []) -> RawEmail? {
        let bytes = data.count > maxMessageBytes ? data.prefix(maxMessageBytes) : data
        guard !bytes.isEmpty else { return nil }
        let entity = parseEntity(Data(bytes))
        let headers = firstValues(entity.headers)

        var bodies = Bodies()
        var budget = maxParts
        collectBodies(entity, depth: 0, budget: &budget, into: &bodies)

        guard let date = receivedDate ?? headers["date"].flatMap(parseDate) else { return nil }
        let plain = bodies.plain?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let usePlain = bodies.html == nil || !isStub(plain, html: bodies.html ?? "")
        return RawEmail(id: id, date: date,
                        from: headers["from"] ?? "",
                        subject: headers["subject"] ?? "",
                        bodyText: usePlain ? plain : "",
                        bodyHTML: bodies.html,
                        headers: headers,
                        labelIds: labelIds)
    }

    /// A plain-text part that only points at the HTML ("View this email in your browser"), or that leaves
    /// out every number the HTML has, so the receipt's details are only in the HTML.
    static func isStub(_ plain: String, html: String) -> Bool {
        if plain.count < 40 { return true }
        let lower = plain.lowercased()
        let pointers = ["view this email", "view in browser", "in your browser", "web version", "view online",
                        "html version", "enable html", "afficher dans", "im browser", "en el navegador", "ブラウザ"]
        if plain.count < 400 && pointers.contains(where: lower.contains) { return true }
        let hasDigits = plain.rangeOfCharacter(from: .decimalDigits) != nil
        return !hasDigits && html.rangeOfCharacter(from: .decimalDigits) != nil
    }

    /// Only the header section, for cheap triage before reading a whole message.
    static func parseHeaders(_ data: Data) -> [String: String] {
        firstValues(parseHeaderBlock(data))
    }

    /// The globally unique id of a message (its Message-ID header), normalized, so the same receipt in two
    /// inboxes is recognised as one.
    static func normalizedMessageID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            .lowercased()
        return trimmed.count >= 6 && trimmed.contains("@") ? trimmed : nil
    }

    // MARK: - Entities

    struct Entity {
        var headers: [(name: String, value: String)]
        var body: Data
    }

    private struct Bodies {
        var plain: String?
        var html: String?
    }

    static func parseEntity(_ data: Data) -> Entity {
        let (headerData, body) = splitHeaders(data)
        return Entity(headers: parseHeaderBlock(headerData), body: body)
    }

    private static func collectBodies(_ entity: Entity, depth: Int, budget: inout Int, into bodies: inout Bodies) {
        guard depth <= maxDepth, budget > 0 else { return }
        budget -= 1
        let headers = firstValues(entity.headers)
        let contentType = ContentType(headers["content-type"])
        let disposition = (headers["content-disposition"] ?? "").lowercased()
        if disposition.hasPrefix("attachment") { return }

        if contentType.type == "multipart", let boundary = contentType.parameters["boundary"], !boundary.isEmpty {
            for part in splitMultipart(entity.body, boundary: boundary) {
                collectBodies(parseEntity(part), depth: depth + 1, budget: &budget, into: &bodies)
                if budget <= 0 { return }
            }
            return
        }
        guard contentType.type == "text", ["plain", "html"].contains(contentType.subtype) else { return }
        let decoded = decodeTransfer(entity.body, encoding: headers["content-transfer-encoding"])
        let text = decodeText(decoded, charset: contentType.parameters["charset"])
        if contentType.subtype == "plain", bodies.plain == nil { bodies.plain = text }
        if contentType.subtype == "html", bodies.html == nil { bodies.html = text }
    }

    // MARK: - Headers

    /// Splits at the first empty line (CRLF CRLF, or bare LF LF from some servers).
    static func splitHeaders(_ data: Data) -> (headers: Data, body: Data) {
        let crlf = Data([13, 10, 13, 10]), lf = Data([10, 10])
        let a = data.range(of: crlf), b = data.range(of: lf)
        let split: Range<Data.Index>?
        switch (a, b) {
        case let (a?, b?): split = a.lowerBound <= b.lowerBound ? a : b
        case let (a?, nil): split = a
        case let (nil, b?): split = b
        default: split = nil
        }
        guard let split else { return (data, Data()) }
        return (data[data.startIndex..<split.lowerBound], data[split.upperBound...])
    }

    static func parseHeaderBlock(_ data: Data) -> [(name: String, value: String)] {
        // Headers are ASCII with encoded words, but some senders put raw UTF-8 in them (RFC 6532).
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        var result: [(String, String)] = []
        var currentName: String?
        var currentValue = ""
        func flush() {
            if let name = currentName {
                result.append((name, decodeEncodedWords(currentValue.trimmingCharacters(in: .whitespaces))))
            }
        }
        // Swift treats "\r\n" as one Character, so normalize before splitting into lines.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for rawLine in normalized.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" }) {
            let line = String(rawLine)
            if line.isEmpty { continue }
            if let first = line.first, first == " " || first == "\t" {
                currentValue += " " + line.trimmingCharacters(in: .whitespaces)  // folded continuation
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            flush()
            currentName = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            currentValue = String(line[line.index(after: colon)...])
        }
        flush()
        return result
    }

    /// First occurrence of each header. For trace headers such as Authentication-Results the first is the
    /// topmost, added by the receiving provider, which is the one to trust.
    static func firstValues(_ headers: [(name: String, value: String)]) -> [String: String] {
        var map: [String: String] = [:]
        for (name, value) in headers where map[name] == nil { map[name] = value }
        return map
    }

    // MARK: - RFC 2047 encoded words

    private static let encodedWord = try! NSRegularExpression(  // swiftlint:disable:this force_try
        pattern: #"=\?([^?\s]+)\?([BbQq])\?([^?\s]*)\?="#)

    static func decodeEncodedWords(_ value: String) -> String {
        guard value.contains("=?") else { return value }
        let ns = value as NSString
        let matches = encodedWord.matches(in: value, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return value }
        var output = ""
        var cursor = 0
        var previousWasEncoded = false
        for match in matches {
            let between = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            // Whitespace between two encoded words is dropped (RFC 2047 §6.2).
            if !(previousWasEncoded && between.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                output += between
            }
            let charset = ns.substring(with: match.range(at: 1))
            let mode = ns.substring(with: match.range(at: 2)).uppercased()
            let payload = ns.substring(with: match.range(at: 3))
            let bytes: Data? = mode == "B"
                ? Data(base64Encoded: paddedBase64(payload))
                : decodeQuotedPrintable(Data(payload.replacingOccurrences(of: "_", with: " ").utf8), header: true)
            if let bytes {
                output += decodeText(bytes, charset: charset.components(separatedBy: "*").first)
            } else {
                output += ns.substring(with: match.range)
            }
            cursor = match.range.location + match.range.length
            previousWasEncoded = true
        }
        output += ns.substring(from: cursor)
        return output
    }

    private static func paddedBase64(_ value: String) -> String {
        var text = value
        while text.count % 4 != 0 { text += "=" }
        return text
    }

    // MARK: - Content-Type

    struct ContentType {
        var type = "text"
        var subtype = "plain"
        var parameters: [String: String] = [:]

        init(_ header: String?) {
            guard let header, !header.isEmpty else { return }
            let pieces = Self.splitParameters(header)
            let mime = (pieces.first ?? "").trimmingCharacters(in: .whitespaces).lowercased()
            let slash = mime.split(separator: "/", maxSplits: 1)
            if slash.count == 2 {
                type = String(slash[0]).trimmingCharacters(in: .whitespaces)
                subtype = String(slash[1]).trimmingCharacters(in: .whitespaces)
            }
            for piece in pieces.dropFirst() {
                guard let equals = piece.firstIndex(of: "=") else { continue }
                var name = piece[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
                var value = piece[piece.index(after: equals)...].trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                    value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
                }
                if name.hasSuffix("*") {  // RFC 2231: charset''percent-encoded
                    name.removeLast()
                    if let quote = value.range(of: "''") { value = String(value[quote.upperBound...]) }
                    value = value.removingPercentEncoding ?? value
                }
                if parameters[name] == nil { parameters[name] = value }
            }
        }

        /// Splits on ";" outside quotes.
        static func splitParameters(_ header: String) -> [String] {
            var parts: [String] = []
            var current = ""
            var inQuotes = false
            var escaped = false
            for character in header {
                if escaped { current.append(character); escaped = false; continue }
                if character == "\\" && inQuotes { current.append(character); escaped = true; continue }
                if character == "\"" { inQuotes.toggle() }
                if character == ";" && !inQuotes { parts.append(current); current = ""; continue }
                current.append(character)
            }
            parts.append(current)
            return parts
        }
    }

    // MARK: - Multipart

    static func splitMultipart(_ body: Data, boundary: String) -> [Data] {
        let delimiter = Data(("--" + boundary).utf8)
        var parts: [Data] = []
        var searchStart = body.startIndex
        var partStart: Data.Index?
        while let found = body.range(of: delimiter, in: searchStart..<body.endIndex) {
            // A delimiter only counts at the start of a line.
            let atLineStart = found.lowerBound == body.startIndex || body[found.lowerBound - 1] == 10
            guard atLineStart else { searchStart = found.upperBound; continue }
            if let start = partStart {
                var end = found.lowerBound
                if end > start, body[end - 1] == 10 { end -= 1 }
                if end > start, body[end - 1] == 13 { end -= 1 }
                parts.append(body[start..<max(start, end)])
                if parts.count >= maxParts { break }
            }
            let afterDelimiter = found.upperBound
            if afterDelimiter + 1 < body.endIndex, body[afterDelimiter] == 45, body[afterDelimiter + 1] == 45 { break }  // "--" closes
            guard let lineEnd = body[afterDelimiter...].firstIndex(of: 10) else { break }
            partStart = lineEnd + 1
            searchStart = lineEnd + 1
        }
        return parts
    }

    // MARK: - Transfer encodings and character sets

    static func decodeTransfer(_ data: Data, encoding: String?) -> Data {
        switch (encoding ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "base64":
            return Data(base64Encoded: data, options: .ignoreUnknownCharacters) ?? data
        case "quoted-printable":
            return decodeQuotedPrintable(data, header: false) ?? data
        default:
            return data
        }
    }

    static func decodeQuotedPrintable(_ data: Data, header: Bool) -> Data? {
        var output = Data(capacity: data.count)
        var index = data.startIndex
        func hexValue(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 48...57: return byte - 48
            case 65...70: return byte - 55
            case 97...102: return byte - 87
            default: return nil
            }
        }
        while index < data.endIndex {
            let byte = data[index]
            if byte == 61 {  // "="
                let next = index + 1
                if next < data.endIndex, data[next] == 13, next + 1 < data.endIndex, data[next + 1] == 10 {
                    index = next + 2; continue  // soft line break CRLF
                }
                if next < data.endIndex, data[next] == 10 { index = next + 1; continue }  // soft break LF
                if next + 1 < data.endIndex, let high = hexValue(data[next]), let low = hexValue(data[next + 1]) {
                    output.append(high << 4 | low)
                    index = next + 2
                    continue
                }
                output.append(byte)  // malformed: keep as is
                index = next
                continue
            }
            output.append(byte)
            index += 1
        }
        return output
    }

    /// Bytes to text in the declared character set, falling back to UTF-8, then Windows-1252, then Latin-1
    /// (which can decode any bytes), so a body is never silently dropped.
    static func decodeText(_ data: Data, charset: String?) -> String {
        if let charset, let encoding = stringEncoding(forCharset: charset), let text = String(data: data, encoding: encoding) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    static func stringEncoding(forCharset charset: String) -> String.Encoding? {
        let name = charset.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))).lowercased()
        switch name {
        case "utf-8", "utf8": return .utf8
        case "us-ascii", "ascii": return .utf8  // ASCII is a subset; tolerates mislabelled UTF-8
        case "iso-8859-1", "latin1", "latin-1": return .isoLatin1
        case "windows-1252", "cp1252": return .windowsCP1252
        default:
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        }
    }

    // MARK: - Dates

    private static let dateFormats = [
        "EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm Z", "d MMM yyyy HH:mm Z",
        "EEE, d MMM yy HH:mm:ss Z", "d MMM yy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss zzz", "d MMM yyyy HH:mm:ss zzz"
    ]

    private static let dateFormatters: [DateFormatter] = dateFormats.map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }

    private static let dateLock = NSLock()

    static func parseDate(_ value: String) -> Date? {
        // Drop comments such as "(UTC)" and collapse whitespace.
        var text = value.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(of: " UT$", with: " +0000", options: .regularExpression)
            .replacingOccurrences(of: " GMT$", with: " +0000", options: .regularExpression)
        dateLock.lock()
        defer { dateLock.unlock() }
        for formatter in dateFormatters {
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
