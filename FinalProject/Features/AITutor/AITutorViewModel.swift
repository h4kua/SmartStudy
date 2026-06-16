import Foundation

@MainActor
final class AITutorViewModel: ObservableObject {
    @Published var messages:      [ChatMessage] = []
    @Published var inputText:     String        = ""
    @Published var isLoading:     Bool          = false
    @Published var errorMessage:  String?
    @Published var isRecording:   Bool          = false

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

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: "user", content: text))
        inputText  = ""
        isLoading  = true
        errorMessage = nil

        let history = messages.suffix(6).map { ["role": $0.role, "content": $0.content] }

        do {
            let reply = try await GroqService.shared.chat(
                system:      systemPrompt,
                history:     Array(history.dropLast()),   // exclude the latest user msg (already appended)
                userMessage: text,
                maxTokens:   450
            )
            messages.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            let msg = (error as? GroqError)?.errorDescription ?? error.localizedDescription
            errorMessage = msg
            messages.append(ChatMessage(role: "assistant",
                                        content: "Sorry, I couldn't connect right now. Please check your internet connection and try again."))
        }
        isLoading = false
    }
}
