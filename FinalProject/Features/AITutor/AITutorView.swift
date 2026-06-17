import SwiftUI

struct AITutorView: View {
    @EnvironmentObject var store: LearningStore
    @StateObject private var vm = AITutorViewModel()
    @ObservedObject private var speech = SpeechService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tutorHeader
                messageList
                inputBar
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var tutorHeader: some View {
        HStack(spacing: StudySpacing.medium) {
            ZStack {
                Circle()
                    .fill(StudyTheme.accentGradient)
                    .frame(width: 42, height: 42)
                    .shadow(color: StudyTheme.accentGlow.opacity(0.3), radius: 8, x: 0, y: 2)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Academic Tutor")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                HStack(spacing: 5) {
                    Circle()
                        .fill(StudyTheme.success)
                        .frame(width: 6, height: 6)
                    Text("Llama 3 · Groq")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                }
            }
            Spacer()
            if vm.isLoading {
                ProgressView().tint(StudyTheme.accent).scaleEffect(0.8)
            }
            // Clear chat button
            if vm.messages.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        vm.clearChat()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(StudyTheme.tertiaryText)
                        .frame(width: 32, height: 32)
                        .background(StudyTheme.surface2.opacity(0.7))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, StudySpacing.medium)
        .background(
            StudyTheme.surface
                .overlay(alignment: .bottom) {
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                }
        )
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: StudySpacing.medium) {
                    if vm.messages.count <= 1 {
                        emptyState.padding(.top, StudySpacing.xxLarge)
                    }
                    ForEach(vm.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    if vm.isLoading {
                        TypingDotsView()
                            .id("typing")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.vertical, StudySpacing.medium)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.messages.count)
            }
            .onChange(of: vm.messages.count) { _ in
                withAnimation(.spring(response: 0.4)) {
                    if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: vm.isLoading) { loading in
                if loading { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: StudySpacing.large) {
            ZStack {
                Circle()
                    .fill(StudyTheme.accentSoft)
                    .frame(width: 72, height: 72)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(StudyTheme.accent)
            }
            VStack(spacing: StudySpacing.small) {
                Text("Your AI Academic Tutor")
                    .font(StudyFont.cardTitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text("Ask anything — concepts, homework,\nexam prep, or study strategies.")
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            // Suggestion chips
            VStack(spacing: StudySpacing.small) {
                suggestionChip("Explain quantum entanglement simply")
                suggestionChip("Help me study for my biology exam")
                suggestionChip("What's the best note-taking method?")
            }
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            vm.inputText = text
            Task { await vm.send() }
        } label: {
            HStack(spacing: StudySpacing.small) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudyTheme.accent)
                Text(text)
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(StudyTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: StudySpacing.small) {
                if isUser { Spacer(minLength: 52) }
                if !isUser {
                    ZStack {
                        Circle().fill(StudyTheme.accentGradient).frame(width: 26, height: 26)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    }
                    .alignmentGuide(.bottom) { $0[.bottom] }
                }
                Text(msg.content)
                    .font(StudyFont.body)
                    .foregroundStyle(isUser ? .white : StudyTheme.primaryText)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isUser
                                  ? AnyShapeStyle(StudyTheme.accentGradient)
                                  : AnyShapeStyle(StudyTheme.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(isUser ? Color.clear : StudyTheme.surfaceStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: isUser ? StudyTheme.accentGlow.opacity(0.25) : StudyTheme.shadow.opacity(0.15),
                            radius: isUser ? 10 : 6, x: 0, y: 4)
                    .frame(maxWidth: 292, alignment: isUser ? .trailing : .leading)
                if !isUser { Spacer(minLength: 52) }
            }
            // Timestamp
            Text(msg.date, style: .time)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(StudyTheme.tertiaryText)
                .padding(.horizontal, isUser ? 4 : 38)
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if speech.isListening {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                        .opacity(speech.isListening ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(), value: speech.isListening)
                    Text(speech.transcript.isEmpty ? "Listening..." : speech.transcript)
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.vertical, 8)
                .background(StudyTheme.surface2.opacity(0.9))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: StudySpacing.small) {
                Button { vm.toggleRecording() } label: {
                    Image(systemName: speech.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(speech.isListening ? Color.red : StudyTheme.secondaryText)
                        .scaleEffect(speech.isListening ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speech.isListening)
                }

                TextField("Ask your tutor...", text: $vm.inputText, axis: .vertical)
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.primaryText)
                    .lineLimit(1...4)
                    .padding(.horizontal, StudySpacing.medium)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(StudyTheme.surface2)
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                    )
                    .onSubmit { Task { await vm.send() } }

                let isEmpty = vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button { Task { await vm.send() } } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(isEmpty ? StudyTheme.tertiaryText : StudyTheme.accent)
                        .scaleEffect(isEmpty ? 1 : 1.05)
                        .animation(.easeOut(duration: 0.15), value: isEmpty)
                }
                .disabled(isEmpty || vm.isLoading)
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.vertical, StudySpacing.medium)
            .background(
                StudyTheme.surface
                    .overlay(alignment: .top) {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
            )
        }
        .animation(.easeInOut(duration: 0.2), value: speech.isListening)
        .onChange(of: speech.transcript) { newValue in
            if speech.isListening { vm.inputText = newValue }
        }
    }
}

// MARK: - Typing indicator

struct TypingDotsView: View {
    @State private var phase = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(StudyTheme.secondaryText)
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase ? 1 : 0.5)
                    .opacity(phase ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.14),
                               value: phase)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                )
        )
        .onAppear { phase = true }
    }
}
