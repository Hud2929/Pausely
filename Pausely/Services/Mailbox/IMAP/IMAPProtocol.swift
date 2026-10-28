import Foundation

// The pure half of the IMAP client (RFC 3501): framing, parsing and query building on bytes.
// No networking here, so every case can be unit-tested.

// MARK: - Tokens

indirect enum IMAPToken: Equatable {
    case atom(String)
    case number(UInt64)
    case string(Data)      // quoted string or literal
    case list([IMAPToken])
    case nilValue

    var text: String? {
        switch self {
        case .atom(let value): return value
        case .number(let value): return String(value)
        case .string(let data): return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        case .nilValue, .list: return nil
        }
    }

    var data: Data? {
        switch self {
        case .string(let data): return data
        case .atom(let value): return Data(value.utf8)
        default: return nil
        }
    }

    var number: UInt64? {
        switch self {
        case .number(let value): return value
        case .atom(let value): return UInt64(value)
        default: return nil
        }
    }
}

/// One complete server response.
struct IMAPResponse: Equatable {
    enum Kind: Equatable { case untagged, continuation, tagged(String) }
    var kind: Kind
    /// For tagged and status responses: OK, NO, BAD, BYE, PREAUTH. For untagged data: the data name
    /// (CAPABILITY, LIST, SEARCH, FETCH, EXISTS…).
    var status: String?
    /// The number before FETCH / EXISTS / EXPUNGE ("* 12 FETCH …").
    var number: UInt64?
    /// Bracketed response code, e.g. ["UIDVALIDITY", "123"] or ["AUTHENTICATIONFAILED"].
    var code: [String] = []
    /// Remaining tokens after the status or data name.
    var tokens: [IMAPToken] = []
    /// Human-readable text of a status response.
    var text: String = ""
}

enum IMAPProtocolError: Error, Equatable {
    case malformed(String)
    case literalTooLarge(Int)
}

// MARK: - Framing

enum IMAPFraming {
    /// Literals larger than this are refused (the client asks for at most a few MB per message).
    static let maxLiteral = 8 * 1024 * 1024

    /// If `buffer` starts with a complete response (including any literals), returns its length in bytes.
    static func completeResponseLength(in buffer: [UInt8], from start: Int = 0) throws -> Int? {
        var position = start
        while true {
            guard let lineEnd = indexOfLF(buffer, from: position) else { return nil }
            // Does this line end with a literal announcement "{123}" or "{123+}"?
            var end = lineEnd
            if end > position, buffer[end - 1] == 13 { end -= 1 }
            if end > position, buffer[end - 1] == UInt8(ascii: "}"),
               let open = lastIndex(of: UInt8(ascii: "{"), in: buffer, from: position, to: end - 1) {
                var digits = Array(buffer[(open + 1)..<(end - 1)])
                if digits.last == UInt8(ascii: "+") { digits.removeLast() }
                if !digits.isEmpty, digits.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                   let count = Int(String(decoding: digits, as: UTF8.self)) {
                    guard count <= maxLiteral else { throw IMAPProtocolError.literalTooLarge(count) }
                    let literalStart = lineEnd + 1
                    guard buffer.count >= literalStart + count else { return nil }
                    position = literalStart + count
                    continue
                }
            }
            return lineEnd + 1 - start
        }
    }

    private static func indexOfLF(_ buffer: [UInt8], from: Int) -> Int? {
        var index = from
        while index < buffer.count {
            if buffer[index] == 10 { return index }
            index += 1
        }
        return nil
    }

    private static func lastIndex(of byte: UInt8, in buffer: [UInt8], from: Int, to: Int) -> Int? {
        var index = to
        while index >= from {
            if buffer[index] == byte { return index }
            index -= 1
        }
        return nil
    }
}

// MARK: - Parsing

enum IMAPParser {

    static func parseResponse(_ bytes: [UInt8]) throws -> IMAPResponse {
        var reader = Reader(bytes: bytes)
        guard let first = reader.peek() else { throw IMAPProtocolError.malformed("empty") }

        if first == UInt8(ascii: "+") {
            reader.advance()
            reader.skipSpaces()
            return IMAPResponse(kind: .continuation, text: reader.restOfLine())
        }

        let tag = reader.readUntilSpace()
        reader.skipSpaces()
        let kind: IMAPResponse.Kind = tag == "*" ? .untagged : .tagged(tag)
        var response = IMAPResponse(kind: kind)

        // "* 12 FETCH (…)" / "* 3 EXISTS"
        let word = reader.readUntilSpace()
        reader.skipSpaces()
        if let number = UInt64(word), kind == .untagged {
            response.number = number
            response.status = reader.readUntilSpace().uppercased()
            reader.skipSpaces()
        } else {
            response.status = word.uppercased()
        }

        switch response.status ?? "" {
        case "OK", "NO", "BAD", "BYE", "PREAUTH":
            if reader.peek() == UInt8(ascii: "[") {
                reader.advance()
                let codeText = reader.readUntil(UInt8(ascii: "]"))
                reader.advance()
                response.code = codeText.split(separator: " ").map(String.init)
                reader.skipSpaces()
            }
            response.text = reader.restOfLine()
        default:
            response.tokens = try reader.readTokens(until: nil)
        }
        return response
    }

    // MARK: Data responses

    /// "* SEARCH 2 84 882" → [2, 84, 882]
    static func searchResults(_ response: IMAPResponse) -> [UInt32] {
        guard response.status == "SEARCH" || response.status == "ESEARCH" else { return [] }
        return response.tokens.compactMap { $0.number }.compactMap { UInt32(exactly: $0) }
    }

    struct Folder: Equatable {
        var name: String
        var flags: Set<String>
        var isSelectable: Bool { !flags.contains("\\NOSELECT") && !flags.contains("\\NONEXISTENT") }
    }

    /// `* LIST (\HasNoChildren \Archive) "/" "Archive"`
    static func folder(_ response: IMAPResponse) -> Folder? {
        guard response.status == "LIST", response.tokens.count >= 3, case .list(let flagTokens) = response.tokens[0] else { return nil }
        let flags = Set(flagTokens.compactMap { $0.text?.uppercased() })
        guard let name = response.tokens[2].text else { return nil }
        return Folder(name: name, flags: flags)
    }

    struct FetchItem: Equatable {
        var sequence: UInt64
        var uid: UInt32?
        var internalDate: Date?
        var size: Int?
        /// The body section that was asked for (headers or the whole message).
        var section: Data?
    }

    /// `* 12 FETCH (UID 345 INTERNALDATE "…" RFC822.SIZE 2048 BODY[…] {n}…)`
    static func fetchItem(_ response: IMAPResponse) -> FetchItem? {
        guard response.status == "FETCH", let sequence = response.number,
              case .list(let items)? = response.tokens.first else { return nil }
        var result = FetchItem(sequence: sequence)
        var index = 0
        while index + 1 < items.count {
            let key = items[index].text?.uppercased() ?? ""
            let value = items[index + 1]
            if key == "UID" { result.uid = value.number.flatMap { UInt32(exactly: $0) } }
            else if key == "INTERNALDATE" { result.internalDate = value.text.flatMap(parseInternalDate) }
            else if key == "RFC822.SIZE" { result.size = value.number.map { Int($0) } }
            else if key.hasPrefix("BODY[") || key.hasPrefix("BINARY[") || key == "RFC822" || key == "RFC822.HEADER" {
                if case .nilValue = value { result.section = nil } else { result.section = value.data }
            }
            index += 2
        }
        return result
    }

    // MARK: Dates

    private static let internalDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d-MMM-yyyy HH:mm:ss Z"
        return formatter
    }()
    private static let dateLock = NSLock()

    /// "17-Jul-1996 02:44:25 -0700" (the day may be space-padded).
    static func parseInternalDate(_ text: String) -> Date? {
        dateLock.lock(); defer { dateLock.unlock() }
        return internalDateFormatter.date(from: text.trimmingCharacters(in: .whitespaces))
    }

    // MARK: Reader

    struct Reader {
        let bytes: [UInt8]
        var index = 0

        init(bytes: [UInt8]) { self.bytes = bytes }

        func peek() -> UInt8? { index < bytes.count ? bytes[index] : nil }
        mutating func advance() { index += 1 }

        mutating func skipSpaces() {
            while let byte = peek(), byte == 32 { advance() }
        }

        mutating func readUntilSpace() -> String {
            let start = index
            while let byte = peek(), byte != 32, byte != 13, byte != 10 { advance() }
            return String(decoding: bytes[start..<index], as: UTF8.self)
        }

        mutating func readUntil(_ terminator: UInt8) -> String {
            let start = index
            while let byte = peek(), byte != terminator, byte != 13, byte != 10 { advance() }
            return String(decoding: bytes[start..<index], as: UTF8.self)
        }

        mutating func restOfLine() -> String {
            let start = index
            while let byte = peek(), byte != 13, byte != 10 { advance() }
            return String(decoding: bytes[start..<index], as: UTF8.self)
        }

        /// Reads tokens until `terminator` (a closing parenthesis) or the end of the line.
        mutating func readTokens(until terminator: UInt8?) throws -> [IMAPToken] {
            var tokens: [IMAPToken] = []
            while true {
                skipSpaces()
                guard let byte = peek() else {
                    if terminator != nil { throw IMAPProtocolError.malformed("unclosed list") }
                    return tokens
                }
                if byte == 13 || byte == 10 {
                    if terminator != nil { throw IMAPProtocolError.malformed("unclosed list at end of line") }
                    return tokens
                }
                if let terminator, byte == terminator { advance(); return tokens }
                tokens.append(try readToken())
            }
        }

        mutating func readToken() throws -> IMAPToken {
            guard let byte = peek() else { throw IMAPProtocolError.malformed("missing token") }
            switch byte {
            case UInt8(ascii: "("):
                advance()
                return .list(try readTokens(until: UInt8(ascii: ")")))
            case UInt8(ascii: "\""):
                advance()
                var data = Data()
                while let current = peek() {
                    advance()
                    if current == UInt8(ascii: "\\"), let escaped = peek() { data.append(escaped); advance(); continue }
                    if current == UInt8(ascii: "\"") { return .string(data) }
                    data.append(current)
                }
                throw IMAPProtocolError.malformed("unterminated quoted string")
            case UInt8(ascii: "{"):
                advance()
                let digits = readUntil(UInt8(ascii: "}")).replacingOccurrences(of: "+", with: "")
                guard let count = Int(digits), peek() == UInt8(ascii: "}") else { throw IMAPProtocolError.malformed("bad literal") }
                advance()
                if peek() == 13 { advance() }
                guard peek() == 10 else { throw IMAPProtocolError.malformed("literal without line end") }
                advance()
                guard index + count <= bytes.count else { throw IMAPProtocolError.malformed("short literal") }
                let data = Data(bytes[index..<(index + count)])
                index += count
                return .string(data)
            default:
                // An atom. A section like BODY[HEADER.FIELDS (FROM SUBJECT)]<0> is one atom, brackets included.
                let start = index
                var depth = 0
                while let current = peek() {
                    if current == UInt8(ascii: "[") { depth += 1 }
                    else if current == UInt8(ascii: "]") { depth = max(0, depth - 1) }
                    else if depth == 0 && (current == 32 || current == UInt8(ascii: "(") || current == UInt8(ascii: ")")
                                           || current == 13 || current == 10) { break }
                    advance()
                }
                let atom = String(decoding: bytes[start..<index], as: UTF8.self)
                if atom.uppercased() == "NIL" { return .nilValue }
                if let number = UInt64(atom) { return .number(number) }
                return .atom(atom)
            }
        }
    }
}

// MARK: - Commands

/// A piece of a command: plain text, or a string the client sends safely (quoted, or as a literal when it
/// holds characters a quoted string can't).
enum IMAPArgument: Equatable {
    case raw(String)
    case string(String)

    /// True when the string must be sent as a literal (non-ASCII, CR, LF or NUL).
    static func needsLiteral(_ value: String) -> Bool {
        value.utf8.contains { $0 > 0x7E || $0 == 13 || $0 == 10 || $0 == 0 }
    }

    static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

/// Search criteria (RFC 3501 §6.4.4), built from the search plan.
indirect enum IMAPSearchKey: Equatable {
    case since(Date)
    case from(String)
    case subject(String)
    case uidRange(lower: UInt32, upper: UInt32?)
    case or(IMAPSearchKey, IMAPSearchKey)
    case and([IMAPSearchKey])

    /// "OR a OR b c": IMAP's OR takes exactly two keys, so longer lists nest. Balanced to keep it shallow.
    static func anyOf(_ keys: [IMAPSearchKey]) -> IMAPSearchKey? {
        guard !keys.isEmpty else { return nil }
        if keys.count == 1 { return keys[0] }
        let middle = keys.count / 2
        guard let left = anyOf(Array(keys[..<middle])), let right = anyOf(Array(keys[middle...])) else { return nil }
        return .or(left, right)
    }

    var arguments: [IMAPArgument] {
        switch self {
        case .since(let date): return [.raw("SINCE " + IMAPSearchKey.searchDate(date))]
        case .from(let value): return [.raw("FROM"), .string(value)]
        case .subject(let value): return [.raw("SUBJECT"), .string(value)]
        case .uidRange(let lower, let upper): return [.raw("UID \(lower):\(upper.map(String.init) ?? "*")")]
        case .or(let left, let right): return [.raw("OR")] + left.parenthesized + right.parenthesized
        case .and(let keys): return keys.flatMap(\.arguments)
        }
    }

    private var parenthesized: [IMAPArgument] {
        switch self {
        case .and(let keys) where keys.count > 1: return [.raw("(")] + arguments + [.raw(")")]
        default: return arguments
        }
    }

    var needsUTF8: Bool {
        arguments.contains { if case .string(let value) = $0 { return IMAPArgument.needsLiteral(value) }; return false }
    }

    private static let searchDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d-MMM-yyyy"
        return formatter
    }()
    private static let lock = NSLock()

    static func searchDate(_ date: Date) -> String {
        lock.lock(); defer { lock.unlock() }
        return searchDateFormatter.string(from: date)
    }
}
