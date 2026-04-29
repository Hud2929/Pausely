import Foundation
import XCTest
@testable import Pausely

@MainActor
final class WidgetDataStoreTests: XCTestCase {

    private var sut: WidgetDataStore!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "test.pausely.widget")
        testDefaults.removePersistentDomain(forName: "test.pausely.widget")
        sut = WidgetDataStore.forTesting(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "test.pausely.widget")
        sut = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Publish & Read

    func testPublish_emptySubscriptions() {
        sut.publish(subscriptions: [])
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 0)
        XCTAssertEqual(summary.activeCount, 0)
        XCTAssertEqual(summary.upcomingCount, 0)
        XCTAssertEqual(summary.topInsight, "Add your first subscription to start tracking")
    }

    func testPublish_singleActiveSubscription() {
        let sub = TestFactories.makeSubscription(
            name: "Netflix",
            amount: 15.99,
            billingFrequency: .monthly,
            status: .active
        )
        sut.publish(subscriptions: [sub])
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 15.99, accuracy: 0.01)
        XCTAssertEqual(summary.activeCount, 1)
        XCTAssertEqual(summary.upcomingCount, 0)
    }

    func testPublish_ignoresCancelledSubscriptionsInSpend() {
        let active = TestFactories.makeSubscription(
            name: "Netflix",
            amount: 15.99,
            status: .active
        )
        let cancelled = TestFactories.makeSubscription(
            name: "Spotify",
            amount: 9.99,
            status: .cancelled
        )
        sut.publish(subscriptions: [active, cancelled])
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 15.99, accuracy: 0.01)
        XCTAssertEqual(summary.activeCount, 1)
    }

    func testPublish_multipleSubscriptions() {
        let subs = [
            TestFactories.makeSubscription(name: "A", amount: 10, status: .active),
            TestFactories.makeSubscription(name: "B", amount: 20, status: .active),
            TestFactories.makeSubscription(name: "C", amount: 30, status: .active)
        ]
        sut.publish(subscriptions: subs)
        let summary = sut.readSummary()

        XCTAssertEqual(summary.monthlySpend, 60, accuracy: 0.01)
        XCTAssertEqual(summary.activeCount, 3)
    }

    func testPublish_highSpendInsight() {
        let sub = TestFactories.makeSubscription(amount: 250, status: .active)
        sut.publish(subscriptions: [sub])
        let summary = sut.readSummary()

        XCTAssertTrue(summary.topInsight.contains("250"))
        XCTAssertTrue(summary.topInsight.contains("review"))
    }

    func testPublish_pausedInsight() {
        let active = TestFactories.makeSubscription(amount: 10, status: .active)
        let paused = TestFactories.makeSubscription(amount: 10, status: .active, pausedUntil: Calendar.current.date(byAdding: .day, value: 7, to: Date()))
        sut.publish(subscriptions: [active, paused])
        let summary = sut.readSummary()

        XCTAssertTrue(summary.topInsight.contains("paused"))
    }

    // MARK: - Live Activity Data

    func testReadLiveActivityData_withUpcomingRenewal() {
        let future = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let sub = TestFactories.makeSubscription(
            name: "Hulu",
            amount: 12.99,
            billingFrequency: .monthly,
            status: .active,
            nextBillingDate: future
        )
        sut.publish(subscriptions: [sub])
        let data = sut.readLiveActivityData()

        XCTAssertEqual(data.subscriptionName, "Hulu")
        XCTAssertEqual(data.amount, 12.99, accuracy: 0.01)
        XCTAssertEqual(data.frequency, "Monthly")
        // Allow 2-3 days due to time-of-day boundary
        XCTAssertTrue(data.daysUntilRenewal == 2 || data.daysUntilRenewal == 3)
    }

    func testReadLiveActivityData_fallbackToFirstActive() {
        let sub = TestFactories.makeSubscription(
            name: "Disney+",
            amount: 7.99,
            status: .active
        )
        sut.publish(subscriptions: [sub])
        let data = sut.readLiveActivityData()

        XCTAssertEqual(data.subscriptionName, "Disney+")
        XCTAssertEqual(data.amount, 7.99, accuracy: 0.01)
    }

    func testReadLiveActivityData_defaultsWhenEmpty() {
        let data = sut.readLiveActivityData()
        XCTAssertEqual(data.subscriptionName, "Subscription")
        XCTAssertEqual(data.frequency, "Monthly")
    }
}
