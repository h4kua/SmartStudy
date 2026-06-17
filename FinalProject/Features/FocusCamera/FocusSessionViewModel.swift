import AVFoundation
import Combine
import SwiftUI

// MARK: - Camera Permission

enum CameraPermission {
    case unknown, granted, denied
}

// MARK: - Session Stats

struct FocusSessionStats {
    var totalSeconds:   Int    = 0
    var focusedSeconds: Int    = 0
    var avgScore:       Double = 0
    var scoreHistory:   [Double] = []

    var focusedPercent: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(focusedSeconds) / Double(totalSeconds) * 100.0
    }

    var focusedTimeString: String {
        let m = focusedSeconds / 60
        let s = focusedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - ViewModel

@MainActor
final class FocusSessionViewModel: ObservableObject {

    // MARK: Published State

    @Published var focusState:  AttentionState       = .away
    @Published var focusScore:  Double           = 0
    @Published var stats:       FocusSessionStats = .init()
    @Published var awaySeconds: Int              = 0
    @Published var isActive:    Bool             = false
    @Published var showAwayWarning: Bool         = false
    @Published var permission:  CameraPermission = .unknown

    // Expose service session for the camera preview layer.
    let cameraService = FocusCameraService()

    // MARK: Private

    private var smoothedScore: Double = 50
    private var awayCount:     Int    = 0
    private let awayThreshold: Int    = 30   // seconds before auto-warning

    private var timerCancellable: AnyCancellable?

    // MARK: Init

    init() {
        cameraService.onResult = { [weak self] result in
            // Called on background thread — hop to main actor.
            Task { @MainActor [weak self] in
                self?.processResult(result)
            }
        }
    }

    // MARK: - Session Control

    func requestAndStart() async {
        // Check / request camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permission = .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permission  = granted ? .granted : .denied
        default:
            permission = .denied
        }
        guard permission == .granted else { return }

        // Reset
        stats       = .init()
        awayCount   = 0
        awaySeconds = 0
        smoothedScore = 50
        isActive    = true
        showAwayWarning = false

        // Start camera
        cameraService.start()

        // 1-second tick via Combine
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stop() {
        isActive = false
        cameraService.stop()
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Private

    private func tick() {
        stats.totalSeconds += 1

        switch focusState {
        case .focused:
            stats.focusedSeconds += 1
            awayCount = 0
            awaySeconds = 0
            showAwayWarning = false

        case .away:
            awayCount += 1
            awaySeconds = awayCount
            if awayCount >= awayThreshold {
                showAwayWarning = true
            }

        default:
            // drowsy / distracted — don't count as away OR focused
            awayCount = max(0, awayCount - 1)
        }
    }

    private func processResult(_ result: FaceDetectionResult) {
        let rawScore  = FocusAnalyzer.score(from: result)
        smoothedScore = FocusAnalyzer.ema(current: rawScore, previous: smoothedScore, alpha: 0.25)

        focusScore = smoothedScore
        focusState = FocusAnalyzer.state(from: result)

        // Update rolling average
        stats.scoreHistory.append(smoothedScore)
        if stats.scoreHistory.count > 1800 { stats.scoreHistory.removeFirst(300) }
        stats.avgScore = stats.scoreHistory.reduce(0, +) / Double(stats.scoreHistory.count)
    }
}
