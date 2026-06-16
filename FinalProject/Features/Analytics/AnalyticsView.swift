import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var store: LearningStore
    @ObservedObject private var health = HealthKitService.shared
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {
                    pageHeader
                    summaryRow
                    healthCard
                    weeklyActivityChart
                    quizPerformanceCard
                    subjectPerformanceCard
                    if !store.recentQuizSessions.isEmpty { recentResultsCard }
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task { await health.requestAuthorization() }
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                Text("Track your learning habits")
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
            }
        }
        .padding(.top, StudySpacing.large)
    }

    // MARK: - Summary tiles

    private var summaryRow: some View {
        HStack(spacing: StudySpacing.medium) {
            summaryTile(icon: "flame.fill",
                        value: "\(store.currentStreak)",
                        label: "Day Streak",
                        color: .orange)
            summaryTile(icon: "checkmark.circle.fill",
                        value: "\(store.totalQuizzesTaken)",
                        label: "Quizzes",
                        color: StudyTheme.accent)
            summaryTile(icon: "rectangle.on.rectangle.fill",
                        value: "\(store.totalFlashcardsReviewed)",
                        label: "Cards",
                        color: StudyTheme.longBreakColor)
        }
    }

    private func summaryTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
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

    // MARK: - Apple Health card

    private var healthCard: some View {
        StudyCard(title: "Apple Health — Today") {
            if !health.isAuthorized {
                HStack {
                    Spacer()
                    VStack(spacing: StudySpacing.small) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 28))
                            .foregroundStyle(StudyTheme.tertiaryText)
                        Text("Tap to allow Apple Health access.")
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(.vertical, StudySpacing.small)
            } else {
                HStack(spacing: StudySpacing.medium) {
                    healthTile(
                        icon: "figure.walk",
                        value: "\(health.todaySteps.formatted())",
                        label: "Steps Today",
                        color: StudyTheme.success
                    )
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(width: 1, height: 50)
                    healthTile(
                        icon: "bed.double.fill",
                        value: String(format: "%.1fh", health.sleepHours),
                        label: "Sleep Last Night",
                        color: StudyTheme.accent
                    )
                }
            }
        }
    }

    private func healthTile(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: StudySpacing.medium) {
            ZStack {
                Circle().fill(color.opacity(0.14)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                Text(label)
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly chart

    private var weeklyActivityChart: some View {
        StudyCard(title: "Last 7 Days") {
            let data = store.last7DaysActivity
            let maxCount = max(data.map(\.count).max() ?? 1, 1)

            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                GeometryReader { geo in
                    let barWidth = (geo.size.width - CGFloat(data.count - 1) * 6) / CGFloat(data.count)
                    let chartH: CGFloat = 120

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                            let barH = max(4, CGFloat(item.count) / CGFloat(maxCount) * chartH)
                            let isToday = idx == data.count - 1

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isToday
                                      ? AnyShapeStyle(StudyTheme.accentGradient)
                                      : AnyShapeStyle(StudyTheme.accent.opacity(0.28)))
                                .frame(width: barWidth, height: barH)
                                .frame(width: barWidth, height: chartH, alignment: .bottom)
                        }
                    }
                }
                .frame(height: 120)

                HStack(spacing: 6) {
                    ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                        Text(item.label)
                            .font(StudyFont.tiny)
                            .foregroundStyle(idx == data.count - 1
                                             ? StudyTheme.accent : StudyTheme.tertiaryText)
                            .frame(maxWidth: .infinity)
                    }
                }

                let total = data.map(\.count).reduce(0, +)
                HStack {
                    Text("This week")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                    Spacer()
                    Text("\(total) activit\(total == 1 ? "y" : "ies")")
                        .font(StudyFont.subtitle)
                        .foregroundStyle(StudyTheme.primaryText)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Quiz performance

    private var quizPerformanceCard: some View {
        StudyCard(title: "Quiz Performance") {
            if store.totalQuizzesTaken == 0 {
                HStack {
                    Spacer()
                    VStack(spacing: StudySpacing.small) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 32))
                            .foregroundStyle(StudyTheme.tertiaryText)
                        Text("Complete a quiz to see your stats.")
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, StudySpacing.small)
            } else {
                VStack(spacing: StudySpacing.medium) {
                    HStack {
                        statColumn(value: store.averageQuizScore.percentString,
                                   label: "Average Score",
                                   color: StudyTheme.accent)
                        Divider().frame(height: 40).background(StudyTheme.surfaceStroke)
                        statColumn(value: store.bestQuizScore.percentString,
                                   label: "Best Score",
                                   color: StudyTheme.success)
                        Divider().frame(height: 40).background(StudyTheme.surfaceStroke)
                        statColumn(value: "\(store.totalQuizzesTaken)",
                                   label: "Total Taken",
                                   color: StudyTheme.secondaryText)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6).fill(StudyTheme.surface2)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(StudyTheme.accentGradient)
                                .frame(width: geo.size.width * store.averageQuizScore)
                                .animation(.spring(response: 0.5), value: store.averageQuizScore)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }

    private func statColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subject performance breakdown

    private var subjectPerformanceCard: some View {
        let subjectSessions = store.subjects.compactMap { subject -> (Subject, [QuizSession])? in
            let sessions = store.quizSessions.filter {
                $0.isCompleted && $0.subject == subject.name
            }
            return sessions.isEmpty ? nil : (subject, sessions)
        }

        return Group {
            if !subjectSessions.isEmpty {
                StudyCard(title: "Subject Performance") {
                    VStack(spacing: StudySpacing.medium) {
                        ForEach(subjectSessions, id: \.0.id) { subject, sessions in
                            let avg = sessions.map(\.percentage).reduce(0, +) / Double(sessions.count)
                            VStack(spacing: 6) {
                                HStack {
                                    Circle()
                                        .fill(subject.color)
                                        .frame(width: 10, height: 10)
                                    Text(subject.name)
                                        .font(StudyFont.subtitle)
                                        .foregroundStyle(StudyTheme.primaryText)
                                    Spacer()
                                    Text(avg.percentString)
                                        .font(StudyFont.subtitle)
                                        .foregroundStyle(avg >= 0.7 ? StudyTheme.success : StudyTheme.warning)
                                    Text("· \(sessions.count) quiz\(sessions.count == 1 ? "" : "zes")")
                                        .font(StudyFont.tiny)
                                        .foregroundStyle(StudyTheme.secondaryText)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(StudyTheme.surface2)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(avg >= 0.7 ? AnyShapeStyle(StudyTheme.success) : AnyShapeStyle(StudyTheme.warning))
                                            .frame(width: geo.size.width * avg)
                                            .animation(.spring(response: 0.5), value: avg)
                                    }
                                }
                                .frame(height: 6)
                            }
                            if subject.id != subjectSessions.last?.0.id {
                                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent quiz results

    private var recentResultsCard: some View {
        StudyCard(title: "Recent Results") {
            VStack(spacing: StudySpacing.small) {
                ForEach(store.recentQuizSessions.prefix(5)) { session in
                    HStack(spacing: StudySpacing.medium) {
                        Circle()
                            .fill(session.gradeColor)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .font(StudyFont.subtitle)
                                .foregroundStyle(StudyTheme.primaryText)
                                .lineLimit(1)
                            Text("\(session.score)/\(session.totalQuestions) correct · \(session.difficulty.label)")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.secondaryText)
                        }
                        Spacer()
                        Text(session.percentage.percentString)
                            .font(StudyFont.subtitle)
                            .foregroundStyle(session.gradeColor)
                    }
                    if session.id != store.recentQuizSessions.prefix(5).last?.id {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
            }
        }
    }
}
