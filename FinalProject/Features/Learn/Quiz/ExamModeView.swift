import SwiftUI

// MARK: - Exam Setup Sheet

struct ExamSetupView: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ExamModeViewModel()
    @State private var showExam = false
    @State private var examSource: ExamSource = .topic
    @State private var selectedDoc: AnalyzedDocument? = nil

    enum ExamSource { case topic, document }

    /// Pre-fills the topic field when launched from an AI coach action.
    var initialTopic: String = ""

    init(initialTopic: String = "") {
        self.initialTopic = initialTopic
    }

    private var canStart: Bool {
        switch examSource {
        case .topic:    return !vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .document: return selectedDoc != nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.large) {
                        // Icon header
                        VStack(spacing: StudySpacing.small) {
                            ZStack {
                                Circle()
                                    .fill(StudyTheme.danger.opacity(0.15))
                                    .frame(width: 70, height: 70)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(StudyTheme.danger)
                            }
                            Text("Exam Mode")
                                .font(StudyFont.cardTitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            Text("Locked, timed, real-exam experience.\nNo hints. No going back on answered questions.")
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, StudySpacing.medium)

                        // Source picker
                        HStack(spacing: 0) {
                            ForEach([ExamSource.topic, .document], id: \.self) { src in
                                let selected = examSource == src
                                Button { withAnimation(.spring(response: 0.3)) { examSource = src } } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: src == .topic ? "text.cursor" : "doc.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(src == .topic ? "Type Topic" : "From Document")
                                            .font(StudyFont.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(selected ? .white : StudyTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selected ? StudyTheme.danger : .clear)
                                    )
                                }
                            }
                        }
                        .padding(4)
                        .background(StudyTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Topic input OR document picker
                        if examSource == .topic {
                            VStack(alignment: .leading, spacing: StudySpacing.small) {
                                Text("Topic")
                                    .font(StudyFont.caption)
                                    .foregroundStyle(StudyTheme.secondaryText)
                                TextField("e.g. World War 2, Calculus, Photosynthesis…", text: $vm.topic)
                                    .padding(12)
                                    .background(StudyTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .foregroundStyle(StudyTheme.primaryText)
                                    .font(StudyFont.body)
                            }
                        } else {
                            documentPickerSection
                        }

                        // Difficulty
                        VStack(alignment: .leading, spacing: StudySpacing.small) {
                            Text("Difficulty")
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                            HStack(spacing: StudySpacing.small) {
                                ForEach(QuizQuestion.Difficulty.allCases, id: \.self) { d in
                                    Button { vm.difficulty = d } label: {
                                        Text(d.label)
                                            .font(StudyFont.caption)
                                            .foregroundStyle(vm.difficulty == d ? .white : StudyTheme.secondaryText)
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(vm.difficulty == d ? d.color : StudyTheme.surface)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        // Time limit
                        VStack(alignment: .leading, spacing: StudySpacing.small) {
                            HStack {
                                Text("Time Limit")
                                    .font(StudyFont.caption)
                                    .foregroundStyle(StudyTheme.secondaryText)
                                Spacer()
                                Text("\(vm.timeLimitMinutes) min")
                                    .font(StudyFont.subtitle)
                                    .foregroundStyle(StudyTheme.accent)
                            }
                            Slider(value: Binding(
                                get:  { Double(vm.timeLimitMinutes) },
                                set:  { vm.timeLimitMinutes = Int($0) }
                            ), in: 5...60, step: 5)
                            .tint(StudyTheme.accent)
                        }

                        // Question count
                        VStack(alignment: .leading, spacing: StudySpacing.small) {
                            HStack {
                                Text("Questions")
                                    .font(StudyFont.caption)
                                    .foregroundStyle(StudyTheme.secondaryText)
                                Spacer()
                                Text("\(vm.questionCount)")
                                    .font(StudyFont.subtitle)
                                    .foregroundStyle(StudyTheme.accent)
                            }
                            Slider(value: Binding(
                                get:  { Double(vm.questionCount) },
                                set:  { vm.questionCount = Int($0) }
                            ), in: 5...20, step: 5)
                            .tint(StudyTheme.accent)
                        }

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.danger)
                                .multilineTextAlignment(.center)
                        }

                        // Warning notice
                        HStack(spacing: StudySpacing.small) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(StudyTheme.warning)
                            Text("Once started, you cannot leave the exam until it's submitted or time runs out.")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(StudySpacing.medium)
                        .background(StudyTheme.warning.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        // Start button
                        Button {
                            Task {
                                if examSource == .document, let doc = selectedDoc {
                                    vm.topic = doc.title
                                    vm.documentContext = doc.originalText.isEmpty ? nil : doc.originalText
                                } else {
                                    vm.documentContext = nil
                                }
                                await vm.generateExam(store: store)
                                if vm.activeExam != nil { showExam = true }
                            }
                        } label: {
                            if vm.isGenerating {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Generating…")
                                }
                                .font(StudyFont.subtitle)
                                .frame(maxWidth: .infinity).frame(height: 52)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                    Text("Start Exam")
                                        .font(StudyFont.subtitle)
                                }
                                .frame(maxWidth: .infinity).frame(height: 52)
                            }
                        }
                        .buttonStyle(DangerStudyButtonStyle())
                        .disabled(vm.isGenerating || !canStart)
                    }
                    .padding(.horizontal, StudySpacing.large)
                    .padding(.bottom, StudySpacing.xxLarge)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(StudyTheme.accent)
                }
            }
            .onAppear {
                if !initialTopic.isEmpty { vm.topic = initialTopic }
            }
            .fullScreenCover(isPresented: $showExam, onDismiss: {
                vm.cleanup()
                if vm.examComplete { dismiss() }
            }) {
                if let exam = vm.activeExam {
                    ExamSessionView(vm: vm, initialExam: exam)
                        .environmentObject(store)
                }
            }
        }
    }

    // MARK: - Document picker section

    @ViewBuilder
    private var documentPickerSection: some View {
        VStack(alignment: .leading, spacing: StudySpacing.medium) {
            Text("Select Document")
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)

            if store.analyzedDocuments.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .foregroundStyle(StudyTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No analyzed documents yet")
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.primaryText)
                        Text("Go to Documents tab, scan or paste content, then tap Analyze.")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                    }
                }
                .padding(StudySpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudyTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(store.analyzedDocuments) { doc in
                        let isSelected = selectedDoc?.id == doc.id
                        Button { withAnimation { selectedDoc = doc } } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(isSelected ? StudyTheme.danger : StudyTheme.secondaryText)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.title)
                                        .font(StudyFont.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(StudyTheme.primaryText)
                                    Text("\(doc.wordCount) words · \(doc.keyConcepts.prefix(2).joined(separator: ", "))")
                                        .font(StudyFont.tiny)
                                        .foregroundStyle(StudyTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(StudyTheme.danger)
                                        .font(.system(size: 18))
                                }
                            }
                            .padding(StudySpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? StudyTheme.danger.opacity(0.08) : StudyTheme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? StudyTheme.danger.opacity(0.5) : StudyTheme.surfaceStroke, lineWidth: 1.5)
                                    )
                            )
                        }
                    }
                }

                if let doc = selectedDoc {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(StudyTheme.accent)
                        Text("Exam questions will be generated from \"\(doc.title)\"")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
}

// MARK: - Active Exam Session View

struct ExamSessionView: View {
    @EnvironmentObject var store: LearningStore
    @ObservedObject var vm: ExamModeViewModel
    @Environment(\.scenePhase) private var scenePhase
    let initialExam: ExamSession

    var body: some View {
        ZStack {
            StudyTheme.backgroundGradient.ignoresSafeArea()

            if vm.examComplete {
                examResultsView
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            } else {
                VStack(spacing: 0) {
                    examHeader
                    questionBody
                    navigationFooter
                }
                .transition(.opacity)
            }

            // Anti-cheat warning banner
            if vm.showWarningBanner {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                            .foregroundStyle(.white)
                        Text("Warning \(vm.antiCheatWarnings): Stay focused on the exam!")
                            .font(StudyFont.caption)
                            .foregroundStyle(.white)
                    }
                    .padding(StudySpacing.medium)
                    .frame(maxWidth: .infinity)
                    .background(StudyTheme.danger)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.35), value: vm.showWarningBanner)
            }
        }
        .onChange(of: vm.timeRemaining) { t in
            if t == 0 { vm.submitExam(store: store) }
        }
        .onChange(of: scenePhase) { phase in
            // Anti-cheat: only fire on .background, not .inactive.
            // iOS transitions .active → .inactive → .background on app switch,
            // so checking both would log two warnings for one event.
            guard !vm.examComplete, phase == .background else { return }
            vm.logAntiCheatWarning(store: store)
        }
        .onDisappear { vm.cleanup() }
        .interactiveDismissDisabled(true)  // cannot swipe away during exam
    }

    // MARK: Header

    private var examHeader: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(initialExam.title)
                        .font(StudyFont.subtitle)
                        .foregroundStyle(StudyTheme.primaryText)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("Q \(vm.currentIndex + 1)/\(vm.totalQuestions)")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                        if vm.antiCheatWarnings > 0 {
                            Label("\(vm.antiCheatWarnings) warning\(vm.antiCheatWarnings > 1 ? "s" : "")",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.warning)
                        }
                    }
                }
                Spacer()
                // Countdown clock
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(vm.timeRemainingString)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(vm.isLowTime ? StudyTheme.danger : StudyTheme.primaryText)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(vm.isLowTime ? StudyTheme.danger.opacity(0.12) : StudyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(.default, value: vm.isLowTime)
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.top, StudySpacing.large)
            .padding(.bottom, StudySpacing.small)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 3)
                    Rectangle()
                        .fill(vm.isLowTime ? StudyTheme.danger : StudyTheme.accent)
                        .frame(width: geo.size.width * vm.progress, height: 3)
                        .animation(.linear(duration: 1), value: vm.timeRemaining)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: Question body

    private var questionBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                if let q = vm.currentQuestion {
                    Text(q.question)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(StudyTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, StudySpacing.medium)

                    VStack(spacing: StudySpacing.small) {
                        let answered = vm.activeExam?.userAnswers[vm.currentIndex] ?? -1
                        ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                            Button { vm.selectAnswer(idx, store: store) } label: {
                                HStack(spacing: StudySpacing.medium) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(answered == idx ? StudyTheme.accent : StudyTheme.surfaceStroke, lineWidth: 2)
                                            .frame(width: 28, height: 28)
                                        if answered == idx {
                                            Circle().fill(StudyTheme.accent).frame(width: 14, height: 14)
                                        }
                                    }
                                    Text(opt)
                                        .font(StudyFont.body)
                                        .foregroundStyle(StudyTheme.primaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(StudySpacing.medium)
                                .background(
                                    answered == idx
                                    ? StudyTheme.accentSoft
                                    : StudyTheme.surface
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(answered == idx ? StudyTheme.accent : .clear, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, 100)
        }
    }

    // MARK: Navigation footer

    private var navigationFooter: some View {
        VStack(spacing: 0) {
            Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
            HStack(spacing: StudySpacing.medium) {
                Button {
                    withAnimation { vm.previousQuestion() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(vm.currentIndex > 0 ? StudyTheme.accent : StudyTheme.tertiaryText)
                        .frame(width: 44, height: 44)
                        .background(StudyTheme.surface)
                        .clipShape(Circle())
                }
                .disabled(vm.currentIndex == 0)

                Spacer()

                // Question dots
                questionDots

                Spacer()

                if vm.currentIndex == vm.totalQuestions - 1 {
                    Button {
                        vm.submitExam(store: store)
                    } label: {
                        Text("Submit")
                            .font(StudyFont.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(StudyTheme.danger)
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        withAnimation { vm.nextQuestion() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(StudyTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(StudyTheme.surface)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.vertical, StudySpacing.medium)
            .background(StudyTheme.backgroundGradient)
        }
    }

    private var questionDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(vm.totalQuestions, 15), id: \.self) { i in
                let answered = (vm.activeExam?.userAnswers[i] ?? -1) >= 0
                Circle()
                    .fill(i == vm.currentIndex
                          ? StudyTheme.accent
                          : (answered ? StudyTheme.success : StudyTheme.surfaceStroke))
                    .frame(width: i == vm.currentIndex ? 8 : 6,
                           height: i == vm.currentIndex ? 8 : 6)
                    .animation(.spring(response: 0.25), value: vm.currentIndex)
            }
        }
    }

    // MARK: Results view

    private var examResultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: StudySpacing.large) {
                // Grade circle
                VStack(spacing: StudySpacing.small) {
                    ZStack {
                        Circle()
                            .stroke(StudyTheme.surfaceStroke, lineWidth: 10)
                            .frame(width: 130, height: 130)
                        Circle()
                            .trim(from: 0, to: vm.activeExam.map { CGFloat($0.percentage) } ?? 0)
                            .stroke(vm.activeExam?.gradeColor ?? StudyTheme.accent,
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.8), value: vm.examComplete)
                        VStack(spacing: 2) {
                            Text(vm.activeExam.map { "\($0.score)/\($0.totalQuestions)" } ?? "–")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(StudyTheme.primaryText)
                            Text(vm.activeExam?.gradeLabel ?? "")
                                .font(StudyFont.tiny)
                                .foregroundStyle(vm.activeExam?.gradeColor ?? StudyTheme.accent)
                        }
                    }

                    Text("Exam Complete")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(StudyTheme.primaryText)
                }
                .padding(.top, StudySpacing.xxLarge)

                // Stats row
                if let exam = vm.activeExam {
                    HStack(spacing: StudySpacing.medium) {
                        statPill(icon: "clock", label: "Time Used", value: exam.timeUsedString)
                        statPill(icon: "eye.slash", label: "Warnings", value: "\(exam.antiCheatWarnings)")
                        statPill(icon: "percent", label: "Score", value: exam.percentage.percentString)
                    }
                }

                // AI Debrief
                VStack(alignment: .leading, spacing: StudySpacing.small) {
                    HStack {
                        Label("AI Debrief", systemImage: "brain")
                            .font(StudyFont.cardTitle)
                            .foregroundStyle(StudyTheme.primaryText)
                        Spacer()
                    }
                    if isLoadingDebrief {
                        HStack(spacing: 8) {
                            ProgressView().tint(StudyTheme.accent)
                            Text("Analysing your results…")
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                        }
                        .padding(StudySpacing.medium)
                        .frame(maxWidth: .infinity)
                        .background(StudyTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if let debrief = vm.debriefText {
                        Text(debrief)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .padding(StudySpacing.medium)
                            .background(StudyTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Button {
                            Task { await vm.loadDebrief(store: store) }
                        } label: {
                            Label("Generate AI Debrief", systemImage: "brain")
                                .font(StudyFont.caption)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(StudyTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(StudySpacing.medium)
                .background(StudyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Close button
                Button("Done") {
                    vm.cleanup()
                }
                .buttonStyle(PrimaryStudyButtonStyle())
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, StudySpacing.xxLarge)
        }
        .task {
            guard vm.examComplete else { return }
            await vm.loadDebrief(store: store)
        }
    }

    private var isLoadingDebrief: Bool { vm.isLoadingDebrief }

    private func statPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(StudyTheme.accent)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(StudySpacing.medium)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Danger button style

struct DangerStudyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StudyFont.subtitle)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? StudyTheme.danger : StudyTheme.danger.opacity(0.4))
                    .shadow(color: StudyTheme.danger.opacity(configuration.isPressed ? 0.1 : 0.3),
                            radius: 12, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}
