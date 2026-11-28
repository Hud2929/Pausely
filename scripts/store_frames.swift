// Makes the App Store pictures: each capture inside a drawn device, under a caption, on paper or ink.
//
//   swiftc -O scripts/store_frames.swift -o /tmp/PauselyBuild/store_frames
//   /tmp/PauselyBuild/store_frames . [locale …]        (no locale: every one in captions.json)
//
// Reads  AppStoreScreenshots/captions.json                       the locales, the frames, the words
//        AppStoreScreenshots/captures/<capture>/<device>/*.png   from scripts/store_capture.sh
//        AppStoreScreenshots/fonts/*.ttf                         open-licence faces (see fonts/README.md)
// Writes AppStoreScreenshots/store/<locale>/<device>/*.png       what is uploaded, at the capture's size
//
// A caption's headline breaks where it says "\n", and what stands between two stars is the part in
// colour. A headline too wide or too tall for its place is set smaller, never cut.
import CoreGraphics
import CoreText
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: - What it is told

struct Spec: Decodable {
    struct Place: Decodable { let capture: String; let language: String }
    struct Frame: Decodable { let file: String; let theme: String }
    struct Caption: Decodable { let eyebrow: String; let headline: String }
    let locales: [String: Place]
    let frames: [Frame]
    let captions: [String: [String: Caption]]
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else { fail("usage: store_frames <repository root> [locale …]") }
let shots = URL(fileURLWithPath: arguments[1]).appendingPathComponent("AppStoreScreenshots")
let spec: Spec
do {
    spec = try JSONDecoder().decode(Spec.self, from: Data(contentsOf: shots.appendingPathComponent("captions.json")))
} catch { fail("captions.json: \(error)") }
let wanted = arguments.count > 2 ? Array(arguments[2...]) : spec.locales.keys.sorted()

// MARK: - Colour (the app's own, Shared/Palette.swift)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

struct Theme { let ground, headline, emphasis, eyebrow: CGColor; let shadow: CGFloat }
let themes: [String: Theme] = [
    "paper": Theme(ground: color(0xECE7DC), headline: color(0x1A1A17), emphasis: color(0x0B6245),
                   eyebrow: color(0x5A574E), shadow: 0.34),
    "ink": Theme(ground: color(0x0A0B0D), headline: color(0xF5F4F0), emphasis: color(0x34D399),
                 eyebrow: color(0xB4B6BC), shadow: 0),
]

// MARK: - Type

func face(_ file: String) -> CGFont {
    let url = shots.appendingPathComponent("fonts/" + file)
    guard let provider = CGDataProvider(url: url as CFURL), let font = CGFont(provider) else { fail("no font at \(url.path)") }
    return font
}

/// The faces of one script. `scale` and `small` even out how large each script's headline and
/// eyebrow look at one size; `leading` is the line height as a share of the size; `tracking` opens
/// the eyebrow's letters (never for a joined script, whose letters it would pull apart).
struct Faces {
    let headline, emphasis, eyebrow: CGFont
    let scale, small, leading, tracking: CGFloat
    let capitals: Bool
}

let latin = Faces(headline: face("Newsreader-Display-SemiBold.ttf"), emphasis: face("Newsreader-Display-SemiBoldItalic.ttf"),
                  eyebrow: face("IBMPlexMono-Medium.ttf"), scale: 1, small: 1, leading: 1.07, tracking: 0.14, capitals: true)
func faces(for language: String) -> Faces {
    switch language {
    case "ja":
        let serif = face("NotoSerifJP-Bold.ttf")
        return Faces(headline: serif, emphasis: serif, eyebrow: face("NotoSansJP-Medium.ttf"),
                     scale: 0.80, small: 1.08, leading: 1.26, tracking: 0.10, capitals: false)
    case "ar":
        let naskh = face("NotoNaskhArabic-Bold.ttf")
        return Faces(headline: naskh, emphasis: naskh, eyebrow: face("IBMPlexSansArabic-Medium.ttf"),
                     scale: 0.94, small: 1.22, leading: 1.42, tracking: 0, capitals: false)
    default:
        return latin
    }
}

func attributes(_ font: CGFont, _ size: CGFloat, _ color: CGColor, kern: CGFloat = 0) -> [NSAttributedString.Key: Any] {
    [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithGraphicsFont(font, size, nil, nil),
     NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
     NSAttributedString.Key(kCTKernAttributeName as String): kern]
}

/// One line of a headline: the part between two stars is the emphasis.
func headlineLine(_ text: String, size: CGFloat, faces: Faces, theme: Theme) -> CTLine {
    let whole = NSMutableAttributedString()
    for (index, part) in text.components(separatedBy: "*").enumerated() where !part.isEmpty {
        let strong = index % 2 == 1
        whole.append(NSAttributedString(string: part, attributes: attributes(
            strong ? faces.emphasis : faces.headline, size, strong ? theme.emphasis : theme.headline)))
    }
    return CTLineCreateWithAttributedString(whole)
}

func width(_ line: CTLine) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) - CGFloat(CTLineGetTrailingWhitespaceWidth(line))
}

// MARK: - Where things go

/// Measures are in the picture's own pixels. `corner` is the screen's corner in the capture's pixels.
/// The iPhone stands whole above the foot of the picture. The iPad runs off it (`bottomGap` below
/// zero): the app keeps to a phone's width there, and a whole iPad would show it too small to read.
struct Layout {
    let name: String
    let size: CGSize
    let side, eyebrowTop, eyebrowSize, headlineTop, headlineSize, deviceTop, bottomGap: CGFloat
    let ring, border, corner: CGFloat
    let phone: Bool
}

let layouts = [
    Layout(name: "iphone-6.9", size: CGSize(width: 1320, height: 2868), side: 78, eyebrowTop: 150, eyebrowSize: 38,
           headlineTop: 236, headlineSize: 124, deviceTop: 610, bottomGap: 92, ring: 9, border: 18, corner: 186, phone: true),
    Layout(name: "ipad-13", size: CGSize(width: 2064, height: 2752), side: 150, eyebrowTop: 168, eyebrowSize: 52,
           headlineTop: 282, headlineSize: 164, deviceTop: 770, bottomGap: -400, ring: 12, border: 44, corner: 36, phone: false),
]

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    let r = min(radius, min(rect.width, rect.height) / 2)
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func load(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

/// A line of text with its baseline at a place measured from the top left. The page is turned the
/// right way up around the line, and the text matrix is left alone: with the matrix itself turned
/// over, a face whose letters step up and down as they join (Arabic) is drawn with each step
/// counted twice, and the line climbs.
func draw(_ line: CTLine, in ctx: CGContext, x: CGFloat, baseline: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: x, y: baseline)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textMatrix = .identity
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// The largest size at which this headline has room: across, and down to just above the device.
func headlineSize(_ caption: Spec.Caption, layout: Layout, faces: Faces) -> CGFloat {
    let texts = caption.headline.components(separatedBy: "\n")
    let tall = layout.deviceTop - layout.headlineTop - layout.headlineSize * 0.42
    let size = min(layout.headlineSize * faces.scale, tall / (CGFloat(texts.count) * faces.leading))
    let widest = texts.map { width(headlineLine($0, size: size, faces: faces, theme: themes["paper"]!)) }.max() ?? 0
    let room = layout.size.width - 2 * layout.side
    return widest > room ? floor(size * room / widest) : size
}

/// One picture. Draws with the origin at the top left, as the measures above are written.
func picture(_ capture: CGImage, caption: Spec.Caption, layout: Layout, theme: Theme, faces: Faces, size: CGFloat) -> CGImage {
    let W = layout.size.width, H = layout.size.height
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fail("no canvas") }
    ctx.translateBy(x: 0, y: H)
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.setFillColor(theme.ground)
    ctx.fill(CGRect(origin: .zero, size: layout.size))

    // The eyebrow.
    let label = faces.capitals ? caption.eyebrow.uppercased() : caption.eyebrow
    var eyebrowSize = layout.eyebrowSize * faces.small
    var eyebrow = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes:
        attributes(faces.eyebrow, eyebrowSize, theme.eyebrow, kern: eyebrowSize * faces.tracking)))
    let room = W - 2 * layout.side
    if width(eyebrow) > room {
        eyebrowSize = floor(eyebrowSize * room / width(eyebrow))
        eyebrow = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes:
            attributes(faces.eyebrow, eyebrowSize, theme.eyebrow, kern: eyebrowSize * faces.tracking)))
    }
    // The kern after the last letter is not part of the word: leave it out of the centring.
    let eyebrowWidth = width(eyebrow) - eyebrowSize * faces.tracking
    draw(eyebrow, in: ctx, x: (W - eyebrowWidth) / 2, baseline: layout.eyebrowTop + layout.eyebrowSize * 0.74)

    // The headline, at the one size the whole set is given.
    let texts = caption.headline.components(separatedBy: "\n")
    let lines = texts.map { headlineLine($0, size: size, faces: faces, theme: theme) }
    // Two lines sit where the measures put them; one line or three keep the same middle.
    let block = CGFloat(texts.count) * size * faces.leading
    let usual = 2 * layout.headlineSize * latin.leading
    var baseline = layout.headlineTop + (usual - block) / 2 + size * (faces.leading + 0.52) / 2
    for line in lines {
        draw(line, in: ctx, x: (W - width(line)) / 2, baseline: baseline)
        baseline += size * faces.leading
    }

    // The device: a metal ring, a black border, the capture.
    let edge = layout.ring + layout.border
    let screenHeight = H - layout.deviceTop - layout.bottomGap - 2 * edge
    let scale = screenHeight / CGFloat(capture.height)
    let screen = CGRect(x: (W - CGFloat(capture.width) * scale) / 2, y: layout.deviceTop + edge,
                        width: CGFloat(capture.width) * scale, height: screenHeight)
    let body = screen.insetBy(dx: -edge, dy: -edge)
    let corner = layout.corner * scale
    let metal = color(0x34363B), metalEdge = color(0x5D6068)

    if layout.phone {
        // The buttons: action, volume up and down on the left; power on the right.
        ctx.setFillColor(color(0x2A2C30))
        let out: CGFloat = 5, thick: CGFloat = 14
        for (side, top, tall) in [(0, 0.150, 0.030), (0, 0.205, 0.052), (0, 0.268, 0.052), (1, 0.235, 0.085)] as [(Int, CGFloat, CGFloat)] {
            let x = side == 0 ? body.minX - out : body.maxX - thick + out
            ctx.addPath(rounded(CGRect(x: x, y: body.minY + body.height * top, width: thick, height: body.height * tall), 4))
            ctx.fillPath()
        }
    }
    ctx.saveGState()
    if theme.shadow > 0 {
        ctx.setShadow(offset: CGSize(width: 0, height: -34), blur: 90, color: color(0x1A1A17, theme.shadow))
    }
    ctx.addPath(rounded(body, corner + edge))
    ctx.setFillColor(metal)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(rounded(body.insetBy(dx: 1, dy: 1), corner + edge - 1))
    ctx.setStrokeColor(metalEdge)
    ctx.setLineWidth(2)
    ctx.strokePath()
    ctx.addPath(rounded(body.insetBy(dx: layout.ring, dy: layout.ring), corner + layout.border))
    ctx.setFillColor(color(0x000000))
    ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(rounded(screen, corner))
    ctx.clip()
    ctx.translateBy(x: screen.minX, y: screen.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(capture, in: CGRect(origin: .zero, size: screen.size))
    ctx.restoreGState()

    if layout.phone {
        // The Dynamic Island, which a simulator's capture leaves out: 125 by 37 points, 14 from the top.
        let island = CGRect(x: screen.midX - 187 * scale, y: screen.minY + 42 * scale, width: 374 * scale, height: 110 * scale)
        ctx.addPath(rounded(island, island.height / 2))
        ctx.setFillColor(color(0x000000))
        ctx.fillPath()
    }
    guard let image = ctx.makeImage() else { fail("no picture") }
    return image
}

// MARK: - The run

var made = 0
for locale in wanted {
    guard let place = spec.locales[locale] else { fail("captions.json has no locale \(locale)") }
    guard let words = spec.captions[place.language] else { fail("captions.json has no captions in \(place.language)") }
    let faces = faces(for: place.language)
    for layout in layouts {
        let from = shots.appendingPathComponent("captures/\(place.capture)/\(layout.name)")
        let to = shots.appendingPathComponent("store/\(locale)/\(layout.name)")
        // Every headline of a set is the size of the one with the least room, so the eight read as one.
        let size = spec.frames.compactMap { words[$0.file] }.map { headlineSize($0, layout: layout, faces: faces) }.min() ?? layout.headlineSize
        for frame in spec.frames {
            guard let capture = load(from.appendingPathComponent(frame.file + ".png")) else { continue }
            guard capture.width == Int(layout.size.width), capture.height == Int(layout.size.height) else {
                fail("\(place.capture)/\(layout.name)/\(frame.file).png is \(capture.width) by \(capture.height)")
            }
            guard let caption = words[frame.file], let theme = themes[frame.theme] else { fail("no caption or theme for \(frame.file) in \(place.language)") }
            let image = picture(capture, caption: caption, layout: layout, theme: theme, faces: faces, size: size)
            try? FileManager.default.createDirectory(at: to, withIntermediateDirectories: true)
            let file = to.appendingPathComponent(frame.file + ".png")
            guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) else { fail("cannot write \(file.path)") }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { fail("cannot write \(file.path)") }
            made += 1
        }
    }
}
print("\(made) pictures")
