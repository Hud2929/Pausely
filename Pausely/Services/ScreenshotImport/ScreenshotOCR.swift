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
        let orientation = cgOrientation(from: image.imageOrientation)
        if let cgImage = image.cgImage {
            return try await Task.detached(priority: .userInitiated) {
                try performRecognition(on: cgImage, orientation: orientation)
            }.value
        }
        // Fallback only when UIImage is CIImage-backed with no direct CGImage.
        guard let fallbackData = image.pngData() else {
            throw Failure.unreadableImage
        }
        return try await Task.detached(priority: .userInitiated) {
            guard let rendered = UIImage(data: fallbackData)?.cgImage else {
                throw Failure.unreadableImage
            }
            return try performRecognition(on: rendered, orientation: .up)
        }.value
    }

    private nonisolated static func performRecognition(
        on cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [ScreenshotParser.TextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
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
