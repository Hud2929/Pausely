import XCTest
@testable import Pausely

/// The catalog offered when adding a subscription, and where a service's logo may come from.
@MainActor
final class CatalogTests: XCTestCase {

    private var catalog: [CatalogEntry] { SubscriptionCatalogService.shared.catalog }

    /// A row is a name, a category and a checked link. One row per service: no name twice, and no
    /// row that is only another row's plan ("iCloud+ 200GB", "Spotify Family").
    func testOneRowPerService() {
        XCTAssertEqual(catalog.count, 849)
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

    // MARK: - The icon a service's own front page names

    /// On a new install 382 of the catalog's 848 services showed a letter: most of their sites keep no
    /// icon at the three usual addresses (measured 2026-11-17 in the app, by scrolling the whole
    /// catalog from an empty cache). A site's own front page says where its icon is; this is how
    /// that is read.
    func testAPagesIconsAreReadLargestFirstWhateverTheQuoting() throws {
        let page = try XCTUnwrap(URL(string: "https://www.example.com/en/"))
        let html = """
        <html><head>
        <link rel="stylesheet" href="/style.css">
        <link rel=icon href=/favicon-32.png sizes=32x32>
        <link rel='apple-touch-icon' href='/static/touch.png'>
        <link rel="icon" type="image/png" sizes="192x192" href="https://www.example.com/static/icon-192.png?v=2&amp;x=1">
        <link rel="mask-icon" href="/mask.svg" color="#000">
        <link rel="icon" href="/logo.svg" type="image/svg+xml">
        <link rel="shortcut icon" data-href="/wrong.png" href="favicon.ico">
        <link rel="icon" sizes="192x192" href="https://www.example.com/static/icon-192.png?v=2&amp;x=1">
        </head>
        """

        XCTAssertEqual(PageIcons.named(in: html, at: page).map(\.absoluteString), [
            "https://www.example.com/static/icon-192.png?v=2&x=1",
            "https://www.example.com/static/touch.png",
            "https://www.example.com/favicon-32.png",
            "https://www.example.com/en/favicon.ico"
        ])
        XCTAssertEqual(PageIcons.named(in: "<html><body>No head here</body></html>", at: page), [])
    }

    /// Every service on the first run's grid has a site its logo can be asked of. "Uber One" had none
    /// listed, so its tile was a letter on every phone, though uber.com gives an icon.
    @MainActor
    func testEveryFirstRunServiceHasASiteToAskForItsLogo() {
        let withoutASite = TallyCatalog.services.map(\.name).filter { ServiceDomains.domain(for: $0) == nil }
        XCTAssertEqual(withoutASite, [])
        XCTAssertEqual(ServiceDomains.domain(for: "Uber One"), "uber.com")
    }

    /// A front page can be megabytes; what is wanted is in its head. Reading stops where the head
    /// ends, or at the limit for a page that never ends it.
    func testAPageIsReadOnlyAsFarAsTheEndOfItsHead() {
        let opening = Data("<html><head><title>Example</title><link rel=\"icon\" href=\"/i.png\">".utf8)
        XCTAssertFalse(PageIcons.hasReadEnough(opening))
        XCTAssertTrue(PageIcons.hasReadEnough(opening + Data("</head><body>".utf8)))
        XCTAssertTrue(PageIcons.hasReadEnough(opening + Data("</HEAD>".utf8)))
        // The end of the head is found at the end of what has arrived, however much came before.
        let long = Data(repeating: 0x20, count: 120_000)
        XCTAssertFalse(PageIcons.hasReadEnough(long))
        XCTAssertTrue(PageIcons.hasReadEnough(long + Data("</head>".utf8) + Data(repeating: 0x20, count: 3_000)))
        XCTAssertTrue(PageIcons.hasReadEnough(Data(repeating: 0x20, count: PageIcons.bytesRead)), "a page with no end to its head stops at the limit")
        XCTAssertFalse(PageIcons.hasReadEnough(Data(repeating: 0x20, count: PageIcons.bytesRead - 1)))
    }

    /// An icon is asked of the service's own site and nobody else: one its page keeps on another
    /// company's servers is not asked for, and a page that answered from somewhere else (a service
    /// not offered in a country sends its visitors to another company) names nothing of the service's.
    func testOnlyIconsOnTheServicesOwnSiteAreAskedFor() throws {
        let page = try XCTUnwrap(URL(string: "https://www.example.com/"))
        let html = """
        <link rel="apple-touch-icon" sizes="180x180" href="https://cdn.example-assets.net/touch.png">
        <link rel="icon" sizes="96x96" href="/icon-96.png">
        <link rel="icon" sizes="64x64" href="https://static.example.com/icon-64.png">
        <link rel="icon" sizes="48x48" href="/icon-48.png">
        <link rel="icon" sizes="32x32" href="/icon-32.png">
        """

        let asked = ["https://www.example.com/icon-96.png", "https://static.example.com/icon-64.png", "https://www.example.com/icon-48.png"]
        XCTAssertEqual(LogoStore.icons(namedIn: html, at: page, for: "example.com").map(\.absoluteString), asked, "the three largest, on its own site")
        XCTAssertEqual(LogoStore.icons(namedIn: html, at: page, for: "www.example.com").map(\.absoluteString), asked)

        let elsewhere = try XCTUnwrap(URL(string: "https://www.another-company.com/not-available"))
        XCTAssertEqual(LogoStore.icons(namedIn: html, at: elsewhere, for: "example.com"), [])
        let plain = "<link rel=\"icon\" sizes=\"96x96\" href=\"http://www.example.com/icon.png\">"
        XCTAssertEqual(LogoStore.icons(namedIn: plain, at: page, for: "example.com"), [], "never over plain http")
    }

    /// The front page is asked after the three usual addresses, at the same site.
    func testTheFrontPageAskedIsTheServicesOwn() {
        XCTAssertEqual(LogoStore.frontPages(of: "www.netflix.com").map(\.absoluteString), ["https://www.netflix.com/", "https://netflix.com/"])
        XCTAssertEqual(LogoStore.frontPages(of: "netflix.com"), LogoStore.frontPages(of: "www.netflix.com"))
    }

    /// A site that answered and has no icon is left alone for a week, so its front page is not
    /// fetched on every launch. A site that could not be reached, or was in trouble, is asked again.
    func testASiteWithNoIconIsNotAskedAgainForAWeek() {
        let marked = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertTrue(LogoStore.missIsFresh(markedAt: marked, now: marked))
        XCTAssertTrue(LogoStore.missIsFresh(markedAt: marked, now: marked.addingTimeInterval(7 * 86_400 - 1)))
        XCTAssertFalse(LogoStore.missIsFresh(markedAt: marked, now: marked.addingTimeInterval(7 * 86_400)))
        XCTAssertFalse(LogoStore.missIsFresh(markedAt: marked, now: marked.addingTimeInterval(-60)), "a mark from the future is not believed")

        XCTAssertEqual([200, 403, 404, 410].map(LogoStore.settles(status:)), [true, true, true, true])
        XCTAssertEqual([408, 429, 500, 502, 503, 301].map(LogoStore.settles(status:)), [false, false, false, false, false, false])
    }

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
        XCTAssertEqual(ServiceDomains.assetHosts, ["duolingo.com": "d35aaqx5ub95lt.cloudfront.net",
                                                   "deezer.com": "cdn-files.dzcdn.net"])
        // Gmail's icon is asked of Gmail's own site (gmail.com has none).
        XCTAssertEqual(ServiceDomains.domain(for: "Gmail"), "mail.google.com")
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
