import SwiftUI

// MARK: - Coach Mode

private enum CoachMode: String, CaseIterable {
    case weeklyPlan        = "Weekly Plan"
    case performanceReview = "Performance Review"

    var icon: String {
        switch self {
        case .weeklyPlan:        return "calendar.circle.fill"
        case .performanceReview: return "chart.bar.fill"
        }
    }

    var description: String {
        switch self {
        case .weeklyPlan:        return "7-day personalised study schedule"
        case .performanceReview: return "Quiz analysis + improvement tips"
        }
    }

    var buttonTitle: String {
        switch self {
        case .weeklyPlan:        return "Generate Study Plan"
        case .performanceReview: return "Review My Performance"
        }
    }

    var resultTitle: String {
        switch self {
        case .weeklyPlan:        return "Your 7-Day Study Plan"
        case .performanceReview: return "Performance Review"
        }
    }
}

// MARK: - StudyCoachView

struct StudyCoachView: View {
    @EnvironmentObject var store: LearningStore
    @StateObject private var crew = CrewAIService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: CoachMode = .weeklyPlan
    @State private var studyGoal = "Prepare for final exams"
    @State private var result: String = ""
    @State private var isGenerating = false
    @State private var serverStatus: ServerStatus = .checking
    @State private var errorMessage: String?

    private enum ServerStatus { case checking, online, offline }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.large) {
                        headerSection
                            .padding(.top, StudySpacing.small)

                        modeSelector

                        switch serverStatus {
                        case .checking:
                            checkingCard
                        case .offline:
                            offlineCard
                        case .online:
                            inputSection
                            generateButton
                            if let err = errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(StudyTheme.danger)
                                    Text(err)
                                        .font(StudyFont.caption)
                                        .foregroundStyle(StudyTheme.danger)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(StudySpacing.medium)
                                .background(StudyTheme.danger.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .transition(.opacity)
                            }
                            if !result.isEmpty {
                                resultCard
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }

                        Spacer().frame(height: StudySpacing.xxLarge)
                    }
                    .padding(.horizontal, StudySpacing.large)
                }
                .animation(.easeInOut(duration: 0.3), value: result.isEmpty)
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
                        Button {
                            Task { await checkServer() }
                        } label: {
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [StudyTheme.accent.opacity(0.25), StudyTheme.accent.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
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
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(StudyTheme.accent.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 10) {
            ForEach(CoachMode.allCases, id: \.rawValue) { mode in
                let isSelected = selectedMode == mode
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        selectedMode = mode
                        result = ""
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 22))
                        Text(mode.rawValue)
                            .font(StudyFont.caption)
                            .fontWeight(.semibold)
                        Text(mode.description)
                            .font(StudyFont.tiny)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(isSelected ? .white : StudyTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StudySpacing.medium)
                    .padding(.horizontal, 8)
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

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {
        if selectedMode == .weeklyPlan {
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
        }
        dataContextCard
    }

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
                contextChip(icon: "books.vertical.fill",
                            value: "\(store.subjects.count)",
                            label: "Subjects",
                            color: StudyTheme.accent)
                contextDivider
                contextChip(icon: "checkmark.circle.fill",
                            value: "\(store.quizSessions.count)",
                            label: "Quizzes",
                            color: StudyTheme.success)
                contextDivider
                contextChip(icon: "flame.fill",
                            value: "\(store.currentStreak)d",
                            label: "Streak",
                            color: StudyTheme.warning)
                contextDivider
                contextChip(icon: "timer",
                            value: "\(store.totalStudyMinutes)m",
                            label: "Studied",
                            color: StudyTheme.shortBreakColor)
            }
            .padding(StudySpacing.medium)
            .background(StudyTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func contextChip(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var contextDivider: some View {
        Rectangle()
            .fill(StudyTheme.surfaceStroke)
            .frame(width: 1, height: 36)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Agents working…")
                        .font(StudyFont.subtitle)
                } else {
                    Image(systemName: "sparkles")
                    Text(selectedMode.buttonTitle)
                        .font(StudyFont.subtitle)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(PrimaryStudyButtonStyle())
        .disabled(isGenerating)
        .animation(.easeInOut(duration: 0.2), value: isGenerating)
    }

    // MARK: - Result Card

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(StudyTheme.success)
                Text(selectedMode.resultTitle)
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Spacer()
                Button {
                    UIPasteboard.general.string = result
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc.fill")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(StudyTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Divider()
                .background(StudyTheme.surfaceStroke)

            Text(result)
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(StudySpacing.large)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(StudyTheme.success.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: StudyTheme.shadow, radius: 8, y: 3)
    }

    // MARK: - Server Status Cards

    private var checkingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(StudyTheme.accent)
            Text("Connecting to CrewAI server…")
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)
            Spacer()
        }
        .padding(StudySpacing.medium)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(StudyTheme.danger)
                Text("CrewAI Server Not Running")
                    .font(StudyFont.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(StudyTheme.primaryText)
                Spacer()
                Button {
                    Task { await checkServer() }
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(StudyTheme.accent)
                }
            }

            Text("Start the Python backend, then tap ↺ to retry:")
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)

            VStack(alignment: .leading, spacing: 6) {
                codeSnippet("cd SmartStudy/crew_backend")
                codeSnippet("cp .env.example .env   # add your GROQ_API_KEY")
                codeSnippet("./start.sh")
            }

            Text("The server runs on http://localhost:8000")
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.tertiaryText)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudyTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // MARK: - Actions

    private func checkServer() async {
        serverStatus = .checking
        let running = await crew.isServerRunning()
        withAnimation {
            serverStatus = running ? .online : .offline
        }
    }

    private func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        result = ""
        errorMessage = nil

        do {
            switch selectedMode {
            case .weeklyPlan:
                result = try await crew.generateWeeklyPlan(
                    store: store,
                    studyGoal: studyGoal
                )
            case .performanceReview:
                if store.quizSessions.isEmpty {
                    result = "Complete a few quizzes first — then come back for a detailed performance review!"
                } else {
                    result = try await crew.getPerformanceReview(store: store)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            result = ""
        }

        withAnimation(.spring(response: 0.5)) {
            isGenerating = false
        }
    }
}
