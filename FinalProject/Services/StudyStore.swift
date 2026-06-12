import Foundation
import Combine

@MainActor
final class StudyStore: ObservableObject {
    @Published var subjects: [Subject] = []
    @Published var sessions: [StudySession] = []
    @Published var config: PomodoroConfig = PomodoroConfig()

    private let subjectsKey = "study.subjects"
    private let sessionsKey  = "study.sessions"
    private let configKey    = "study.config"

    init() {
        load()
        if subjects.isEmpty {
            subjects = Subject.presets
            saveSubjects()
        }
    }

    // MARK: - Sessions

    func addSession(_ session: StudySession) {
        sessions.insert(session, at: 0)
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        sessions = sessions.filter { $0.startDate > cutoff }
        saveSessions()
    }

    // MARK: - Subjects

    func addSubject(_ subject: Subject) {
        subjects.append(subject)
        saveSubjects()
    }

    func updateSubject(_ subject: Subject) {
        if let idx = subjects.firstIndex(where: { $0.id == subject.id }) {
            subjects[idx] = subject
            saveSubjects()
        }
    }

    func deleteSubject(at offsets: IndexSet) {
        subjects.remove(atOffsets: offsets)
        saveSubjects()
    }

    func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
    }

    // MARK: - Computed stats

    var todayWorkMinutes: Int {
        sessions.filter { $0.isToday && $0.sessionType == .work }
                .reduce(0) { $0 + $1.durationMinutes }
    }

    var todayGoalProgress: Double {
        let goal = config.dailyGoalHours * 60
        guard goal > 0 else { return 0 }
        return min(Double(todayWorkMinutes) / goal, 1.0)
    }

    var currentStreak: Int {
        var streak = 0
        let goalMins = Int(config.dailyGoalHours * 60)
        var checkDate = Date()

        if todayWorkMinutes < goalMins {
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = prev
        }

        for _ in 0..<90 {
            let dayMins = sessions.filter {
                $0.sessionType == .work &&
                Calendar.current.isDate($0.startDate, inSameDayAs: checkDate)
            }.reduce(0) { $0 + $1.durationMinutes }

            if dayMins >= goalMins {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else { break }
        }
        return streak
    }

    /// Last 7 days of work minutes, index 0 = oldest, 6 = today.
    var last7DaysMinutes: [(label: String, minutes: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).reversed().map { daysAgo in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let mins = sessions.filter {
                $0.sessionType == .work &&
                Calendar.current.isDate($0.startDate, inSameDayAs: date)
            }.reduce(0) { $0 + $1.durationMinutes }
            return (formatter.string(from: date), mins)
        }
    }

    var minutesBySubjectToday: [(subject: Subject, minutes: Int)] {
        var result: [UUID: Int] = [:]
        for s in sessions where s.isToday && s.sessionType == .work {
            if let id = s.subjectId { result[id, default: 0] += s.durationMinutes }
        }
        return subjects.compactMap { sub -> (Subject, Int)? in
            guard let mins = result[sub.id], mins > 0 else { return nil }
            return (sub, mins)
        }.sorted { $0.1 > $1.1 }
    }

    var recentSessions: [StudySession] {
        sessions.filter { $0.sessionType == .work }.prefix(10).map { $0 }
    }

    // MARK: - Persistence

    private func saveSubjects() {
        if let e = try? JSONEncoder().encode(subjects) { UserDefaults.standard.set(e, forKey: subjectsKey) }
    }
    private func saveSessions() {
        if let e = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(e, forKey: sessionsKey) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: subjectsKey),
           let v = try? JSONDecoder().decode([Subject].self, from: d) { subjects = v }
        if let d = UserDefaults.standard.data(forKey: sessionsKey),
           let v = try? JSONDecoder().decode([StudySession].self, from: d) { sessions = v }
        if let d = UserDefaults.standard.data(forKey: configKey),
           let v = try? JSONDecoder().decode(PomodoroConfig.self, from: d) { config = v }
    }
}
