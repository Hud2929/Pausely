// Reads a screen tour's captures the way a person would have to, and says what it finds.
//
//   swiftc -O scripts/tour_read.swift -o /tmp/tour_read
//   /tmp/tour_read contrast <tour folder>   every text on every capture, by the pixels it was drawn with
//   /tmp/tour_read words <tour folder>      every word that can be read on a capture, looked up in what
//                                           accessibility says for that screen
//   /tmp/tour_read audit <tour folder>      what is drawn at each place the system audit called low contrast
//
// A tour folder is what `PauselyUITests/ScreenTourTests` writes when `TEST_RUNNER_PAUSELY_TOUR_DIR`
// is set: for each screen a capture (`name.png`) and its element tree (`name.txt`).
//
// Why this exists: the system audit's contrast lines change from run to run on a screen that has
// not changed (the same list, three runs on 2026-11-16: 11 lines, 3, none), and its "potentially
// inaccessible text" lines name no element. These three readings are of the capture itself, so
// they come out the same every time and each line can be looked up.
//
// Each reading lists; a person decides. What has turned out not to be the app's, each time:
// the system's own controls (the red button of a confirmation, the calendar's days that cannot
// be chosen, a paste button with nothing to paste), a row passing under a bar or a pinned
// heading, an empty field read by the edge it has while typed in, and words the reader got
// wrong (a logo's lettering, text cut by a bar).

import Foundation
import CoreGraphics
import ImageIO
import Vision

typealias Picture = (data: [UInt8], width: Int, height: Int)

func load(_ path: String) -> Picture? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let saved = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    // A capture taken with the device on its side is saved the way the screen is built, with a
    // note of how it was turned. Read without the note, every text of an iPad on its side was
    // looked for across the screen's other edge (2026-11-17: 3,345 of its texts "not drawn").
    var image = saved
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    if let turned = properties?[kCGImagePropertyOrientation] as? Int, turned != 1 {
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: max(saved.width, saved.height)]
        guard let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        image = upright
    }
    let width = image.width, height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (data, width, height)
}

/// WCAG 2 relative luminance and contrast ratio.
func luminance(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Double {
    func linear(_ c: UInt8) -> Double { let v = Double(c) / 255; return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
}
func ratio(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }
func hex(_ c: (UInt8, UInt8, UInt8)) -> String { String(format: "#%02X%02X%02X", c.0, c.1, c.2) }

struct Reading {
    var background: (UInt8, UInt8, UInt8)
    var text: (UInt8, UInt8, UInt8)
    var ratio: Double
    /// False when fewer than 13 pixels differ from the background: nothing is drawn there (the
    /// element is covered, or is not where the tree says).
    var drawn: Bool

    var line: String { "on \(hex(background)) | drawn \(hex(text)) | \(String(format: "%.1f", ratio)) to 1" }
}

/// What is drawn inside `frame` (in points) of a capture `pointsWide` points wide. The commonest
/// colour is the background. The text is what stands furthest from it, taken where at least 13
/// pixels reach: a stroke's core, not one stray pixel of a neighbour.
func read(_ picture: Picture, _ frame: [Double], pointsWide: Double) -> Reading? {
    let scale = Double(picture.width) / pointsWide
    let x0 = max(0, Int(frame[0] * scale)), y0 = max(0, Int(frame[1] * scale))
    let x1 = min(picture.width, Int((frame[0] + frame[2]) * scale)), y1 = min(picture.height, Int((frame[1] + frame[3]) * scale))
    guard x1 > x0 + 2, y1 > y0 + 2 else { return nil }
    var bins: [Int: (count: Int, r: Int, g: Int, b: Int)] = [:]
    for y in y0..<y1 { for x in x0..<x1 {
        let i = (y * picture.width + x) * 4
        let key = (Int(picture.data[i]) >> 3) << 10 | (Int(picture.data[i + 1]) >> 3) << 5 | Int(picture.data[i + 2]) >> 3
        var bin = bins[key] ?? (0, 0, 0, 0)
        bin.count += 1; bin.r += Int(picture.data[i]); bin.g += Int(picture.data[i + 1]); bin.b += Int(picture.data[i + 2])
        bins[key] = bin
    } }
    guard let commonest = bins.values.max(by: { $0.count < $1.count }) else { return nil }
    let background = (UInt8(commonest.r / commonest.count), UInt8(commonest.g / commonest.count), UInt8(commonest.b / commonest.count))
    let backgroundLuminance = luminance(background.0, background.1, background.2)
    var ratios: [(Double, (UInt8, UInt8, UInt8))] = []
    for y in y0..<y1 { for x in x0..<x1 {
        let i = (y * picture.width + x) * 4
        let value = ratio(luminance(picture.data[i], picture.data[i + 1], picture.data[i + 2]), backgroundLuminance)
        if value > 1.5 { ratios.append((value, (picture.data[i], picture.data[i + 1], picture.data[i + 2]))) }
    } }
    ratios.sort { $0.0 > $1.0 }
    let reached = ratios.count > 12 ? ratios[12] : (ratios.last ?? (1, background))
    return Reading(background: background, text: reached.1, ratio: reached.0, drawn: ratios.count > 12)
}

/// One line of a capture's element tree.
struct Element {
    var depth: Int
    var kind: String
    var frame: [Double]
    /// Everything the line says after the frame, without identifiers (they are not spoken).
    var says: String
}

func elements(of tree: String) -> [Element] {
    var found: [Element] = []
    var seenWindow = false
    for row in tree.components(separatedBy: "\n") {
        let trimmed = row.drop { $0 == " " || $0 == "→" }
        let kind = String(trimmed.prefix { $0 != "," })
        // The tree is printed twice (the second time as the query that found it): once is enough.
        if kind == "Application", seenWindow { break }
        if kind.hasPrefix("Window (Main)") { seenWindow = true }
        var frame: [Double] = []
        var says = ""
        if let open = row.range(of: "{{"), let close = row.range(of: "}}", range: open.upperBound..<row.endIndex) {
            frame = row[open.upperBound..<close.lowerBound].split(whereSeparator: { "{}, ".contains($0) }).compactMap { Double($0) }
            says = String(row[close.upperBound...])
            while let id = says.range(of: "identifier: '") {
                let end = says.range(of: "'", range: id.upperBound..<says.endIndex)?.upperBound ?? says.endIndex
                says.removeSubrange(id.lowerBound..<end)
            }
        }
        found.append(Element(depth: row.count - trimmed.count, kind: kind, frame: frame.count == 4 ? frame : [], says: says))
    }
    return found
}

func captures(in folder: String) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
        .filter { $0.hasSuffix(".png") }.map { String($0.dropLast(4)) }.sorted()
}

let arguments = CommandLine.arguments
guard arguments.count == 3, ["contrast", "words", "audit"].contains(arguments[1]) else {
    print("usage: tour_read contrast|words|audit <tour folder>")
    exit(2)
}
let folder = arguments[2]

switch arguments[1] {
case "contrast":
    var fine = 0, low = 0, blank = 0
    let measured: Set = ["StaticText", "TextField", "SecureTextField", "SearchField", "Button", "Link"]
    for screen in captures(in: folder) {
        guard let tree = try? String(contentsOfFile: folder + "/" + screen + ".txt", encoding: .utf8),
              let picture = load(folder + "/" + screen + ".png") else { continue }
        let all = elements(of: tree)
        guard let window = all.firstIndex(where: { $0.kind.hasPrefix("Window (Main)") }), all[window].frame.count == 4 else { continue }
        let width = all[window].frame[2], height = all[window].frame[3]
        // Only what is on top is measured. Each presentation (the screen, a sheet over it, a
        // confirmation over that) is one child of the main window, in the order they were put up,
        // so everything before the last of them is covered or dimmed by it.
        var end = window + 1
        var presentations: [Int] = []
        while end < all.count, all[end].depth > all[window].depth {
            if all[end].depth == all[window].depth + 2 { presentations.append(end) }
            end += 1
        }
        let first = presentations.last ?? window + 1
        var skipDeeperThan: Int? = nil
        for index in first..<end {
            let element = all[index]
            if let depth = skipDeeperThan { if element.depth > depth { continue } else { skipDeeperThan = nil } }
            // The system's own bars and keyboard are not the app's to colour.
            if ["TabBar", "Keyboard", "NavigationBar"].contains(element.kind) { skipDeeperThan = element.depth; continue }
            guard measured.contains(element.kind), element.frame.count == 4 else { continue }
            var frame = element.frame
            if element.kind == "Button" {
                // A button is measured by its texts when it has them, and by itself, inside its
                // edge, when it is only a symbol or a word.
                var next = index + 1
                var hasText = false
                while next < end, all[next].depth > element.depth { if all[next].kind == "StaticText" { hasText = true }; next += 1 }
                if hasText { continue }
                frame = [frame[0] + 5, frame[1] + 5, frame[2] - 10, frame[3] - 10]
            }
            // Below the status bar and wholly on the screen.
            guard frame[1] >= 54, frame[1] + frame[3] <= height, frame[0] >= 0, frame[0] + frame[2] <= width, frame[2] > 4, frame[3] > 4,
                  let reading = read(picture, frame, pointsWide: width) else { continue }
            if !reading.drawn { blank += 1; continue }
            // A field with nothing in it and no hint is read by its edge, which has to be seen
            // (3 to 1); words have to be read (4.5 to 1).
            let isAField = element.kind == "TextField" || element.kind == "SecureTextField"
            let onlyAnEdge = isAField && !element.says.contains("placeholderValue:") && !element.says.contains("value:")
            if reading.ratio >= (onlyAnEdge ? 3 : 4.5) { fine += 1; continue }
            low += 1
            let place = "\(Int(element.frame[0])),\(Int(element.frame[1])) \(Int(element.frame[2]))x\(Int(element.frame[3]))"
            print("\(screen) | \(element.kind) |\(element.says.prefix(70)) | \(place) | \(reading.line)")
        }
    }
    print("texts measured: \(fine) at 4.5 to 1 or more (an empty field's edge at 3), \(low) below, \(blank) with nothing drawn at their place")

case "words":
    func plain(_ text: String) -> String { String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }) }
    var lines = 0, unsaid = 0
    for screen in captures(in: folder) {
        guard let tree = try? String(contentsOfFile: folder + "/" + screen + ".txt", encoding: .utf8),
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: folder + "/" + screen + ".png") as CFURL, nil),
              let picture = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
        var said = ""
        var logos: [CGRect] = []
        var keyboardTop = Double.infinity
        var width = 402.0, height = 874.0
        for element in elements(of: tree) where element.frame.count == 4 {
            if element.kind.hasPrefix("Window (Main)") { width = element.frame[2]; height = element.frame[3] }
            if element.kind == "Keyboard" { keyboardTop = min(keyboardTop, element.frame[1]) }
            // A service's logo has lettering of its own; its name is the text beside it.
            if element.kind == "Image", element.frame[2] <= 90, element.frame[3] <= 90 {
                logos.append(CGRect(x: element.frame[0], y: element.frame[1], width: element.frame[2], height: element.frame[3]))
            }
            said += "|" + plain(element.says)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: picture, options: [:]).perform([request])
        for observation in request.results ?? [] {
            guard let best = observation.topCandidates(1).first else { continue }
            let box = observation.boundingBox
            let x = box.minX * width, y = (1 - box.maxY) * height, w = box.width * width, h = box.height * height
            let middle = CGPoint(x: x + w / 2, y: y + h / 2)
            // Not the status bar, the keyboard or a logo.
            if y < 54 || middle.y >= keyboardTop || logos.contains(where: { $0.insetBy(dx: -4, dy: -4).contains(middle) }) { continue }
            lines += 1
            var missing: [String] = []
            for word in best.string.split(separator: " ") {
                let token = plain(String(word))
                guard token.count >= 3, !said.contains(token) else { continue }
                // A figure read with one sign wrong ("S20.00"): its digits are what is looked up.
                let digits = String(token.filter { $0.isNumber })
                if digits.count >= 3, Double(digits.count) / Double(token.count) >= 0.6, said.contains(digits) { continue }
                missing.append(String(word))
            }
            if !missing.isEmpty {
                unsaid += 1
                print("\(screen) | \(best.string.prefix(70)) | \(Int(x)),\(Int(y)) \(Int(w))x\(Int(h)) | not said: \(missing.joined(separator: " "))")
            }
        }
    }
    print("lines read: \(lines); with a word accessibility does not say: \(unsaid)")

default:
    guard let text = try? String(contentsOfFile: folder + "/audit.txt", encoding: .utf8) else { print("no audit.txt in \(folder)"); exit(2) }
    var pictures: [String: Picture] = [:]
    var fine = 0, low = 0, blank = 0
    for row in text.split(separator: "\n") {
        // capture | kind | title | element | x,y WxH | detail
        let parts = row.components(separatedBy: " | ")
        guard parts.count >= 5, parts[1] == "contrast" else { continue }
        let frame = parts[4].split(whereSeparator: { ", x".contains($0) }).compactMap { Double($0) }
        if pictures[parts[0]] == nil { pictures[parts[0]] = load(folder + "/" + parts[0] + ".png") }
        // The audit's places are in points on a phone 402 wide; an iPad tour is read with `contrast`.
        guard frame.count == 4, let picture = pictures[parts[0]], let reading = read(picture, frame, pointsWide: 402) else {
            blank += 1
            print("\(parts[0]) | \(parts[3].prefix(40)) | no place")
            continue
        }
        if !reading.drawn { blank += 1 } else if reading.ratio >= 4.5 { fine += 1 } else { low += 1 }
        print("\(parts[0]) | \(parts[3].prefix(40)) | \(parts[4]) | \(reading.drawn ? reading.line : "nothing drawn there")")
    }
    print("the audit's contrast lines: \(fine) at 4.5 to 1 or more as drawn, \(low) below, \(blank) with nothing drawn at the place given")
}
