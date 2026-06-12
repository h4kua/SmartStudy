import SwiftUI

// MARK: - Subject

struct Subject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var emoji: String

    var color: Color { Color(hex: colorHex) ?? StudyTheme.accent }

    static let presets: [Subject] = [
        Subject(name: "Mathematics",  colorHex: "#4A8EFF", emoji: "📐"),
        Subject(name: "Physics",      colorHex: "#FF6B3D", emoji: "⚛️"),
        Subject(name: "Programming",  colorHex: "#9B6DFF", emoji: "💻"),
        Subject(name: "English",      colorHex: "#00C875", emoji: "📖"),
        Subject(name: "History",      colorHex: "#FFC433", emoji: "🏛️"),
    ]

    static let colorOptions: [String] = [
        "#4A8EFF","#FF6B3D","#9B6DFF","#00C875","#FFC433",
        "#FF4D6D","#00B4D8","#06D6A0","#FF9F1C","#E040FB"
    ]
}

// MARK: - Study Session

struct StudySession: Identifiable, Codable {
    var id: UUID = UUID()
    var subjectId: UUID?
    var subjectName: String?
    var startDate: Date
    var durationMinutes: Int
    var sessionType: SessionType

    enum SessionType: String, Codable {
        case work, shortBreak, longBreak
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(startDate)
    }
}

// MARK: - Pomodoro Config

struct PomodoroConfig: Codable, Equatable {
    var workMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var longBreakAfterPomodoros: Int = 4
    var dailyGoalHours: Double = 4.0
    var autoStartBreaks: Bool = true
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    let content: String
    let date: Date = Date()
}

// MARK: - Color hex initialiser

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                   .replacingOccurrences(of: "#", with: "")
        guard h.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - Helpers

extension Int {
    var minutesToHoursString: String {
        let h = self / 60
        let m = self % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }
}
