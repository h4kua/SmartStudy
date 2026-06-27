import Foundation

// MARK: - Backend URL

/// Single source of truth for the backend server URL.
/// Update the physical-device IP here if your Mac's WiFi IP changes
/// (run `ipconfig getifaddr en0` in Terminal to find the current IP).
enum BackendConfig {
    static let baseURL: String = {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        return "http://10.24.162.130:8000"
        #endif
    }()
}

// MARK: - Request Models

struct CrewWeeklyPlanRequest: Encodable {
    let subjects: [String]
    let quizHistory: [QuizItem]
    let streakDays: Int
    let totalStudyMinutes: Int
    let studyGoal: String

    struct QuizItem: Encodable {
        let subject: String
        let score: Int          // 0–100
        let difficulty: String
        let topic: String
    }

    enum CodingKeys: String, CodingKey {
        case subjects
        case quizHistory      = "quiz_history"
        case streakDays       = "streak_days"
        case totalStudyMinutes = "total_study_minutes"
        case studyGoal        = "study_goal"
    }
}

struct CrewPerformanceRequest: Encodable {
    let quizHistory: [CrewWeeklyPlanRequest.QuizItem]
    let subjects: [String]
    let streakDays: Int

    enum CodingKeys: String, CodingKey {
        case quizHistory  = "quiz_history"
        case subjects
        case streakDays   = "streak_days"
    }
}

// MARK: - Daily Coach Request

struct DailyCoachRequest: Encodable {
    let subjects: [String]
    let quizHistory: [CrewWeeklyPlanRequest.QuizItem]
    let flashcardDecks: [FlashcardDeckItem]
    let examSessions: [ExamItem]
    let notes: [NotePreview]
    let streakDays: Int
    let totalStudyMinutes: Int

    struct NotePreview: Encodable {
        let title: String
        let preview: String   // first ~300 chars of note content
    }

    struct FlashcardDeckItem: Encodable {
        let title: String
        let masteryPercent: Double
        let dueCount: Int
        let totalCards: Int
        enum CodingKeys: String, CodingKey {
            case title
            case masteryPercent = "mastery_percent"
            case dueCount       = "due_count"
            case totalCards     = "total_cards"
        }
    }

    struct ExamItem: Encodable {
        let topic: String
        let score: Double
        let difficulty: String
    }

    enum CodingKeys: String, CodingKey {
        case subjects
        case quizHistory       = "quiz_history"
        case flashcardDecks    = "flashcard_decks"
        case examSessions      = "exam_sessions"
        case notes
        case streakDays        = "streak_days"
        case totalStudyMinutes = "total_study_minutes"
    }
}

// MARK: - Response Models

struct CrewPlanResponse: Decodable {
    let success: Bool
    let plan: String
}

struct CrewReviewResponse: Decodable {
    let success: Bool
    let review: String
}

// MARK: - Error

enum CrewAIError: LocalizedError {
    case serverOffline
    case invalidURL
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .serverOffline:
            return "CrewAI server is offline. Run ./start.sh inside crew_backend/ first."
        case .invalidURL:
            return "Invalid server URL."
        case .httpError(let code):
            return "Server returned HTTP \(code)."
        case .decodingError(let msg):
            return "Response decode error: \(msg)"
        }
    }
}

// MARK: - Service

@MainActor
final class CrewAIService: ObservableObject {

    static let shared = CrewAIService()

    private let baseURL = BackendConfig.baseURL
    private let timeout: TimeInterval = 120   // agents can take ~30-45 s

    @Published var isLoading = false

    private init() {}

    // MARK: - Liveness check

    func isServerRunning() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        do {
            var req = URLRequest(url: url, timeoutInterval: 5)
            req.httpMethod = "GET"
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Weekly Plan

    func generateWeeklyPlan(
        store: LearningStore,
        studyGoal: String
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        let history = store.quizSessions.prefix(15).map { s in
            CrewWeeklyPlanRequest.QuizItem(
                subject: s.subject ?? s.title,
                score: Int((s.percentage * 100).rounded()),
                difficulty: s.difficulty.rawValue,
                topic: s.title
            )
        }

        let body = CrewWeeklyPlanRequest(
            subjects: store.subjects.map(\.name),
            quizHistory: Array(history),
            streakDays: store.currentStreak,
            totalStudyMinutes: store.totalStudyMinutes,
            studyGoal: studyGoal.isEmpty ? "Improve academic performance" : studyGoal
        )

        let resp: CrewPlanResponse = try await post("/study/weekly-plan", body: body)
        return resp.plan
    }

    // MARK: - Performance Review

    func getPerformanceReview(store: LearningStore) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        let history = store.quizSessions.prefix(20).map { s in
            CrewWeeklyPlanRequest.QuizItem(
                subject: s.subject ?? s.title,
                score: Int((s.percentage * 100).rounded()),
                difficulty: s.difficulty.rawValue,
                topic: s.title
            )
        }

        let body = CrewPerformanceRequest(
            quizHistory: Array(history),
            subjects: store.subjects.map(\.name),
            streakDays: store.currentStreak
        )

        let resp: CrewReviewResponse = try await post("/study/performance-review", body: body)
        return resp.review
    }

    // MARK: - Daily Coach

    func getDailyCoach(store: LearningStore) async throws -> DailyCoachResponse {
        isLoading = true
        defer { isLoading = false }

        let quizItems = store.quizSessions.prefix(10).map { s in
            CrewWeeklyPlanRequest.QuizItem(
                subject: s.subject ?? s.title,
                score: Int((s.percentage * 100).rounded()),
                difficulty: s.difficulty.rawValue,
                topic: s.title
            )
        }

        let deckItems = store.flashcardDecks.map { deck in
            DailyCoachRequest.FlashcardDeckItem(
                title: deck.title,
                masteryPercent: deck.overallMastery * 100,
                dueCount: deck.cards.filter(\.isDueForReview).count,
                totalCards: deck.totalCards
            )
        }

        let examItems = store.examSessions.prefix(5).map { exam in
            DailyCoachRequest.ExamItem(
                topic: exam.title,
                score: exam.percentage * 100,
                difficulty: exam.difficulty.rawValue
            )
        }

        // Send note titles + content preview so AI recommends real topics from documents
        let notePreviews = store.studyNotes.prefix(6).map { note in
            DailyCoachRequest.NotePreview(
                title: note.title,
                preview: String(note.content.prefix(300))
            )
        }

        let body = DailyCoachRequest(
            subjects: store.subjects.map(\.name),
            quizHistory: Array(quizItems),
            flashcardDecks: deckItems,
            examSessions: Array(examItems),
            notes: Array(notePreviews),
            streakDays: store.currentStreak,
            totalStudyMinutes: store.totalStudyMinutes
        )

        return try await post("/study/daily-coach", body: body)
    }

    // MARK: - Generic POST helper

    private func post<B: Encodable, R: Decodable>(_ endpoint: String, body: B) async throws -> R {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw CrewAIError.invalidURL
        }

        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw CrewAIError.serverOffline
        }

        guard let http = response as? HTTPURLResponse else {
            throw CrewAIError.invalidURL
        }
        guard http.statusCode == 200 else {
            // Try to extract detail from FastAPI error response
            if let detail = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = detail["detail"] {
                throw CrewAIError.decodingError("HTTP \(http.statusCode): \(msg)")
            }
            throw CrewAIError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            // Print the raw response so decode failures are diagnosable in Xcode console
            if let raw = String(data: data, encoding: .utf8) {
                print("⚠️ CrewAI decode failed for \(endpoint). Raw response:\n\(raw.prefix(800))")
            }
            throw CrewAIError.decodingError(error.localizedDescription)
        }
    }
}
