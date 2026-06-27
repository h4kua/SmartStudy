import Foundation
import SwiftUI
import Combine

@MainActor
final class ExamModeViewModel: ObservableObject {

    // MARK: - Exam setup

    @Published var topic      = ""
    @Published var difficulty: QuizQuestion.Difficulty = .intermediate
    @Published var timeLimitMinutes = 30
    @Published var questionCount    = 10
    @Published var isGenerating     = false
    @Published var errorMessage: String?
    /// Full text content of an uploaded document — when set, exam questions are
    /// generated FROM this content instead of Groq's general knowledge.
    @Published var documentContext: String?

    // MARK: - Active exam state

    @Published var activeExam: ExamSession?
    @Published var currentIndex  = 0
    @Published var timeRemaining = 0            // seconds
    @Published var antiCheatWarnings = 0
    @Published var showWarningBanner  = false
    @Published var examComplete = false

    // MARK: - Debrief

    @Published var isLoadingDebrief = false
    @Published var debriefText: String?

    // MARK: - Timer

    private var timerTask: Task<Void, Never>?

    var progress: Double {
        guard let e = activeExam, e.timeLimitSeconds > 0 else { return 0 }
        return Double(timeRemaining) / Double(e.timeLimitSeconds)
    }

    var timeRemainingString: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var isLowTime: Bool { timeRemaining > 0 && timeRemaining <= 60 }

    var currentQuestion: QuizQuestion? {
        guard let e = activeExam, currentIndex < e.questions.count else { return nil }
        return e.questions[currentIndex]
    }

    var totalQuestions: Int { activeExam?.questions.count ?? 0 }

    // MARK: - Generate exam

    func generateExam(store: LearningStore) async {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a topic."
            return
        }
        isGenerating = true
        errorMessage = nil

        do {
            let questions = try await GroqService.shared.generateQuiz(
                topic: trimmed,
                difficulty: difficulty,
                count: questionCount,
                context: documentContext
            )
            guard !questions.isEmpty else { throw GroqError.emptyResponse }

            let exam = ExamSession(
                title: trimmed,
                subject: nil,
                difficulty: difficulty,
                questions: questions,
                userAnswers: Array(repeating: -1, count: questions.count),
                timeLimitSeconds: timeLimitMinutes * 60
            )
            store.addExamSession(exam)
            startExam(exam)
        } catch {
            errorMessage = (error as? GroqError)?.errorDescription ?? error.localizedDescription
        }
        isGenerating = false
    }

    // MARK: - Start / control exam

    func startExam(_ exam: ExamSession) {
        activeExam     = exam
        currentIndex   = 0
        timeRemaining  = exam.timeLimitSeconds
        antiCheatWarnings = exam.antiCheatWarnings
        examComplete   = false
        debriefText    = nil
        startTimer()
    }

    func selectAnswer(_ answerIndex: Int, store: LearningStore) {
        guard var exam = activeExam,
              currentIndex < exam.questions.count else { return }
        exam.userAnswers[currentIndex] = answerIndex
        activeExam = exam
        store.updateExamSession(exam)
    }

    func nextQuestion() {
        guard let exam = activeExam, currentIndex < exam.questions.count - 1 else { return }
        currentIndex += 1
    }

    func previousQuestion() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func submitExam(store: LearningStore) {
        finishExam(store: store)
    }

    func logAntiCheatWarning(store: LearningStore) {
        antiCheatWarnings += 1
        showWarningBanner  = true
        guard var exam = activeExam else { return }
        exam.antiCheatWarnings = antiCheatWarnings
        activeExam = exam
        store.updateExamSession(exam)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showWarningBanner = false
        }
    }

    // MARK: - AI Debrief

    func loadDebrief(store: LearningStore) async {
        guard let exam = activeExam else { return }
        isLoadingDebrief = true

        let wrong: [(question: String, correct: String, chosen: String)] =
            zip(exam.questions, exam.userAnswers).compactMap { q, a in
                guard q.correctIndex != a else { return nil }
                let chosen = a >= 0 && a < q.options.count ? q.options[a] : "No answer"
                return (q.question, q.options[q.correctIndex], chosen)
            }

        do {
            let text = try await GroqService.shared.generateExamDebrief(
                topic: exam.title,
                wrongQuestions: wrong
            )
            debriefText = text
            var updated = exam
            updated.aiDebrief = text
            activeExam = updated
            store.updateExamSession(updated)
        } catch {
            debriefText = "Could not load AI debrief: \(error.localizedDescription)"
        }
        isLoadingDebrief = false
    }

    // MARK: - Private

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                timeRemaining -= 1
            }
            // Time's up — auto submit (will be handled by the view observing timeRemaining == 0)
        }
    }

    private func finishExam(store: LearningStore) {
        timerTask?.cancel()
        guard var exam = activeExam else { return }
        exam.completedDate   = Date()
        exam.timeUsedSeconds = exam.timeLimitSeconds - timeRemaining
        exam.antiCheatWarnings = antiCheatWarnings
        activeExam  = exam
        examComplete = true
        store.updateExamSession(exam)
    }

    func cleanup() {
        timerTask?.cancel()
        timerTask = nil
    }
}
