import Foundation
import SwiftUI
import AVFoundation

@MainActor
final class QuizViewModel: ObservableObject {

    // MARK: - Generation

    @Published var topic           = ""
    @Published var difficulty: QuizQuestion.Difficulty = .intermediate
    @Published var questionCount   = 10
    @Published var isGenerating    = false
    @Published var showGenerateSheet = false
    @Published var errorMessage: String?

    // MARK: - Active session

    @Published var activeSession: QuizSession?
    @Published var showSession     = false
    @Published var currentIndex    = 0
    @Published var selectedAnswer: Int? = nil   // nil = not answered yet
    @Published var showExplanation = false
    @Published var showResults     = false

    // MARK: - Voice feedback

    @Published var voiceFeedbackEnabled: Bool = true

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Computed

    var currentQuestion: QuizQuestion? {
        guard let s = activeSession, currentIndex < s.questions.count else { return nil }
        return s.questions[currentIndex]
    }

    var progressFraction: Double {
        guard let s = activeSession, s.totalQuestions > 0 else { return 0 }
        return Double(currentIndex) / Double(s.totalQuestions)
    }

    var isLastQuestion: Bool {
        guard let s = activeSession else { return false }
        return currentIndex == s.totalQuestions - 1
    }

    var answeredCount: Int {
        activeSession?.userAnswers.filter { $0 != -1 }.count ?? 0
    }

    // MARK: - Generate new quiz

    func generateQuiz(store: LearningStore) async {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Please enter a topic."; return }

        isGenerating = true
        errorMessage = nil

        do {
            let questions = try await GroqService.shared.generateQuiz(
                topic: trimmed,
                difficulty: difficulty,
                count: questionCount
            )
            guard !questions.isEmpty else { throw GroqError.emptyResponse }

            let session = QuizSession(
                title: trimmed,
                subject: nil,
                difficulty: difficulty,
                questions: questions,
                userAnswers: Array(repeating: -1, count: questions.count)
            )
            store.addQuizSession(session)
            beginSession(session)
            showGenerateSheet = false
        } catch {
            errorMessage = (error as? GroqError)?.errorDescription ?? error.localizedDescription
        }
        isGenerating = false
    }

    // MARK: - Start / resume a stored session

    func startSession(_ session: QuizSession) {
        guard !session.isCompleted else {
            // Already done — jump straight to results
            activeSession  = session
            showResults    = true
            showSession    = true
            return
        }
        beginSession(session)
    }

    // MARK: - Voice toggle

    func toggleVoiceFeedback() {
        voiceFeedbackEnabled.toggle()
        if !voiceFeedbackEnabled { synthesizer.stopSpeaking(at: .word) }
    }

    // MARK: - Answer selection

    func selectAnswer(_ index: Int, store: LearningStore) {
        guard selectedAnswer == nil, var session = activeSession else { return }
        selectedAnswer   = index
        showExplanation  = true

        let isCorrect = currentQuestion?.correctIndex == index

        if currentIndex < session.userAnswers.count {
            session.userAnswers[currentIndex] = index
            activeSession = session
            store.updateQuizSession(session)
        }

        // Voice feedback
        if voiceFeedbackEnabled {
            if isCorrect {
                speak("Correct!")
            } else if let q = currentQuestion,
                      let correctOpt = q.options[safe: q.correctIndex] {
                speak("Incorrect. The correct answer is: \(correctOpt)")
            } else {
                speak("Incorrect.")
            }
        }
    }

    // MARK: - Private: TTS

    private func speak(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
        synthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice  = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate   = 0.50
        utterance.volume = 0.90
        synthesizer.speak(utterance)
    }

    // MARK: - Navigation within session

    func nextQuestion(store: LearningStore) {
        guard activeSession != nil else { return }
        if isLastQuestion {
            finishSession(store: store)
        } else {
            currentIndex    += 1
            selectedAnswer   = nil
            showExplanation  = false
        }
    }

    func finishSession(store: LearningStore) {
        if var session = activeSession {
            session.completedDate = Date()
            activeSession = session
            store.updateQuizSession(session)
        }
        showResults = true
    }

    func dismissSession() {
        showSession    = false
        showResults    = false
        activeSession  = nil
        currentIndex   = 0
        selectedAnswer = nil
        showExplanation = false
    }

    func retakeSession(_ original: QuizSession, store: LearningStore) {
        // Create a fresh copy of the same questions
        let fresh = QuizSession(
            title: original.title,
            subject: original.subject,
            difficulty: original.difficulty,
            questions: original.questions,
            userAnswers: Array(repeating: -1, count: original.questions.count)
        )
        store.addQuizSession(fresh)
        beginSession(fresh)
    }

    // MARK: - Private

    private func beginSession(_ session: QuizSession) {
        activeSession  = session
        currentIndex   = session.userAnswers.firstIndex(of: -1) ?? 0
        selectedAnswer = nil
        showExplanation = false
        showResults    = false
        showSession    = true
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
