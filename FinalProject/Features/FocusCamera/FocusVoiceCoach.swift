import AVFoundation

// MARK: - Focus Voice Coach

/// Speaks contextual coaching cues via AVSpeechSynthesizer.
/// Call-safe from any thread; all state is protected by a serial queue.
final class FocusVoiceCoach {

    // MARK: - Public

    var isEnabled: Bool = true

    /// BUG FIX: track stopped state so queued closures on the serial queue
    /// don't call speak() after stop() has been invoked.
    private var isStopped: Bool = false

    var isSpeaking: Bool { synthesizer.isSpeaking }

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private let queue       = DispatchQueue(label: "focus.voice.coach")

    /// Per-state cooldown to avoid repeating the same cue too often.
    private var lastSpokenAt: [String: TimeInterval] = [:]
    private let stateCooldown: TimeInterval = 20   // seconds between same-state repeats
    private let praiseCooldown: TimeInterval = 60  // don't over-praise

    // MARK: - Transition Feedback

    /// Call this when the attention state changes.
    func onTransition(to newState: AttentionState, from oldState: AttentionState) {
        guard isEnabled, newState != oldState else { return }

        switch newState {
        case .focused:
            // Only praise if they just came back from a bad state
            if oldState != .focused {
                speakIfCooled(key: "praise", cooldown: praiseCooldown) {
                    self.randomPhrases(for: .praise)
                }
            }
        case .drowsy:
            speakIfCooled(key: "drowsy", cooldown: stateCooldown) {
                self.randomPhrases(for: .drowsy)
            }
        case .distracted:
            speakIfCooled(key: "distracted", cooldown: stateCooldown) {
                self.randomPhrases(for: .distracted)
            }
        case .away:
            break  // Away reminders handled by periodicReminder
        }
    }

    /// Call every second from the timer tick for time-based reminders.
    func periodicReminder(state: AttentionState, awaySeconds: Int) {
        guard isEnabled else { return }

        switch state {
        case .away:
            if awaySeconds == 30 {
                speak(randomPhrases(for: .away30))
            } else if awaySeconds == 60 {
                speak(randomPhrases(for: .away60))
            } else if awaySeconds > 60 && awaySeconds % 60 == 0 {
                speak(randomPhrases(for: .awayLong))
            }

        case .drowsy:
            // Repeat drowsy cue every 30 s if still drowsy
            speakIfCooled(key: "drowsy.periodic", cooldown: 30) {
                self.randomPhrases(for: .drowsy)
            }

        default:
            break
        }
    }

    func stop() {
        isStopped = true
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Reset stopped flag — call when starting a new session.
    func reset() {
        isStopped = false
        lastSpokenAt.removeAll()
    }

    // MARK: - Private helpers

    private func speakIfCooled(key: String, cooldown: TimeInterval, phrase: @escaping () -> String) {
        queue.async { [weak self] in
            guard let self, !self.isStopped else { return }
            let now = CACurrentMediaTime()
            if let last = self.lastSpokenAt[key], now - last < cooldown { return }
            self.lastSpokenAt[key] = now
            let text = phrase()
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isStopped else { return }
                self.speak(text)
            }
        }
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .word)
        let utterance       = AVSpeechUtterance(string: text)
        utterance.voice     = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate      = 0.48
        utterance.pitchMultiplier = 1.05
        utterance.volume    = 0.95
        utterance.preUtteranceDelay = 0.2
        synthesizer.speak(utterance)
    }

    // MARK: - Phrase Banks

    private enum PhraseCategory {
        case praise, drowsy, distracted, away30, away60, awayLong
    }

    private func randomPhrases(for category: PhraseCategory) -> String {
        let bank: [String]
        switch category {

        case .praise:
            bank = [
                "Welcome back! Great focus.",
                "You're back in the zone. Keep it up!",
                "Nice work. Let's stay focused.",
                "That's the spirit — eyes on the goal!",
            ]

        case .drowsy:
            bank = [
                "Eyes getting heavy? Blink a few times and sit up straight.",
                "Drowsiness detected. Take a deep breath and refocus.",
                "You look a little tired. Roll your shoulders and keep going.",
                "Feeling sleepy? Sit upright and look at the screen.",
            ]

        case .distracted:
            bank = [
                "Hey — look back at the screen. You've got this!",
                "Stay with it. Eyes on your material.",
                "Come on, refocus. Your study session is still running.",
                "Head turning away? Bring it back and concentrate.",
            ]

        case .away30:
            bank = [
                "I can't see you. Come back to your desk.",
                "Your session is waiting — come back and keep studying.",
                "You've been away for 30 seconds. Ready to refocus?",
            ]

        case .away60:
            bank = [
                "You've been away for a minute. Time to get back to work!",
                "One minute away — come back and let's get focused again.",
            ]

        case .awayLong:
            bank = [
                "Still away? Your study timer is still running.",
                "Come back whenever you're ready — I'll be here.",
            ]
        }

        return bank.randomElement() ?? bank[0]
    }
}
