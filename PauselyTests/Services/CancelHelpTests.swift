import XCTest
@testable import Pausely

/// Whose cancellation help a subscription gets. Another company's steps, link and phone number are
/// worse than none, so a name gets a service's help only when it is that service.
@MainActor
final class CancelHelpTests: XCTestCase {

    private let matcher = ServiceMatcher(services: ServiceDatabase.services)
    private let manager = SubscriptionActionManager.shared
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

    func testAPhoneNumberIsOnlyEverTheServicesOwn() {
        let barkBox = TestFactories.makeSubscription(name: "BarkBox")
        XCTAssertTrue(manager.getSupportContacts(for: barkBox).isEmpty, "not Box's phone number")
        let netflix = TestFactories.makeSubscription(name: "Netflix")
        XCTAssertEqual(manager.getSupportContacts(for: netflix).first?.value, "1-866-579-7172")
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
        XCTAssertGreaterThanOrEqual(found, 285, "help that exists must not be lost either (291 when this was written)")
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

    func testAKnownServiceGetsItsStepsAndItsOwnCancellationPage() {
        let help = manager.cancelHelp(for: TestFactories.makeSubscription(name: "Netflix Premium"))
        XCTAssertEqual(help.kind, .cancellationPage)
        XCTAssertEqual(help.link?.absoluteString, "https://www.netflix.com/cancelplan")
        XCTAssertEqual(help.service?.instructions.count, 4)
    }

    /// In the catalog under exactly this name, but not a service with steps: the catalog's own link,
    /// which is the service's site. Called a website, with no steps claimed.
    func testACatalogNameGetsTheCatalogsLinkForExactlyThatName() {
        let help = manager.cancelHelp(for: TestFactories.makeSubscription(name: "barkbox"))
        XCTAssertEqual(help.kind, .website)
        XCTAssertEqual(help.link?.host, URL(string: SubscriptionCatalogService.shared.entry(named: "BarkBox")?.cancellationURL ?? "")?.host)
        XCTAssertNotNil(help.link?.host)
        XCTAssertNil(help.service)
    }

    /// Unknown: a search, called a search. The name goes in whole ("&" used to cut the question short).
    func testAnUnknownNameGetsASearchForExactlyThatName() throws {
        let help = manager.cancelHelp(for: TestFactories.makeSubscription(name: "Tom & Ann's Gym #2"))
        XCTAssertEqual(help.kind, .search)
        XCTAssertNil(help.service)
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
