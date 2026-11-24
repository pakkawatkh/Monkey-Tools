import AppKit
import Foundation
import Vision

public final class OCRService {
    public static let shared = OCRService()

    private init() {}

    /// Extracts text from raw image Data using Apple Vision framework (offline, on-device).
    public func extractText(from imageData: Data) async -> String? {
        guard let cgImage = Self.makeCGImage(from: imageData) else { return nil }
        return await extractText(from: cgImage)
    }

    /// Extracts text from an NSImage using Apple Vision framework (offline, on-device).
    public func extractText(from nsImage: NSImage) async -> String? {
        var proposedRect = CGRect(origin: .zero, size: nsImage.size)
        guard let cgImage = nsImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        return await extractText(from: cgImage)
    }

    /// Extracts text from a CGImage using VNRecognizeTextRequest.
    public func extractText(from cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, error in
                    if let error = error {
                        print("[OCRService] Vision OCR error: \(error)")
                        continuation.resume(returning: nil)
                        return
                    }
                    guard let observations = req.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    let combined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: combined.isEmpty ? nil : combined)
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                if #available(macOS 13.0, *) {
                    request.automaticallyDetectsLanguage = true
                }
                request.recognitionLanguages = ["en-US", "th-TH", "zh-Hans", "zh-Hant"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    print("[OCRService] Failed to perform OCR request: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
