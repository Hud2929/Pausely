import XCTest
@testable import Pausely

// MARK: - Helpers

private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
}

private var counter = 0

private func email(_ date: Date, from: String, subject: String, text: String = "", html: String? = nil,
                   headers: [String: String] = [:], labels: [String] = []) -> RawEmail {
    counter += 1
    return RawEmail(id: "t\(counter)", date: date, from: from, subject: subject, bodyText: text, bodyHTML: html,
                    headers: headers, labelIds: labels)
}

private func jsonLD(_ object: Any) -> String {
    let data = try! JSONSerialization.data(withJSONObject: object)
    return "<script type=\"application/ld+json\">\(String(data: data, encoding: .utf8)!)</script>"
}

private func analyze(_ emails: [RawEmail], now: Date = day(2026, 10, 7), corrections: [String: UserVerdict] = [:]) -> IntelligenceReport {
    let signals = emails.compactMap { EmailSignalExtractor.extract($0)?.signal }
    return SubscriptionIntelligenceEngine().analyze(signals: signals, now: now, calendar: utc,
                                                    defaultCurrency: "CAD", corrections: corrections)
}

// MARK: - Structured markup

final class StructuredReceiptParserTests: XCTestCase {

    func testInvoiceWithBillingPeriod_isASubscription() {
        let html = jsonLD(["@type": "Invoice", "provider": ["name": "Acme"], "billingPeriod": "P1M",
                           "totalPaymentDue": ["price": "9.99", "priceCurrency": "usd"]])
        let result = StructuredReceiptParser.parse(html: html)
        XCTAssertEqual(result?.kind, .subscription)
        XCTAssertEqual(result?.merchant, "Acme")
        XCTAssertEqual(result?.amount, 9.99)
        XCTAssertEqual(result?.currency, "USD")
        XCTAssertEqual(result?.cadence, .monthly)
    }

    func testInvoiceWithoutPeriod_isJustAnInvoice() {
        let html = jsonLD(["@type": "Invoice", "totalPaymentDue": ["price": "20.00", "priceCurrency": "CAD"]])
        XCTAssertEqual(StructuredReceiptParser.parse(html: html)?.kind, .invoice)
    }

    func testOrderWithAnnualUnitPrice_isYearly() {
        let html = jsonLD(["@type": "Order", "seller": ["name": "Acme"], "price": "99.00", "priceCurrency": "USD",
                           "acceptedOffer": ["priceSpecification": ["unitCode": "ANN", "price": "99.00"]]])
        let result = StructuredReceiptParser.parse(html: html)
        XCTAssertEqual(result?.kind, .subscription)
        XCTAssertEqual(result?.cadence, .yearly)
    }

    func testPlainOrder_isOneTime() {
        let html = jsonLD(["@type": "Order", "seller": ["name": "Shop"], "price": "30.00", "priceCurrency": "CAD"])
        XCTAssertEqual(StructuredReceiptParser.parse(html: html)?.kind, .order)
    }

    func testParcelAndReservation_areOneTime() {
        XCTAssertTrue(StructuredReceiptParser.parse(html: jsonLD(["@type": "ParcelDelivery"]))!.kind.isOneTime)
        XCTAssertTrue(StructuredReceiptParser.parse(html: jsonLD(["@type": "LodgingReservation", "totalPrice": "300"]))!.kind.isOneTime)
    }

    func testGraphAndArraysAreWalked_andSubscriptionOutranksParcel() {
        let html = jsonLD(["@graph": [["@type": "ParcelDelivery"],
                                      ["@type": "Invoice", "billingPeriod": "P1Y", "totalPaymentDue": ["price": "50.00"]]]])
        XCTAssertEqual(StructuredReceiptParser.parse(html: html)?.kind, .subscription)
    }

    func testMalformedJSON_isIgnoredSafely() {
        let html = "<script type=\"application/ld+json\">{ not json </script>"
        XCTAssertNil(StructuredReceiptParser.parse(html: html))
        XCTAssertNil(StructuredReceiptParser.parse(html: "<html><body>no markup</body></html>"))
    }

    func testDurations() {
        XCTAssertEqual(StructuredReceiptParser.durationCadence("P1M"), .monthly)
        XCTAssertEqual(StructuredReceiptParser.durationCadence("P3M"), .quarterly)
        XCTAssertEqual(StructuredReceiptParser.durationCadence("P6M"), .semiannual)
        XCTAssertEqual(StructuredReceiptParser.durationCadence("P12M"), .yearly)
        XCTAssertEqual(StructuredReceiptParser.durationCadence("P1Y"), .yearly)
        XCTAssertEqual(StructuredReceiptParser.durationCadence("P1W"), .weekly)
        XCTAssertEqual(StructuredReceiptParser.durationCadence("P14D"), .biweekly)
        XCTAssertNil(StructuredReceiptParser.durationCadence("nonsense"))
    }
}

// MARK: - Headers, triage, HTML

final class EmailPlumbingTests: XCTestCase {

    func testDKIM_fromAuthenticationResults() {
        let intel = HeaderIntel.analyze(headers: ["authentication-results": "mx.google.com; dkim=pass header.i=@Mail.Quickfolio.io header.s=s1; spf=pass"])
        XCTAssertEqual(intel.authenticatedDomain, "quickfolio.io")
    }

    func testDKIM_failedSignatureIsNotTrusted() {
        let intel = HeaderIntel.analyze(headers: ["authentication-results": "mx.google.com; dkim=fail header.i=@evil.example"])
        XCTAssertNil(intel.authenticatedDomain)
    }

    func testDKIM_fallsBackToSignatureHeader() {
        let intel = HeaderIntel.analyze(headers: ["dkim-signature": "v=1; a=rsa-sha256; d=billing.acme.io; s=k1; h=from"])
        XCTAssertEqual(intel.authenticatedDomain, "acme.io")
    }

    func testEffectiveDomain_prefersAuthenticatedDomainBehindRelays() {
        XCTAssertEqual(HeaderIntel.effectiveDomain(from: "mail.sendgrid.net", authenticated: "quickfolio.io"), "quickfolio.io")
        XCTAssertEqual(HeaderIntel.effectiveDomain(from: "mailer.netflix.com", authenticated: "netflix.com"), "mailer.netflix.com")
        XCTAssertEqual(HeaderIntel.effectiveDomain(from: "mail.sendgrid.net", authenticated: "sendgrid.net"), "mail.sendgrid.net")
        XCTAssertEqual(HeaderIntel.effectiveDomain(from: "gmail.com", authenticated: nil), "gmail.com")
    }

    func testBulkAndUnsubscribeDetection() {
        let intel = HeaderIntel.analyze(headers: ["list-unsubscribe": "<mailto:x@y.z>", "precedence": "bulk"])
        XCTAssertTrue(intel.hasUnsubscribe)
        XCTAssertTrue(intel.bulk)
        XCTAssertFalse(HeaderIntel.analyze(headers: [:]).bulk)
    }

    func testTriage_readsReceiptsAndSkipsNoise() {
        XCTAssertTrue(EmailTriage.shouldReadBody(from: "Foo <a@foo.com>", subject: "Your receipt", snippet: "", labelIds: []))
        XCTAssertTrue(EmailTriage.shouldReadBody(from: "Foo <a@foo.com>", subject: "Hello", snippet: "Your subscription renews soon", labelIds: []))
        XCTAssertTrue(EmailTriage.shouldReadBody(from: "Foo <a@foo.com>", subject: "Hello", snippet: "", labelIds: ["CATEGORY_PURCHASES"]))
        XCTAssertTrue(EmailTriage.shouldReadBody(from: "Netflix <a@mailer.netflix.com>", subject: "Hello", snippet: "", labelIds: []))
        XCTAssertFalse(EmailTriage.shouldReadBody(from: "Friend <sam@gmail.com>", subject: "Lunch tomorrow?", snippet: "Are you free at noon", labelIds: []))
        XCTAssertFalse(EmailTriage.shouldReadBody(from: "Netflix <a@mailer.netflix.com>", subject: "New this week", snippet: "Top picks", labelIds: ["CATEGORY_PROMOTIONS"]))
    }

    func testHTMLText_keepsLinesAndDecodesEntities() {
        let html = "<html><head><style>p{color:red}</style></head><body><script>var x=1;</script><p>Total&nbsp;&euro;9,99</p><p>Caf&#233; &amp; Co &#x2014; ok</p><br>line<br/>two</body></html>"
        let text = HTMLText.plain(html)
        XCTAssertTrue(text.contains("Total €9,99"))
        XCTAssertTrue(text.contains("Café & Co — ok"))
        XCTAssertFalse(text.contains("color:red"))
        XCTAssertFalse(text.contains("var x"))
        XCTAssertTrue(text.contains("\n"))
    }
}

// MARK: - Learning from the user

final class UserCorrectionsTests: XCTestCase {

    private func isolatedDefaults() -> UserDefaults {
        let suite = "UserCorrectionsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testStoreRoundTrip() {
        let defaults = isolatedDefaults()
        XCTAssertTrue(UserCorrections.load(defaults: defaults).isEmpty)
        UserCorrections.set("netflix", .trusted, defaults: defaults)
        UserCorrections.set("uber", .notSubscription, defaults: defaults)
        XCTAssertEqual(UserCorrections.load(defaults: defaults), ["netflix": .trusted, "uber": .notSubscription])
        UserCorrections.set("uber", nil, defaults: defaults)
        XCTAssertEqual(UserCorrections.load(defaults: defaults), ["netflix": .trusted])
        UserCorrections.clear(defaults: defaults)
        XCTAssertTrue(UserCorrections.load(defaults: defaults).isEmpty)
    }

    private func gymEmails() -> [RawEmail] {
        [(7, 3), (8, 3), (9, 3)].map {
            email(day(2026, $0.0, $0.1), from: "Ironside Fitness <billing@ironsidefitness.ca>", subject: "Membership payment received",
                  text: "Thank you for your monthly membership payment of $34.99. Your membership renews on the 3rd.")
        }
    }

    func testNotSubscription_removesItForever() {
        XCTAssertNotNil(analyze(gymEmails()).subscriptions.first { $0.name == "Ironside Fitness" })
        let after = analyze(gymEmails(), corrections: ["ironside fitness": .notSubscription])
        XCTAssertNil(after.subscriptions.first { $0.name == "Ironside Fitness" })
    }

    func testTrusted_liftsAWeakCandidate() {
        // Two same-amount charges with no renewal language: hidden by default...
        let weak = [(8, 14), (9, 14)].map {
            email(day(2026, $0.0, $0.1), from: "Club Foo <pay@clubfoo.ca>", subject: "Payment received", text: "Payment received: $25.00")
        }
        XCTAssertNil(analyze(weak).subscriptions.first { $0.name.contains("Club Foo") })
        // ...but the user vouching for it makes it appear.
        let trusted = analyze(weak, corrections: ["club foo": .trusted])
        XCTAssertGreaterThanOrEqual(trusted.subscriptions.first { $0.name.contains("Club Foo") }?.tier ?? .hidden, .likely)
    }
}

// MARK: - Extractor behaviour

final class EmailSignalExtractorTests: XCTestCase {

    func testReceiptFiledUnderPromotions_isKeptWhenMarkupProvesIt() {
        let html = "<html><head>" + jsonLD(["@type": "Invoice", "provider": ["name": "Acme"], "billingPeriod": "P1M",
                                              "totalPaymentDue": ["price": "9.99", "priceCurrency": "CAD"]]) + "</head><body>Receipt</body></html>"
        let result = EmailSignalExtractor.extract(email(day(2026, 9, 1), from: "Acme <bill@acme.io>", subject: "Receipt", html: html,
                                                        labels: ["CATEGORY_PROMOTIONS"]))
        XCTAssertEqual(result?.signal.promotional, false)
        XCTAssertEqual(result?.signal.markup, .subscription)
    }

    func testPlainPromotionWithPrice_isStillPromotional() {
        let result = EmailSignalExtractor.extract(email(day(2026, 9, 1), from: "Acme <deals@acme.io>", subject: "Big sale",
                                                        text: "Now only $9.99!", labels: ["CATEGORY_PROMOTIONS"]))
        XCTAssertEqual(result?.signal.promotional, true)
    }

    func testBrandMentionedInPassing_doesNotRenameAnOrder() {
        let order = email(day(2026, 9, 1), from: "DoorDash <no-reply@doordash.com>", subject: "Your order from Pizza Palace",
                          text: "Order #1\nDelivered.\nDashPass savings: C$3.00\nTotal C$33.83")
        XCTAssertNil(EmailSignalExtractor.extract(order)?.signal.merchantHint)
    }

    func testMembershipInSubject_isNamedEvenWithoutRenewalWords() {
        let receipt = email(day(2026, 9, 1), from: "DoorDash <no-reply@doordash.com>", subject: "Your DashPass receipt", text: "Fee C$9.99")
        XCTAssertEqual(EmailSignalExtractor.extract(receipt)?.signal.merchantHint, "DashPass")
    }

    func testUnknownChargeWithNoLanguage_isFlaggedAmbiguousForTheOnDeviceModel() {
        let result = EmailSignalExtractor.extract(email(day(2026, 9, 1), from: "Mystery Co <hi@mysteryco.io>", subject: "Thanks",
                                                        text: "We processed $12.00 today."))
        XCTAssertNotNil(result?.ambiguousExcerpt)
    }

    func testClearReceipts_areNotSentToTheModel() {
        let result = EmailSignalExtractor.extract(email(day(2026, 9, 1), from: "Netflix <info@mailer.netflix.com>", subject: "Your Netflix receipt",
                                                        text: "Amount charged: C$16.49. Your plan renews monthly."))
        XCTAssertNil(result?.ambiguousExcerpt)
    }

    func testModelVerdicts_updateTheSignal() {
        let base = EmailSignalExtractor.extract(email(day(2026, 9, 1), from: "Mystery Co <hi@mysteryco.io>", subject: "Thanks", text: "We processed $12.00 today."))!.signal
        let recurring = base.applying(.recurring(.yearly))
        XCTAssertTrue(recurring.renewalLanguage)
        XCTAssertEqual(recurring.cadenceHint, .yearly)
        XCTAssertTrue(base.applying(.oneTime).oneTimeLanguage)
        XCTAssertEqual(base.applying(.unsure), base)
    }

    func testEmailWithNoAmountOrLifecycle_isDropped() {
        XCTAssertNil(EmailSignalExtractor.extract(email(day(2026, 9, 1), from: "News <n@x.io>", subject: "Weekly digest", text: "Stories only.")))
    }
}

// MARK: - Other languages and number formats

final class MultilingualTests: XCTestCase {

    func testFrenchCanadianReceipts_withCommaDecimalAndDollarSign() {
        let emails = [(7, 9), (8, 9), (9, 9)].map {
            email(day(2026, $0.0, $0.1), from: "Netflix <info@mailer.netflix.com>", subject: "Votre reçu Netflix",
                  text: "Merci d'être membre.\nMontant facturé : 16,49 $\nVotre abonnement mensuel se renouvelle chaque mois.")
        }
        let sub = analyze(emails).subscriptions.first { $0.name == "Netflix" }
        XCTAssertNotNil(sub)
        XCTAssertEqual(sub?.amount, Decimal(string: "16.49"))
        XCTAssertEqual(sub?.frequency, .monthly)
        XCTAssertEqual(sub?.tier, .confirmed)
    }

    func testSpanishReceipts_withEuroComma() {
        let emails = [(7, 5), (8, 5), (9, 5)].map {
            email(day(2026, $0.0, $0.1), from: "Spotify <no-reply@spotify.com>", subject: "Tu recibo de Spotify",
                  text: "Importe cobrado: 10,99 €\nTu suscripción mensual se renovará automáticamente.")
        }
        let sub = analyze(emails).subscriptions.first { $0.name == "Spotify" }
        XCTAssertEqual(sub?.amount, Decimal(string: "10.99"))
        XCTAssertEqual(sub?.currency, "EUR")
    }

    func testGermanReceipts_withThousandsAndComma() {
        let emails = [(2025, 10, 20), (2026, 10, 1)].map {
            email(day($0.0, $0.1, $0.2), from: "Adobe <mail@mail.adobe.com>", subject: "Ihre Rechnung",
                  text: "Gesamt: 1.079,88 EUR\nIhr Abonnement verlängert sich jährlich automatisch.")
        }
        let sub = analyze(emails, now: day(2026, 10, 7)).subscriptions.first { $0.name.contains("Adobe") }
        XCTAssertNotNil(sub)
        XCTAssertEqual(sub?.amount, Decimal(string: "1079.88"))
    }

    func testFrenchOrders_areNotSubscriptions() {
        let orders = [(6, 3, "42,17"), (7, 14, "18,99"), (8, 9, "33,15")].map {
            email(day(2026, $0.0, $0.1), from: "Amazon.ca <commande@amazon.ca>", subject: "Votre commande a été expédiée",
                  text: "Merci pour votre achat. Numéro de commande 702-\($0.1). Total : \($0.2) $")
        }
        XCTAssertTrue(analyze(orders).subscriptions.isEmpty)
    }

    func testMoneyTransfers_areNeverSubscriptions() {
        let transfers = [(8, 8), (8, 22), (9, 5), (9, 19)].map {
            email(day(2026, $0.0, $0.1), from: "Interac e-Transfer <notify@payments.interac.ca>", subject: "You received money",
                  text: "Sam sent you $60.00 with Interac e-Transfer.")
        }
        XCTAssertTrue(analyze(transfers).subscriptions.isEmpty)
    }
}

// MARK: - Adversarial subscriptions

final class AdversarialEngineTests: XCTestCase {

    private func netflix(_ y: Int, _ m: Int, _ d: Int, _ amount: String) -> RawEmail {
        email(day(y, m, d), from: "Netflix <info@mailer.netflix.com>", subject: "Your Netflix receipt",
              text: "Amount charged: C$\(amount). Your plan renews monthly.")
    }

    func testMissingMonth_doesNotBreakDetection() {
        let sub = analyze([netflix(2026, 6, 12, "16.49"), netflix(2026, 8, 12, "16.49"), netflix(2026, 9, 12, "16.49")]).subscriptions.first { $0.name == "Netflix" }
        XCTAssertEqual(sub?.frequency, .monthly)
        XCTAssertEqual(sub?.status, .active)
    }

    func testForeignCurrencyDrift_isNotAPriceIncrease() {
        let emails = [netflix(2026, 6, 12, "13.21"), netflix(2026, 7, 12, "13.34"), netflix(2026, 8, 12, "13.18"), netflix(2026, 9, 12, "13.40")]
        XCTAssertEqual(analyze(emails).subscriptions.first { $0.name == "Netflix" }?.status, .active)
    }

    func testDowngrade_isNotFlaggedAsPriceIncrease() {
        let emails = [netflix(2026, 6, 12, "22.99"), netflix(2026, 7, 12, "22.99"), netflix(2026, 8, 12, "16.49"), netflix(2026, 9, 12, "16.49")]
        let sub = analyze(emails).subscriptions.first { $0.name == "Netflix" }
        XCTAssertEqual(sub?.status, .active)
        XCTAssertEqual(sub?.amount, Decimal(string: "16.49"))
    }

    func testReceiptPlusPaymentNotice_sameDay_countAsOneCharge() {
        var emails = [netflix(2026, 8, 12, "16.49"), netflix(2026, 9, 12, "16.49")]
        emails.append(email(day(2026, 9, 12), from: "Netflix <info@mailer.netflix.com>", subject: "Payment received",
                            text: "We received your payment of C$16.49. Your plan renews monthly."))
        XCTAssertEqual(analyze(emails).subscriptions.first { $0.name == "Netflix" }?.evidence.count, 2)
    }

    func testWeeklyMealKit_isDetectedAsWeekly() {
        let emails = (0..<5).map {
            email(day(2026, 9, 1 + $0 * 7), from: "Fresh Crate <hello@freshcrate.ca>", subject: "Your weekly box receipt",
                  text: "Amount charged: $64.00. Your weekly subscription box renews every week.")
        }
        XCTAssertEqual(analyze(emails).subscriptions.first { $0.name.contains("Fresh Crate") }?.frequency, .weekly)
    }

    func testSingleYearlyReceipt_isFoundAndNextRenewalIsProjected() {
        let adobe = email(day(2026, 2, 20), from: "Adobe <mail@mail.adobe.com>", subject: "Your Adobe subscription receipt",
                          text: "Amount charged: C$779.88 per year. Your subscription will renew on February 20.")
        let sub = analyze([adobe]).subscriptions.first { $0.name.contains("Adobe") }
        XCTAssertEqual(sub?.frequency, .yearly)
        XCTAssertNotNil(sub?.nextBillingDate)
    }

    func testOneOffAppStorePurchase_isIgnored() {
        let purchase = email(day(2026, 9, 3), from: "Apple <no_reply@email.apple.com>", subject: "Your receipt from Apple.",
                             text: "Pixel Quest\nC$9.99\nTotal C$9.99")
        XCTAssertTrue(analyze([purchase]).subscriptions.isEmpty)
    }

    func testTwoSteadyChargesFromUnknownMerchantWithoutRenewalWords_staysHidden() {
        let emails = [(8, 14), (9, 14)].map {
            email(day(2026, $0.0, $0.1), from: "Club Foo <pay@clubfoo.ca>", subject: "Payment received", text: "Payment received: $25.00")
        }
        XCTAssertTrue(analyze(emails).subscriptions.isEmpty)
    }

    func testChargedAfterCancelling_isCaughtThroughTheWholePipeline() {
        var emails = [netflix(2026, 6, 12, "16.49"), netflix(2026, 7, 12, "16.49"), netflix(2026, 8, 12, "16.49")]
        emails.append(email(day(2026, 8, 20), from: "Netflix <info@mailer.netflix.com>", subject: "Your Netflix membership has been cancelled",
                            text: "Your subscription has been cancelled. We're sorry to see you go."))
        emails.append(netflix(2026, 9, 12, "16.49"))
        XCTAssertTrue(analyze(emails).insights.contains { $0.kind == .chargedAfterCancel })
    }
}
