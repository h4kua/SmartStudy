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

    @Published var focusState:       AttentionState    = .away
    @Published var focusScore:       Double            = 0
    @Published var stats:            FocusSessionStats = .init()
    @Published var awaySeconds:      Int               = 0
    @Published var isActive:         Bool              = false
    @Published var showAwayWarning:  Bool              = false
    @Published var permission:       CameraPermission  = .unknown
    @Published var voiceEnabled:     Bool              = true  // user can toggle
    @Published var isSpeaking:       Bool              = false

    // Expose session for the camera preview layer.
    let cameraService = FocusCameraService()

    // MARK: Private

    private let voiceCoach    = FocusVoiceCoach()
    private var smoothedScore: Double = 50
    private var awayCount:     Int    = 0
    private let awayThreshold: Int    = 30
    private var previousState: AttentionState = .away

    private var timerCancellable:       AnyCancellable?
    private var speakingCheckCancellable: AnyCancellable?

    // MARK: Init

    init() {
        cameraService.onResult = { [weak self] result in
            Task { @MainActor [weak self] in
                self?.processResult(result)
            }
        }
    }

    // MARK: - Voice Toggle

    func toggleVoice() {
        voiceEnabled.toggle()
        voiceCoach.isEnabled = voiceEnabled
        if !voiceEnabled { voiceCoach.stop() }
    }

    // MARK: - Session Control

    func requestAndStart() async {
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

        // Reset all state
        stats          = .init()
        awayCount      = 0
        awaySeconds    = 0
        smoothedScore  = 50
        previousState  = .away
        isActive       = true
        showAwayWarning = false
        voiceCoach.isEnabled = voiceEnabled

        cameraService.start()

        // 1-second tick
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }

        // Poll isSpeaking every 0.3 s for the mic indicator
        speakingCheckCancellable = Timer.publish(every: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.isSpeaking = self.voiceCoach.isSpeaking
            }
    }

    func stop() {
        isActive = false
        cameraService.stop()
        voiceCoach.stop()
        timerCancellable?.cancel()
        timerCancellable = nil
        speakingCheckCancellable?.cancel()
        speakingCheckCancellable = nil
    }

    // MARK: - Private: per-second tick

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
            if awayCount >= awayThreshold { showAwayWarning = true }

        default:
            // drowsy / distracted — don't count as fully away OR focused
            awayCount = max(0, awayCount - 1)
        }

        // Voice: periodic reminders
        voiceCoach.periodicReminder(state: focusState, awaySeconds: awaySeconds)
    }

    // MARK: - Private: process Vision result

    private func processResult(_ result: FaceDetectionResult) {
        let rawScore  = FocusAnalyzer.score(from: result)
        smoothedScore = FocusAnalyzer.ema(current: rawScore, previous: smoothedScore, alpha: 0.25)

        let newState  = FocusAnalyzer.state(from: result)

        focusScore = smoothedScore

        // Voice: state-change feedback
        if newState != previousState {
            voiceCoach.onTransition(to: newState, from: previousState)
            previousState = newState
        }

        focusState = newState

        // Update rolling average
        stats.scoreHistory.append(smoothedScore)
        if stats.scoreHistory.count > 1800 { stats.scoreHistory.removeFirst(300) }
        stats.avgScore = stats.scoreHistory.reduce(0, +) / Double(stats.scoreHistory.count)
    }
}
