import Foundation
import os.log

// MARK: - Structured Logger
/// Replaces ad-hoc `print()` statements with os.log for proper log levels,
/// persistence, and performance. Errors and faults are logged in release builds.
@MainActor
enum PauselyLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app.pausely"

    private static func logger(for category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    static func debug(_ message: String, category: String = "default") {
        #if DEBUG
        logger(for: category).debug("\(message)")
        #endif
    }

    static func info(_ message: String, category: String = "default") {
        logger(for: category).info("\(message)")
    }

    static func error(_ message: String, category: String = "default") {
        logger(for: category).error("\(message)")
    }

    static func fault(_ message: String, category: String = "default") {
        logger(for: category).fault("\(message)")
    }
}
