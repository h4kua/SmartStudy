import Foundation

@MainActor
final class AITutorViewModel: ObservableObject {
    @Published var messages:      [ChatMessage] = []
    @Published var inputText:     String        = ""
    @Published var isLoading:     Bool          = false
    @Published var errorMessage:  String?
    @Published var isRecording:   Bool          = false
    @Published var canRetry:      Bool          = false

    /// The last failed user message — kept so we can retry.
    private var lastFailedText: String?

    /// Cap total messages to prevent unbounded memory growth in long sessions.
    private let maxMessages = 100

    private let systemPrompt = """
    You are a helpful and encouraging AI academic tutor for university students. \
    Provide clear, concise explanations tailored to the student's level. \
    Use simple markdown (bold, bullet points) when helpful. \
    Keep responses under 200 words unless the student asks for more detail.
    """

    init() {
        messages = [
            ChatMessage(role: "assistant",
                        content: "Hi! I'm your AI Academic Tutor. Ask me to explain any concept, help with homework, or suggest a study strategy. What are you working on?")
        ]
    }

    // MARK: - Voice input

    func toggleRecording() {
        let speech = SpeechService.shared
        if speech.isListening {
            speech.stop()
            if !speech.transcript.isEmpty {
                inputText = speech.transcript
            }
            isRecording = false
        } else {
            isRecording = true
            Task {
                let granted = await speech.requestPermissions()
                guard granted else { isRecording = false; return }
                speech.start()
            }
        }
    }

    func clearChat() {
        messages = [
            ChatMessage(role: "assistant",
                        content: "Hi! I'm your AI Academic Tutor. Ask me to explain any concept, help with homework, or suggest a study strategy. What are you working on?")
        ]
        errorMessage = nil
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        // BUG FIX: guard against concurrent sends (e.g. suggestion chip tapped while loading)
        guard !text.isEmpty, !isLoading else { return }

        await sendMessage(text)
    }

    /// Retry the last failed message.
    func retry() async {
        guard let text = lastFailedText, !isLoading else { return }
        // Remove the error reply before retrying
        if let last = messages.last, last.role == "assistant",
           last.content.hasPrefix("Sorry, I couldn't connect") {
            messages.removeLast()
        }
        await sendMessage(text)
    }

    private func sendMessage(_ text: String) async {
        messages.append(ChatMessage(role: "user", content: text))
        inputText      = ""
        isLoading      = true
        errorMessage   = nil
        canRetry       = false
        lastFailedText = nil

        let history = messages.suffix(6).map { ["role": $0.role, "content": $0.content] }

        do {
            let reply = try await GroqService.shared.chat(
                system:      systemPrompt,
                history:     Array(history.dropLast()),   // exclude the latest user msg (already appended)
                userMessage: text,
                maxTokens:   450
            )
            messages.append(ChatMessage(role: "assistant", content: reply))
            canRetry       = false
            lastFailedText = nil
        } catch {
            let msg = (error as? GroqError)?.errorDescription ?? error.localizedDescription
            errorMessage = msg
            lastFailedText = text
            canRetry = true
            messages.append(ChatMessage(role: "assistant",
                                        content: "Sorry, I couldn't connect right now. Please check your internet connection and try again."))
        }
        isLoading = false

        // Cap message history to prevent unbounded memory growth
        if messages.count > maxMessages {
            let greeting = messages[0]
            messages = [greeting] + Array(messages.suffix(maxMessages - 1))
        }
    }
}
