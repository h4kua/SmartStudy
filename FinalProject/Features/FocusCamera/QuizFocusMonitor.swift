import AVFoundation
import Combine
import SwiftUI

// MARK: - Quiz Focus Result

struct QuizFocusResult {
    let avgScore:       Double   // 0–100
    let focusedPercent: Double   // 0–100  (time spent focused / total time)
    let totalSeconds:   Int
    let focusedSeconds: Int

    static let empty = QuizFocusResult(
        avgScore: 0, focusedPercent: 0,
        totalSeconds: 0, focusedSeconds: 0
    )

    var isValid: Bool { totalSeconds >= 5 }
}

// MARK: - QuizFocusMonitor

/// Lightweight background focus tracker for quiz sessions.
/// No camera preview, no voice coaching, no haptics —
/// just attention state + running statistics.
@MainActor
final class QuizFocusMonitor: ObservableObject {

    // MARK: Published

    @Published var focusState:  AttentionState = .away
    @Published var avgScore:    Double = 0
    @Published var isActive:    Bool   = false
    @Published var awaySeconds: Int    = 0   // consecutive away seconds (drives nudge banner)

    // MARK: Snapshot for results screen

    private(set) var finalResult: QuizFocusResult = .empty

    // MARK: Private

    private let cameraService  = FocusCameraService()
    private var smoothedScore: Double = 50
    private var totalSeconds:  Int    = 0
    private var focusedSecs:   Int    = 0
    private var timerCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        cameraService.onResult = { [weak self] result in
            Task { @MainActor [weak self] in
                self?.processResult(result)
            }
        }
    }

    // MARK: - Lifecycle

    func start() async {
        // Check / request permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var permitted = (status == .authorized)
        if status == .notDetermined {
            permitted = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard permitted else { return }

        // Reset state
        totalSeconds  = 0
        focusedSecs   = 0
        awaySeconds   = 0
        smoothedScore = 50
        avgScore      = 0
        finalResult   = .empty
        isActive      = true

        cameraService.start()

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        guard isActive else { return }
        cameraService.stop()
        timerCancellable?.cancel()
        timerCancellable = nil
        isActive = false
        // Snapshot final stats
        let pct = totalSeconds > 0
            ? Double(focusedSecs) / Double(totalSeconds) * 100.0
            : 0
        finalResult = QuizFocusResult(
            avgScore:       avgScore,
            focusedPercent: pct,
            totalSeconds:   totalSeconds,
            focusedSeconds: focusedSecs
        )
    }

    // MARK: - Private

    private func tick() {
        totalSeconds += 1
        switch focusState {
        case .focused:
            focusedSecs += 1
            awaySeconds  = 0
        case .away:
            awaySeconds += 1
        default:
            // drowsy / distracted — partial count-down
            awaySeconds = max(0, awaySeconds - 1)
        }
        // Running average (O(1), constant memory)
        let n = Double(totalSeconds)
        if n <= 1 { avgScore = smoothedScore }
        else       { avgScore = avgScore + (smoothedScore - avgScore) / n }
    }

    private func processResult(_ r: FaceDetectionResult) {
        let raw   = FocusAnalyzer.score(from: r)
        smoothedScore = FocusAnalyzer.ema(current: raw, previous: smoothedScore, alpha: 0.25)
        focusState    = FocusAnalyzer.state(from: r)
    }
}
