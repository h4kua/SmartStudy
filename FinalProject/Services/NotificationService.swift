import Foundation
import UserNotifications

// MARK: - NotificationService

@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published var isAuthorized    = false
    @Published var reminderEnabled = false
    @Published var reminderHour:   Int = 19   // default 7 PM
    @Published var reminderMinute: Int = 0

    private let center = UNUserNotificationCenter.current()

    private enum Key {
        static let enabled = "notif.reminder.enabled"
        static let hour    = "notif.reminder.hour"
        static let minute  = "notif.reminder.minute"
    }

    private init() {
        reminderEnabled = UserDefaults.standard.bool(forKey: Key.enabled)
        // BUG FIX: integer(forKey:) returns 0 when key is absent, which is also a valid hour (midnight).
        // Use object(forKey:) to distinguish "never set" from "set to 0".
        if let stored = UserDefaults.standard.object(forKey: Key.hour) as? Int {
            reminderHour = stored
        } else {
            reminderHour = 19   // default 7 PM for first launch only
        }
        reminderMinute  = UserDefaults.standard.integer(forKey: Key.minute)
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted && reminderEnabled { scheduleDaily() }
        } catch {
            print("NotificationService: \(error.localizedDescription)")
        }
    }

    func checkStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Daily Study Reminder

    func setReminderEnabled(_ on: Bool) {
        reminderEnabled = on
        UserDefaults.standard.set(on, forKey: Key.enabled)
        on ? scheduleDaily() : cancelDaily()
    }

    func setReminderTime(hour: Int, minute: Int) {
        reminderHour   = hour
        reminderMinute = minute
        UserDefaults.standard.set(hour,   forKey: Key.hour)
        UserDefaults.standard.set(minute, forKey: Key.minute)
        if reminderEnabled { scheduleDaily() }
    }

    private func scheduleDaily() {
        cancelDaily()
        var comps      = DateComponents()
        comps.hour     = reminderHour
        comps.minute   = reminderMinute

        let content    = UNMutableNotificationContent()
        content.title  = "Time to Study! 📚"
        content.body   = "Keep your streak alive — open AI Academic Mentor and review your materials."
        content.sound  = .default
        content.badge  = 1

        let trigger    = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request    = UNNotificationRequest(identifier: "study.daily",
                                               content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelDaily() {
        center.removePendingNotificationRequests(withIdentifiers: ["study.daily"])
    }

    // MARK: - Pomodoro Complete

    func notifyPomodoroComplete(phase: String) {
        let content    = UNMutableNotificationContent()
        content.title  = phase == "Focus" ? "✅ Focus Session Done!" : "☕ Break Over!"
        content.body   = phase == "Focus"
            ? "Great work! Take a well-deserved break."
            : "Time to focus again — let's go!"
        content.sound  = .defaultCritical

        let trigger    = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request    = UNNotificationRequest(identifier: "pomodoro.complete.\(Date().timeIntervalSince1970)",
                                               content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Streak Alert

    func notifyStreak(days: Int) {
        let content    = UNMutableNotificationContent()
        content.title  = "🔥 \(days)-Day Streak!"
        content.body   = "Amazing consistency! Keep studying to extend your streak."
        content.sound  = .default

        let trigger    = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request    = UNNotificationRequest(identifier: "streak.\(days)",
                                               content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Clear all

    func clearAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
