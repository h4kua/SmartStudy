import Foundation

// MARK: - GroqError

enum GroqError: LocalizedError {
    case missingAPIKey
    case httpError(Int)
    case invalidResponse
    case emptyResponse
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "GROQ_API_KEY is not set. Add it in Xcode: Edit Scheme → Run → Environment Variables."
        case .httpError(let code):
            return "AI service returned HTTP \(code). Check your API key and try again."
        case .invalidResponse:
            return "Could not parse the AI response. Please try again."
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

    private let endpoint  = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let modelID   = "llama-3.3-70b-versatile"

    /// Reuse decoders — creating them is surprisingly expensive.
    private let decoder = JSONDecoder()

    /// Maximum automatic retries for transient network errors (timeout, 429, 5xx).
    private let maxRetries = 2

    private var apiKey: String {
        ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
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
    func generateQuiz(topic: String,
                      difficulty: QuizQuestion.Difficulty,
                      count: Int) async throws -> [QuizQuestion] {

        let system = """
        You are an expert academic quiz creator.
        Generate exactly \(count) multiple-choice questions about the topic below.
        Respond with a single valid JSON array — no extra text, no markdown, no code fences.
        Each item must follow this exact shape:
        {
          "question": "<question text>",
          "options": ["<option A>", "<option B>", "<option C>", "<option D>"],
          "correctIndex": <0|1|2|3>,
          "explanation": "<why this answer is correct>"
        }
        Difficulty: \(difficulty.label). Make questions clear and unambiguous.
        correctIndex is the 0-based index of the correct option inside the options array.
        """

        let raw  = try await rawRequest(messages: [
            ["role": "system", "content": system],
            ["role": "user",   "content": "Topic: \(topic)"]
        ], maxTokens: count * 230, temperature: 0.5)

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
            return dtos.prefix(count).map { dto in
                QuizQuestion(
                    question: dto.question,
                    options: dto.options,
                    correctIndex: max(0, min(3, dto.correctIndex)),
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
    // MARK: - Private helpers
    // =========================================================

    private func rawRequest(messages: [[String: String]],
                            maxTokens: Int,
                            temperature: Double) async throws -> String {
        guard !apiKey.isEmpty else { throw GroqError.missingAPIKey }

        let body: [String: Any] = [
            "model":       modelID,
            "messages":    messages,
            "max_tokens":  maxTokens,
            "temperature": temperature
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 45

        // Retry loop for transient errors (429 rate-limit, 5xx server, timeout)
        var lastError: Error?
        for attempt in 0...maxRetries {
            if attempt > 0 {
                // Exponential backoff: 1s, 2s
                let delay = UInt64(attempt) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: req)

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    let responseBody = String(data: data, encoding: .utf8) ?? "no body"
                    print("❌ Groq HTTP \(http.statusCode) (attempt \(attempt + 1)): \(responseBody)")

                    // Retry on rate-limit or server errors; give up on 4xx client errors
                    let retryable = http.statusCode == 429 || http.statusCode >= 500
                    if retryable && attempt < maxRetries {
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
                // URLSession timeout / network error → retry
                lastError = error
                if attempt < maxRetries { continue }
                throw error
            }
        }
        throw lastError ?? GroqError.invalidResponse
    }

    /// Decodes the Groq chat completion response.
    private struct GroqResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let content: String }
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
