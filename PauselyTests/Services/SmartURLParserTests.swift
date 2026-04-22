import Foundation
import XCTest
@testable import Pausely

final class SmartURLParserTests: XCTestCase {

    @MainActor
    func testParseURL_netflix() async {
        let parser = SmartURLParser.shared
        let result = await parser.parseURL("https://www.netflix.com")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Netflix")
        XCTAssertEqual(result?.category, .streaming)
        XCTAssertEqual(result?.confidence ?? 0, 0.95, accuracy: 0.01)
    }

    @MainActor
    func testParseURL_spotify() async {
        let parser = SmartURLParser.shared
        let result = await parser.parseURL("https://open.spotify.com")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Spotify")
        XCTAssertEqual(result?.category, .music)
    }

    @MainActor
    func testParseURL_unknownDomain() async {
        let parser = SmartURLParser.shared
        let result = await parser.parseURL("https://unknown-service-12345.com")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.confidence ?? 0, 0.3, accuracy: 0.01)
        XCTAssertEqual(result?.category, .other)
    }

    @MainActor
    func testParseURL_invalidURL() async {
        let parser = SmartURLParser.shared
        let result = await parser.parseURL("")
        XCTAssertNil(result)
    }

    @MainActor
    func testDetectService_spotify() async {
        let parser = SmartURLParser.shared
        let pattern = parser.detectService(from: "Spotify Premium")
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.name, "Spotify")
    }

    @MainActor
    func testDetectService_unknown() async {
        let parser = SmartURLParser.shared
        let pattern = parser.detectService(from: "XYZ Unknown Service")
        XCTAssertNil(pattern)
    }

    @MainActor
    func testParseMultipleURLs() async {
        let parser = SmartURLParser.shared
        let urls = [
            "https://www.netflix.com",
            "https://www.spotify.com",
            "https://unknown-domain-xyz.com"
        ]
        let results = await parser.parseMultipleURLs(urls)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].name, "Netflix")
        XCTAssertEqual(results[1].name, "Spotify")
        XCTAssertEqual(results[2].category, .other)
    }

    @MainActor
    func testParsedSubscriptionConfidenceLevel() async {
        let parser = SmartURLParser.shared
        let high = await parser.parseURL("https://www.netflix.com")
        XCTAssertEqual(high?.confidenceLevel, .high)

        let low = await parser.parseURL("https://some-random-site.com")
        XCTAssertEqual(low?.confidenceLevel, .low)
    }
}
