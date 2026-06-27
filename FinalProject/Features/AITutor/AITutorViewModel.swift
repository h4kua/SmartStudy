import Foundation
import UIKit

@MainActor
final class AITutorViewModel: ObservableObject {
    @Published var messages:      [ChatMessage] = []
    @Published var inputText:     String        = ""
    @Published var isLoading:     Bool          = false
    @Published var errorMessage:  String?
    @Published var isRecording:   Bool          = false
    @Published var canRetry:      Bool          = false

    // Equation Photo Solver
    @Published var showEquationMenu:   Bool = false
    @Published var showEquationPicker: Bool = false
    @Published var equationSourceType: UIImagePickerController.SourceType = .photoLibrary
    @Published var isSolvingEquation:  Bool = false

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

    // MARK: - Equation Photo Solver

    /// Scan an equation photo with Vision OCR → send to Groq for step-by-step solution.
    func solveEquation(from image: UIImage) async {
        isSolvingEquation = true

        do {
            let scannedText = try await NoteScannerService.recognizeText(from: image)

            // Show user what was extracted so they can verify
            let preview = scannedText.count > 250
                ? String(scannedText.prefix(250)) + "…"
                : scannedText
            messages.append(ChatMessage(
                role: "user",
                content: "Solve this (scanned from photo):\n\(preview)"
            ))

            // Send an OCR-aware solving prompt directly to Groq
            await sendEquationToGroq(scannedText)
        } catch {
            let errMsg = (error as? NoteScannerService.ScanError)?.errorDescription
                         ?? error.localizedDescription
            messages.append(ChatMessage(
                role: "assistant",
                content: "Could not read the photo clearly: \(errMsg)\n\nTips: use good lighting, hold the camera steady, and make sure the equation fills most of the frame."
            ))
        }

        isSolvingEquation = false
    }

    /// Sends the OCR text to Groq with context about potential OCR errors.
    /// Does NOT append a user bubble — the caller already did that.
    private func sendEquationToGroq(_ scannedText: String) async {
        isLoading    = true
        errorMessage = nil
        canRetry     = false

        let prompt = """
        The following text was extracted via OCR from a handwritten or printed math problem. \
        OCR commonly misreads math symbols:
        - Superscripts flatten: x² → x2, n³ → n3
        - Multiplication: × → x or X, · → .
        - Division/fractions: ÷ → +, ½ → 1/2 or "1 2"
        - Square roots: √ may disappear or become V
        - Equals: = may become -, ≠ may become =
        - Greek letters: θ → 0, π → n or TT
        - Negative signs: −3 → 3 (sign dropped)

        Please:
        1. Identify and correct any OCR errors — show the corrected expression clearly.
        2. Solve step-by-step with numbered steps. Show ALL working — do not skip algebra.
        3. Verify your final answer by substituting back or checking units.

        OCR-extracted text:
        \(scannedText)
        """

        do {
            let reply = try await GroqService.shared.chat(
                system:      systemPrompt,
                history:     [],
                userMessage: prompt,
                maxTokens:   700
            )
            messages.append(ChatMessage(role: "assistant", content: reply))
            canRetry       = false
            lastFailedText = nil
        } catch {
            let msg = (error as? GroqError)?.errorDescription ?? error.localizedDescription
            errorMessage = msg
            canRetry     = true
            lastFailedText = prompt
            messages.append(ChatMessage(role: "assistant",
                content: "Could not reach the AI right now. Check your connection and tap Retry."))
        }
        isLoading = false
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
           (last.content.hasPrefix("Sorry, I couldn't connect") ||
            last.content.hasPrefix("Could not reach the AI")) {
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
