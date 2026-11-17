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

    /// A service's icon is asked of the three usual addresses on its own site. A few of the
    /// best-known keep theirs elsewhere on that site: on a simulator that had never run the app,
    /// YouTube Premium, Google One and PlayStation Plus were letters on the first-run screen
    /// (2026-11-17). Their address is known, asked first, and never on anyone else's site.
    func testAnIconKeptElsewhereIsAskedForFirstAndOnlyOnTheServicesOwnSite() throws {
        XCTAssertEqual(LogoStore.sources(for: "netflix.com").map(\.absoluteString),
                       ["https://netflix.com/apple-touch-icon.png", "https://www.netflix.com/apple-touch-icon.png", "https://netflix.com/favicon.ico"])
        XCTAssertEqual(ServiceDomains.iconAddresses.count, 6)
        for (domain, address) in ServiceDomains.iconAddresses {
            let url = try XCTUnwrap(URL(string: address), address)
            // On the service's own domain, or the one host its own front page names for its icon.
            XCTAssertTrue(ServiceDomains.isOwnSite(url, of: domain),
                          "\(address) is not on \(domain): an icon is asked of the service's own site and nobody else")
            XCTAssertEqual(LogoStore.sources(for: domain).first, url)
            XCTAssertEqual(LogoStore.sources(for: "www." + domain).first, url)
            XCTAssertEqual(LogoStore.sources(for: domain).count, 4, "the usual three are still tried after it")
        }
        // The services that showed a letter on a new install, on the first screens with logos.
        XCTAssertEqual(ServiceDomains.assetHosts, ["duolingo.com": "d35aaqx5ub95lt.cloudfront.net"])
        // What "its own site" means, and that an address anywhere else is never asked.
        XCTAssertTrue(ServiceDomains.isOwnSite(try XCTUnwrap(URL(string: "https://gmedia.playstation.com/x.png")), of: "playstation.com"))
        XCTAssertFalse(ServiceDomains.isOwnSite(try XCTUnwrap(URL(string: "https://notplaystation.com/x.png")), of: "playstation.com"))
        XCTAssertFalse(ServiceDomains.isOwnSite(try XCTUnwrap(URL(string: "http://www.youtube.com/img/favicon_144.png")), of: "youtube.com"), "not over plain http")
        XCTAssertFalse(ServiceDomains.isOwnSite(try XCTUnwrap(URL(string: "https://d35aaqx5ub95lt.cloudfront.net/x.png")), of: "dropbox.com"),
                       "the one listed host is Duolingo's, and nobody else's")
        for name in ["YouTube Premium", "Google One", "PlayStation Plus", "Discord Nitro", "Notion", "Duolingo"] {
            let domain = try XCTUnwrap(ServiceDomains.domain(for: name), name)
            XCTAssertNotNil(ServiceDomains.iconAddresses[domain], "\(name) is asked for its icon where its site keeps none")
        }
    }

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
