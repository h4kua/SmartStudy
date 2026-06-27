import SwiftUI

// MARK: - Coach Mode

private enum CoachMode: String, CaseIterable {
    case dailyCoach       = "Daily Coach"
    case weeklyPlan       = "Weekly Plan"
    case performanceReview = "Performance Review"

    var icon: String {
        switch self {
        case .dailyCoach:        return "sparkles"
        case .weeklyPlan:        return "calendar.circle.fill"
        case .performanceReview: return "chart.bar.fill"
        }
    }

    var description: String {
        switch self {
        case .dailyCoach:        return "Today's personalised missions"
        case .weeklyPlan:        return "7-day personalised schedule"
        case .performanceReview: return "Quiz analysis + improvement tips"
        }
    }

    var buttonTitle: String {
        switch self {
        case .dailyCoach:        return "Get Today's Missions"
        case .weeklyPlan:        return "Generate Study Plan"
        case .performanceReview: return "Review My Performance"
        }
    }
}

// MARK: - StudyCoachView

struct StudyCoachView: View {
    @EnvironmentObject var store: LearningStore
    @ObservedObject private var crew = CrewAIService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: CoachMode = .dailyCoach
    @State private var studyGoal               = "Prepare for final exams"
    @State private var planText: String        = ""
    @State private var isGenerating            = false
    @State private var serverStatus: ServerStatus = .checking
    @State private var errorMessage: String?

    // Action sheet targets
    @State private var showQuizSheet      = false
    @State private var showFlashSheet     = false
    @State private var showExamSheet      = false
    @State private var pendingAction: DailyCoachAction?

    private enum ServerStatus { case checking, online, offline }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.large) {
                        headerSection.padding(.top, StudySpacing.small)
                        modeSelector

                        switch serverStatus {
                        case .checking:
                            checkingCard
                        case .offline:
                            offlineCard
                        case .online:
                            onlineContent
                        }

                        Spacer().frame(height: StudySpacing.xxLarge)
                    }
                    .padding(.horizontal, StudySpacing.large)
                }
                .animation(.easeInOut(duration: 0.3), value: serverStatus)
                .animation(.easeInOut(duration: 0.3), value: selectedMode)
            }
            .navigationTitle("AI Study Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StudyTheme.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if serverStatus == .online {
                        Button { Task { await checkServer() } } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundStyle(StudyTheme.secondaryText)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await checkServer() }
        // Quiz from daily coach action
        .sheet(isPresented: $showQuizSheet) {
            if let a = pendingAction {
                CoachQuizLaunchView(topic: a.topic, questionCount: a.questionCount ?? 5)
                    .environmentObject(store)
            }
        }
        // Flashcard from daily coach action
        .sheet(isPresented: $showFlashSheet) {
            if let a = pendingAction {
                CoachFlashcardLaunchView(topic: a.topic)
                    .environmentObject(store)
            }
        }
        // Exam from daily coach action
        .sheet(isPresented: $showExamSheet) {
            ExamSetupView(initialTopic: pendingAction?.topic ?? "")
                .environmentObject(store)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [StudyTheme.accent.opacity(0.25),
                                                   StudyTheme.accent.opacity(0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(StudyTheme.accent)
            }
            Text("Multi-Agent AI Coach")
                .font(StudyFont.subtitle)
                .foregroundStyle(StudyTheme.primaryText)
            HStack(spacing: 6) {
                agentBadge("Analyst")
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(StudyTheme.tertiaryText)
                agentBadge("Coach")
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(StudyTheme.tertiaryText)
                agentBadge("Planner")
            }
        }
    }

    private func agentBadge(_ name: String) -> some View {
        Text(name)
            .font(StudyFont.tiny)
            .foregroundStyle(StudyTheme.accent)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(StudyTheme.accent.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CoachMode.allCases, id: \.rawValue) { mode in
                    let isSelected = selectedMode == mode
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            selectedMode = mode
                            planText = ""
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                            Text(mode.rawValue)
                                .font(StudyFont.caption)
                                .fontWeight(.semibold)
                            Text(mode.description)
                                .font(StudyFont.tiny)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(isSelected ? .white : StudyTheme.secondaryText)
                        .frame(width: 130)
                        .padding(.vertical, StudySpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected
                                      ? AnyShapeStyle(StudyTheme.accentGradient)
                                      : AnyShapeStyle(StudyTheme.surface))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(isSelected ? Color.clear : StudyTheme.surfaceStroke, lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Online content (mode-dependent)

    @ViewBuilder
    private var onlineContent: some View {
        switch selectedMode {
        case .dailyCoach:
            dailyCoachContent
        case .weeklyPlan:
            weeklyPlanContent
        case .performanceReview:
            performanceContent
        }
    }

    // MARK: - Daily Coach Content

    @ViewBuilder
    private var dailyCoachContent: some View {
        // Context snapshot
        dataContextCard

        if let coach = store.cachedDailyCoach, !store.isDailyCoachStale {
            // Morning message
            if let msg = coach.morningMessage {
                morningMessageCard(msg)
            }
            // Action cards
            if let actions = coach.actions, !actions.isEmpty {
                VStack(spacing: StudySpacing.medium) {
                    HStack {
                        Text("TODAY'S MISSIONS")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .tracking(1.2)
                        Spacer()
                        Text("\(actions.count) tasks")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.tertiaryText)
                    }
                    ForEach(Array(actions.enumerated()), id: \.element.id) { i, action in
                        actionCard(action, index: i)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))

                // Refresh button
                Button { Task { await fetchDailyCoach() } } label: {
                    Label("Refresh missions", systemImage: "arrow.clockwise")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(StudyTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                // AI returned a response but with no actions — let user retry
                generateButton(title: "Retry Missions") {
                    Task { await fetchDailyCoach() }
                }
            }
        } else {
            // Not yet fetched
            generateButton(title: selectedMode.buttonTitle) {
                Task { await fetchDailyCoach() }
            }
        }

        if let err = errorMessage {
            errorBanner(err)
        }
    }

    private func morningMessageCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(StudyTheme.accent)
                .padding(.top, 1)
            Text(message)
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StudySpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudyTheme.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(StudyTheme.accent.opacity(0.2), lineWidth: 1))
    }

    private func actionCard(_ action: DailyCoachAction, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Numbered badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(action.actionColor.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: action.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(action.actionColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(StudyFont.subtitle)
                        .foregroundStyle(StudyTheme.primaryText)
                    Text(action.subject + (action.topic.isEmpty ? "" : " · \(action.topic)"))
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(action.estimatedTime)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(action.actionColor)
                    Text("START")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(action.actionColor.opacity(0.7))
                        .tracking(1)
                }
            }

            Text(action.reason)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                pendingAction = action
                switch action.type {
                case "quiz":      showQuizSheet  = true
                case "flashcard": showFlashSheet = true
                default:          showExamSheet  = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: action.iconName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Start \(action.title)")
                        .font(StudyFont.caption).fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(action.actionColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(StudySpacing.medium)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(action.actionColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: StudyTheme.shadow, radius: 6, y: 2)
    }

    // MARK: - Weekly Plan content

    @ViewBuilder
    private var weeklyPlanContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Study Goal")
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)
            TextField("e.g. Prepare for final exams", text: $studyGoal)
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.primaryText)
                .padding(StudySpacing.medium)
                .background(StudyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
        }
        dataContextCard
        generateButton(title: selectedMode.buttonTitle) {
            Task { await generateWeeklyPlan() }
        }
        if let err = errorMessage { errorBanner(err) }
        if !planText.isEmpty {
            resultCard(title: "Your 7-Day Study Plan", text: planText)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Performance Review content

    @ViewBuilder
    private var performanceContent: some View {
        dataContextCard
        generateButton(title: selectedMode.buttonTitle) {
            Task { await generatePerformanceReview() }
        }
        if let err = errorMessage { errorBanner(err) }
        if !planText.isEmpty {
            resultCard(title: "Performance Review", text: planText)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Shared Subviews

    private var dataContextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(StudyTheme.accent.opacity(0.7))
                Text("Context sent to AI agents")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            HStack(spacing: 0) {
                contextChip(icon: "books.vertical.fill", value: "\(store.subjects.count)",
                            label: "Subjects", color: StudyTheme.accent)
                contextDivider
                contextChip(icon: "checkmark.circle.fill", value: "\(store.quizSessions.count)",
                            label: "Quizzes", color: StudyTheme.success)
                contextDivider
                contextChip(icon: "rectangle.on.rectangle", value: "\(store.flashcardDecks.count)",
                            label: "Decks", color: StudyTheme.longBreakColor)
                contextDivider
                contextChip(icon: "flame.fill", value: "\(store.currentStreak)d",
                            label: "Streak", color: StudyTheme.warning)
            }
            .padding(StudySpacing.medium)
            .background(StudyTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func contextChip(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
            Text(value).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(StudyTheme.primaryText)
            Text(label).font(StudyFont.tiny).foregroundStyle(StudyTheme.tertiaryText)
        }.frame(maxWidth: .infinity)
    }

    private var contextDivider: some View {
        Rectangle().fill(StudyTheme.surfaceStroke).frame(width: 1, height: 36)
    }

    private func generateButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Agents working…").font(StudyFont.subtitle)
                } else {
                    Image(systemName: "sparkles")
                    Text(title).font(StudyFont.subtitle)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
        }
        .buttonStyle(PrimaryStudyButtonStyle())
        .disabled(isGenerating)
        .animation(.easeInOut(duration: 0.2), value: isGenerating)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(StudyTheme.danger)
            Text(message).font(StudyFont.caption).foregroundStyle(StudyTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StudySpacing.medium)
        .background(StudyTheme.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity)
    }

    private func resultCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(StudyTheme.success)
                Text(title).font(StudyFont.subtitle).foregroundStyle(StudyTheme.primaryText)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc.fill")
                        .font(StudyFont.tiny).foregroundStyle(StudyTheme.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(StudyTheme.accent.opacity(0.12)).clipShape(Capsule())
                }
            }
            Divider().background(StudyTheme.surfaceStroke)
            Text(text).font(StudyFont.caption).foregroundStyle(StudyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(4)
        }
        .padding(StudySpacing.large)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(StudyTheme.success.opacity(0.3), lineWidth: 1))
        .shadow(color: StudyTheme.shadow, radius: 8, y: 3)
    }

    // MARK: - Server status cards

    private var checkingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(StudyTheme.accent)
            Text("Connecting to CrewAI server…").font(StudyFont.caption).foregroundStyle(StudyTheme.secondaryText)
            Spacer()
        }
        .padding(StudySpacing.medium)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash").foregroundStyle(StudyTheme.danger)
                Text("CrewAI Server Not Running")
                    .font(StudyFont.body).fontWeight(.semibold).foregroundStyle(StudyTheme.primaryText)
                Spacer()
                Button { Task { await checkServer() } } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20)).foregroundStyle(StudyTheme.accent)
                }
            }
            Text("Start the Python backend, then tap ↺ to retry:")
                .font(StudyFont.caption).foregroundStyle(StudyTheme.secondaryText)
            VStack(alignment: .leading, spacing: 6) {
                codeSnippet("cd FinalProject/crew_backend")
                codeSnippet("cp .env.example .env   # add your GROQ_API_KEY")
                codeSnippet(".venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000")
            }
            Text("Mac & iPhone must be on the same WiFi network.")
                .font(StudyFont.tiny).foregroundStyle(StudyTheme.tertiaryText)
        }
        .padding(StudySpacing.medium)
        .background(StudyTheme.danger.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(StudyTheme.danger.opacity(0.3), lineWidth: 1))
    }

    private func codeSnippet(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(StudyTheme.accent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudyTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // MARK: - Actions

    private func checkServer() async {
        serverStatus = .checking
        let running = await crew.isServerRunning()
        withAnimation { serverStatus = running ? .online : .offline }
    }

    private func fetchDailyCoach() async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        do {
            let response = try await crew.getDailyCoach(store: store)
            withAnimation(.spring(response: 0.5)) {
                store.storeDailyCoach(response)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        withAnimation(.spring(response: 0.5)) { isGenerating = false }
    }

    private func generateWeeklyPlan() async {
        guard !isGenerating else { return }
        isGenerating = true; planText = ""; errorMessage = nil
        do {
            planText = try await crew.generateWeeklyPlan(store: store, studyGoal: studyGoal)
        } catch {
            errorMessage = error.localizedDescription
        }
        withAnimation(.spring(response: 0.5)) { isGenerating = false }
    }

    private func generatePerformanceReview() async {
        guard !isGenerating else { return }
        isGenerating = true; planText = ""; errorMessage = nil
        do {
            if store.quizSessions.isEmpty {
                planText = "Complete a few quizzes first — then come back for a detailed performance review!"
            } else {
                planText = try await crew.getPerformanceReview(store: store)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        withAnimation(.spring(response: 0.5)) { isGenerating = false }
    }
}

// MARK: - CoachQuizLaunchView

struct CoachQuizLaunchView: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = QuizViewModel()

    let topic: String
    let questionCount: Int

    /// Finds the first StudyNote whose title or content relates to the given topic.
    private func matchingNote() -> StudyNote? {
        let lowerTopic = topic.lowercased()
        return store.studyNotes.first {
            $0.title.lowercased().contains(lowerTopic) ||
            lowerTopic.contains($0.title.lowercased()) ||
            $0.content.lowercased().contains(lowerTopic)
        } ?? store.studyNotes.first  // fallback: use any note if no topic match
    }

    private var sourceNote: StudyNote? { matchingNote() }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()
                if vm.showSession {
                    QuizSessionView(vm: vm)
                        .environmentObject(store)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity))
                } else {
                    VStack(spacing: StudySpacing.large) {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 52, weight: .semibold))
                                .foregroundStyle(StudyTheme.accent)
                            Text("AI-Recommended Quiz")
                                .font(StudyFont.cardTitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            Text("Topic: \(topic)")
                                .font(StudyFont.body)
                                .foregroundStyle(StudyTheme.secondaryText)

                            // Show which note is being used as source
                            if let note = sourceNote {
                                HStack(spacing: 6) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(StudyTheme.success)
                                    Text("From your note: \"\(note.title)\"")
                                        .font(StudyFont.tiny)
                                        .foregroundStyle(StudyTheme.success)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(StudyTheme.success.opacity(0.1))
                                .clipShape(Capsule())
                            } else {
                                Text("\(questionCount) questions · General knowledge")
                                    .font(StudyFont.caption)
                                    .foregroundStyle(StudyTheme.tertiaryText)
                            }
                        }
                        Spacer()
                        if let err = vm.errorMessage {
                            Text(err).font(StudyFont.caption).foregroundStyle(StudyTheme.danger)
                                .multilineTextAlignment(.center).padding(.horizontal)
                        }
                        Button {
                            let noteContent = sourceNote?.content
                            Task {
                                vm.topic = topic
                                vm.questionCount = questionCount
                                // Generate quiz from note content if available
                                await vm.generateQuizFromContent(
                                    topic: topic,
                                    count: questionCount,
                                    context: noteContent,
                                    store: store
                                )
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isGenerating {
                                    ProgressView().tint(.white).scaleEffect(0.85)
                                    Text("Generating…").font(StudyFont.subtitle)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text(sourceNote != nil ? "Quiz from My Notes" : "Start Quiz")
                                        .font(StudyFont.subtitle)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                        }
                        .buttonStyle(PrimaryStudyButtonStyle())
                        .disabled(vm.isGenerating)
                        .padding(.horizontal, StudySpacing.large)
                        .padding(.bottom, StudySpacing.xxLarge)
                    }
                }
            }
            .animation(.spring(response: 0.4), value: vm.showSession)
            .navigationTitle("Mission: Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }.foregroundStyle(StudyTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - CoachFlashcardLaunchView

struct CoachFlashcardLaunchView: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = FlashcardsViewModel()

    let topic: String

    private var matchingDeck: FlashcardDeck? {
        store.flashcardDecks.first {
            $0.title.localizedCaseInsensitiveContains(topic) ||
            topic.localizedCaseInsensitiveContains($0.title)
        } ?? store.flashcardDecks.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()
                if vm.showReview {
                    FlashcardReviewView(vm: vm)
                        .environmentObject(store)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity))
                } else {
                    VStack(spacing: StudySpacing.large) {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "rectangle.on.rectangle.fill")
                                .font(.system(size: 52, weight: .semibold))
                                .foregroundStyle(StudyTheme.longBreakColor)
                            Text("AI-Recommended Flashcards")
                                .font(StudyFont.cardTitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            if let deck = matchingDeck {
                                Text("Deck: \(deck.title)")
                                    .font(StudyFont.body)
                                    .foregroundStyle(StudyTheme.secondaryText)
                                Text("\(deck.totalCards) cards · \(vm.dueCount(for: deck)) due today")
                                    .font(StudyFont.caption)
                                    .foregroundStyle(StudyTheme.tertiaryText)
                            } else {
                                Text("Topic: \(topic)")
                                    .font(StudyFont.body).foregroundStyle(StudyTheme.secondaryText)
                                Text("No matching deck found — create one in Flashcards.")
                                    .font(StudyFont.caption).foregroundStyle(StudyTheme.tertiaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        Spacer()
                        if let deck = matchingDeck {
                            Button { vm.startReview(deck: deck) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Start Review").font(StudyFont.subtitle)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 52)
                            }
                            .buttonStyle(PrimaryStudyButtonStyle())
                            .padding(.horizontal, StudySpacing.large)
                        } else {
                            Button { dismiss() } label: {
                                Text("Go to Flashcards").font(StudyFont.subtitle)
                                    .frame(maxWidth: .infinity).frame(height: 52)
                            }
                            .buttonStyle(GhostStudyButtonStyle())
                            .padding(.horizontal, StudySpacing.large)
                        }
                        Spacer().frame(height: StudySpacing.xxLarge)
                    }
                }
            }
            .animation(.spring(response: 0.4), value: vm.showReview)
            .navigationTitle("Mission: Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }.foregroundStyle(StudyTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
