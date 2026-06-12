import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: StudyStore

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {
                    heroBanner
                    goalProgressCard
                    if !store.minutesBySubjectToday.isEmpty { todaySubjectsCard }
                    recentSessionsCard
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: - Hero

    private var heroBanner: some View {
        GradientStudyCard(gradient: StudyTheme.focusGradient) {
            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                HStack {
                    Label("SMART STUDY", systemImage: "brain.head.profile")
                        .font(StudyFont.tiny)
                        .foregroundStyle(.white.opacity(0.70))
                        .tracking(1)
                    Spacer()
                    if store.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange)
                            Text("\(store.currentStreak) day streak")
                        }
                        .font(StudyFont.tiny)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(store.todayWorkMinutes.minutesToHoursString)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("studied today")
                        .font(StudyFont.body)
                        .foregroundStyle(.white.opacity(0.70))
                        .padding(.bottom, 8)
                }

                Text(motivationalText)
                    .font(StudyFont.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.top, StudySpacing.medium)
    }

    private var motivationalText: String {
        let progress = store.todayGoalProgress
        switch progress {
        case 0:       return "Start your first session today! 🚀"
        case ..<0.33: return "Great start — keep building momentum."
        case ..<0.66: return "Halfway there — you're doing great! 💪"
        case ..<1.0:  return "Almost at your goal — push through!"
        default:      return "Daily goal reached! Outstanding work 🎉"
        }
    }

    // MARK: - Goal progress

    private var goalProgressCard: some View {
        StudyCard(title: "Today's Goal") {
            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                HStack {
                    Text("\(Int(store.todayGoalProgress * 100))%")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(StudyTheme.accent)
                        .contentTransition(.numericText())
                    Spacer()
                    Text("\(store.todayWorkMinutes.minutesToHoursString) / \(store.config.dailyGoalHours, specifier: "%.0f")h")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(StudyTheme.surface2)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(StudyTheme.accentGradient)
                            .frame(width: geo.size.width * store.todayGoalProgress)
                            .animation(.spring(response: 0.5), value: store.todayGoalProgress)
                    }
                }
                .frame(height: 12)
            }
        }
    }

    // MARK: - Today subjects

    private var todaySubjectsCard: some View {
        StudyCard(title: "Today's Focus") {
            VStack(spacing: StudySpacing.small) {
                ForEach(store.minutesBySubjectToday.prefix(4), id: \.subject.id) { item in
                    HStack(spacing: StudySpacing.medium) {
                        Text(item.subject.emoji).font(.title3)
                        Text(item.subject.name)
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.primaryText)
                        Spacer()
                        Text(item.minutes.minutesToHoursString)
                            .font(StudyFont.caption)
                            .foregroundStyle(item.subject.color)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(item.subject.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Recent sessions

    @ViewBuilder
    private var recentSessionsCard: some View {
        if store.recentSessions.isEmpty {
            StudyCard {
                VStack(spacing: StudySpacing.medium) {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundStyle(StudyTheme.secondaryText)
                    Text("No sessions yet")
                        .font(StudyFont.cardTitle)
                        .foregroundStyle(StudyTheme.primaryText)
                    Text("Start a Pomodoro session to track your study time.")
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            StudyCard(title: "Recent Sessions") {
                VStack(spacing: StudySpacing.small) {
                    ForEach(store.recentSessions) { session in
                        HStack(spacing: StudySpacing.medium) {
                            Image(systemName: "timer")
                                .font(.body)
                                .foregroundStyle(StudyTheme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.subjectName ?? "Free study")
                                    .font(StudyFont.subtitle)
                                    .foregroundStyle(StudyTheme.primaryText)
                                Text(session.startDate, style: .relative)
                                    .font(StudyFont.tiny)
                                    .foregroundStyle(StudyTheme.secondaryText)
                            }
                            Spacer()
                            Text(session.durationMinutes.minutesToHoursString)
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                        }
                        if session.id != store.recentSessions.last?.id {
                            Divider().background(StudyTheme.surfaceStroke)
                        }
                    }
                }
            }
        }
    }
}
