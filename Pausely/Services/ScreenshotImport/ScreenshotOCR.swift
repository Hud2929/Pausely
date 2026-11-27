import Foundation
import UIKit
import Vision

/// On-device OCR using Apple's Vision framework (`VNRecognizeTextRequest`).
/// Images are processed purely in memory off the main actor and never written to disk or sent anywhere.
enum ScreenshotOCR {

    enum Failure: Error {
        case unreadableImage
    }

    /// Brand names with unusual casing or symbols so Vision's language correction keeps them intact.
    private static let subscriptionVocabulary: [String] = [
        "iCloud+", "Disney+", "Apple TV+", "Paramount+", "ESPN+", "Discovery+", "Instacart+", "Walmart+",
        "ChatGPT", "ChatGPT Plus", "Claude Pro", "Duolingo", "Crunchyroll", "NordVPN", "ExpressVPN",
        "Surfshark", "YouTube", "YouTube Premium", "Spotify", "Netflix", "Peloton", "Headspace",
        "Midjourney", "Perplexity", "1Password", "Bitwarden", "PlayStation", "DoorDash", "DashPass",
        "Substack", "Patreon", "Audible", "Strava", "Canva", "Figma", "Notion", "Cloudflare",
        "Replit", "Grammarly", "Dropbox", "Microsoft 365", "Google One", "WHOOP", "SiriusXM",
        "Apple Music", "Apple One", "Apple Arcade", "Kindle Unlimited", "Amazon Prime",
        "/mo", "/yr", "/wk", "/month", "/year", "/week"
    ]

    /// Aspect ratio threshold above which a tall scrolling / stitched screenshot is processed in
    /// overlapping vertical tiles so Vision does not downscale small text below its recognition floor.
    private static let tallAspectThreshold: CGFloat = 2.4

    /// Runs a blocking Vision OCR block on a background executor while propagating Swift task cancellation.
    private nonisolated static func runOffMain<T: Sendable>(
        _ work: @Sendable @escaping () throws -> T
    ) async throws -> T {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try work()
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Recognizes text directly from raw image bytes (HEIC, PNG, JPEG), letting Vision read EXIF
    /// orientation natively without decoding a full `UIImage` bitmap first. Tall scrolling captures
    /// are automatically tiled in overlapping vertical strips for full-resolution accuracy.
    nonisolated static func recognizeText(in data: Data) async throws -> [ScreenshotParser.TextObservation] {
        guard !data.isEmpty else { throw Failure.unreadableImage }
        try Task.checkCancellation()
        return try await runOffMain {
            if let image = UIImage(data: data),
               image.size.width > 0,
               image.size.height > image.size.width * tallAspectThreshold,
               let upright = uprightCGImage(from: image) {
                return try performTiledRecognition(on: upright)
            }
            let request = makeRequest()
            let handler = VNImageRequestHandler(data: data, options: [:])
            try handler.perform([request])
            return extractObservations(from: request)
        }
    }

    nonisolated static func recognizeText(in image: UIImage) async throws -> [ScreenshotParser.TextObservation] {
        try Task.checkCancellation()
        let orientation = cgOrientation(from: image.imageOrientation)
        let isTall = image.size.width > 0 && image.size.height > image.size.width * tallAspectThreshold
        if isTall, let upright = uprightCGImage(from: image) {
            return try await runOffMain {
                try performTiledRecognition(on: upright)
            }
        }
        if let cgImage = image.cgImage {
            return try await runOffMain {
                try performRecognition(on: cgImage, orientation: orientation)
            }
        }
        // Fallback only when UIImage is CIImage-backed with no direct CGImage.
        guard let fallbackData = image.pngData() else {
            throw Failure.unreadableImage
        }
        return try await recognizeText(in: fallbackData)
    }

    private nonisolated static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.customWords = subscriptionVocabulary
        return request
    }

    private nonisolated static func performRecognition(
        on cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [ScreenshotParser.TextObservation] {
        let request = makeRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])
        return extractObservations(from: request)
    }

    /// Runs Vision across overlapping vertical strips of a tall scrolling screenshot, remapping each
    /// strip's normalized boxes back to full-image coordinates and deduplicating overlap rows.
    private nonisolated static func performTiledRecognition(
        on cgImage: CGImage
    ) throws -> [ScreenshotParser.TextObservation] {
        let fullW = cgImage.width
        let fullH = cgImage.height
        guard fullW > 0, fullH > 0 else { throw Failure.unreadableImage }

        let tileH = min(fullH, max(Int(Double(fullW) * 1.8), 1600))
        let overlap = max(Int(Double(tileH) * 0.14), 160)
        let step = max(tileH - overlap, 1)

        var merged: [ScreenshotParser.TextObservation] = []
        var top = 0
        while true {
            try Task.checkCancellation()
            let isFirst = top == 0
            let bottom = min(top + tileH, fullH)
            let isLast = bottom >= fullH
            let actualTop = isLast ? max(0, fullH - tileH) : top
            let sliceH = bottom - actualTop

            let cropRect = CGRect(x: 0, y: actualTop, width: fullW, height: sliceH)
            guard let tileImage = cgImage.cropping(to: cropRect) else { break }
            let tileObs = try performRecognition(on: tileImage, orientation: .up)

            for obs in tileObs {
                let b = obs.boundingBox
                // Skip fragments clipped right against an interior cut edge; the adjacent tile owns them cleanly.
                if !isLast && b.minY < 0.015 { continue }
                if !isFirst && b.maxY > 0.985 { continue }

                let fullMinY = (CGFloat(fullH - bottom) + b.minY * CGFloat(sliceH)) / CGFloat(fullH)
                let fullHeight = (b.height * CGFloat(sliceH)) / CGFloat(fullH)
                let mappedBox = CGRect(x: b.minX, y: fullMinY, width: b.width, height: fullHeight)
                let mapped = ScreenshotParser.TextObservation(text: obs.text, boundingBox: mappedBox)

                if let dupIdx = merged.firstIndex(where: { isDuplicateTileObservation($0.boundingBox, mappedBox) }) {
                    if mapped.text.count > merged[dupIdx].text.count {
                        merged[dupIdx] = mapped
                    }
                } else {
                    merged.append(mapped)
                }
            }

            if isLast { break }
            top += step
        }
        return merged
    }

    private nonisolated static func isDuplicateTileObservation(_ a: CGRect, _ b: CGRect) -> Bool {
        let minH = min(a.height, b.height)
        guard abs(a.midY - b.midY) <= max(minH * 0.6, 0.004) else { return false }
        let overlapX = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        let minW = max(min(a.width, b.width), 0.001)
        return overlapX > minW * 0.45
    }

    private nonisolated static func uprightCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let rendered = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }

    private nonisolated static func extractObservations(
        from request: VNRecognizeTextRequest
    ) -> [ScreenshotParser.TextObservation] {
        (request.results ?? []).compactMap { observation in
            guard let top = observation.topCandidates(1).first else { return nil }
            let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return ScreenshotParser.TextObservation(text: text, boundingBox: observation.boundingBox)
        }
    }

    private nonisolated static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
