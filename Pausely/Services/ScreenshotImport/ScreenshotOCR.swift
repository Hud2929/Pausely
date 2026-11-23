import Foundation
import UIKit
import Vision

/// On-device OCR using Apple's Vision framework (`VNRecognizeTextRequest`).
/// Images are processed purely in memory off the main actor and never written to disk or sent anywhere.
enum ScreenshotOCR {

    enum Failure: Error {
        case unreadableImage
    }

    nonisolated static func recognizeText(in image: UIImage) async throws -> [ScreenshotParser.TextObservation] {
        guard let cgImage = normalizedCGImage(from: image) else {
            throw Failure.unreadableImage
        }
        return try await Task.detached(priority: .userInitiated) {
            try performRecognition(on: cgImage)
        }.value
    }

    private nonisolated static func performRecognition(on cgImage: CGImage) throws -> [ScreenshotParser.TextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let top = observation.topCandidates(1).first else { return nil }
            let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return ScreenshotParser.TextObservation(text: text, boundingBox: observation.boundingBox)
        }
    }

    /// Normalizes orientation before passing to Vision so rotated screenshots still cluster rows cleanly.
    private nonisolated static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return normalized.cgImage
    }
}
