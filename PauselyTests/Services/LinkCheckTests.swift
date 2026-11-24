import XCTest
@testable import Pausely

/// Every cancellation link the app offers has been requested, and none of them is a page that does
/// not exist. `scripts/links/check_links.py` asks each one and keeps what came back in
/// `scripts/links/checked.json`; a link added or changed later has to go through it too.
///
/// When this was first run, 416 of 1,120 links were dead (404, or no such domain).
final class LinkCheckTests: XCTestCase {

    private struct Checked: Decodable {
        let result: String
        let checked: String
    }

    private func record() throws -> [String: Checked] {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scripts/links/checked.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file.path), "Sources aren't readable from this test run")
        return try JSONDecoder().decode([String: Checked].self, from: Data(contentsOf: file))
    }

    @MainActor
    func testEveryLinkTheAppOffersWasRequestedAndExists() throws {
        let record = try record()
        var links = Set(ServiceDatabase.services.map(\.cancelURL))
        links.formUnion(SubscriptionCatalogService.shared.catalog.compactMap(\.cancellationURL))
        XCTAssertGreaterThan(links.count, 800)

        let neverChecked = links.filter { record[$0] == nil }.sorted()
        XCTAssertEqual(neverChecked, [], "run python3 scripts/links/check_links.py")
        let gone = links.filter { record[$0]?.result == "gone" }.sorted()
        XCTAssertEqual(gone, [], "run python3 scripts/links/check_links.py --repair")
    }

    func testTheRecordSaysWhenEachLinkWasChecked() throws {
        let record = try record()
        XCTAssertTrue(record.values.allSatisfy { ["ok", "walled", "unclear"].contains($0.result) })
        XCTAssertTrue(record.values.allSatisfy { $0.checked.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil })
    }
}
