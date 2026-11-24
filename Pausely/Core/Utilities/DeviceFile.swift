import Foundation

/// A JSON file kept on the device that code may need while the phone is locked: a notification's
/// "Keep it" button and Shortcuts both run in the background.
///
/// Two rules protect what is in it. It is readable from the first unlock after a restart (not only
/// while the phone is unlocked), and a load says whether the file was missing or could not be read,
/// so a caller never mistakes "couldn't read it" for "there is nothing" and writes over it.
@MainActor
enum DeviceFile {
    enum Loaded<Value> {
        case value(Value)
        /// No file yet. Starting empty and saving is safe.
        case missing
        /// The file is there and could not be read. Do not save until a later load succeeds.
        case unreadable
    }

    static func load<Value: Decodable>(_ type: Value.Type, from url: URL, fileManager: FileManager = .default) -> Loaded<Value> {
        guard fileManager.fileExists(atPath: url.path) else { return .missing }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return .unreadable
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let value = try? decoder.decode(Value.self, from: data) {
            return .value(value)
        }
        // Readable, but not something this version understands. Set it aside instead of writing over it.
        let aside = url.deletingLastPathComponent()
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent + "-set-aside-\(Int(Date().timeIntervalSince1970)).json")
        try? fileManager.moveItem(at: url, to: aside)
        PauselyLogger.error("\(url.lastPathComponent) could not be decoded and was set aside", category: "lifecycle")
        return .missing
    }

    static func save<Value: Encodable>(_ value: Value, to url: URL, fileManager: FileManager = .default) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(resourceValues)
    }

    /// Files written by earlier versions were readable only while the phone was unlocked.
    static func relaxProtection(of url: URL, fileManager: FileManager = .default) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(resourceValues)
    }
}
