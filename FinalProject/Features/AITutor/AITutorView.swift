import SwiftUI

// Full implementation comes in Step 8.
// Stub is intentionally minimal — replaces AICoachView.

struct AITutorView: View {
    @EnvironmentObject var store: LearningStore
    @StateObject private var vm = AITutorViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tutorHeader
                messageList
                inputBar
            }
            .background(StudyTheme.background.ignoresSafeArea())
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
                LazyVStack(spacing: StudySpacing.small) {
                    if vm.messages.isEmpty { emptyState.padding(.top, StudySpacing.xxLarge) }
                    ForEach(vm.messages) { msg in
                        messageBubble(msg).id(msg.id)
                    }
                    if vm.isLoading {
                        TypingDotsView().id("typing").frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.vertical, StudySpacing.medium)
            }
            .onChange(of: vm.messages.count) { _ in
                withAnimation {
                    if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: vm.isLoading) { loading in
                if loading { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: StudySpacing.medium) {
            ZStack {
                Circle().fill(StudyTheme.accentSoft).frame(width: 64, height: 64)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(StudyTheme.accent)
            }
            Text("Your AI Academic Tutor")
                .font(StudyFont.cardTitle)
                .foregroundStyle(StudyTheme.primaryText)
            Text("Ask anything — concepts, homework,\nexam prep, or study strategies.")
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
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
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isUser
                              ? AnyShapeStyle(StudyTheme.accentGradient)
                              : AnyShapeStyle(StudyTheme.surface2))
                )
                .frame(maxWidth: 292, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 52) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: StudySpacing.small) {
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
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(StudyTheme.surface2))
        .onAppear { phase = true }
    }
}
