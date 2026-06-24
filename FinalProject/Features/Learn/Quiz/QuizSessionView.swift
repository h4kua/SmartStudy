import SwiftUI

struct QuizSessionView: View {
    @EnvironmentObject var store: LearningStore
    @ObservedObject var vm: QuizViewModel
    @StateObject private var focusMonitor = QuizFocusMonitor()
    @State private var showFullReview = false

    var body: some View {
        ZStack {
            StudyTheme.backgroundGradient.ignoresSafeArea()
            if vm.showResults {
                resultsView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .opacity))
            } else {
                quizView
                    .transition(.opacity)
            }

            // ── Focus nudge banner (away ≥ 8 s) ────────────────
            if focusMonitor.isActive
                && !vm.showResults
                && focusMonitor.awaySeconds >= 8 {
                VStack {
                    focusNudgeBanner
                        .padding(.top, 58)   // clears the header
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.showResults)
        .animation(.easeInOut(duration: 0.3), value: focusMonitor.awaySeconds >= 8)
        // Start focus monitor for NEW sessions only
        .task {
            if !vm.showResults {
                await focusMonitor.start()
            }
        }
        // Stop when results appear (snapshot final stats)
        .onChange(of: vm.showResults) { isResults in
            if isResults { focusMonitor.stop() }
        }
        // Clean up if user exits mid-quiz
        .onDisappear { focusMonitor.stop() }
        .sheet(isPresented: $showFullReview) {
            if let session = vm.activeSession {
                QuizReviewView(session: session)
            }
        }
    }

    // =========================================================
    // MARK: - Focus nudge banner
    // =========================================================

    private var focusNudgeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 13, weight: .bold))
            Text("Come back — stay focused on the quiz!")
                .font(StudyFont.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(StudyTheme.warning, in: Capsule())
        .shadow(color: StudyTheme.warning.opacity(0.45), radius: 10, y: 4)
    }

    // =========================================================
    // MARK: - Active quiz
    // =========================================================

    private var quizView: some View {
        VStack(spacing: 0) {
            quizHeader
            progressBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {
                    questionCard
                    answerOptions
                    if vm.showExplanation { explanationCard }
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.vertical, StudySpacing.large)
            }

            if vm.showExplanation { nextButton }
        }
    }

    // --- Quiz header ---

    private var quizHeader: some View {
        HStack {
            Button { vm.dismissSession() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(StudyTheme.surface2)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(vm.activeSession?.title ?? "Quiz")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                    .lineLimit(1)
                Text("Question \(vm.currentIndex + 1) of \(vm.activeSession?.totalQuestions ?? 0)")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()

            // Focus state dot indicator
            focusDot
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, StudySpacing.medium)
        .background(StudyTheme.surface
            .overlay(alignment: .bottom) {
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
            })
    }

    /// Small colored dot in top-right of quiz header showing live focus state.
    private var focusDot: some View {
        ZStack {
            if focusMonitor.isActive {
                Circle()
                    .fill(focusMonitor.focusState.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(focusMonitor.focusState.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: focusMonitor.focusState.color.opacity(0.5), radius: 4)
            } else {
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.3), value: focusMonitor.focusState.rawValue)
    }

    // --- Progress bar ---

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(StudyTheme.surface2)
                Rectangle()
                    .fill(StudyTheme.accentGradient)
                    .frame(width: geo.size.width * vm.progressFraction)
                    .animation(.spring(response: 0.4), value: vm.progressFraction)
            }
        }
        .frame(height: 3)
    }

    // --- Question card ---

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: StudySpacing.medium) {
            if let diff = vm.activeSession?.difficulty {
                Text(diff.label.uppercased())
                    .font(StudyFont.tiny)
                    .foregroundStyle(diff.color)
                    .tracking(1)
            }
            Text(vm.currentQuestion?.question ?? "")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StudySpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
        )
    }

    // --- Answer options ---

    private var answerOptions: some View {
        VStack(spacing: StudySpacing.small) {
            ForEach(0..<(vm.currentQuestion?.options.count ?? 0), id: \.self) { i in
                answerButton(index: i)
            }
        }
    }

    private func answerButton(index: Int) -> some View {
        let letters  = ["A", "B", "C", "D"]
        let correct  = vm.currentQuestion?.correctIndex == index
        let chosen   = vm.selectedAnswer == index
        let answered = vm.selectedAnswer != nil

        let bg: Color = {
            guard answered else { return StudyTheme.surface }
            if correct { return StudyTheme.success.opacity(0.15) }
            if chosen  { return StudyTheme.danger.opacity(0.15) }
            return StudyTheme.surface
        }()

        let border: Color = {
            guard answered else { return StudyTheme.surfaceStroke }
            if correct { return StudyTheme.success }
            if chosen  { return StudyTheme.danger }
            return StudyTheme.surfaceStroke
        }()

        let letterBg: Color = {
            guard answered else { return StudyTheme.surface2 }
            if correct { return StudyTheme.success }
            if chosen  { return StudyTheme.danger }
            return StudyTheme.surface2
        }()

        return Button {
            let isCorrect = vm.currentQuestion?.correctIndex == index
            UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .error)
            vm.selectAnswer(index, store: store)
        } label: {
            HStack(spacing: StudySpacing.medium) {
                Text(letters[safe: index] ?? "")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(letterBg)
                    .clipShape(Circle())

                Text(vm.currentQuestion?.options[safe: index] ?? "")
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if answered {
                    Image(systemName: correct
                          ? "checkmark.circle.fill"
                          : (chosen ? "xmark.circle.fill" : ""))
                        .foregroundStyle(correct ? StudyTheme.success : StudyTheme.danger)
                        .opacity(correct || chosen ? 1 : 0)
                }
            }
            .padding(StudySpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(bg)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(border, lineWidth: 1.5))
            )
        }
        .disabled(answered)
        .animation(.easeOut(duration: 0.2), value: vm.selectedAnswer)
    }

    // --- Explanation card ---

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: StudySpacing.small) {
            Label("Explanation", systemImage: "lightbulb")
                .font(StudyFont.subtitle)
                .foregroundStyle(StudyTheme.accent)
            Text(vm.currentQuestion?.explanation ?? "")
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StudySpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudyTheme.accentSoft)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(StudyTheme.accent.opacity(0.2), lineWidth: 1))
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // --- Next button ---

    private var nextButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            vm.nextQuestion(store: store)
        } label: {
            HStack(spacing: 8) {
                Text(vm.isLastQuestion ? "Finish Quiz" : "Next Question")
                    .font(StudyFont.subtitle)
                Image(systemName: vm.isLastQuestion ? "flag.checkered" : "arrow.right")
            }
            .frame(maxWidth: .infinity).frame(height: 52)
        }
        .buttonStyle(PrimaryStudyButtonStyle())
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, StudySpacing.medium)
        .background(StudyTheme.surface
            .overlay(alignment: .top) {
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
            })
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // =========================================================
    // MARK: - Results screen
    // =========================================================

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: StudySpacing.large) {
                resultsHeader
                scoreCircle
                statsRow
                // Focus stats card — only shown when camera was active this session
                if focusMonitor.finalResult.isValid {
                    focusStatsCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let session = vm.activeSession { reviewCard(session) }
                actionButtons
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, StudySpacing.xxLarge)
            .padding(.top, StudySpacing.large)
        }
    }

    private var resultsHeader: some View {
        HStack {
            Button { vm.dismissSession() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(StudyTheme.surface2)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Results")
                .font(StudyFont.subtitle)
                .foregroundStyle(StudyTheme.primaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var scoreCircle: some View {
        let session = vm.activeSession
        let pct     = session?.percentage ?? 0
        let color   = session?.gradeColor ?? StudyTheme.accent

        return VStack(spacing: StudySpacing.small) {
            ZStack {
                Circle()
                    .stroke(StudyTheme.surface2, lineWidth: 14)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: pct)
                    .shadow(color: color.opacity(0.4), radius: 8)

                VStack(spacing: 2) {
                    Text(pct.percentString)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    Text(session?.gradeLabel ?? "")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .tracking(1)
                }
            }

            if let session {
                Text(session.title)
                    .font(StudyFont.cardTitle)
                    .foregroundStyle(StudyTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text(session.difficulty.label)
                    .font(StudyFont.caption)
                    .foregroundStyle(session.difficulty.color)
            }
        }
    }

    private var statsRow: some View {
        let session = vm.activeSession
        return HStack(spacing: StudySpacing.medium) {
            statTile(value: "\(session?.score ?? 0)",
                     label: "Correct", color: StudyTheme.success)
            statTile(value: "\((session?.totalQuestions ?? 0) - (session?.score ?? 0))",
                     label: "Incorrect", color: StudyTheme.danger)
            statTile(value: "\(session?.totalQuestions ?? 0)",
                     label: "Total", color: StudyTheme.secondaryText)
        }
    }

    private func statTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StudySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
        )
    }

    // =========================================================
    // MARK: - Focus Stats Card (new — shown on results screen)
    // =========================================================

    private var focusStatsCard: some View {
        let r        = focusMonitor.finalResult
        let avgScore = r.avgScore
        let focusPct = r.focusedPercent
        let quizPct  = (vm.activeSession?.percentage ?? 0) * 100

        let avgColor: Color = avgScore >= 65
            ? StudyTheme.success
            : (avgScore >= 40 ? StudyTheme.warning : StudyTheme.danger)

        let focusColor: Color = focusPct >= 70
            ? StudyTheme.success
            : (focusPct >= 45 ? StudyTheme.warning : StudyTheme.danger)

        return StudyCard(title: "Focus During Quiz") {
            VStack(spacing: StudySpacing.medium) {

                // Eye icon + header hint
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudyTheme.accent)
                    Text("Tracked by front camera · no video stored")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.tertiaryText)
                    Spacer()
                }

                // Two metric tiles
                HStack(spacing: StudySpacing.medium) {
                    focusMetricTile(
                        icon: "brain.head.profile",
                        value: "\(Int(avgScore))%",
                        label: "Avg Focus Score",
                        color: avgColor
                    )
                    focusMetricTile(
                        icon: "clock.fill",
                        value: "\(Int(focusPct))%",
                        label: "Time Focused",
                        color: focusColor
                    )
                }

                // AI insight line
                let insight = focusInsight(quizPct: quizPct, focusPct: focusPct, avgScore: avgScore)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudyTheme.accent)
                        .padding(.top, 1)
                    Text(insight)
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(StudySpacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudyTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(StudyTheme.accent.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    private func focusMetricTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StudySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudyTheme.surface2)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.2), lineWidth: 1))
        )
    }

    private func focusInsight(quizPct: Double, focusPct: Double, avgScore: Double) -> String {
        switch (quizPct, focusPct) {
        case (80..., 70...):
            return "Outstanding! High focus + high score — you were fully in the zone."
        case (80..., ..<50):
            return "Great score despite lower focus. Full concentration could push you even higher next time."
        case (..<60, ..<50):
            return "Low focus likely impacted your score. Try a quieter environment and take a short break first."
        case (..<60, 70...):
            return "Good focus but the topic needs more review. Go over the wrong answers — you have the attention, now build the knowledge."
        case (60..., 70...):
            return "Solid focus kept you on track. Review the missed questions to close the gap."
        default:
            return "Decent session. Reducing short distractions during quizzes typically improves scores by 10–15%."
        }
    }

    // =========================================================
    // MARK: - Review card (existing)
    // =========================================================

    private func reviewCard(_ session: QuizSession) -> some View {
        StudyCard(title: "Review Answers") {
            VStack(spacing: StudySpacing.medium) {
                ForEach(Array(session.questions.enumerated()), id: \.offset) { i, q in
                    let userAnswer = i < session.userAnswers.count ? session.userAnswers[i] : -1
                    let correct    = userAnswer == q.correctIndex

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: StudySpacing.small) {
                            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(correct ? StudyTheme.success : StudyTheme.danger)
                            Text("Q\(i + 1). \(q.question)")
                                .font(StudyFont.subtitle)
                                .foregroundStyle(StudyTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !correct {
                            Text("Your answer: \(q.options[safe: userAnswer] ?? "—")")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.danger)
                            Text("Correct: \(q.options[safe: q.correctIndex] ?? "")")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.success)
                        }
                    }
                    if i < session.questions.count - 1 {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: StudySpacing.small) {
            if let session = vm.activeSession {
                Button { showFullReview = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard.fill")
                        Text("Review All Answers").font(StudyFont.subtitle)
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(PrimaryStudyButtonStyle())

                Button { vm.retakeSession(session, store: store) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Retake Quiz").font(StudyFont.subtitle)
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(GhostStudyButtonStyle())
            }

            Button { vm.dismissSession() } label: {
                Text("Done").font(StudyFont.subtitle)
                    .frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(GhostStudyButtonStyle())
        }
    }
}

// MARK: - Safe array subscript helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
