import Foundation
import SwiftUI

// MARK: - LearningStore
//
// Single source of truth for AI Academic Mentor.
// Injected via .environmentObject() from FinalProjectApp.
// Replaces the legacy StudyStore (removed in Step 7).

@MainActor
final class LearningStore: ObservableObject {

    // =========================================================
    // MARK: - Published state
    // =========================================================

    @Published var subjects:          [Subject]          = []
    @Published var quizSessions:      [QuizSession]      = []
    @Published var flashcardDecks:    [FlashcardDeck]    = []
    @Published var analyzedDocuments: [AnalyzedDocument] = []

    // =========================================================
    // MARK: - UserDefaults keys
    // =========================================================

    private enum Key {
        static let subjects   = "mentor.subjects"
        static let quizzes    = "mentor.quizSessions"
        static let decks      = "mentor.flashcardDecks"
        static let documents  = "mentor.analyzedDocuments"
    }

    // =========================================================
    // MARK: - Init
    // =========================================================

    init() {
        load()
        if subjects.isEmpty {
            subjects = Subject.presets
            saveSubjects()
        }
    }

    // =========================================================
    // MARK: - Quiz Sessions
    // =========================================================

    func addQuizSession(_ session: QuizSession) {
        quizSessions.insert(session, at: 0)
        if quizSessions.count > 100 {
            quizSessions = Array(quizSessions.prefix(100))
        }
        saveQuizSessions()
    }

    func updateQuizSession(_ session: QuizSession) {
        guard let idx = quizSessions.firstIndex(where: { $0.id == session.id }) else { return }
        quizSessions[idx] = session
        saveQuizSessions()
    }

    func deleteQuizSession(id: UUID) {
        quizSessions.removeAll { $0.id == id }
        saveQuizSessions()
    }

    // =========================================================
    // MARK: - Flashcard Decks
    // =========================================================

    func addFlashcardDeck(_ deck: FlashcardDeck) {
        flashcardDecks.insert(deck, at: 0)
        saveFlashcardDecks()
    }

    func updateFlashcardDeck(_ deck: FlashcardDeck) {
        guard let idx = flashcardDecks.firstIndex(where: { $0.id == deck.id }) else { return }
        flashcardDecks[idx] = deck
        saveFlashcardDecks()
    }

    func deleteFlashcardDeck(id: UUID) {
        flashcardDecks.removeAll { $0.id == id }
        saveFlashcardDecks()
    }

    // =========================================================
    // MARK: - Analyzed Documents
    // =========================================================

    func addAnalyzedDocument(_ doc: AnalyzedDocument) {
        analyzedDocuments.insert(doc, at: 0)
        if analyzedDocuments.count > 50 {
            analyzedDocuments = Array(analyzedDocuments.prefix(50))
        }
        saveDocuments()
    }

    func deleteAnalyzedDocument(id: UUID) {
        analyzedDocuments.removeAll { $0.id == id }
        saveDocuments()
    }

    // =========================================================
    // MARK: - Subjects
    // =========================================================

    func addSubject(_ subject: Subject) {
        subjects.append(subject)
        saveSubjects()
    }

    func updateSubject(_ subject: Subject) {
        guard let idx = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        subjects[idx] = subject
        saveSubjects()
    }

    func deleteSubject(id: UUID) {
        subjects.removeAll { $0.id == id }
        saveSubjects()
    }

    // =========================================================
    // MARK: - Analytics  (computed — no extra persistence needed)
    // =========================================================

    // ---------- Quiz stats ----------

    var totalQuizzesTaken: Int {
        quizSessions.filter(\.isCompleted).count
    }

    var averageQuizScore: Double {
        let completed = quizSessions.filter(\.isCompleted)
        guard !completed.isEmpty else { return 0 }
        return completed.map(\.percentage).reduce(0, +) / Double(completed.count)
    }

    var bestQuizScore: Double {
        quizSessions.filter(\.isCompleted).map(\.percentage).max() ?? 0
    }

    var todayQuizSessions: [QuizSession] {
        quizSessions.filter { $0.isToday && $0.isCompleted }
    }

    var recentQuizSessions: [QuizSession] {
        Array(quizSessions.filter(\.isCompleted).prefix(10))
    }

    // ---------- Flashcard stats ----------

    var totalFlashcardsReviewed: Int {
        flashcardDecks.flatMap(\.cards).reduce(0) { $0 + $1.reviewCount }
    }

    var totalDecksCreated: Int { flashcardDecks.count }

    var recentDecks: [FlashcardDeck] {
        Array(flashcardDecks.prefix(5))
    }

    // ---------- Document stats ----------

    var totalDocumentsAnalyzed: Int { analyzedDocuments.count }

    // ---------- Study time estimate ----------

    /// Rough estimate: 5 min per completed quiz + 10 min per reviewed deck.
    var totalStudyMinutes: Int {
        let quizMinutes = quizSessions.filter(\.isCompleted).count * 5
        let deckMinutes = flashcardDecks.filter { $0.lastReviewedDate != nil }.count * 10
        return quizMinutes + deckMinutes
    }

    // ---------- Streak ----------

    /// Consecutive days the user had at least one learning activity.
    var currentStreak: Int {
        var streak    = 0
        var checkDate = Date()

        // If nothing happened today, start checking from yesterday
        if !hasActivity(on: checkDate) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)
            else { return 0 }
            checkDate = yesterday
        }

        for _ in 0..<365 {
            if hasActivity(on: checkDate) {
                streak += 1
                guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)
                else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    /// True when the user had any quiz or flashcard activity on `date`.
    func hasActivity(on date: Date) -> Bool {
        let cal = Calendar.current
        let quiz  = quizSessions.contains { cal.isDate($0.createdDate, inSameDayAs: date) }
        let cards = flashcardDecks.contains { deck in
            guard let d = deck.lastReviewedDate else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
        return quiz || cards
    }

    // ---------- Weekly chart ----------

    /// Activity count per day for the last 7 days.
    /// Index 0 = oldest (6 days ago), index 6 = today.
    var last7DaysActivity: [(label: String, count: Int)] {
        let formatter       = DateFormatter()
        formatter.dateFormat = "EEE"
        let cal             = Calendar.current

        return (0..<7).reversed().map { daysAgo in
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()

            let quizCount = quizSessions.filter {
                cal.isDate($0.createdDate, inSameDayAs: date)
            }.count

            let deckCount = flashcardDecks.filter { deck in
                guard let d = deck.lastReviewedDate else { return false }
                return cal.isDate(d, inSameDayAs: date)
            }.count

            return (formatter.string(from: date), quizCount + deckCount)
        }
    }

    // =========================================================
    // MARK: - Persistence helpers
    // =========================================================

    private func saveSubjects()      { save(subjects,          to: Key.subjects) }
    private func saveQuizSessions()  { save(quizSessions,      to: Key.quizzes) }
    private func saveFlashcardDecks(){ save(flashcardDecks,    to: Key.decks) }
    private func saveDocuments()     { save(analyzedDocuments,  to: Key.documents) }

    private func save<T: Encodable>(_ value: T, to key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, from key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func load() {
        subjects          = load([Subject].self,          from: Key.subjects)   ?? []
        quizSessions      = load([QuizSession].self,      from: Key.quizzes)   ?? []
        flashcardDecks    = load([FlashcardDeck].self,    from: Key.decks)      ?? []
        analyzedDocuments = load([AnalyzedDocument].self, from: Key.documents)  ?? []
    }
}
