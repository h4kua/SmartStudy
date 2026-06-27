import Foundation

// MARK: - GroqError

enum GroqError: LocalizedError {
    case httpError(Int)
    case invalidResponse
    case emptyResponse
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "AI service error (HTTP \(code)). Check GROQ_API_KEY in crew_backend/.env and restart the server."
        case .invalidResponse:
            return "Cannot reach the backend server. Make sure crew_backend is running (./start.sh)."
        case .emptyResponse:
            return "The AI returned an empty response."
        case .parseError(let detail):
            return "JSON parse error: \(detail)"
        }
    }
}

// MARK: - GroqService

/// Shared networking layer for all Groq API calls.
/// ViewModels call these async methods from their @MainActor context.
final class GroqService {

    static let shared = GroqService()
    private init() {}

    private let modelID = "llama-3.3-70b-versatile"
    private let decoder = JSONDecoder()

    /// All Groq calls go through the backend proxy so the API key
    /// never needs to be in the Xcode scheme (works on physical devices too).
    private var backendEndpoint: URL {
        URL(string: "\(BackendConfig.baseURL)/groq/completions")!
    }

    // =========================================================
    // MARK: - 1. Generic Chat Completion  (AI Tutor)
    // =========================================================

    /// Sends a chat request and returns the assistant's text reply.
    /// - Parameters:
    ///   - system: The system prompt that sets the assistant's behaviour.
    ///   - history: Prior turns as `[["role": ..., "content": ...]]` (max 6 recommended).
    ///   - userMessage: The latest message from the user.
    ///   - maxTokens: Token budget for the reply (default 400).
    func chat(system: String,
              history: [[String: String]] = [],
              userMessage: String,
              maxTokens: Int = 400) async throws -> String {

        var messages: [[String: String]] = [["role": "system", "content": system]]
        messages += history
        messages.append(["role": "user", "content": userMessage])

        return try await rawRequest(messages: messages, maxTokens: maxTokens, temperature: 0.75)
    }

    // =========================================================
    // MARK: - 2. Document Analysis
    // =========================================================

    /// Analyzes study material and returns a structured `AnalyzedDocument`.
    func analyzeDocument(title: String, text: String) async throws -> AnalyzedDocument {
        let system = """
        You are an expert academic document analyzer.
        Analyze the study material and respond with a single valid JSON object — no extra text, no markdown, no code fences.
        Use this exact shape:
        {
          "summary": "<3-5 sentence overview>",
          "keyConcepts": ["<concept>", ...],
          "definitions": {"<term>": "<definition>", ...},
          "suggestedQuestions": ["<question>", ...]
        }
        Include 5-8 key concepts, 3-6 definitions, and 4-5 suggested questions.
        """

        let prompt = "Title: \(title)\n\nContent:\n\(text.prefix(3500))"
        let raw    = try await rawRequest(messages: [
            ["role": "system", "content": system],
            ["role": "user",   "content": prompt]
        ], maxTokens: 1200, temperature: 0.4)

        let json = stripCodeFences(raw)
        guard let data = json.data(using: .utf8) else { throw GroqError.invalidResponse }

        struct DTO: Codable {
            let summary: String
            let keyConcepts: [String]
            let definitions: [String: String]
            let suggestedQuestions: [String]
        }

        do {
            let dto = try decoder.decode(DTO.self, from: data)
            return AnalyzedDocument(
                title: title,
                originalText: text,
                summary: dto.summary,
                keyConcepts: dto.keyConcepts,
                definitions: dto.definitions,
                suggestedQuestions: dto.suggestedQuestions
            )
        } catch {
            throw GroqError.parseError(error.localizedDescription)
        }
    }

    // =========================================================
    // MARK: - 3. Quiz Generation
    // =========================================================

    /// Generates multiple-choice quiz questions for the given topic.
    /// - Parameters:
    ///   - topic: Topic or text to generate questions about.
    ///   - difficulty: Difficulty level for the questions.
    ///   - count: Number of questions to generate (5, 10, or 15).
    /// - parameter context: Optional raw text from a saved note. When provided, ALL questions
    ///   are generated exclusively from this source material — not from general AI knowledge.
    func generateQuiz(topic: String,
                      difficulty: QuizQuestion.Difficulty,
                      count: Int,
                      context: String? = nil) async throws -> [QuizQuestion] {

        let contextNote = context.map { c in
            "\n\nSOURCE MATERIAL — base every question on this content only:\n\(c.prefix(3500))"
        } ?? ""

        let system = """
        You are an expert academic quiz creator. \
        Generate exactly \(count) multiple-choice questions about the topic below.
        \(context != nil ? "IMPORTANT: Generate questions ONLY from the provided source material, not from outside knowledge." : "")
        Respond with a single valid JSON array — no extra text, no markdown, no code fences.
        Each item must follow this exact shape:
        {
          "question": "<question text>",
          "options": ["<option A>", "<option B>", "<option C>", "<option D>"],
          "correctIndex": <0|1|2|3>,
          "explanation": "<comprehensive explanation>"
        }
        Difficulty: \(difficulty.label).
        EXPLANATION REQUIREMENTS — include ALL three parts in every explanation:
        1. WHY the correct answer is right (with specific facts or reasoning).
        2. WHY each wrong option is incorrect (brief but clear).
        3. A memory tip or real-world application of this concept.
        Explanations must be at least 3 sentences and genuinely educational.
        ANSWER RULES:
        - correctIndex is the 0-based index of the correct option inside options.
        - Always provide exactly 4 options per question.
        - Double-check correctIndex points to the ACTUALLY correct option.
        - Vary the position of the correct answer — do NOT always put it at index 0.
        - Make wrong options plausible but clearly incorrect upon reflection.
        """

        let raw  = try await rawRequest(messages: [
            ["role": "system", "content": system],
            ["role": "user",   "content": "Topic: \(topic)\(contextNote)"]
        ], maxTokens: count * 320, temperature: 0.5)

        let json = stripCodeFences(raw)
        guard let data = json.data(using: .utf8) else { throw GroqError.invalidResponse }

        struct DTO: Codable {
            let question: String
            let options: [String]
            let correctIndex: Int
            let explanation: String
        }

        do {
            let dtos = try decoder.decode([DTO].self, from: data)
            return dtos.prefix(count).compactMap { dto in
                let opts = dto.options.isEmpty ? ["A", "B", "C", "D"] : dto.options
                guard !opts.isEmpty else { return nil }
                let safeIndex = max(0, min(opts.count - 1, dto.correctIndex))
                return QuizQuestion(
                    question: dto.question,
                    options: opts,
                    correctIndex: safeIndex,
                    explanation: dto.explanation,
                    difficulty: difficulty
                )
            }
        } catch {
            throw GroqError.parseError(error.localizedDescription)
        }
    }

    // =========================================================
    // MARK: - 4. Flashcard Generation
    // =========================================================

    /// Generates study flashcards for the given topic.
    /// - Parameters:
    ///   - topic: Subject matter for the flashcards.
    ///   - count: Number of cards to generate (10, 20, or 30).
    func generateFlashcards(topic: String, count: Int) async throws -> [Flashcard] {
        let system = """
        You are an expert academic content creator specialising in active-recall techniques.
        Generate exactly \(count) study flashcards for the topic below.
        Respond with a single valid JSON array — no extra text, no markdown, no code fences.
        Each item must follow this exact shape:
        {
          "front": "<question or term>",
          "back": "<answer or definition>",
          "category": "<subtopic within the subject>",
          "difficulty": "<beginner|intermediate|advanced>"
        }
        Keep fronts concise (under 20 words). Backs should be clear and informative (under 60 words).
        """

        let raw  = try await rawRequest(messages: [
            ["role": "system", "content": system],
            ["role": "user",   "content": "Topic: \(topic)"]
        ], maxTokens: count * 130, temperature: 0.5)

        let json = stripCodeFences(raw)
        guard let data = json.data(using: .utf8) else { throw GroqError.invalidResponse }

        struct DTO: Codable {
            let front: String
            let back: String
            let category: String
            let difficulty: String
        }

        do {
            let dtos = try decoder.decode([DTO].self, from: data)
            return dtos.prefix(count).map { dto in
                Flashcard(
                    front: dto.front,
                    back: dto.back,
                    category: dto.category,
                    difficulty: QuizQuestion.Difficulty(rawValue: dto.difficulty) ?? .beginner
                )
            }
        } catch {
            throw GroqError.parseError(error.localizedDescription)
        }
    }

    // =========================================================
    // MARK: - 5. Exam Debrief
    // =========================================================

    /// Generates a personalised post-exam analysis based on wrong answers.
    func generateExamDebrief(topic: String, wrongQuestions: [(question: String, correct: String, chosen: String)]) async throws -> String {
        guard !wrongQuestions.isEmpty else {
            return "Perfect score! You answered every question correctly. Outstanding mastery of \(topic)."
        }

        let wrongSummary = wrongQuestions.enumerated().map { i, w in
            "\(i + 1). Question: \(w.question)\n   Correct answer: \(w.correct)\n   Your answer: \(w.chosen)"
        }.joined(separator: "\n\n")

        let system = """
        You are an expert academic coach providing a post-exam debrief.
        Be direct, specific, and encouraging. Keep your response under 300 words.
        Structure your response with these plain-text sections (no emojis):
        Performance Summary
        Key Gaps Identified
        Priority Topics to Review
        Study Recommendations
        """

        let userMsg = """
        Exam topic: \(topic)
        Wrong answers (\(wrongQuestions.count) out of total):

        \(wrongSummary)

        Please analyse these mistakes and give me a personalised study plan.
        """

        return try await rawRequest(messages: [
            ["role": "system", "content": system],
            ["role": "user",   "content": userMsg]
        ], maxTokens: 500, temperature: 0.6)
    }

    // =========================================================
    // MARK: - 6. Solve Problem from Scanned Text
    // =========================================================

    /// Sends OCR'd text from a photo to Groq and returns a step-by-step solution.
    func solveProblem(_ text: String) async throws -> String {
        let system = """
        You are an expert academic tutor. The student has photographed a question or problem from their textbook or exam paper.
        Analyze the scanned text and provide a complete, educational solution.

        Structure your response with these exact section headers:

        Understanding
        [1-2 sentences: what the problem is asking]

        Solution
        [Numbered step-by-step working — show every step clearly]

        Answer
        [The clear, concise final answer]

        Key Concept
        [The main formula, theorem, or concept used — 1-2 sentences]

        Be thorough and educational. If the scanned text is incomplete or unclear, work with what is available and note any assumptions.
        Do not use markdown symbols (* # ` etc) except for the section headers above.
        """
        return try await rawRequest(messages: [
            ["role": "system", "content": system],
            ["role": "user",   "content": "Please solve this problem:\n\n\(text)"]
        ], maxTokens: 1000, temperature: 0.2)
    }

    // =========================================================
    // MARK: - Private helpers
    // =========================================================

    private func rawRequest(messages: [[String: String]],
                            maxTokens: Int,
                            temperature: Double) async throws -> String {
        let body: [String: Any] = [
            "model":       modelID,
            "messages":    messages,
            "max_tokens":  maxTokens,
            "temperature": temperature
        ]

        var req = URLRequest(url: backendEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60  // extra headroom for backend proxy hop

        // One retry for transient 429 / 5xx errors
        var lastError: Error?
        for attempt in 0...1 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2s backoff
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: req)

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    let responseBody = String(data: data, encoding: .utf8) ?? "no body"
                    print("❌ Backend/Groq HTTP \(http.statusCode) (attempt \(attempt + 1)): \(responseBody)")
                    let retryable = http.statusCode == 429 || http.statusCode >= 500
                    if retryable && attempt == 0 {
                        lastError = GroqError.httpError(http.statusCode)
                        continue
                    }
                    throw GroqError.httpError(http.statusCode)
                }

                let decoded = try decoder.decode(GroqResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
                    throw GroqError.emptyResponse
                }
                return content

            } catch let error as GroqError {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Network error (backend offline)
                lastError = GroqError.invalidResponse
                if attempt == 0 { continue }
            }
        }
        throw lastError ?? GroqError.invalidResponse
    }

    /// Decodes the Groq chat completion response.
    private struct GroqResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    /// Removes markdown code fences (```json ... ``` or ``` ... ```) that the model sometimes wraps around JSON.
    private func stripCodeFences(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s }

        // Remove opening fence line (with or without language tag e.g. "```json")
        // BUG FIX: if there's no newline (e.g. "```json{...}```"), skip past the ``` prefix itself
        if let newline = s.range(of: "\n") {
            s = String(s[newline.upperBound...])
        } else {
            // No newline — strip only the opening ``` and any language tag up to the first {/[
            s = String(s.dropFirst(3))
            if let braceOrBracket = s.firstIndex(where: { $0 == "{" || $0 == "[" }) {
                s = String(s[braceOrBracket...])
            }
        }

        // Remove closing fence (handle possible trailing newline before ```)
        let trimmedEnd = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEnd.hasSuffix("```") {
            s = String(trimmedEnd.dropLast(3))
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
