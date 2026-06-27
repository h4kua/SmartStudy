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
    @Published var studyNotes:        [StudyNote]        = []
    @Published var examSessions:      [ExamSession]      = []
    @Published var totalFocusMinutes: Int                = 0

    // Daily coach — in-memory cache only (re-fetches after app quit or new calendar day)
    @Published var cachedDailyCoach: DailyCoachResponse? = nil
    private var dailyCoachFetchDate: Date? = nil

    // =========================================================
    // MARK: - UserDefaults keys
    // =========================================================

    private enum Key {
        static let subjects      = "mentor.subjects"
        static let quizzes       = "mentor.quizSessions"
        static let decks         = "mentor.flashcardDecks"
        static let documents     = "mentor.analyzedDocuments"
        static let notes         = "mentor.studyNotes"
        static let exams         = "mentor.examSessions"
        static let focusMinutes  = "mentor.totalFocusMinutes"
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
        totalFocusMinutes = UserDefaults.standard.integer(forKey: Key.focusMinutes)
    }

    // MARK: - Focus Session Logging

    /// Call when a focus session ends to accumulate total focus time.
    func logFocusSession(durationSeconds: Int) {
        let minutes = durationSeconds / 60
        guard minutes > 0 else { return }
        totalFocusMinutes += minutes
        UserDefaults.standard.set(totalFocusMinutes, forKey: Key.focusMinutes)
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
    // MARK: - Study Notes
    // =========================================================

    func addStudyNote(_ note: StudyNote) {
        studyNotes.insert(note, at: 0)
        if studyNotes.count > 200 { studyNotes = Array(studyNotes.prefix(200)) }
        saveNotes()
    }

    func updateStudyNote(_ note: StudyNote) {
        guard let idx = studyNotes.firstIndex(where: { $0.id == note.id }) else { return }
        studyNotes[idx] = note
        saveNotes()
    }

    func deleteStudyNote(id: UUID) {
        studyNotes.removeAll { $0.id == id }
        saveNotes()
    }

    // =========================================================
    // MARK: - Exam Sessions
    // =========================================================

    func addExamSession(_ exam: ExamSession) {
        examSessions.insert(exam, at: 0)
        if examSessions.count > 50 { examSessions = Array(examSessions.prefix(50)) }
        saveExams()
    }

    func updateExamSession(_ exam: ExamSession) {
        guard let idx = examSessions.firstIndex(where: { $0.id == exam.id }) else { return }
        examSessions[idx] = exam
        saveExams()
    }

    func deleteExamSession(id: UUID) {
        examSessions.removeAll { $0.id == id }
        saveExams()
    }

    // MARK: - Daily Coach Cache

    var isDailyCoachStale: Bool {
        guard let d = dailyCoachFetchDate else { return true }
        return !Calendar.current.isDateInToday(d)
    }

    func storeDailyCoach(_ response: DailyCoachResponse) {
        cachedDailyCoach = response
        dailyCoachFetchDate = Date()
    }

    // =========================================================
    // MARK: - SM-2 Spaced Repetition
    // =========================================================

    /// Updates a single flashcard using the SM-2 algorithm.
    /// - Parameter quality: 0 = Knew It, 1 = Unsure, 2 = Forgot
    func applySpacedRepetition(cardId: UUID, inDeck deckId: UUID, quality: Int) {
        guard let deckIdx = flashcardDecks.firstIndex(where: { $0.id == deckId }),
              let cardIdx = flashcardDecks[deckIdx].cards.firstIndex(where: { $0.id == cardId })
        else { return }

        var card = flashcardDecks[deckIdx].cards[cardIdx]

        // Map quality 0/1/2 → SM-2 q values 5/3/1
        let q = [5, 3, 1][min(quality, 2)]

        // Update ease factor
        let newEF = card.easeFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))
        card.easeFactor = max(1.3, newEF)

        // Update interval
        if q < 3 {
            card.srInterval = 1
            card.consecutiveCorrect = 0
        } else {
            switch card.consecutiveCorrect {
            case 0:  card.srInterval = 1
            case 1:  card.srInterval = 6
            default: card.srInterval = max(1, Int((Double(card.srInterval) * card.easeFactor).rounded()))
            }
            card.consecutiveCorrect += 1
        }

        card.nextReviewDate = Calendar.current.date(
            byAdding: .day, value: card.srInterval, to: Date()
        ) ?? Date()

        flashcardDecks[deckIdx].cards[cardIdx] = card
        saveFlashcardDecks()
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

    /// Rough estimate: 5 min per completed quiz + 10 min per reviewed deck + actual focus session minutes.
    var totalStudyMinutes: Int {
        let quizMinutes  = quizSessions.filter(\.isCompleted).count * 5
        let deckMinutes  = flashcardDecks.filter { $0.lastReviewedDate != nil }.count * 10
        return quizMinutes + deckMinutes + totalFocusMinutes
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
        // BUG FIX: only count *completed* quizzes — incomplete sessions should not inflate streak
        let quiz  = quizSessions.contains { $0.isCompleted && cal.isDate($0.createdDate, inSameDayAs: date) }
        let cards = flashcardDecks.contains { deck in
            guard let d = deck.lastReviewedDate else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
        return quiz || cards
    }

    // ---------- Weekly chart ----------

    // BUG FIX: DateFormatter is expensive — use a static instance instead of creating one per call
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    /// Activity count per day for the last 7 days.
    /// Index 0 = oldest (6 days ago), index 6 = today.
    var last7DaysActivity: [(label: String, count: Int)] {
        let formatter = LearningStore.dayFormatter
        let cal       = Calendar.current

        return (0..<7).reversed().map { daysAgo in
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()

            let quizCount = quizSessions.filter {
                $0.isCompleted && cal.isDate($0.createdDate, inSameDayAs: date)
            }.count

            let deckCount = flashcardDecks.filter { deck in
                guard let d = deck.lastReviewedDate else { return false }
                return cal.isDate(d, inSameDayAs: date)
            }.count

            return (formatter.string(from: date), quizCount + deckCount)
        }
    }

    // =========================================================
    // MARK: - Clear all data
    // =========================================================

    /// Resets all learning data (quizzes, decks, documents) and persists the empty state.
    /// BUG FIX: previously SettingsView modified arrays directly and hardcoded key strings.
    func clearAllLearningData() {
        quizSessions      = []
        flashcardDecks    = []
        analyzedDocuments = []
        studyNotes        = []
        examSessions      = []
        saveQuizSessions()
        saveFlashcardDecks()
        saveDocuments()
        saveNotes()
        saveExams()
    }

    // =========================================================
    // MARK: - Persistence helpers
    // =========================================================

    private func saveSubjects()      { save(subjects,           to: Key.subjects) }
    private func saveQuizSessions()  { save(quizSessions,       to: Key.quizzes) }
    private func saveFlashcardDecks(){ save(flashcardDecks,     to: Key.decks) }
    private func saveDocuments()     { save(analyzedDocuments,  to: Key.documents) }
    private func saveNotes()         { save(studyNotes,         to: Key.notes) }
    private func saveExams()         { save(examSessions,       to: Key.exams) }

    /// Reuse encoder/decoder — creating them is expensive.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    private func save<T: Encodable>(_ value: T, to key: String) {
        do {
            let data = try Self.encoder.encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // Silent `try?` hides data corruption — log so we can diagnose
            print("⚠️ LearningStore: failed to save \(key): \(error.localizedDescription)")
        }
    }

    private func load<T: Decodable>(_ type: T.Type, from key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            print("⚠️ LearningStore: failed to load \(key): \(error.localizedDescription)")
            return nil
        }
    }

    private func load() {
        subjects          = load([Subject].self,          from: Key.subjects)   ?? []
        quizSessions      = load([QuizSession].self,      from: Key.quizzes)    ?? []
        flashcardDecks    = load([FlashcardDeck].self,    from: Key.decks)      ?? []
        analyzedDocuments = load([AnalyzedDocument].self, from: Key.documents)  ?? []
        studyNotes        = load([StudyNote].self,        from: Key.notes)      ?? []
        examSessions      = load([ExamSession].self,      from: Key.exams)      ?? []
    }
}
