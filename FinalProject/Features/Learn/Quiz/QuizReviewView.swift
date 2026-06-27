import SwiftUI

// MARK: - QuizReviewView
// Full-screen detailed review of all quiz questions with explanations.

struct QuizReviewView: View {
    let session: QuizSession
    @Environment(\.dismiss) private var dismiss
    @State private var expandedIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.medium) {
                        // Summary bar
                        summaryBar

                        // Questions
                        ForEach(Array(session.questions.enumerated()), id: \.offset) { idx, q in
                            let userAnswer = idx < session.userAnswers.count ? session.userAnswers[idx] : -1
                            let isCorrect  = userAnswer == q.correctIndex
                            questionCard(q: q, idx: idx, userAnswer: userAnswer, isCorrect: isCorrect)
                        }

                        Spacer().frame(height: StudySpacing.xxLarge)
                    }
                    .padding(.horizontal, StudySpacing.large)
                    .padding(.top, StudySpacing.medium)
                }
            }
            .navigationTitle("Review Answers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.accent)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        VStack(spacing: StudySpacing.medium) {
            // Main score card
            HStack(alignment: .center, spacing: 0) {
                // Left: big percentage + count
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.percentage.percentString)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(session.gradeColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(session.score) of \(session.totalQuestions) correct")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                }

                Spacer()

                // Right: grade label + difficulty badge
                VStack(alignment: .trailing, spacing: 10) {
                    Text(session.gradeLabel)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(session.gradeColor)

                    Text(session.difficulty.label.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(session.difficulty.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(session.difficulty.color.opacity(0.15))
                                .overlay(Capsule().stroke(session.difficulty.color.opacity(0.45), lineWidth: 1))
                        )
                }
            }
            .padding(.horizontal, StudySpacing.medium)
            .padding(.vertical, StudySpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(session.gradeColor.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(session.gradeColor.opacity(0.2), lineWidth: 1.5)
                    )
            )
        }
        .padding(.top, 4)
    }

    // MARK: - Question Card

    private func questionCard(q: QuizQuestion, idx: Int, userAnswer: Int, isCorrect: Bool) -> some View {
        let isExpanded = expandedIndex == idx

        return VStack(alignment: .leading, spacing: 0) {
            // Question header (always visible)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expandedIndex = isExpanded ? nil : idx
                }
            } label: {
                HStack(alignment: .top, spacing: StudySpacing.medium) {
                    // Status badge
                    ZStack {
                        Circle()
                            .fill(isCorrect ? StudyTheme.success.opacity(0.15) : StudyTheme.danger.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: isCorrect ? "checkmark" : "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isCorrect ? StudyTheme.success : StudyTheme.danger)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Q\(idx + 1)")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.tertiaryText)
                        Text(q.question)
                            .font(StudyFont.body)
                            .fontWeight(.medium)
                            .foregroundStyle(StudyTheme.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudyTheme.tertiaryText)
                        .padding(.top, 8)
                }
                .padding(StudySpacing.medium)
            }

            // Expanded: options + explanation
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                        .padding(.horizontal, StudySpacing.medium)

                    ForEach(q.options.indices, id: \.self) { optIdx in
                        optionRow(
                            text: q.options[optIdx],
                            index: optIdx,
                            userAnswer: userAnswer,
                            correctIndex: q.correctIndex
                        )
                    }

                    // Explanation
                    if !q.explanation.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(StudyTheme.warning)
                                .padding(.top, 2)
                            Text(q.explanation)
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(StudySpacing.medium)
                        .background(StudyTheme.warning.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal, StudySpacing.medium)
                        .padding(.bottom, StudySpacing.medium)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isCorrect
                            ? StudyTheme.success.opacity(isExpanded ? 0.4 : 0.2)
                            : StudyTheme.danger.opacity(isExpanded ? 0.4 : 0.2),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: StudyTheme.shadow, radius: 6, y: 2)
    }

    private func optionRow(text: String, index: Int, userAnswer: Int, correctIndex: Int) -> some View {
        let isCorrect  = index == correctIndex
        let isSelected = index == userAnswer
        let isWrong    = isSelected && !isCorrect

        let bg: Color = isCorrect  ? StudyTheme.success.opacity(0.12)
                      : isWrong    ? StudyTheme.danger.opacity(0.12)
                      : .clear
        let border: Color = isCorrect ? StudyTheme.success.opacity(0.5)
                          : isWrong   ? StudyTheme.danger.opacity(0.5)
                          : StudyTheme.surfaceStroke
        let letters = ["A", "B", "C", "D"]
        let letter  = index < letters.count ? letters[index] : "\(index)"

        return HStack(spacing: 10) {
            // Option letter (A / B / C / D)
            Text(letter)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isCorrect ? StudyTheme.success : isWrong ? StudyTheme.danger : StudyTheme.tertiaryText)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(isCorrect || isWrong ? .clear : StudyTheme.surface2)
                        .overlay(Circle().stroke(border.opacity(0.6), lineWidth: 1))
                )

            Text(text)
                .font(StudyFont.caption)
                .foregroundStyle(isCorrect ? StudyTheme.success : isWrong ? StudyTheme.danger : StudyTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if isCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(StudyTheme.success)
                    .font(.system(size: 14))
            } else if isWrong {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(StudyTheme.danger)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, StudySpacing.medium)
        .padding(.vertical, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .padding(.horizontal, StudySpacing.medium)
    }
}
