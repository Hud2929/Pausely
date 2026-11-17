import Foundation

/// Where a web page says it keeps its icon: its `<link rel="apple-touch-icon">` and `<link rel="icon">`
/// tags. Read for a service whose site has no icon at the usual addresses (`LogoStore`).
enum PageIcons {
    /// The most of a page that is read. The links are in its head, so reading stops where the head
    /// ends; this is for a page that never says so.
    static let bytesRead = 300_000

    /// Whether enough of a page has arrived to read its icons from: its head has closed, or the
    /// limit is reached. Only the end of what has arrived is looked at, so this can be asked often.
    static func hasReadEnough(_ arrived: Data) -> Bool {
        if arrived.count >= bytesRead { return true }
        let end = String(decoding: arrived.suffix(4_200), as: UTF8.self).lowercased()
        return end.contains("</head")
    }

    /// The icon addresses a page names, largest first. A touch icon that gives no size is 180 points
    /// by convention; a plain icon that gives none is tried last. Vector icons and the mask for a
    /// pinned tab are left out: neither can be drawn as a picture.
    static func named(in html: String, at page: URL) -> [URL] {
        guard let tags = try? NSRegularExpression(pattern: "<link\\b[^>]*>", options: [.caseInsensitive]) else { return [] }
        let text = html as NSString
        var found: [(side: Int, order: Int, url: URL)] = []
        for match in tags.matches(in: html, range: NSRange(location: 0, length: text.length)) {
            let tag = text.substring(with: match.range)
            guard let rel = attribute("rel", in: tag)?.lowercased(), rel.contains("icon"), !rel.contains("mask-icon"),
                  let href = attribute("href", in: tag)?.replacingOccurrences(of: "&amp;", with: "&"), !href.isEmpty,
                  let url = URL(string: href, relativeTo: page)?.absoluteURL,
                  url.pathExtension.lowercased() != "svg" else { continue }
            let side = attribute("sizes", in: tag).flatMap { Int($0.lowercased().split(separator: "x").first ?? "") }
                ?? (rel.contains("apple-touch") ? 180 : 0)
            if !found.contains(where: { $0.url == url }) { found.append((side, found.count, url)) }
        }
        // Largest first; among equals, the order the page gives them in.
        return found.sorted { $0.side != $1.side ? $0.side > $1.side : $0.order < $1.order }.map(\.url)
    }

    /// The value of one attribute of a tag, quoted either way or bare.
    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "(?<![\\w-])\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        let text = tag as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: text.length)) else { return nil }
        for group in 1...3 where match.range(at: group).location != NSNotFound {
            return text.substring(with: match.range(at: group)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
