import XCTest
@testable import Pausely

/// What reaches the database and what comes back: renewal dates survive the round trip,
/// cleared dates clear on the server, and merging never loses this iPhone's work.
@MainActor
final class SubscriptionSyncTests: XCTestCase {

    private func day(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

    private func json(_ record: SubscriptionRecord) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
    }

    // MARK: The record sent to the database

    func testTheRenewalDateIsSent() throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", nextBillingDate: day("2026-11-20T12:00:00Z"))
        let sent = try json(SubscriptionRecord(from: sub))
        XCTAssertEqual(sent["next_billing_date"] as? String, "2026-11-20T12:00:00Z")
        XCTAssertNil(sent["paused_until"], "the removed pause is never written, so an older row's value is left alone")
    }

    func testClearedDatesAreSentAsNullAndServerOwnedFieldsAreLeftOut() throws {
        let sub = TestFactories.makeSubscription(name: "Hulu", nextBillingDate: nil)
        let sent = try json(SubscriptionRecord(from: sub))
        XCTAssertTrue(sent["next_billing_date"] is NSNull, "a cleared renewal date must clear on the server")
        XCTAssertTrue(sent["trial_ends_at"] is NSNull)
        XCTAssertNil(sent["user_id"], "an update must never null the owner")
        XCTAssertNil(sent["created_at"])
    }

    // MARK: What comes back

    func testDatabaseRowsKeepTheirDates() throws {
        // As PostgREST returns timestamptz: offsets, and microseconds on defaults like created_at.
        let row = """
        {"id":"7B8D7A51-3D59-4C1E-9E39-0A6D4D7F1C11","user_id":"0A8F7E3C-9B7A-4E0B-8D4E-2E1C9F8B7A61","name":"Netflix",
         "amount":15.49,"currency":"CAD","billing_frequency":"monthly","monthly_usage_minutes":0,"status":"active",
         "is_detected":false,"can_pause":true,"next_billing_date":"2026-11-20T12:00:00+00:00",
         "paused_until":"2026-12-01T12:00:00+00:00","trial_ends_at":null,
         "created_at":"2026-03-04T17:30:00.123456+00:00","updated_at":"2026-10-01T09:15:42.5+00:00"}
        """
        let record = try JSONDecoder().decode(SubscriptionRecord.self, from: Data(row.utf8))
        let sub = record.toSubscription()
        // A renewal day comes back as that day, at noon on this phone (`BillingDay`), wherever it is read.
        XCTAssertEqual(sub.nextBillingDate, Calendar.billing.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12)))
        XCTAssertEqual(sub.createdAt.timeIntervalSince1970, day("2026-03-04T17:30:00Z").timeIntervalSince1970 + 0.123, accuracy: 0.001,
                       "the creation date must not reset to now on every fetch")
    }

    func testARoundTripKeepsEverythingTheServerStores() throws {
        let fifteenth = Calendar.billing.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 12))
        var sub = TestFactories.makeSubscription(name: "Crave", amount: 22.6, currency: "CAD", billingFrequency: .yearly,
                                                 status: .trial, nextBillingDate: fifteenth)
        sub.trialEndsAt = fifteenth
        sub.notes = "Shared with family"
        sub.paymentMethod = "Apple"
        let back = try JSONDecoder().decode(SubscriptionRecord.self, from: JSONEncoder().encode(SubscriptionRecord(from: sub))).toSubscription()
        XCTAssertEqual(back.id, sub.id)
        XCTAssertEqual(back.amount, sub.amount)
        XCTAssertEqual(back.currency, "CAD")
        XCTAssertEqual(back.billingFrequency, .yearly)
        XCTAssertEqual(back.status, .trial)
        XCTAssertEqual(back.nextBillingDate, sub.nextBillingDate)
        XCTAssertEqual(back.trialEndsAt, sub.trialEndsAt)
        XCTAssertEqual(back.notes, "Shared with family")
        XCTAssertEqual(back.paymentMethod, "Apple")

        // Oversized text fields are clamped and blank names fall back before upload to satisfy Postgres CHECK constraints.
        var oversized = TestFactories.makeSubscription(name: String(repeating: "x", count: 300), amount: -5)
        oversized.notes = String(repeating: "n", count: 3_000)
        oversized.paymentMethod = String(repeating: "p", count: 200)
        let clamped = SubscriptionRecord(from: oversized)
        XCTAssertEqual(clamped.name.count, 200)
        XCTAssertEqual(clamped.notes?.count, 2_000)
        XCTAssertEqual(clamped.payment_method?.count, 120)
        XCTAssertEqual(clamped.amount, 0)

        var blank = TestFactories.makeSubscription(name: "   ")
        blank.category = nil
        let blankRecord = SubscriptionRecord(from: blank)
        XCTAssertEqual(blankRecord.name, "Subscription")
        let blankJSON = try json(blankRecord)
        XCTAssertTrue(blankJSON["category"] is NSNull, "cleared category must encode as explicit null")
    }

    // MARK: Merging the server's list with this iPhone's

    func testAChangeStillQueuedWinsOverTheServer() {
        var mine = TestFactories.makeSubscription(name: "Netflix", amount: 15.49)
        mine.amount = 17.99
        var theirs = mine
        theirs.amount = 15.49
        let merge = SubscriptionSyncMerge.merge(server: [theirs], local: [mine], pending: [mine.id: .update], firstSyncForUser: false)
        XCTAssertEqual(merge.subscriptions.map(\.amount), [17.99])
    }

    func testADeleteStillQueuedStaysDeleted() {
        let gone = TestFactories.makeSubscription(name: "Hulu")
        let merge = SubscriptionSyncMerge.merge(server: [gone], local: [], pending: [gone.id: .delete], firstSyncForUser: false)
        XCTAssertTrue(merge.subscriptions.isEmpty)
    }

    func testAnOfflineAddIsKeptAndUploaded() {
        let added = TestFactories.makeSubscription(name: "Added offline")
        let onServer = TestFactories.makeSubscription(name: "Netflix")
        let merge = SubscriptionSyncMerge.merge(server: [onServer], local: [added, onServer], pending: [added.id: .create], firstSyncForUser: false)
        XCTAssertEqual(merge.subscriptions.map(\.name), ["Added offline", "Netflix"])
        XCTAssertEqual(merge.upload.map(\.id), [added.id])
    }

    func testTheFirstSyncUploadsWhatOnlyThisIPhoneHad() {
        let local = [TestFactories.makeSubscription(name: "Spotify"), TestFactories.makeSubscription(name: "Max")]
        let merge = SubscriptionSyncMerge.merge(server: [], local: local, pending: [:], firstSyncForUser: true)
        XCTAssertEqual(merge.subscriptions.map(\.name), ["Spotify", "Max"], "nothing is wiped when the server is empty")
        XCTAssertEqual(merge.upload.count, 2)
    }

    func testLaterARowMissingFromTheServerWasDeletedElsewhere() {
        let stale = TestFactories.makeSubscription(name: "Deleted on iPad")
        let merge = SubscriptionSyncMerge.merge(server: [], local: [stale], pending: [:], firstSyncForUser: false)
        XCTAssertTrue(merge.subscriptions.isEmpty)
        XCTAssertTrue(merge.upload.isEmpty)
    }

    /// An edit is not an add. Without this, a trial ending by itself on this iPhone (the app changes
    /// its status) would bring back a subscription the person had just deleted on their iPad.
    func testAnEditDoesNotBringBackWhatAnotherDeviceDeleted() {
        let mine = TestFactories.makeSubscription(name: "Deleted on iPad, edited here")
        let merge = SubscriptionSyncMerge.merge(server: [], local: [mine], pending: [mine.id: .update], firstSyncForUser: false)
        XCTAssertTrue(merge.subscriptions.isEmpty)
        XCTAssertTrue(merge.upload.isEmpty)
    }

    func testARenewalDateTheServerNeverHadIsKeptAndSentUp() {
        let mine = TestFactories.makeSubscription(name: "Netflix", nextBillingDate: day("2026-11-20T12:00:00Z"))
        var theirs = mine
        theirs.nextBillingDate = nil   // saved by an app version that never sent dates
        let merge = SubscriptionSyncMerge.merge(server: [theirs], local: [mine], pending: [:], firstSyncForUser: false)
        XCTAssertEqual(merge.subscriptions.first?.nextBillingDate, day("2026-11-20T12:00:00Z"))
        XCTAssertEqual(merge.backfill.map(\.id), [mine.id])
    }

    /// Pausely's own line used to be known by a mark only the phone that added it held, so on a second
    /// device it was an ordinary row and its price was never brought in step with the App Store. It is
    /// known by its name now, which every device has.
    func testPauselysOwnLineIsStillKnownAfterAFetch() throws {
        let mine = TestFactories.makeSubscription(name: "Pausely Pro")
        var theirs = mine
        theirs.amount = 12.99   // changed on another device
        let merged = SubscriptionSyncMerge.merge(server: [theirs], local: [mine], pending: [:], firstSyncForUser: false).subscriptions
        XCTAssertEqual(merged.first?.amount, 12.99, "the server's change comes through")
        XCTAssertEqual(merged.first?.isPausely, true)

        // As it arrives on a device that never added it: straight from a row of the table.
        let arrived = try JSONDecoder().decode(SubscriptionRecord.self, from: JSONEncoder().encode(SubscriptionRecord(from: mine))).toSubscription()
        XCTAssertTrue(arrived.isPausely)
        XCTAssertFalse(TestFactories.makeSubscription(name: "Pausely Pro Max").isPausely)
    }

    /// The app has thirteen synced fields and sends those. Columns earlier versions filled are left as they are.
    func testOnlyTheFieldsTheAppHasAreSent() throws {
        let sent = try json(SubscriptionRecord(from: TestFactories.makeSubscription(name: "Netflix")))
        XCTAssertEqual(sent.keys.sorted(), ["amount", "billing_frequency", "category", "currency", "id", "name",
                                            "next_billing_date", "notes", "notify_before_days", "payment_method",
                                            "status", "trial_ends_at"])
    }

    // MARK: Pro

    func testProEndsWhenTheSubscriptionEndsUnlessItWasGranted() {
        XCTAssertEqual(PaymentManager.resolveTier(storeKit: .proAnnual, hasGrant: false), .proAnnual)
        XCTAssertEqual(PaymentManager.resolveTier(storeKit: nil, hasGrant: false), .free,
                       "an expired or refunded subscription must not keep Pro")
        XCTAssertEqual(PaymentManager.resolveTier(storeKit: nil, hasGrant: true), .pro)
        XCTAssertEqual(PaymentManager.resolveTier(storeKit: .pro, hasGrant: true), .pro)
    }
}
