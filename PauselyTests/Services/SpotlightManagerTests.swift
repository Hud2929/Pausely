import Foundation
import XCTest
@testable import Pausely

@MainActor
final class SpotlightManagerTests: XCTestCase {

    private var sut: SpotlightManager!

    override func setUp() {
        super.setUp()
        sut = SpotlightManager.shared
        // Clear the index before each test
        let expectation = self.expectation(description: "Delete index")
        sut.deleteIndex()
        // Give Spotlight a moment to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    override func tearDown() {
        sut.deleteIndex()
        sut = nil
        super.tearDown()
    }

    func testIndex_doesNotCrashWithEmptyArray() {
        sut.index(subscriptions: [])
        // If we get here without crashing, the test passes
    }

    func testIndex_doesNotCrashWithSubscriptions() {
        let subs = [
            TestFactories.makeSubscription(name: "Netflix", amount: 15.99, status: .active),
            TestFactories.makeSubscription(name: "Spotify", amount: 9.99, status: .paused)
        ]
        sut.index(subscriptions: subs)
        // If we get here without crashing, the test passes
    }

    func testDelete_doesNotCrash() {
        sut.deleteIndex()
    }

    func testDeleteSubscription_doesNotCrash() {
        sut.delete(subscriptionID: UUID().uuidString)
    }
}
