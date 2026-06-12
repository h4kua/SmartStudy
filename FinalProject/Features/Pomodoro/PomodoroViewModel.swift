import SwiftUI
import Combine

enum TimerMode {
    case work, shortBreak, longBreak

    var label: String {
        switch self {
        case .work:       return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak:  return "Long Break"
        }
    }
    var color: Color {
        switch self {
        case .work:       return StudyTheme.focusColor
        case .shortBreak: return StudyTheme.shortBreakColor
        case .longBreak:  return StudyTheme.longBreakColor
        }
    }
    var icon: String {
        switch self {
        case .work:       return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak:  return "figure.walk"
        }
    }
}

@MainActor
final class PomodoroViewModel: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60
    @Published var totalTime: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var mode: TimerMode = .work
    @Published var completedPomodoros: Int = 0
    @Published var selectedSubjectId: UUID? = nil
    @Published var showCompletionBanner: Bool = false

    private var timer: Timer?
    private var sessionStartDate: Date?
    private let store: StudyStore

    init(store: StudyStore) {
        self.store = store
        applyConfig()
    }

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - Double(timeRemaining) / Double(totalTime)
    }

    var displayTime: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }

    var selectedSubject: Subject? {
        store.subjects.first { $0.id == selectedSubjectId }
    }

    // MARK: - Controls

    func start() {
        guard !isRunning else { return }
        isRunning = true
        sessionStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in self.tick() }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func toggleStartPause() {
        isRunning ? pause() : start()
    }

    func skipToNext() {
        pause()
        saveCurrentSession(skipped: true)
        advance()
        applyConfig()
        if store.config.autoStartBreaks && mode != .work { start() }
    }

    func resetCurrent() {
        pause()
        sessionStartDate = nil
        applyConfig()
    }

    // MARK: - Private

    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            pause()
            saveCurrentSession(skipped: false)
            advance()
            applyConfig()
            showCompletionBanner = true
            if store.config.autoStartBreaks && mode != .work { start() }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                showCompletionBanner = false
            }
        }
    }

    private func saveCurrentSession(skipped: Bool) {
        guard mode == .work, let start = sessionStartDate else { return }
        let elapsed = max(1, Int(Date().timeIntervalSince(start) / 60))
        if elapsed < 1 { return }
        let session = StudySession(
            subjectId: selectedSubjectId,
            subjectName: selectedSubject?.name,
            startDate: start,
            durationMinutes: elapsed,
            sessionType: .work
        )
        store.addSession(session)
        sessionStartDate = nil
    }

    private func advance() {
        switch mode {
        case .work:
            completedPomodoros += 1
            mode = completedPomodoros % store.config.longBreakAfterPomodoros == 0
                ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            mode = .work
        }
    }

    private func applyConfig() {
        switch mode {
        case .work:       totalTime = store.config.workMinutes * 60
        case .shortBreak: totalTime = store.config.shortBreakMinutes * 60
        case .longBreak:  totalTime = store.config.longBreakMinutes * 60
        }
        timeRemaining = totalTime
    }
}
