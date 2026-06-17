import SwiftUI

struct LearnHubView: View {
    @EnvironmentObject var store: LearningStore
    @State private var selectedTab = 0
    @Namespace private var tabNS

    private let tabs = ["Quizzes", "Flashcards", "Timer"]
    private let subtitles = ["Test your knowledge", "Active recall practice", "Focus & take breaks"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                learnHeader
                segmentedPicker
                    .padding(.horizontal, StudySpacing.large)
                    .padding(.bottom, StudySpacing.medium)

                Group {
                    switch selectedTab {
                    case 0:
                        QuizView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading),
                                removal:   .move(edge: .trailing)))
                    case 1:
                        FlashcardsView()
                            .transition(.asymmetric(
                                insertion: selectedTab > 1 ? .move(edge: .leading) : .move(edge: .trailing),
                                removal:   selectedTab > 1 ? .move(edge: .trailing) : .move(edge: .leading)))
                    default:
                        TimerView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal:   .move(edge: .leading)))
                    }
                }
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
    }

    // MARK: - Header

    private var learnHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Learn")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                Text(subtitles[min(selectedTab, subtitles.count - 1)])
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
            Spacer()
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.top, StudySpacing.large)
        .padding(.bottom, StudySpacing.medium)
    }

    // MARK: - Segment Picker

    private var segmentedPicker: some View {
        HStack(spacing: 2) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = i
                    }
                } label: {
                    HStack(spacing: 5) {
                        if i == 2 {
                            Image(systemName: "timer")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(tabs[i])
                            .font(StudyFont.tiny)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(selectedTab == i ? .white : StudyTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selectedTab == i {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(i == 2 ? AnyShapeStyle(StudyTheme.shortBreakColor) : AnyShapeStyle(StudyTheme.accentGradient))
                                    .shadow(color: (i == 2 ? StudyTheme.shortBreakColor : StudyTheme.accent).opacity(0.4), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "learnTab", in: tabNS)
                            }
                        }
                    )
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(StudyTheme.surface2))
    }
}
