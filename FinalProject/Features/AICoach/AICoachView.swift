import SwiftUI

struct AICoachView: View {
    @EnvironmentObject var store: StudyStore
    @StateObject private var vm = AICoachViewModel()
    @State private var scrollProxy: ScrollViewProxy? = nil

    var currentSubjectName: String? {
        store.subjects.first?.name
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                messageList
                inputBar
            }
            .background(StudyTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: StudySpacing.medium) {
            ZStack {
                Circle()
                    .fill(StudyTheme.accentGradient)
                    .frame(width: 44, height: 44)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Study Coach")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text("Powered by Llama 3 · Groq")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
            if vm.isLoading {
                ProgressView().tint(StudyTheme.accent)
            }
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, StudySpacing.medium)
        .background(StudyTheme.surface)
        .overlay(alignment: .bottom) {
            Divider().background(StudyTheme.surfaceStroke)
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: StudySpacing.small) {
                    ForEach(vm.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if vm.isLoading {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.vertical, StudySpacing.medium)
            }
            .onChange(of: vm.messages.count) { _ in
                withAnimation {
                    if let lastId = vm.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.isLoading) { loading in
                if loading {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: StudySpacing.small) {
            if msg.role == "user" { Spacer(minLength: 50) }

            if msg.role == "assistant" {
                ZStack {
                    Circle().fill(StudyTheme.accentGradient).frame(width: 28, height: 28)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .alignmentGuide(.bottom) { $0[.bottom] }
            }

            Text(msg.content)
                .font(StudyFont.body)
                .foregroundStyle(msg.role == "user" ? Color.black : StudyTheme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(msg.role == "user" ? StudyTheme.accent : StudyTheme.surface2)
                )
                .frame(maxWidth: 280, alignment: msg.role == "user" ? .trailing : .leading)

            if msg.role == "assistant" { Spacer(minLength: 50) }
        }
        .frame(maxWidth: .infinity, alignment: msg.role == "user" ? .trailing : .leading)
    }

    private var typingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(StudyTheme.secondaryText)
                    .frame(width: 8, height: 8)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudyTheme.surface2)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: StudySpacing.small) {
            TextField("Ask your coach...", text: $vm.inputText, axis: .vertical)
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.primaryText)
                .lineLimit(1...4)
                .padding(.horizontal, StudySpacing.medium)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(StudyTheme.surface2)
                )
                .onSubmit {
                    Task { await vm.send(currentSubjectName: currentSubjectName) }
                }

            Button {
                Task { await vm.send(currentSubjectName: currentSubjectName) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? StudyTheme.tertiaryText : StudyTheme.accent
                    )
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, StudySpacing.medium)
        .background(StudyTheme.surface)
        .overlay(alignment: .top) {
            Divider().background(StudyTheme.surfaceStroke)
        }
    }
}
