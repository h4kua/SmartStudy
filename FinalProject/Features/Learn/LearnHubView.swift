import SwiftUI

struct LearnHubView: View {
    @EnvironmentObject var store: LearningStore
    @State private var selectedTab = 0
    @Namespace private var tabNS

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                learnHeader
                segmentedPicker
                    .padding(.horizontal, StudySpacing.large)
                    .padding(.bottom, StudySpacing.medium)

                if selectedTab == 0 {
                    QuizView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal:   .move(edge: .trailing)))
                } else {
                    FlashcardsView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal:   .move(edge: .leading)))
                }
            }
            .background(StudyTheme.background.ignoresSafeArea())
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
                Text(selectedTab == 0 ? "Test your knowledge" : "Active recall practice")
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.top, StudySpacing.large)
        .padding(.bottom, StudySpacing.medium)
    }

    // MARK: - Segment picker

    private var segmentedPicker: some View {
        HStack(spacing: 2) {
            ForEach(["Quizzes", "Flashcards"].indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = i
                    }
                } label: {
                    Text(["Quizzes", "Flashcards"][i])
                        .font(StudyFont.subtitle)
                        .foregroundStyle(selectedTab == i ? .white : StudyTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedTab == i {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(StudyTheme.accent)
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
