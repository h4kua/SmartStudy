import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var store: StudyStore

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {
                    headerBanner
                    summaryRow
                    weeklyBarChart
                    subjectBreakdown
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header

    private var headerBanner: some View {
        GradientStudyCard(gradient: StudyTheme.accentGradient) {
            VStack(alignment: .leading, spacing: StudySpacing.small) {
                Label("ANALYTICS", systemImage: "chart.bar.fill")
                    .font(StudyFont.tiny)
                    .foregroundStyle(.black.opacity(0.60))
                    .tracking(1)
                Text("Study\nProgress")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.black.opacity(0.90))
                Text("Track your learning habits")
                    .font(StudyFont.caption)
                    .foregroundStyle(.black.opacity(0.60))
            }
        }
        .padding(.top, StudySpacing.medium)
    }

    // MARK: - Summary row

    private var summaryRow: some View {
        HStack(spacing: StudySpacing.medium) {
            summaryTile(
                icon: "flame.fill",
                value: "\(store.currentStreak)",
                label: "Day streak",
                color: .orange
            )
            summaryTile(
                icon: "clock.fill",
                value: store.todayWorkMinutes.minutesToHoursString,
                label: "Today",
                color: StudyTheme.accent
            )
            summaryTile(
                icon: "books.vertical.fill",
                value: "\(store.subjects.count)",
                label: "Subjects",
                color: StudyTheme.shortBreakColor
            )
        }
    }

    private func summaryTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StudySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Weekly bar chart

    private var weeklyBarChart: some View {
        StudyCard(title: "Last 7 Days") {
            let data = store.last7DaysMinutes
            let maxMins = max(data.map(\.minutes).max() ?? 1, 1)

            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                // Goal line label
                HStack {
                    Spacer()
                    Text("Goal: \(Int(store.config.dailyGoalHours))h")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.warning)
                }

                GeometryReader { geo in
                    let barWidth = (geo.size.width - CGFloat(data.count - 1) * 8) / CGFloat(data.count)
                    let chartHeight: CGFloat = 140
                    let goalY = chartHeight * (1 - CGFloat(Int(store.config.dailyGoalHours) * 60) / CGFloat(max(maxMins, Int(store.config.dailyGoalHours) * 60 + 1)))

                    ZStack(alignment: .topLeading) {
                        // Goal dashed line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: goalY))
                            path.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                        }
                        .stroke(StudyTheme.warning.opacity(0.5),
                                style: StrokeStyle(lineWidth: 1, dash: [5, 3]))

                        // Bars
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                                let barH = CGFloat(item.minutes) / CGFloat(max(maxMins, Int(store.config.dailyGoalHours) * 60 + 1)) * chartHeight
                                let isToday = idx == data.count - 1

                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isToday ? StudyTheme.accentGradient : LinearGradient(
                                            colors: [StudyTheme.accent.opacity(0.5)],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .frame(width: barWidth, height: max(4, barH))
                                }
                                .frame(width: barWidth, height: chartHeight, alignment: .bottom)
                            }
                        }
                    }
                    .frame(height: chartHeight)
                }
                .frame(height: 140)

                // Day labels
                HStack(spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                        Text(item.label)
                            .font(StudyFont.tiny)
                            .foregroundStyle(idx == data.count - 1 ? StudyTheme.accent : StudyTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }

                // This week total
                let totalMins = data.map(\.minutes).reduce(0, +)
                HStack {
                    Text("This week")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                    Spacer()
                    Text(totalMins.minutesToHoursString)
                        .font(StudyFont.subtitle)
                        .foregroundStyle(StudyTheme.primaryText)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Subject breakdown

    @ViewBuilder
    private var subjectBreakdown: some View {
        let data = store.minutesBySubjectToday
        if !data.isEmpty {
            StudyCard(title: "Today by Subject") {
                VStack(spacing: StudySpacing.medium) {
                    ForEach(data, id: \.subject.id) { item in
                        HStack(spacing: StudySpacing.medium) {
                            Text(item.subject.emoji).font(.title3)
                            Text(item.subject.name)
                                .font(StudyFont.subtitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            Spacer()
                            Text(item.minutes.minutesToHoursString)
                                .font(StudyFont.caption)
                                .foregroundStyle(item.subject.color)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(StudyTheme.surface2)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.subject.color)
                                    .frame(width: geo.size.width * CGFloat(item.minutes) / CGFloat(max(data.map(\.minutes).max() ?? 1, 1)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }
}
