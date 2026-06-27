import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

@MainActor
final class DocumentAnalyzerViewModel: ObservableObject {

    // MARK: - Input

    @Published var documentTitle  = ""
    @Published var inputText      = ""
    @Published var showFilePicker = false

    // MARK: - Note Scanner
    @Published var showScanMenu    = false
    @Published var showScanPicker  = false
    @Published var scanSourceType: UIImagePickerController.SourceType = .photoLibrary
    @Published var isScanning      = false
    @Published var showFileImportWarning = false
    @Published var isPDFOCRScanning = false

    private var lastImportedPDFURL: URL?
    var canRescanWithOCR: Bool { lastImportedPDFURL != nil }

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

        let topic = doc.title

        do {
            let questions = try await GroqService.shared.generateQuiz(
                topic: topic,
                difficulty: quizDifficulty,
                count: quizCount,
                context: doc.originalText.isEmpty ? nil : doc.originalText
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

    // MARK: - Note Scanner (Vision OCR)

    /// Called when user picks an image from camera or photo library.
    /// Runs on-device OCR → populates inputText → ready to analyze with AI.
    func scanImage(_ image: UIImage) async {
        isScanning   = true
        errorMessage = nil

        do {
            let text = try await NoteScannerService.recognizeText(from: image)
            inputText = text
            if documentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                documentTitle = "Scanned Notes"
            }
            let wordCount = text.split(separator: " ").count
            bannerMessage = "Extracted \(wordCount) words — tap Analyze to generate quiz & flashcards!"
        } catch {
            errorMessage = (error as? NoteScannerService.ScanError)?.errorDescription
                           ?? error.localizedDescription
        }

        isScanning = false
    }

    // Renders each PDF page to a UIImage and runs Vision OCR — correctly handles
    // slide decks / multi-column layouts that PDFKit text extraction scrambles.
    // Uses .fast recognition + 4-page concurrent batches for speed.
    func scanPDFWithOCR() async {
        guard let url = lastImportedPDFURL else { return }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Could not access the PDF file. Please re-import it."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let pdf = PDFDocument(url: url) else {
            errorMessage = "Could not read PDF file."
            return
        }

        isPDFOCRScanning = true
        errorMessage = nil

        let scale: CGFloat = 1.5
        let pageCount = pdf.pageCount
        var results: [Int: String] = [:]

        // Process 4 pages at a time to bound memory usage (~7 MB/page at 1.5x).
        let batchSize = 4
        for batchStart in stride(from: 0, to: pageCount, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, pageCount)

            // Render this batch to UIImages on the current thread.
            var batchImages: [(index: Int, image: UIImage)] = []
            for i in batchStart..<batchEnd {
                guard let page = pdf.page(at: i) else { continue }
                let pageRect = page.bounds(for: .mediaBox)
                let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    let cgCtx = ctx.cgContext
                    cgCtx.translateBy(x: 0, y: size.height)
                    cgCtx.scaleBy(x: scale, y: -scale)
                    page.draw(with: .mediaBox, to: cgCtx)
                }
                batchImages.append((index: i, image: image))
            }

            // OCR the batch concurrently — each task dispatches to a GCD background
            // thread so all 4 Vision requests run in parallel.
            await withTaskGroup(of: (Int, String).self) { group in
                for entry in batchImages {
                    let idx = entry.index
                    let img = entry.image
                    group.addTask {
                        let text = await DocumentAnalyzerViewModel.ocrPageFast(img)
                        return (idx, text)
                    }
                }
                for await (index, text) in group {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        results[index] = text
                    }
                }
            }
        }

        let joined = (0..<pageCount).compactMap { results[$0] }.joined(separator: "\n\n")

        if joined.isEmpty {
            errorMessage = "OCR could not extract any text from this PDF."
        } else {
            inputText = joined
            showFileImportWarning = false
            let words = joined.split(separator: " ").count
            bannerMessage = "OCR extracted \(words) words from \(pageCount) pages."
        }

        isPDFOCRScanning = false
    }

    // .fast recognition dispatched to a GCD background thread so the main actor
    // is not blocked and multiple pages can be in-flight simultaneously.
    private static func ocrPageFast(_ image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: "")
                return
            }
            let request = VNRecognizeTextRequest { req, _ in
                let sorted = (req.results as? [VNRecognizedTextObservation] ?? []).sorted {
                    let dy = $1.boundingBox.minY - $0.boundingBox.minY
                    return abs(dy) > 0.015 ? dy > 0 : $0.boundingBox.minX < $1.boundingBox.minX
                }
                let text = sorted.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "id-ID"]
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                try? handler.perform([request])
            }
        }
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
                lastImportedPDFURL = url
                let raw = (0..<pdf.pageCount).compactMap {
                    pdf.page(at: $0)?.string
                }.joined(separator: "\n\n")
                inputText = Self.repairAndClean(raw)
                if !inputText.isEmpty { showFileImportWarning = true }
            } else {
                errorMessage = "Could not read PDF file."
            }
        } else {
            let raw = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if raw.isEmpty {
                errorMessage = "File appears to be empty."
            } else {
                inputText = Self.repairAndClean(raw)
                showFileImportWarning = true
            }
        }
    }

    // MARK: - Text repair (public so NoteDetailView can call it on saved notes)

    /// Full pipeline: fix reversed lines, then normalize whitespace/formatting.
    static func repairAndClean(_ text: String) -> String {
        let repaired = repairReversedLines(text)
        return normalizeWhitespace(repaired)
    }

    // Comprehensive word list — common English + Indonesian + academic/tech/security terms.
    private static let readableWords: Set<String> = [
        // Super-common English (2–4 letters)
        "a", "an", "as", "at", "be", "by", "do", "go", "he", "if",
        "in", "is", "it", "me", "my", "no", "of", "on", "or", "so",
        "to", "up", "us", "we", "all", "and", "are", "but", "can",
        "did", "for", "get", "got", "had", "has", "her", "him", "his",
        "how", "its", "let", "may", "new", "not", "now", "one", "our",
        "out", "own", "put", "run", "see", "set", "she", "the", "two",
        "use", "was", "who", "why", "yet", "you", "also", "been",
        "both", "does", "each", "even", "from", "have", "here", "high",
        "into", "just", "keep", "know", "last", "like", "long", "look",
        "made", "make", "many", "more", "most", "much", "must", "need",
        "next", "only", "open", "over", "part", "same", "some", "such",
        "take", "than", "that", "them", "then", "they", "this", "time",
        "used", "very", "well", "when", "will", "with", "your",
        // Security / AI safety
        "agent", "agents", "rule", "rules", "key", "keys",
        "security", "secure", "access", "attack", "threat", "risk",
        "review", "audit", "check", "checks", "scan", "report",
        "static", "dynamic", "hybrid", "control", "controls",
        "human", "mission", "today", "produce", "every",
        "combine", "tool", "tools", "test", "tests", "testing",
        "regression", "triage", "assisted", "privilege", "setting", "settings",
        "prompt", "inject", "injection", "filter", "validate", "log",
        "least", "policy", "trust", "verify", "monitor", "block",
        "application", "applications",
        // General academic / tech
        "model", "models", "data", "class", "type", "layer", "error",
        "input", "output", "train", "learn", "detect", "generate",
        "analyze", "feature", "network", "object", "result", "method",
        "system", "provide", "feedback", "identify", "calculate",
        "architecture", "recommend", "explain", "pattern", "reason",
        "logic", "score", "text", "code", "app", "user", "users",
        "function", "value", "view", "image", "list", "stack", "api",
        "action", "form", "frame", "body", "camera", "video", "vision",
        "classify", "mapper", "advice", "voice", "haptic", "swift",
        "core", "apple", "ios", "select", "where", "eval", "exec",
        "distinct", "critical", "reliable", "answer", "only", "learn",
        // Indonesian
        "yang", "dan", "dari", "untuk", "pada", "dengan", "ini", "itu",
        "adalah", "juga", "dalam", "bahwa", "atau", "dapat", "sebuah",
        "sistem", "hasil", "proses", "fungsi", "setiap", "tidak",
        "lebih", "cara", "jika", "saat", "akan", "bisa", "sudah",
        "keamanan", "pengguna", "aplikasi", "menggunakan"
    ]

    // Checks and repairs each line independently.
    // PDFs with mixed RTL/LTR sections are handled correctly.
    private static func repairReversedLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        return lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count > 5, trimmed.contains(" ") else { return line }
            let reversed = String(trimmed.reversed())
            return scoreWords(reversed) > scoreWords(trimmed) ? reversed : line
        }.joined(separator: "\n")
    }

    // Counts whole-word matches from readableWords in the given text.
    private static func scoreWords(_ text: String) -> Int {
        // Tokenize: split on spaces and strip leading/trailing punctuation
        let tokens = text.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        return tokens.filter { readableWords.contains($0) }.count
    }

    // Cleans up common PDF/OCR formatting issues:
    // strips control chars, trims trailing spaces, collapses 3+ blank lines → 2.
    private static func normalizeWhitespace(_ text: String) -> String {
        let cleaned = text.unicodeScalars.filter {
            $0 == "\n" || $0 == "\t" || $0.value >= 32
        }.map { Character($0) }
        var result = String(cleaned)

        let lines = result.components(separatedBy: "\n").map {
            $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        }
        result = lines.joined(separator: "\n")

        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Save as Note

    func saveAsNote(store: LearningStore) {
        guard let doc = result else { return }
        let note = StudyNote(
            title:   doc.title,
            content: doc.originalText,
            subject: doc.subject,
            pageCount: 1
        )
        store.addStudyNote(note)
        bannerMessage = "Saved as note — view it in My Notes."
    }

    // MARK: - Reset

    func reset() {
        result               = nil
        documentTitle        = ""
        inputText            = ""
        errorMessage         = nil
        bannerMessage        = nil
        showGenerateSheet    = false
        showFileImportWarning = false
        lastImportedPDFURL   = nil
    }
}

// MARK: - SolveProblemViewModel

/// ViewModel for the Scan & Solve feature.
/// User photographs a physical problem → on-device OCR → Groq solves step-by-step.
@MainActor
final class SolveProblemViewModel: ObservableObject {

    @Published var capturedImage: UIImage?
    @Published var detectedText:  String = ""
    @Published var answer:        String?
    @Published var isScanning:    Bool = false
    @Published var isSolving:     Bool = false
    @Published var errorMessage:  String?
    @Published var showImagePicker: Bool = false
    @Published var sourceType: UIImagePickerController.SourceType = .camera

    func scanAndSolve(_ image: UIImage) async {
        capturedImage = image
        detectedText  = ""
        answer        = nil
        errorMessage  = nil
        isScanning    = true

        do {
            let text = try await NoteScannerService.recognizeText(from: image)
            detectedText = text
            isScanning   = false
            isSolving    = true
            answer = try await GroqService.shared.solveProblem(text)
        } catch let e as NoteScannerService.ScanError {
            errorMessage = e.errorDescription
        } catch let e as GroqError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
        isSolving  = false
    }

    func reset() {
        capturedImage = nil
        detectedText  = ""
        answer        = nil
        errorMessage  = nil
    }
}
