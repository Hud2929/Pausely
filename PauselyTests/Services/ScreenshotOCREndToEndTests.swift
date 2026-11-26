import UIKit
import XCTest
@testable import Pausely

/// End-to-end tests that render real iPhone screenshots (`UIGraphicsImageRenderer`) and feed them
/// through Apple's live Vision framework (`ScreenshotOCR.recognizeText`) into `ScreenshotParser`.
/// Exercises dark/light mode, 6 languages, RTL Arabic, 3-column bank rows, tall scrolling captures,
/// Apple Edit Subscription cutoffs, and raw image bytes (`Data`).
final class ScreenshotOCREndToEndTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Toronto")!
        return cal
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private struct DrawItem {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let bold: Bool
        let muted: Bool
        let rightAlign: Bool

        init(_ text: String, x: CGFloat = 56, y: CGFloat, size: CGFloat = 34,
             bold: Bool = false, muted: Bool = false, rightAlign: Bool = false) {
            self.text = text
            self.x = x
            self.y = y
            self.size = size
            self.bold = bold
            self.muted = muted
            self.rightAlign = rightAlign
        }
    }

    private func renderScreenshot(width: CGFloat = 1170, height: CGFloat = 2200,
                                  darkMode: Bool = true, items: [DrawItem]) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            let bg: UIColor = darkMode ? UIColor(white: 0.06, alpha: 1) : .white
            bg.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            for item in items {
                let color: UIColor = if darkMode {
                    item.muted ? UIColor(white: 0.68, alpha: 1) : UIColor(white: 0.96, alpha: 1)
                } else {
                    item.muted ? UIColor(white: 0.35, alpha: 1) : UIColor(white: 0.08, alpha: 1)
                }
                let font = item.bold
                    ? UIFont.systemFont(ofSize: item.size, weight: .semibold)
                    : UIFont.systemFont(ofSize: item.size, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let ns = item.text as NSString
                let measured = ns.size(withAttributes: attrs)
                let drawX = item.rightAlign ? (width - item.x - measured.width) : item.x
                ns.draw(at: CGPoint(x: drawX, y: item.y), withAttributes: attrs)
            }
        }
    }

    private func scan(_ image: UIImage, defaultCurrency: String, now: Date) async throws -> [ScreenshotParser.DetectedItem] {
        let data = try XCTUnwrap(image.pngData())
        let observations = try await ScreenshotOCR.recognizeText(in: data)
        XCTAssertFalse(observations.isEmpty, "Vision OCR must return text observations from rendered screenshot")
        return ScreenshotParser.parse(pages: [observations], defaultCurrency: defaultCurrency, now: now, calendar: calendar)
    }

    // MARK: - 1. Apple Settings › Subscriptions (English, Dark Mode)

    func testLiveOCREnglishDarkAppleSubscriptionsWithCustomPlanSubtitle() async throws {
        let image = renderScreenshot(darkMode: true, items: [
            DrawItem("9:41", x: 70, y: 36, size: 30, bold: true),
            DrawItem("5G", x: 960, y: 36, size: 28, bold: true),
            DrawItem("100%", x: 1035, y: 36, size: 28, bold: true),
            DrawItem("Subscriptions", x: 56, y: 120, size: 54, bold: true),
            DrawItem("ACTIVE", x: 56, y: 230, size: 28, muted: true),

            DrawItem("Netflix", y: 310, size: 38, bold: true),
            DrawItem("Standard Plan", y: 360, size: 30, muted: true),
            DrawItem("$19.99/month", y: 405, size: 30, muted: true),
            DrawItem("Renews Dec 14, 2026", y: 450, size: 30, muted: true),

            DrawItem("Peloton", y: 580, size: 38, bold: true),
            DrawItem("All-Access", y: 630, size: 30, muted: true),
            DrawItem("$44.00/month", y: 675, size: 30, muted: true),
            DrawItem("Renews Dec 20, 2026", y: 720, size: 30, muted: true),

            DrawItem("iCloud+", y: 850, size: 38, bold: true),
            DrawItem("200 GB", y: 900, size: 30, muted: true),
            DrawItem("$2.99/month", y: 945, size: 30, muted: true),
            DrawItem("Renews Dec 1", y: 990, size: 30, muted: true),

            DrawItem("Headspace", y: 1120, size: 38, bold: true),
            DrawItem("Mindfulness Plus", y: 1170, size: 30, muted: true),
            DrawItem("$12.99/month", y: 1215, size: 30, muted: true),
            DrawItem("Renews Dec 9, 2026", y: 1260, size: 30, muted: true),

            DrawItem("Duolingo", y: 1390, size: 38, bold: true),
            DrawItem("Super Duolingo (Annual)", y: 1440, size: 30, muted: true),
            DrawItem("$83.99/year", y: 1485, size: 30, muted: true),
            DrawItem("Free Trial", y: 1530, size: 30, muted: true),
            DrawItem("Renews Dec 3", y: 1575, size: 30, muted: true),

            DrawItem("INACTIVE", x: 56, y: 1730, size: 28, muted: true),
            DrawItem("Hulu", y: 1810, size: 38, bold: true),
            DrawItem("Expired Oct 10, 2026", y: 1860, size: 30, muted: true),
            DrawItem("$18.99/month", y: 1905, size: 30, muted: true),
        ])

        let data = try XCTUnwrap(image.pngData())
        let observations = try await ScreenshotOCR.recognizeText(in: data)
        let items = ScreenshotParser.parse(pages: [observations], defaultCurrency: "USD", now: day(2026, 11, 23), calendar: calendar)
        let byName = Dictionary(items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        XCTAssertEqual(byName["netflix"]?.amount, Decimal(string: "19.99"))
        XCTAssertEqual(byName["netflix"]?.frequency, .monthly)
        XCTAssertEqual(byName["netflix"]?.renewalDate, day(2026, 12, 14))
        XCTAssertEqual(byName["netflix"]?.paymentMethod, "Apple")
        XCTAssertEqual(byName["netflix"]?.isCancelled, false)

        // Peloton + "All-Access" upgrades to exact catalog service "Peloton All-Access"
        XCTAssertEqual(byName["peloton all-access"]?.amount, Decimal(string: "44.00"), "All-Access subtitle must stay attached to Peloton")
        XCTAssertEqual(byName["peloton all-access"]?.renewalDate, day(2026, 12, 20))
        XCTAssertNil(byName["all-access"])

        // Headspace + non-catalog subtitle "Mindfulness Plus" keeps Headspace name and attaches price/date
        XCTAssertEqual(byName["headspace"]?.amount, Decimal(string: "12.99"), "non-catalog plan subtitle must stay attached to Headspace")
        XCTAssertEqual(byName["headspace"]?.renewalDate, day(2026, 12, 9))
        XCTAssertNil(byName["mindfulness plus"])

        let icloudDebug = "items=\(items.map(\.name)) raw=\(observations.map(\.text))"
        XCTAssertEqual(byName["icloud+"]?.amount, Decimal(string: "2.99"), icloudDebug)
        XCTAssertEqual(byName["icloud+"]?.renewalDate, day(2026, 12, 1), icloudDebug)

        XCTAssertEqual(byName["duolingo"]?.amount, Decimal(string: "83.99"))
        XCTAssertEqual(byName["duolingo"]?.frequency, .yearly)
        XCTAssertEqual(byName["duolingo"]?.isTrial, true, "separate Free Trial + Renews lines must still mark trial")
        XCTAssertEqual(byName["duolingo"]?.trialEndsAt, day(2026, 12, 3))

        XCTAssertEqual(byName["hulu"]?.isCancelled, true)
    }

    // MARK: - 2. German, French, Spanish, Japanese, and Arabic Live OCR

    func testLiveOCRGermanAppleSubscriptionsYearlyAndInaktiv() async throws {
        let image = renderScreenshot(darkMode: false, items: [
            DrawItem("Abos", y: 120, size: 54, bold: true),
            DrawItem("AKTIV", y: 230, size: 28, muted: true),
            DrawItem("Spotify", y: 310, size: 38, bold: true),
            DrawItem("10,99 €/Monat", y: 365, size: 32, muted: true),
            DrawItem("Verlängert sich am 14. Dez. 2026", y: 415, size: 30, muted: true),

            DrawItem("Duolingo", y: 550, size: 38, bold: true),
            DrawItem("89,99 €/Jahr", y: 605, size: 32, muted: true),
            DrawItem("Verlängert sich am 3. Mär. 2027", y: 655, size: 30, muted: true),

            DrawItem("INAKTIV", y: 810, size: 28, muted: true),
            DrawItem("Netflix", y: 890, size: 38, bold: true),
            DrawItem("13,99 €/Monat", y: 945, size: 32, muted: true),
        ])

        let items = try await scan(image, defaultCurrency: "EUR", now: day(2026, 11, 23))
        let byName = Dictionary(items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        XCTAssertEqual(byName["spotify"]?.amount, Decimal(string: "10.99"))
        XCTAssertEqual(byName["spotify"]?.frequency, .monthly)
        XCTAssertEqual(byName["spotify"]?.renewalDate, day(2026, 12, 14))

        XCTAssertEqual(byName["duolingo"]?.amount, Decimal(string: "89.99"))
        XCTAssertEqual(byName["duolingo"]?.frequency, .yearly, "€/Jahr must parse as yearly, not monthly")
        XCTAssertEqual(byName["duolingo"]?.renewalDate, day(2027, 3, 3))

        XCTAssertEqual(byName["netflix"]?.isCancelled, true, "INAKTIV section must mark items cancelled")
    }

    func testLiveOCRFrenchAndSpanishYearlyAndDates() async throws {
        let frImage = renderScreenshot(darkMode: true, items: [
            DrawItem("Abonnements", y: 120, size: 50, bold: true),
            DrawItem("ACTIFS", y: 220, size: 28, muted: true),
            DrawItem("Disney+", y: 310, size: 38, bold: true),
            DrawItem("Forfait Standard", y: 360, size: 30, muted: true),
            DrawItem("89,90 €/an", y: 408, size: 32, muted: true),
            DrawItem("Se renouvelle le 14 déc. 2026", y: 458, size: 30, muted: true),
        ])
        let frItems = try await scan(frImage, defaultCurrency: "EUR", now: day(2026, 11, 23))
        let disney = frItems.first { $0.name.lowercased().contains("disney") }
        XCTAssertEqual(disney?.amount, Decimal(string: "89.90"))
        XCTAssertEqual(disney?.frequency, .yearly, "€/an must parse as yearly")
        XCTAssertEqual(disney?.renewalDate, day(2026, 12, 14))

        let esImage = renderScreenshot(darkMode: false, items: [
            DrawItem("Suscripciones", y: 120, size: 50, bold: true),
            DrawItem("ACTIVAS", y: 220, size: 28, muted: true),
            DrawItem("Canva", y: 310, size: 38, bold: true),
            DrawItem("110,00 €/año", y: 365, size: 32, muted: true),
            DrawItem("Se renueva el 5 de ene. de 2027", y: 418, size: 30, muted: true),
        ])
        let esItems = try await scan(esImage, defaultCurrency: "EUR", now: day(2026, 11, 23))
        let canva = esItems.first { $0.name.lowercased() == "canva" }
        XCTAssertEqual(canva?.amount, Decimal(string: "110.00"))
        XCTAssertEqual(canva?.frequency, .yearly, "€/año must parse as yearly")
        XCTAssertEqual(canva?.renewalDate, day(2027, 1, 5))
    }

    func testLiveOCRJapaneseAppleSubscriptions() async throws {
        let image = renderScreenshot(darkMode: true, items: [
            DrawItem("サブスクリプション", y: 120, size: 46, bold: true),
            DrawItem("有効", y: 220, size: 28, muted: true),
            DrawItem("iCloud+", y: 310, size: 38, bold: true),
            DrawItem("¥400/月", y: 368, size: 34, muted: true),
            DrawItem("2026年12月14日更新", y: 422, size: 30, muted: true),

            DrawItem("Duolingo", y: 560, size: 38, bold: true),
            DrawItem("¥9,900/年", y: 618, size: 34, muted: true),
            DrawItem("2027年3月5日更新", y: 672, size: 30, muted: true),
        ])
        let items = try await scan(image, defaultCurrency: "JPY", now: day(2026, 11, 23))
        let byName = Dictionary(items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        XCTAssertEqual(byName["icloud+"]?.amount, Decimal(400))
        XCTAssertEqual(byName["icloud+"]?.currency, "JPY")
        XCTAssertEqual(byName["icloud+"]?.frequency, .monthly)
        XCTAssertEqual(byName["icloud+"]?.renewalDate, day(2026, 12, 14))

        XCTAssertEqual(byName["duolingo"]?.amount, Decimal(9900))
        XCTAssertEqual(byName["duolingo"]?.frequency, .yearly, "¥/年 must parse as yearly")
        XCTAssertEqual(byName["duolingo"]?.renewalDate, day(2027, 3, 5))
    }

    // MARK: - 3. Bank Statement (3-Column Date | Merchant | Amount) & Apple Edit Subscription Cutoff

    func testLiveOCRThreeColumnBankStatementAndDescriptorCleanup() async throws {
        let image = renderScreenshot(darkMode: false, items: [
            DrawItem("Transactions", y: 110, size: 48, bold: true),
            DrawItem("Available balance $3,412.08", y: 185, size: 30, muted: true),

            DrawItem("Nov 19", x: 56, y: 310, size: 30, muted: true),
            DrawItem("NETFLIX.COM*8A2B3C", x: 220, y: 310, size: 32, bold: true),
            DrawItem("-$19.99", x: 56, y: 310, size: 32, bold: true, rightAlign: true),

            DrawItem("Nov 18", x: 56, y: 420, size: 30, muted: true),
            DrawItem("PAYPAL *SPOTIFY", x: 220, y: 420, size: 32, bold: true),
            DrawItem("−$12.99", x: 56, y: 420, size: 32, bold: true, rightAlign: true),

            DrawItem("Nov 17", x: 56, y: 530, size: 30, muted: true),
            DrawItem("ACME PAYROLL", x: 220, y: 530, size: 32, bold: true),
            DrawItem("+$2,850.00", x: 56, y: 530, size: 32, bold: true, rightAlign: true),

            DrawItem("Nov 15", x: 56, y: 640, size: 30, muted: true),
            DrawItem("MONDAY.COM", x: 220, y: 640, size: 32, bold: true),
            DrawItem("-$12.00", x: 56, y: 640, size: 32, bold: true, rightAlign: true),
        ])

        let items = try await scan(image, defaultCurrency: "USD", now: day(2026, 11, 23))
        let byName = Dictionary(items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        XCTAssertEqual(byName["netflix"]?.amount, Decimal(string: "19.99"))
        XCTAssertEqual(byName["netflix"]?.renewalDate, day(2026, 11, 19))
        XCTAssertNil(byName["netflix"]?.paymentMethod, "bank statement must not be mislabeled Apple")

        XCTAssertEqual(byName["spotify"]?.amount, Decimal(string: "12.99"))
        XCTAssertEqual(byName["spotify"]?.renewalDate, day(2026, 11, 18))

        XCTAssertNil(items.first { $0.name.lowercased().contains("payroll") || $0.name.lowercased().contains("balance") })
        XCTAssertEqual(byName["monday.com"]?.amount, Decimal(string: "12.00"), "resolved Monday.com from catalog: \(items.map(\.name))")
        XCTAssertEqual(byName["monday.com"]?.renewalDate, day(2026, 11, 15), "must use Nov 15, not fabricated next Monday")
    }

    func testLiveOCREditSubscriptionScreenIgnoresAlternativePlansAndCancelFooter() async throws {
        let image = renderScreenshot(darkMode: true, items: [
            DrawItem("Edit Subscription", y: 110, size: 46, bold: true),
            DrawItem("Netflix", y: 230, size: 42, bold: true),
            DrawItem("Standard Plan", y: 290, size: 32, muted: true),
            DrawItem("$19.99/month", y: 340, size: 32, muted: true),
            DrawItem("Renews Dec 14, 2026", y: 390, size: 32, muted: true),

            DrawItem("See All Plans", y: 540, size: 34, bold: true),
            DrawItem("Basic with Ads", x: 56, y: 620, size: 32),
            DrawItem("$7.99/month", x: 56, y: 620, size: 32, rightAlign: true),
            DrawItem("Premium", x: 56, y: 700, size: 32),
            DrawItem("$24.99/month", x: 56, y: 700, size: 32, rightAlign: true),

            DrawItem("Cancel Subscription", y: 840, size: 34, bold: true),
            DrawItem("If you cancel now, access continues until Dec 14, 2026.", y: 900, size: 28, muted: true),
        ])

        let items = try await scan(image, defaultCurrency: "USD", now: day(2026, 11, 23))
        XCTAssertEqual(items.count, 1, "alternative plans and Cancel Subscription must never leak as items: \(items.map(\.name))")
        XCTAssertEqual(items.first?.name, "Netflix")
        XCTAssertEqual(items.first?.amount, Decimal(string: "19.99"))
        XCTAssertEqual(items.first?.renewalDate, day(2026, 12, 14))
    }

    func testLiveOCRTallScrollingCaptureKeepsDenseRowsSeparate() async throws {
        // 12 rows spanning y=220..3080 across a tall 1170x3400 scrolling screenshot (crossing the vertical tile seam).
        let services: [(String, String)] = [
            ("Netflix", "$19.99/mo"),
            ("Spotify", "$12.99/mo"),
            ("Disney+", "$15.99/mo"),
            ("iCloud+", "$2.99/mo"),
            ("Claude Pro", "$20.00/mo"),
            ("ChatGPT Plus", "$20.00/mo"),
            ("NordVPN", "$59.99/yr"),
            ("Notion", "$10.00/mo"),
            ("Dropbox", "$11.99/mo"),
            ("Figma", "$15.00/mo"),
            ("Audible", "$14.95/mo"),
            ("Strava", "$79.99/yr"),
        ]
        var draws: [DrawItem] = [DrawItem("Recurring payments", y: 90, size: 44, bold: true)]
        // First 8 rows tightly spaced (110px apart) + 4 rows across the vertical tile seam and bottom.
        let yPositions: [CGFloat] = [220, 330, 440, 550, 660, 770, 880, 990, 1850, 1980, 2120, 3050]
        for (idx, (name, price)) in services.enumerated() {
            let y = yPositions[idx]
            draws.append(DrawItem(name, x: 56, y: y, size: 34, bold: true))
            draws.append(DrawItem(price, x: 56, y: y, size: 34, rightAlign: true))
        }
        let image = renderScreenshot(width: 1170, height: 3400, darkMode: true, items: draws)
        let data = try XCTUnwrap(image.pngData())
        let observations = try await ScreenshotOCR.recognizeText(in: data)
        let items = ScreenshotParser.parse(pages: [observations], defaultCurrency: "USD", now: day(2026, 11, 23), calendar: calendar)
        XCTAssertEqual(items.count, 12, "tall scrolling screenshot must recognize and separate all 12 rows across tiles: \(items.map(\.name))")
        let nordObs = observations.filter { $0.text.contains("59") || $0.text.lowercased().contains("nord") }.map(\.text)
        XCTAssertEqual(items.first { $0.name == "NordVPN" }?.frequency, .yearly, "NordVPN raw OCR: \(nordObs)")
        XCTAssertEqual(items.first { $0.name == "Strava" }?.frequency, .yearly)
        XCTAssertEqual(items.first { $0.name == "Strava" }?.amount, Decimal(string: "79.99"))
    }

    // MARK: - 4. Live Arabic RTL Screenshot & EXIF-Rotated JPEG

    func testLiveOCRArabicRTLScreenshot() async throws {
        let image = renderScreenshot(darkMode: true, items: [
            DrawItem("الاشتراكات", x: 56, y: 120, size: 50, bold: true, rightAlign: true),
            DrawItem("نشطة", x: 56, y: 220, size: 30, muted: true, rightAlign: true),
            DrawItem("Netflix", x: 56, y: 330, size: 38, bold: true, rightAlign: true),
            DrawItem("49.99 ر.س./شهر", x: 56, y: 330, size: 34, muted: false, rightAlign: false),
            DrawItem("يتجدد 14 ديسمبر 2026", x: 56, y: 395, size: 30, muted: true, rightAlign: true),
        ])
        let items = try await scan(image, defaultCurrency: "SAR", now: day(2026, 11, 23))
        let netflix = items.first { $0.name.lowercased() == "netflix" }
        XCTAssertEqual(netflix?.amount, Decimal(string: "49.99"), "Arabic RTL screenshot items: \(items)")
        XCTAssertEqual(netflix?.currency, "SAR")
        XCTAssertEqual(netflix?.frequency, .monthly)
        XCTAssertEqual(netflix?.renewalDate, day(2026, 12, 14))
    }

    func testLiveOCRExifRotatedJPEGAndUIImageOrientation() async throws {
        // Render upright screenshot, then rotate pixel buffer 90° CCW and tag it with EXIF orientation 6 (.right)
        // so display orientation is upright again — just like a rotated iPhone photo/screenshot.
        let upright = renderScreenshot(width: 900, height: 1400, darkMode: false, items: [
            DrawItem("Subscriptions", y: 100, size: 48, bold: true),
            DrawItem("ACTIVE", y: 200, size: 28, muted: true),
            DrawItem("Spotify", y: 290, size: 38, bold: true),
            DrawItem("$11.99/month", y: 345, size: 32, muted: true),
            DrawItem("Renews Dec 18, 2026", y: 398, size: 30, muted: true),
        ])
        // Rotate pixels 90° counter-clockwise in UIKit Y-down coordinates so raw pixels are landscape (1400x900)
        // and EXIF orientation .right (6, rotate 90° CW) restores upright.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rotatedPixels = UIGraphicsImageRenderer(size: CGSize(width: 1400, height: 900), format: format).image { ctx in
            ctx.cgContext.translateBy(x: 0, y: 900)
            ctx.cgContext.rotate(by: -.pi / 2)
            upright.draw(in: CGRect(x: 0, y: 0, width: 900, height: 1400))
        }
        let rotatedCG = try XCTUnwrap(rotatedPixels.cgImage)
        let orientedImage = UIImage(cgImage: rotatedCG, scale: 1, orientation: .right)

        // 1. UIImage path
        let uiObs = try await ScreenshotOCR.recognizeText(in: orientedImage)
        let uiItems = ScreenshotParser.parse(pages: [uiObs], defaultCurrency: "USD", now: day(2026, 11, 23), calendar: calendar)
        XCTAssertEqual(uiItems.first?.name, "Spotify")
        XCTAssertEqual(uiItems.first?.amount, Decimal(string: "11.99"))

        // 2. Raw JPEG bytes path with EXIF Orientation=6 preserved
        let jpegData = try XCTUnwrap(orientedImage.jpegData(compressionQuality: 0.92))
        let dataObs = try await ScreenshotOCR.recognizeText(in: jpegData)
        let dataItems = ScreenshotParser.parse(pages: [dataObs], defaultCurrency: "USD", now: day(2026, 11, 23), calendar: calendar)
        XCTAssertEqual(dataItems.first?.name, "Spotify")
        XCTAssertEqual(dataItems.first?.amount, Decimal(string: "11.99"))
        XCTAssertEqual(dataItems.first?.renewalDate, day(2026, 12, 18))
    }
}
