import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: LearningStore
    @Binding var selectedTab: Int
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {
                    heroBanner
                    quickActionsRow
                    if !store.recentQuizSessions.isEmpty { recentQuizzesCard }
                    if !store.recentDecks.isEmpty         { recentDecksCard   }
                    if store.recentQuizSessions.isEmpty && store.recentDecks.isEmpty {
                        gettingStartedCard
                    }
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
    }

    // MARK: - Hero

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: StudySpacing.small) {
            HStack(spacing: StudySpacing.small) {
                Text(greetingText.uppercased())
                    .font(StudyFont.tiny)
                    .foregroundStyle(.white.opacity(0.60))
                    .tracking(1.4)
                Spacer()
                if store.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.caption.bold())
                        Text("\(store.currentStreak) day streak")
                    }
                    .font(StudyFont.tiny)
                    .foregroundStyle(.white.opacity(0.90))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.14), in: Capsule())
                }
                // Settings gear
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.80))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.14))
                        .clipShape(Circle())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.totalQuizzesTaken)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("quizzes completed")
                    .font(StudyFont.body)
                    .foregroundStyle(.white.opacity(0.60))
                    .padding(.bottom, 6)
            }

            Text(motivationalText)
                .font(StudyFont.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(StudySpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: StudyRadius.xLarge, style: .continuous)
                    .fill(StudyTheme.focusGradient)
                Circle()
                    .fill(StudyTheme.longBreakColor.opacity(0.35))
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(x: 60, y: -70)
                Circle()
                    .fill(StudyTheme.accent.opacity(0.25))
                    .frame(width: 120, height: 120)
                    .blur(radius: 40)
                    .offset(x: -10, y: 60)
            }
            .clipShape(RoundedRectangle(cornerRadius: StudyRadius.xLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StudyRadius.xLarge, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        )
        .shadow(color: StudyTheme.accentGlow.opacity(0.45), radius: 24, x: 0, y: 12)
        .padding(.top, StudySpacing.medium)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var motivationalText: String {
        switch store.totalQuizzesTaken {
        case 0:     return "Start your first quiz or flashcard session today."
        case 1...3: return "Good start — keep building your knowledge."
        case 4...9: return "You're on a roll. Keep the momentum going."
        default:    return "Excellent consistency. Your hard work is paying off."
        }
    }

    // MARK: - Quick actions

    private var quickActionsRow: some View {
        HStack(spacing: StudySpacing.medium) {
            quickAction(icon: "brain.head.profile", label: "Ask Tutor",
                        color: StudyTheme.accent, tab: 1)
            quickAction(icon: "checkmark.circle",   label: "New Quiz",
                        color: StudyTheme.shortBreakColor, tab: 3)
            quickAction(icon: "rectangle.on.rectangle", label: "Flashcards",
                        color: StudyTheme.longBreakColor, tab: 3)
        }
    }

    private func quickAction(icon: String, label: String, color: Color, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .multilineTextAlignment(.center)
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
    }

    // MARK: - Recent Quizzes

    private var recentQuizzesCard: some View {
        StudyCard(title: "Recent Quizzes") {
            VStack(spacing: StudySpacing.small) {
                ForEach(store.recentQuizSessions.prefix(3)) { session in
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
                            Text(session.createdDate, style: .relative)
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.secondaryText)
                        }
                        Spacer()
                        Text(session.percentage.percentString)
                            .font(StudyFont.subtitle)
                            .foregroundStyle(session.gradeColor)
                    }
                    if session.id != store.recentQuizSessions.prefix(3).last?.id {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
                Button { selectedTab = 3 } label: {
                    Text("View All Quizzes →")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Recent Decks

    private var recentDecksCard: some View {
        StudyCard(title: "Flashcard Decks") {
            VStack(spacing: StudySpacing.small) {
                ForEach(store.recentDecks.prefix(3)) { deck in
                    HStack(spacing: StudySpacing.medium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(StudyTheme.longBreakColor.opacity(0.14))
                                .frame(width: 36, height: 36)
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(StudyTheme.longBreakColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deck.title)
                                .font(StudyFont.subtitle)
                                .foregroundStyle(StudyTheme.primaryText)
                                .lineLimit(1)
                            Text("\(deck.totalCards) cards")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.secondaryText)
                        }
                        Spacer()
                        Text(deck.overallMastery.percentString)
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.longBreakColor)
                    }
                    if deck.id != store.recentDecks.prefix(3).last?.id {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
                Button { selectedTab = 3 } label: {
                    Text("View All Decks →")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Getting started

    private var gettingStartedCard: some View {
        StudyCard {
            VStack(spacing: StudySpacing.medium) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 36))
                    .foregroundStyle(StudyTheme.tertiaryText)
                Text("Welcome to AI Academic Mentor")
                    .font(StudyFont.cardTitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text("Use the tabs below to ask your AI tutor a question, analyze a document, or generate a quiz.")
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .multilineTextAlignment(.center)

                HStack(spacing: StudySpacing.medium) {
                    Button { selectedTab = 1 } label: {
                        Text("Ask Tutor")
                            .font(StudyFont.subtitle)
                            .frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .buttonStyle(PrimaryStudyButtonStyle())

                    Button { selectedTab = 3 } label: {
                        Text("Start Learning")
                            .font(StudyFont.subtitle)
                            .frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .buttonStyle(GhostStudyButtonStyle())
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, StudySpacing.small)
        }
    }
}
