import Vision
import UIKit

/// On-device OCR using Apple's Vision framework (VNRecognizeTextRequest).
///
/// Used by:
///  - DocumentAnalyzerView  → scan handwritten or printed notes → auto-fill text → AI analysis
///  - AITutorView           → scan math equations → Groq solves step-by-step
///
/// Runs entirely on-device — no network call, no data leaves the phone.
final class NoteScannerService {

    // MARK: - Errors

    enum ScanError: LocalizedError {
        case noTextFound
        case processingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noTextFound:
                return "No readable text found in the image. Try better lighting or a clearer angle."
            case .processingFailed(let msg):
                return "Scan failed: \(msg)"
            }
        }
    }

    // MARK: - Public API

    /// Extracts all text from a UIImage using accurate on-device Vision OCR.
    /// Lines are returned in natural reading order (top-to-bottom, left-to-right).
    /// Throws `ScanError` if no text is found or Vision fails.
    static func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ScanError.processingFailed("Could not process image data.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: ScanError.processingFailed(error.localizedDescription))
                    return
                }

                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []

                // Sort observations into natural reading order:
                // primary sort: top-to-bottom (Vision uses bottom-left origin, so descending minY)
                // secondary sort: left-to-right for text on the same line
                let sorted = observations.sorted {
                    let yDiff = $1.boundingBox.minY - $0.boundingBox.minY
                    if abs(yDiff) > 0.015 { return yDiff > 0 }   // different lines
                    return $0.boundingBox.minX < $1.boundingBox.minX  // same line → L→R
                }

                let text = sorted
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if text.isEmpty {
                    continuation.resume(throwing: ScanError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            // .accurate gives best results for handwriting and printed text
            request.recognitionLevel       = .accurate
            request.usesLanguageCorrection = true
            // Cover English and Indonesian (common for this student's context)
            request.recognitionLanguages   = ["en-US", "id-ID"]

            let handler = VNImageRequestHandler(
                cgImage:     cgImage,
                orientation: cgOrientation(from: image),
                options:     [:]
            )
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ScanError.processingFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Private helpers

    /// Maps UIImage orientation to CGImagePropertyOrientation so Vision
    /// receives correctly-oriented pixel data regardless of how the photo was taken.
    private static func cgOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
