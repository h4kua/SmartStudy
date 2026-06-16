import Foundation
import PDFKit
import UniformTypeIdentifiers

@MainActor
final class DocumentAnalyzerViewModel: ObservableObject {

    // MARK: - Input

    @Published var documentTitle  = ""
    @Published var inputText      = ""
    @Published var showFilePicker = false

    // MARK: - Analysis state

    @Published var isAnalyzing = false
    @Published var result: AnalyzedDocument?

    // MARK: - Generation config

    @Published var showGenerateSheet = false
    @Published var generateMode: GenerateMode = .quiz
    @Published var quizDifficulty: QuizQuestion.Difficulty = .intermediate
    @Published var quizCount      = 10
    @Published var flashcardCount = 15

    // MARK: - Generation state

    @Published var isGeneratingQuiz       = false
    @Published var isGeneratingFlashcards = false

    // MARK: - Feedback

    @Published var errorMessage:  String?
    @Published var bannerMessage: String?

    enum GenerateMode { case quiz, flashcards }

    var isGenerating: Bool { isGeneratingQuiz || isGeneratingFlashcards }

    var wordCount: Int {
        inputText.split(separator: " ").count
    }

    // MARK: - Analyze

    func analyze(store: LearningStore) async {
        let text  = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            errorMessage = "Please paste some content before analyzing."
            return
        }

        isAnalyzing  = true
        errorMessage = nil

        do {
            let doc = try await GroqService.shared.analyzeDocument(
                title: title.isEmpty ? "Untitled Document" : title,
                text: text
            )
            result = doc
            store.addAnalyzedDocument(doc)
        } catch {
            errorMessage = (error as? GroqError)?.errorDescription ?? error.localizedDescription
        }

        isAnalyzing = false
    }

    // MARK: - Generate Quiz

    func generateQuiz(store: LearningStore) async {
        guard let doc = result else { return }

        isGeneratingQuiz = true
        errorMessage     = nil

        let topic = "\(doc.title). \(doc.summary). Key concepts: \(doc.keyConcepts.prefix(5).joined(separator: ", "))"

        do {
            let questions = try await GroqService.shared.generateQuiz(
                topic: topic,
                difficulty: quizDifficulty,
                count: quizCount
            )
            guard !questions.isEmpty else { throw GroqError.emptyResponse }

            let session = QuizSession(
                title: doc.title,
                subject: nil,
                difficulty: quizDifficulty,
                questions: questions,
                userAnswers: Array(repeating: -1, count: questions.count)
            )
            store.addQuizSession(session)
            bannerMessage = "\(questions.count)-question quiz created. Go to Learn → Quizzes to take it."
            showGenerateSheet = false
        } catch {
            errorMessage = (error as? GroqError)?.errorDescription ?? error.localizedDescription
        }

        isGeneratingQuiz = false
    }

    // MARK: - Generate Flashcards

    func generateFlashcards(store: LearningStore) async {
        guard let doc = result else { return }

        isGeneratingFlashcards = true
        errorMessage           = nil

        let topic = "\(doc.title). Key concepts: \(doc.keyConcepts.joined(separator: ", "))"

        do {
            let cards = try await GroqService.shared.generateFlashcards(
                topic: topic,
                count: flashcardCount
            )
            guard !cards.isEmpty else { throw GroqError.emptyResponse }

            let deck = FlashcardDeck(
                title: doc.title,
                subject: nil,
                cards: cards
            )
            store.addFlashcardDeck(deck)
            bannerMessage = "\(cards.count) flashcards created. Go to Learn → Flashcards to review."
            showGenerateSheet = false
        } catch {
            errorMessage = (error as? GroqError)?.errorDescription ?? error.localizedDescription
        }

        isGeneratingFlashcards = false
    }

    // MARK: - File import

    func loadFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Could not access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        documentTitle = url.deletingPathExtension().lastPathComponent

        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            if let pdf = PDFDocument(url: url) {
                inputText = (0..<pdf.pageCount).compactMap {
                    pdf.page(at: $0)?.string
                }.joined(separator: "\n\n")
            } else {
                errorMessage = "Could not read PDF file."
            }
        } else {
            inputText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if inputText.isEmpty {
                errorMessage = "File appears to be empty."
            }
        }
    }

    // MARK: - Reset

    func reset() {
        result          = nil
        documentTitle   = ""
        inputText       = ""
        errorMessage    = nil
        bannerMessage   = nil
        showGenerateSheet = false
    }
}
