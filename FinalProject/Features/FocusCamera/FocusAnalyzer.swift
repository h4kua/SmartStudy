import Vision
import SwiftUI

// MARK: - Focus State

enum AttentionState: String {
    case focused    = "Focused"
    case drowsy     = "Drowsy"
    case distracted = "Distracted"
    case away       = "Not at Desk"

    var color: Color {
        switch self {
        case .focused:    return StudyTheme.success
        case .drowsy:     return StudyTheme.warning
        case .distracted: return Color(red: 1.0, green: 0.6, blue: 0.1)
        case .away:       return StudyTheme.danger
        }
    }

    var icon: String {
        switch self {
        case .focused:    return "checkmark.circle.fill"
        case .drowsy:     return "eye.slash.fill"
        case .distracted: return "arrow.turn.up.right"
        case .away:       return "person.slash.fill"
        }
    }

    var message: String {
        switch self {
        case .focused:    return "Keep going! You're in the zone."
        case .drowsy:     return "Eyes getting heavy? Take a 2-min break."
        case .distracted: return "Stay with it — look back at the screen."
        case .away:       return "Come back to your desk to resume."
        }
    }
}

// MARK: - Focus Analyzer (pure static functions)

struct FocusAnalyzer {

    // MARK: Eye Aspect Ratio

    /// Calculates the eye aspect ratio from a Vision landmark region.
    /// Returns ≈ 0.30 for a fully open eye, ≈ 0.05 for a closed eye.
    /// Falls back to 0.30 (open) if the region has too few points.
    static func eyeAspectRatio(from region: VNFaceLandmarkRegion2D?) -> Double {
        guard let pts = region?.normalizedPoints, pts.count >= 4 else {
            return 0.30
        }
        let xs = pts.map { Double($0.x) }
        let ys = pts.map { Double($0.y) }
        let width  = (xs.max() ?? 0) - (xs.min() ?? 0)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        guard width > 0.001 else { return 0.30 }
        return height / width
    }

    // MARK: Focus Score  (0 – 100)

    /// Combines eye openness and head alignment into a single 0–100 score.
    static func score(from result: FaceDetectionResult) -> Double {
        guard result.hasFace else { return 0 }

        // Eye score — normalise EAR into 0-1
        // Fully open ≥ 0.28 → 1.0 ; closed ≤ 0.10 → 0.0
        let avgEAR   = (result.leftEyeAR + result.rightEyeAR) / 2.0
        let eyeScore = min(1.0, max(0.0, (avgEAR - 0.10) / 0.18))

        // Head pose score — penalise turning / tilting away
        let yawScore   = max(0.0, 1.0 - abs(result.yaw)   / 0.52)
        let pitchScore = max(0.0, 1.0 - abs(result.pitch) / 0.60)
        let headScore  = yawScore * 0.65 + pitchScore * 0.35

        return (0.50 * eyeScore + 0.50 * headScore) * 100.0
    }

    // MARK: Focus State

    static func state(from result: FaceDetectionResult) -> AttentionState {
        guard result.hasFace else { return .away }
        let avgEAR = (result.leftEyeAR + result.rightEyeAR) / 2.0
        // Drowsy: eyes closing OR head drooping forward (negative pitch)
        if avgEAR < 0.17                           { return .drowsy }
        if result.pitch < -0.40 && avgEAR < 0.22   { return .drowsy }
        if abs(result.yaw) > 0.48                   { return .distracted }
        return .focused
    }

    // MARK: Smoothing

    /// Exponential moving average — α = 0 is all-previous, 1 is all-current.
    static func ema(current: Double, previous: Double, alpha: Double = 0.25) -> Double {
        alpha * current + (1.0 - alpha) * previous
    }
}
