import XCTest
@testable import Pausely

/// The catalog offered when adding a subscription, and where a service's logo may come from.
@MainActor
final class CatalogTests: XCTestCase {

    private var catalog: [CatalogEntry] { SubscriptionCatalogService.shared.catalog }

    /// A row is a name, a category and a checked link. One row per service: no name twice, and no
    /// row that is only another row's plan ("iCloud+ 200GB", "Spotify Family").
    func testOneRowPerService() {
        XCTAssertEqual(catalog.count, 848)
        XCTAssertEqual(Set(catalog.map { $0.name.lowercased() }).count, catalog.count)
        let names = Set(catalog.map(\.name))
        for gone in ["iCloud+ 200GB", "Spotify Family", "Netflix Premium", "Google One 2TB", "ChatGPT Pro ($100)", "Dropbox Plus"] {
            XCTAssertFalse(names.contains(gone), gone)
        }
        for kept in ["iCloud+", "Spotify", "Netflix", "Google One", "ChatGPT Plus", "ChatGPT Pro", "Dropbox", "Apple One", "Target Circle 360"] {
            XCTAssertTrue(names.contains(kept), kept)
        }
    }

    /// Pausely's own row used to be offered here, described as having "bank sync". Its line is added
    /// from the App Store's own price when someone subscribes, never picked from a list.
    func testPauselyDoesNotListItself() {
        XCTAssertNil(SubscriptionCatalogService.shared.entry(named: "Pausely Pro"))
        XCTAssertFalse(catalog.contains { $0.name.lowercased().contains("pausely") })
    }

    func testLookupIsByExactNameAnyCase() {
        XCTAssertEqual(SubscriptionCatalogService.shared.entry(named: " netflix ")?.name, "Netflix")
        XCTAssertNil(SubscriptionCatalogService.shared.entry(named: "Netflix Premium"))
        XCTAssertNil(SubscriptionCatalogService.shared.entry(named: "Net"))
    }

    // MARK: Logos

    /// A logo comes from the service's own site: the one in Pausely's own list, else the site of the
    /// catalog's checked link. The catalog used to invent a website from the name with ".com" on the
    /// end, and whoever owned that address supplied the logo.
    func testALogoComesFromTheServicesOwnSite() {
        XCTAssertEqual(ServiceDomains.siteDomain(ofLink: "https://account.adobe.com/plans"), "adobe.com")
        XCTAssertEqual(ServiceDomains.siteDomain(ofLink: "https://www.stitchfix.com/"), "stitchfix.com")
        XCTAssertEqual(ServiceDomains.siteDomain(ofLink: "https://www.screamingfrog.co.uk/seo-spider/"), "screamingfrog.co.uk")
        XCTAssertNil(ServiceDomains.siteDomain(ofLink: "https://apps.apple.com/account/subscriptions"),
                     "Apple's subscriptions page is nobody's logo in particular")
        XCTAssertNil(ServiceDomains.siteDomain(ofLink: "not a link"))

        XCTAssertEqual(ServiceDomains.domain(for: "Netflix"), "netflix.com")
        XCTAssertNil(ServiceDomains.domain(for: "My Gym Downtown"), "an unknown name gets the initial, never a guessed site")
        let linkOnly = try? XCTUnwrap(catalog.first { entry in
            entry.cancellationURL.flatMap(ServiceDomains.siteDomain(ofLink:)) != nil
        })
        if let entry = linkOnly, let link = entry.cancellationURL {
            XCTAssertNotNil(ServiceDomains.domain(for: entry.name))
            XCTAssertNotNil(URL(string: link)?.host)
        }
    }

    /// Icons are asked of the service's own site and nobody else. A lookup service used to be asked
    /// as a last resort, which told it the address of every service whose icon was missing.
    func testIconsAreOnlyAskedOfTheServiceItself() {
        let sources = LogoStore.sources(for: "www.netflix.com")
        XCTAssertEqual(sources.map(\.absoluteString), [
            "https://netflix.com/apple-touch-icon.png",
            "https://www.netflix.com/apple-touch-icon.png",
            "https://netflix.com/favicon.ico"
        ])
        XCTAssertTrue(sources.allSatisfy { $0.host?.hasSuffix("netflix.com") == true })
    }
}
