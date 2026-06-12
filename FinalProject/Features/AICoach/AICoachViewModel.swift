import Foundation

@MainActor
final class AICoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var groqApiKey: String {
        ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
    }

    init() {
        messages = [
            ChatMessage(
                role: "assistant",
                content: "Hi! I'm your AI study coach 📚 Ask me about study techniques, subject explanations, or how to boost your focus. What are you working on today?"
            )
        ]
    }

    func send(currentSubjectName: String?) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: "user", content: text))
        inputText = ""
        isLoading = true
        errorMessage = nil

        do {
            let reply = try await callGroq(text, subjectContext: currentSubjectName)
            messages.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            errorMessage = "Couldn't reach the coach. Check your connection."
            messages.append(ChatMessage(role: "assistant", content: "Sorry, I couldn't connect right now. Please try again. 🔌"))
        }
        isLoading = false
    }

    // MARK: - Groq API

    private func callGroq(_ userMessage: String, subjectContext: String?) async throws -> String {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        guard !groqApiKey.isEmpty else {
            return "⚠️ GROQ_API_KEY is not set. Add it to your Xcode scheme's environment variables to enable AI coaching."
        }

        var systemPrompt = "You are a helpful, encouraging study coach for a university student. Provide concise, actionable advice about studying, learning strategies, and academic topics. Keep responses under 180 words. Use simple markdown (bold, bullet points)."
        if let sub = subjectContext {
            systemPrompt += " The student is currently studying \(sub)."
        }

        let history: [[String: String]] = messages.suffix(6).map {
            ["role": $0.role, "content": $0.content]
        }

        let body: [String: Any] = [
            "model": "llama3-70b-8192",
            "messages": [["role": "system", "content": systemPrompt]] + history,
            "max_tokens": 350,
            "temperature": 0.75
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(groqApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.choices.first?.message.content ?? "No response."
    }
}
