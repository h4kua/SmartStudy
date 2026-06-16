import SwiftUI

struct QuizView: View {
    @EnvironmentObject var store: LearningStore
    @StateObject private var vm = QuizViewModel()

    private var incompleteSessions: [QuizSession] {
        store.quizSessions.filter { !$0.isCompleted }
    }
    private var completedSessions: [QuizSession] {
        store.quizSessions.filter(\.isCompleted)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: StudySpacing.large) {
                newQuizButton
                if !incompleteSessions.isEmpty { incompleteSection }
                if !completedSessions.isEmpty  { completedSection  }
                if store.quizSessions.isEmpty  { emptyState        }
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, StudySpacing.xxLarge)
        }
        .sheet(isPresented: $vm.showGenerateSheet) { generateSheet }
        .fullScreenCover(isPresented: $vm.showSession) {
            QuizSessionView(vm: vm)
                .environmentObject(store)
        }
    }

    // MARK: - New quiz button

    private var newQuizButton: some View {
        Button { vm.showGenerateSheet = true } label: {
            HStack(spacing: StudySpacing.small) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("New Quiz")
                    .font(StudyFont.subtitle)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
        }
        .buttonStyle(PrimaryStudyButtonStyle())
    }

    // MARK: - Incomplete sessions

    private var incompleteSection: some View {
        StudyCard(title: "Continue") {
            VStack(spacing: StudySpacing.small) {
                ForEach(incompleteSessions.prefix(3)) { session in
                    Button { vm.startSession(session) } label: {
                        HStack(spacing: StudySpacing.medium) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(StudyTheme.warning.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "play.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(StudyTheme.warning)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(StudyFont.subtitle)
                                    .foregroundStyle(StudyTheme.primaryText)
                                    .lineLimit(1)
                                Text("\(session.totalQuestions) questions · \(session.difficulty.label)")
                                    .font(StudyFont.tiny)
                                    .foregroundStyle(StudyTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(StudyTheme.tertiaryText)
                        }
                    }
                    if session.id != incompleteSessions.prefix(3).last?.id {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - Completed sessions

    private var completedSection: some View {
        StudyCard(title: "Completed") {
            VStack(spacing: StudySpacing.small) {
                ForEach(completedSessions.prefix(10)) { session in
                    Button { vm.startSession(session) } label: {
                        HStack(spacing: StudySpacing.medium) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(session.gradeColor.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(session.gradeColor)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(StudyFont.subtitle)
                                    .foregroundStyle(StudyTheme.primaryText)
                                    .lineLimit(1)
                                Text("\(session.difficulty.label) · \(session.createdDate, style: .date)")
                                    .font(StudyFont.tiny)
                                    .foregroundStyle(StudyTheme.secondaryText)
                            }
                            Spacer()
                            Text(session.percentage.percentString)
                                .font(StudyFont.subtitle)
                                .foregroundStyle(session.gradeColor)
                        }
                    }
                    if session.id != completedSessions.prefix(10).last?.id {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        StudyCard {
            VStack(spacing: StudySpacing.medium) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(StudyTheme.tertiaryText)
                Text("No quizzes yet")
                    .font(StudyFont.cardTitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text("Tap \"New Quiz\" to generate a quiz on any topic, or analyze a document to create one automatically.")
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, StudySpacing.small)
        }
    }

    // MARK: - Generate sheet

    private var generateSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {

                    VStack(spacing: StudySpacing.small) {
                        ZStack {
                            Circle().fill(StudyTheme.accentSoft).frame(width: 60, height: 60)
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(StudyTheme.accent)
                        }
                        Text("New Quiz")
                            .font(StudyFont.cardTitle)
                            .foregroundStyle(StudyTheme.primaryText)
                        Text("Enter a topic and the AI will generate questions for you.")
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, StudySpacing.medium)

                    // Topic
                    sheetSection(label: "Topic") {
                        TextField("e.g. Newton's Laws of Motion", text: $vm.topic)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                            .padding(StudySpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(StudyTheme.surface2)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                            )
                    }

                    // Difficulty
                    sheetSection(label: "Difficulty") {
                        HStack(spacing: 2) {
                            ForEach(QuizQuestion.Difficulty.allCases, id: \.rawValue) { diff in
                                Button { vm.difficulty = diff } label: {
                                    Text(diff.label)
                                        .font(StudyFont.tiny)
                                        .foregroundStyle(vm.difficulty == diff ? .white : StudyTheme.secondaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            Group {
                                                if vm.difficulty == diff {
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(diff.color)
                                                }
                                            }
                                        )
                                }
                            }
                        }
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudyTheme.surface2))
                    }

                    // Question count
                    sheetSection(label: "Number of Questions") {
                        HStack(spacing: StudySpacing.small) {
                            ForEach([5, 10, 15], id: \.self) { count in
                                Button { vm.questionCount = count } label: {
                                    Text("\(count)")
                                        .font(StudyFont.subtitle)
                                        .foregroundStyle(vm.questionCount == count ? .white : StudyTheme.secondaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(vm.questionCount == count ? StudyTheme.accent : StudyTheme.surface2)
                                        )
                                }
                            }
                        }
                    }

                    if let err = vm.errorMessage {
                        HStack(spacing: StudySpacing.small) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(err).font(StudyFont.caption)
                        }
                        .foregroundStyle(StudyTheme.danger)
                        .padding(StudySpacing.medium)
                        .background(RoundedRectangle(cornerRadius: 12).fill(StudyTheme.danger.opacity(0.10)))
                    }

                    // Generate button
                    Button {
                        Task { await vm.generateQuiz(store: store) }
                    } label: {
                        Group {
                            if vm.isGenerating {
                                HStack(spacing: 8) { ProgressView().tint(.white); Text("Generating...") }
                            } else {
                                Text("Generate Quiz")
                            }
                        }
                        .font(StudyFont.subtitle)
                        .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(PrimaryStudyButtonStyle())
                    .disabled(vm.isGenerating || vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.showGenerateSheet = false }
                        .foregroundStyle(StudyTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func sheetSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: StudySpacing.small) {
            Text(label.uppercased())
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
                .tracking(0.8)
            content()
        }
    }
}
