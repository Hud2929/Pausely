import AppKit

// Finds parts of a screen nothing painted.
//
// usage: swift scripts/tour_black_bands.swift <tour dir>/*.png
//
// Pausely's background is ink (#0B0C0E), never pure black. A vertical band of pure black running most
// of a capture's height is the window showing through: a scroll view that shrank to its content (the
// empty Insights tab did, in Arabic, at the largest text size and on iPad, until 2026-11-12).
// Prints each capture that has one, with the band's columns. Nothing printed means nothing found.

var found = false
for path in CommandLine.arguments.dropFirst() {
    guard let image = NSImage(contentsOfFile: path),
          let picture = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let width = picture.width, height = picture.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
    context.draw(picture, in: CGRect(x: 0, y: 0, width: width, height: height))

    // A column counts when it is black on 85% of the rows sampled across the middle of the screen.
    let rows = Array(stride(from: height / 5, to: height * 4 / 5, by: max(1, height / 60)))
    var blackColumns: [Int] = []
    for x in 0..<width {
        let black = rows.filter { y in
            let i = (y * width + x) * 4
            return pixels[i] <= 2 && pixels[i + 1] <= 2 && pixels[i + 2] <= 2
        }.count
        if Double(black) >= Double(rows.count) * 0.85 { blackColumns.append(x) }
    }

    // Bands at least 1% of the width.
    var bands: [String] = []
    var start: Int?
    var previous = -2
    for x in blackColumns + [Int.max] {
        if x != previous + 1 {
            if let first = start, previous - first + 1 >= max(6, width / 100) { bands.append("\(first)-\(previous)") }
            start = x == Int.max ? nil : x
        }
        previous = x
    }
    if !bands.isEmpty {
        found = true
        print((path as NSString).lastPathComponent, bands.joined(separator: " "), "of", width)
    }
}
exit(found ? 1 : 0)
