import XCTest
@testable import Pausely

/// Whose cancellation help a subscription gets. Another company's steps, link and phone number are
/// worse than none, so a name gets a service's help only when it is that service.
@MainActor
final class CancelHelpTests: XCTestCase {

    private let matcher = ServiceMatcher(services: ServiceDatabase.services)
    private func service(_ name: String) -> String? { matcher.service(for: name)?.name }

    // MARK: Never the wrong company

    /// Every name here is in the app's own catalog, and each used to be shown the help of the company
    /// beside it, because its name contained or resembled that company's.
    func testANameThatOnlyContainsOrResemblesAServiceBelongsToNoService() {
        let usedToGet = [
            "Loom": "Bloomberg", "Allstate": "Paramount+", "Healthy Paws Pet Insurance": "AWS",
            "Amazon Home Services": "AWS", "AT&T": "DirecTV Stream", "StreamYard": "DirecTV Stream",
            "BarkBox": "Box", "BarkBox Monthly": "Box", "BattlBox": "Box", "Bean Box": "Box", "Birchbox": "Box",
            "ButcherBox": "Box", "UnboxBoardom": "Box", "Anytime Mailbox": "Box",
            "LegalZoom Business": "Zoom", "Postman": "Washington Post", "Bitbucket": "Bitwarden",
            "Datadog": "DataCamp", "CircleCI": "Target Circle 360", "ClassPass": "MasterClass",
            "Comixology": "Monday.com", "Ghost": "CyberGhost VPN", "Greenhouse": "Green Blender",
            "GameFly": "Xbox Game Pass", "Oura": "OurTime", "Sunrun": "Sunbasket",
            "Runway": "Nike Run Club Premium", "Dollar Flight Club Premium": "Nike Training Club Premium",
            "Reddit Premium": "YouTube Premium", "Musicbed": "YouTube Premium",
            "Audible Premium Plus": "Spotify", "Ring Protect Plus": "Dropbox", "Ring Protect Pro": "SoundCloud Go+",
            "Prodigy": "SoundCloud Go+", "Progressive": "SoundCloud Go+",
            "WeWork All Access": "Paramount+", "iHeartRadio All Access": "Paramount+",
            "Amazon Music Prime": "Amazon Prime Video", "NordPass": "NordVPN"
        ]
        for (name, wrong) in usedToGet.sorted(by: { $0.key < $1.key }) {
            XCTAssertNil(service(name), "\(name) was shown \(wrong)'s cancellation help")
        }
    }

    func testAnotherProductOfTheSameCompanyIsNotGuessed() {
        for name in ["YouTube Kids", "Netflix Party", "Google Fi", "Apple Pay", "Udemy Business", "ChatGPT Team",
                     "Spotify for Podcasters", "Dropbox Sign", "Box of Style", "Zoom Phone", "Max Mara", "Prime Gaming"] {
            XCTAssertNil(service(name), name)
        }
    }

    /// Across the whole catalog: whatever service a name gets, one of that service's names is how the
    /// catalog name begins. Matching on "contains" can't come back without failing this.
    func testEveryCatalogNameThatGetsAServiceBeginsWithThatServicesName() {
        var found = 0
        for entry in SubscriptionCatalogService.shared.catalog {
            guard let service = matcher.service(for: entry.name) else { continue }
            found += 1
            let wanted = ServiceMatcher.words(entry.name).joined()
            let names = ([service.name, service.id] + service.aliases).map { ServiceMatcher.words($0).joined() }
            XCTAssertTrue(names.contains { !$0.isEmpty && wanted.hasPrefix($0) },
                          "\(entry.name) got \(service.name)")
        }
        XCTAssertGreaterThanOrEqual(found, 195, "help that exists must not be lost either (200 of the catalog's 848 rows when this was written)")
    }

    // MARK: Always the right one

    func testEveryServiceIsFoundByItsNameItsIdAndEachOfItsOtherNames() {
        for wanted in ServiceDatabase.services {
            for name in [wanted.name, wanted.id] + wanted.aliases {
                XCTAssertEqual(matcher.service(for: name)?.id, wanted.id, "\"\(name)\" should be \(wanted.name)")
            }
        }
    }

    func testTheSameNameWrittenAnotherWayIsTheSameService() {
        for name in ["Disney+", "disney plus", "DISNEYPLUS", " Disney + ", "Disney-Plus"] {
            XCTAssertEqual(service(name), "Disney+", name)
        }
        XCTAssertEqual(service("ProtonVPN"), "Proton VPN")
        XCTAssertEqual(service("netflix.com"), "Netflix")
    }

    func testAPlanAfterTheNameIsStillThatService() {
        let expected = [
            "Netflix Premium": "Netflix", "Netflix Standard with Ads": "Netflix", "Spotify Family": "Spotify",
            "Spotify Premium Duo (monthly)": "Spotify", "Hulu (No Ads)": "Hulu", "iCloud+ 200GB": "iCloud+",
            "Google One 2TB": "Google One", "YouTube Premium Family": "YouTube Premium",
            "Apple Music Student": "Apple Music", "ProtonVPN Plus": "Proton VPN",
            "Xbox Game Pass Ultimate": "Xbox Game Pass", "PlayStation Plus Extra": "PlayStation Plus",
            "1Password Families": "1Password", "New York Times Digital": "New York Times",
            "Apple One Family": "Apple One"
        ]
        for (name, wanted) in expected.sorted(by: { $0.key < $1.key }) {
            XCTAssertEqual(service(name), wanted, name)
        }
    }

    /// The longest name wins: YouTube Music's plans are YouTube Music's, never YouTube Premium's.
    func testTheLongestNameWins() {
        XCTAssertEqual(service("YouTube Music Premium"), "YouTube Music")
        XCTAssertEqual(service("YouTube Music Family"), "YouTube Music")
        XCTAssertEqual(service("Amazon Music Unlimited Family"), "Amazon Music Unlimited")
        XCTAssertEqual(service("Amazon Prime"), "Amazon Prime")
        XCTAssertEqual(service("Prime Video"), "Amazon Prime Video")
    }

    // MARK: What the cancel screen offers

    func testAKnownServiceGetsItsOwnCancellationPage() {
        let help = CancelHelp.find(for: TestFactories.makeSubscription(name: "Netflix Premium"))
        XCTAssertEqual(help, CancelHelp(kind: .cancellationPage, link: URL(string: "https://www.netflix.com/cancelplan")))
    }

    /// Where the page Pausely had for a service turned out not to exist, the link is the service's
    /// front page, and the screen calls it a website, not a cancellation page.
    func testALinkToAFrontPageIsCalledAWebsite() throws {
        let frontPage = try XCTUnwrap(ServiceDatabase.services.first {
            !$0.isBilledByApple && URL(string: $0.cancelURL).map(CancelHelp.isFrontPage) == true
        })
        let help = CancelHelp.find(for: TestFactories.makeSubscription(name: frontPage.name))
        XCTAssertEqual(help, CancelHelp(kind: .website, link: URL(string: frontPage.cancelURL)))
        XCTAssertTrue(CancelHelp.isFrontPage(URL(string: "https://www.example.com")!))
        XCTAssertTrue(CancelHelp.isFrontPage(URL(string: "https://www.example.com/")!))
        XCTAssertFalse(CancelHelp.isFrontPage(URL(string: "https://www.example.com/account/cancel")!))
    }

    /// Anything Apple bills is cancelled in Settings by the same steps, so it gets those steps and
    /// Apple's own link, whether Pausely knows it as a service or only from the catalog.
    func testASubscriptionBilledByAppleGetsApplesSteps() {
        let apples = CancelHelp(kind: .appleSubscription, link: URL(string: "https://apps.apple.com/account/subscriptions"))
        for name in ["Apple One", "Apple TV+", "iCloud+ 200GB", "Apple Music Student", "Apple News+"] {
            XCTAssertEqual(CancelHelp.find(for: TestFactories.makeSubscription(name: name)), apples, name)
        }
        let listedByTheCatalog = SubscriptionCatalogService.shared.catalog.first {
            CancelHelp.isApples($0.cancellationURL ?? "") && CancelHelp.service(named: $0.name) == nil
        }
        if let entry = listedByTheCatalog {
            XCTAssertEqual(CancelHelp.find(for: TestFactories.makeSubscription(name: entry.name)), apples, entry.name)
        }
    }

    /// The data holds a link and names for each service, and nothing that was never checked.
    func testEveryServiceHasASecureCancellationLinkOfItsOwn() {
        XCTAssertEqual(ServiceDatabase.services.count, 201)
        XCTAssertEqual(Set(ServiceDatabase.services.map(\.id)).count, 201, "no id twice")
        for service in ServiceDatabase.services {
            let url = URL(string: service.cancelURL)
            XCTAssertEqual(url?.scheme, "https", service.name)
            XCTAssertNotNil(url?.host, service.name)
        }
        XCTAssertEqual(ServiceDatabase.services.filter(\.isBilledByApple).map(\.name).sorted(),
                       ["Apple Arcade", "Apple Fitness+", "Apple Music", "Apple News+", "Apple One", "Apple TV+", "iCloud+"])
    }

    /// In the catalog under exactly this name, but not a service with steps: the catalog's own link,
    /// which is the service's site. Called a website, with no steps claimed.
    func testACatalogNameGetsTheCatalogsLinkForExactlyThatName() {
        let help = CancelHelp.find(for: TestFactories.makeSubscription(name: "barkbox"))
        XCTAssertEqual(help.kind, .website)
        XCTAssertEqual(help.link?.host, URL(string: SubscriptionCatalogService.shared.entry(named: "BarkBox")?.cancellationURL ?? "")?.host)
        XCTAssertNotNil(help.link?.host)
    }

    /// Unknown: a search, called a search. The name goes in whole ("&" used to cut the question short).
    func testAnUnknownNameGetsASearchForExactlyThatName() throws {
        let help = CancelHelp.find(for: TestFactories.makeSubscription(name: "Tom & Ann's Gym #2"))
        XCTAssertEqual(help.kind, .search)
        let link = try XCTUnwrap(help.link)
        XCTAssertEqual(link.host, "www.google.com")
        let question = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(question, [URLQueryItem(name: "q", value: "cancel Tom & Ann's Gym #2 subscription")])
    }

    /// Every link the catalog offers for cancelling is a secure address with a host.
    func testEveryCatalogLinkIsASecureAddress() {
        for entry in SubscriptionCatalogService.shared.catalog {
            guard let text = entry.cancellationURL else { continue }
            let url = URL(string: text)
            XCTAssertEqual(url?.scheme, "https", "\(entry.name): \(text)")
            XCTAssertNotNil(url?.host, "\(entry.name): \(text)")
        }
    }
}
