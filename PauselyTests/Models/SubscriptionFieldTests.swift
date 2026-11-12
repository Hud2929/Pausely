import XCTest
@testable import Pausely

/// Every field a subscription has is read by something: a screen, the renewal engine, the export.
/// The record once carried fourteen that nothing read (scores, a pause link, a logo address, a
/// description, usage minutes), several of them sent to the server on every change. A field added
/// without a reader fails here.
final class SubscriptionFieldTests: XCTestCase {

    func testEveryFieldOfASubscriptionIsReadSomewhere() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let model = root.appendingPathComponent("Pausely/Models/Subscription.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: model.path), "Sources aren't readable from this test run")

        // The fields: the cases of the model's CodingKeys.
        let text = try String(contentsOf: model, encoding: .utf8)
        let keysBlock = try XCTUnwrap(text.range(of: "enum CodingKeys: String, CodingKey {").map { text[$0.upperBound...] })
        let block = keysBlock[..<(try XCTUnwrap(keysBlock.firstIndex(of: "}")))]
        let fields = block.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("case ") }
            .flatMap { $0.replacingOccurrences(of: "case ", with: "").components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        XCTAssertEqual(fields.sorted(), ["amount", "billingFrequency", "category", "createdAt", "currency", "id", "name",
                                         "nextBillingDate", "notifyBeforeDays", "status", "trialEndsAt"])

        // Read somewhere other than the model itself and the record that carries it to the server.
        var sources = ""
        for folder in ["Pausely", "PauselyWidget"] {
            let files = try XCTUnwrap(FileManager.default.enumerator(at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" {
                if file.lastPathComponent == "Subscription.swift" || file.lastPathComponent == "SupabaseManager.swift" { continue }
                sources += try String(contentsOf: file, encoding: .utf8)
            }
        }
        let unread = fields.filter { field in
            sources.range(of: "\\.\(field)\\b", options: .regularExpression) == nil
        }
        XCTAssertEqual(unread, [], "Stored and read by nothing")
    }
}
