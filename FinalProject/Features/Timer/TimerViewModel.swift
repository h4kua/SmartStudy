import Foundation
import SwiftUI
import Combine

// MARK: - Timer Phase

enum TimerPhase: String, CaseIterable {
    case focus      = "Focus"
    case shortBreak = "Short Break"
    case longBreak  = "Long Break"

    var seconds: Int {
        switch self {
        case .focus:      return 25 * 60
        case .shortBreak: return  5 * 60
        case .longBreak:  return 15 * 60
        }
    }

    var color: Color {
        switch self {
        case .focus:      return StudyTheme.accent
        case .shortBreak: return StudyTheme.shortBreakColor
        case .longBreak:  return StudyTheme.longBreakColor
        }
    }

    var icon: String {
        switch self {
        case .focus:      return "brain.head.profile"
        case .shortBreak: return "cup.and.heat.waves.fill"
        case .longBreak:  return "figure.walk"
        }
    }

    var label: String { rawValue }
}

// MARK: - TimerViewModel

@MainActor
final class TimerViewModel: ObservableObject {

    @Published var phase:         TimerPhase = .focus
    @Published var remaining:     Int        = TimerPhase.focus.seconds
    @Published var isRunning:     Bool       = false
    @Published var pomodorosDone: Int        = 0   // focus sessions completed this cycle
    @Published var totalToday:    Int        = 0   // all focus sessions today

    private var cancellable: AnyCancellable?

    // Persist today's pomodoro count so it survives app restart
    private static let todayCountKey = "timer.totalToday"
    private static let todayDateKey  = "timer.todayDate"

    init() {
        loadTodayCount()
    }

    private func loadTodayCount() {
        let savedDate = UserDefaults.standard.string(forKey: Self.todayDateKey) ?? ""
        let today = todayString()
        if savedDate == today {
            totalToday = UserDefaults.standard.integer(forKey: Self.todayCountKey)
        } else {
            // New day — reset
            totalToday = 0
            UserDefaults.standard.set(today, forKey: Self.todayDateKey)
            UserDefaults.standard.set(0, forKey: Self.todayCountKey)
        }
    }

    private func saveTodayCount() {
        UserDefaults.standard.set(todayString(), forKey: Self.todayDateKey)
        UserDefaults.standard.set(totalToday, forKey: Self.todayCountKey)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func todayString() -> String {
        Self.dayFormatter.string(from: Date())
    }

    // MARK: - Computed

    var progress: Double {
        guard phase.seconds > 0 else { return 0 }
        return 1.0 - (Double(remaining) / Double(phase.seconds))
    }

    var timeString: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    // Dots: 4 circles representing one full Pomodoro cycle
    var cycleDots: [Bool] {
        (0..<4).map { $0 < (pomodorosDone % 4) }
    }

    // MARK: - Controls

    func startPause() {
        isRunning ? pause() : start()
    }

    func reset() {
        pause()
        remaining = phase.seconds
    }

    func skipPhase() {
        pause()
        advance()
    }

    func setPhase(_ p: TimerPhase) {
        pause()
        phase     = p
        remaining = p.seconds
    }

    // MARK: - Private

    private func start() {
        isRunning  = true
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func pause() {
        isRunning   = false
        cancellable = nil
    }

    private func tick() {
        guard remaining > 0 else {
            complete()
            return
        }
        remaining -= 1
    }

    private func complete() {
        pause()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        NotificationService.shared.notifyPomodoroComplete(phase: phase.rawValue)

        if phase == .focus {
            pomodorosDone += 1
            totalToday    += 1
            saveTodayCount()
        }
        advance()
    }

    private func advance() {
        switch phase {
        case .focus:
            // Every 4 focus sessions → long break
            phase = (pomodorosDone % 4 == 0 && pomodorosDone > 0) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .focus
        }
        remaining = phase.seconds
    }
}
