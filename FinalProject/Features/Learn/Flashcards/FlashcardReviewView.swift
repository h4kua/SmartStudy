import SwiftUI

struct FlashcardReviewView: View {
    @EnvironmentObject var store: LearningStore
    @ObservedObject var vm: FlashcardsViewModel
    @State private var dragOffset: CGFloat = 0
    // BUG FIX: prevent asyncAfter from firing after dismiss
    @State private var isDismissed = false

    var body: some View {
        ZStack {
            StudyTheme.backgroundGradient.ignoresSafeArea()
            if vm.sessionComplete {
                completionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .opacity))
            } else {
                reviewView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.sessionComplete)
    }

    // =========================================================
    // MARK: - Active review
    // =========================================================

    private var reviewView: some View {
        VStack(spacing: 0) {
            reviewHeader
            progressBar

            Spacer()
            cardStack
            Spacer()

            bottomControls
        }
    }

    // --- Header ---

    private var reviewHeader: some View {
        HStack {
            Button {
                isDismissed = true   // BUG FIX: cancel any pending asyncAfter
                vm.dismissReview()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(StudyTheme.surface2)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(vm.activeDeck?.title ?? "Flashcards")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                    .lineLimit(1)
                Text("Card \(vm.reviewIndex + 1) of \(vm.reviewCards.count)")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, StudySpacing.medium)
        .background(StudyTheme.surface
            .overlay(alignment: .bottom) {
                Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
            })
    }

    // --- Progress bar ---

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(StudyTheme.surface2)
                Rectangle()
                    .fill(StudyTheme.longBreakColor)
                    .frame(width: geo.size.width * vm.reviewProgress)
                    .animation(.spring(response: 0.4), value: vm.reviewProgress)
            }
        }
        .frame(height: 3)
    }

    // --- Card ---

    private var cardStack: some View {
        ZStack {
            // Shadow card (depth illusion)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(StudyTheme.surface2)
                .frame(height: 300)
                .padding(.horizontal, StudySpacing.large + 8)
                .offset(y: 8)
                .opacity(0.6)

            // Main card with flip
            ZStack {
                // Front face
                cardFace(
                    content: vm.currentCard?.front ?? "",
                    label: "TERM",
                    bgColor: StudyTheme.surface,
                    accentColor: StudyTheme.accent
                )
                .rotation3DEffect(
                    .degrees(vm.isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(vm.isFlipped ? 0 : 1)

                // Back face
                cardFace(
                    content: vm.currentCard?.back ?? "",
                    label: "ANSWER",
                    bgColor: StudyTheme.surface2,
                    accentColor: StudyTheme.shortBreakColor
                )
                .rotation3DEffect(
                    .degrees(vm.isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(vm.isFlipped ? 1 : 0)
            }
            .padding(.horizontal, StudySpacing.large)
            .offset(x: vm.isFlipped ? dragOffset : 0)
            .rotationEffect(.degrees(vm.isFlipped ? Double(dragOffset) / 20 : 0))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard vm.isFlipped else { return }
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard vm.isFlipped else { return }
                        let threshold: CGFloat = 80
                        if value.translation.width > threshold {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            withAnimation(.spring(response: 0.3)) { dragOffset = 400 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                guard !isDismissed else { return }
                                dragOffset = 0
                                vm.markCard(quality: 0, store: store)  // Knew It
                            }
                        } else if value.translation.width < -threshold {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            withAnimation(.spring(response: 0.3)) { dragOffset = -400 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                guard !isDismissed else { return }
                                dragOffset = 0
                                vm.markCard(quality: 2, store: store)  // Forgot
                            }
                        } else {
                            withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                        }
                    }
            )
            .onTapGesture { vm.flipCard() }
            // Swipe hint overlay
            .overlay {
                if vm.isFlipped && abs(dragOffset) > 30 {
                    HStack {
                        if dragOffset < -30 {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(StudyTheme.danger)
                                .opacity(Double(min(1, abs(dragOffset) / 100)))
                        }
                        Spacer()
                        if dragOffset > 30 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(StudyTheme.success)
                                .opacity(Double(min(1, dragOffset / 100)))
                        }
                    }
                    .padding(.horizontal, StudySpacing.large + 16)
                }
            }
        }
    }

    private func cardFace(content: String, label: String, bgColor: Color, accentColor: Color) -> some View {
        VStack(spacing: StudySpacing.medium) {
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(accentColor)
                .tracking(1.2)

            Spacer()

            Text(content)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(StudyTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, StudySpacing.small)

            Spacer()

            if let card = vm.currentCard, !card.category.isEmpty {
                Text(card.category)
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.tertiaryText)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(StudyTheme.surface3)
                    .clipShape(Capsule())
            }
        }
        .padding(StudySpacing.large)
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(bgColor)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
        )
        .shadow(color: StudyTheme.shadow, radius: 16, x: 0, y: 8)
    }

    // --- Bottom controls ---

    private var bottomControls: some View {
        VStack(spacing: StudySpacing.medium) {
            if !vm.isFlipped {
                VStack(spacing: 4) {
                    Text("Tap card to reveal answer")
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.tertiaryText)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: StudySpacing.small) {
                    Text("How well did you know this?")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.tertiaryText)

                    HStack(spacing: StudySpacing.small) {
                        // Forgot
                        Button { vm.markCard(quality: 2, store: store) } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Forgot")
                                    .font(StudyFont.tiny)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(StudyTheme.danger)
                                    .shadow(color: StudyTheme.danger.opacity(0.35), radius: 8, y: 3)
                            )
                        }
                        // Unsure
                        Button { vm.markCard(quality: 1, store: store) } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "questionmark")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Unsure")
                                    .font(StudyFont.tiny)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(StudyTheme.warning)
                                    .shadow(color: StudyTheme.warning.opacity(0.35), radius: 8, y: 3)
                            )
                        }
                        // Knew it
                        Button { vm.markCard(quality: 0, store: store) } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Knew it!")
                                    .font(StudyFont.tiny)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(StudyTheme.success)
                                    .shadow(color: StudyTheme.success.opacity(0.35), radius: 8, y: 3)
                            )
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.isFlipped)
        .padding(.horizontal, StudySpacing.large)
        .padding(.bottom, StudySpacing.xxLarge)
    }

    // =========================================================
    // MARK: - Completion screen
    // =========================================================

    private var completionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: StudySpacing.large) {
                completionHeader
                scoreCircle
                sessionStats
                actionButtons
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, StudySpacing.xxLarge)
            .padding(.top, StudySpacing.large)
        }
    }

    private var completionHeader: some View {
        HStack {
            Button { isDismissed = true; vm.dismissReview() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(StudyTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(StudyTheme.surface2)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Session Complete")
                .font(StudyFont.subtitle)
                .foregroundStyle(StudyTheme.primaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var scoreCircle: some View {
        let mastery = vm.sessionMastery
        let color   = mastery >= 0.8 ? StudyTheme.success
                    : mastery >= 0.5 ? StudyTheme.accent
                    : StudyTheme.warning

        return VStack(spacing: StudySpacing.medium) {
            ZStack {
                Circle()
                    .stroke(StudyTheme.surface2, lineWidth: 14)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: mastery)
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: mastery)
                    .shadow(color: color.opacity(0.4), radius: 8)

                VStack(spacing: 2) {
                    Text("\(vm.sessionKnewCount)/\(vm.reviewCards.count)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    Text("KNEW IT")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .tracking(1)
                }
            }

            Text(vm.activeDeck?.title ?? "Session Done")
                .font(StudyFont.cardTitle)
                .foregroundStyle(StudyTheme.primaryText)
                .multilineTextAlignment(.center)

            Text(sessionMessage)
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var sessionMessage: String {
        switch vm.sessionMastery {
        case 0.9...: return "Outstanding! You've mastered this topic."
        case 0.7...: return "Great job! Keep reviewing the ones you missed."
        case 0.5...: return "Good effort. A few more sessions will help."
        default:     return "Keep practicing — repetition builds mastery."
        }
    }

    private var sessionStats: some View {
        HStack(spacing: StudySpacing.medium) {
            statPill(value: "\(vm.sessionKnewCount)",
                     label: "Knew it",
                     color: StudyTheme.success)
            statPill(value: "\(vm.reviewCards.count - vm.sessionKnewCount)",
                     label: "Missed",
                     color: StudyTheme.danger)
            statPill(value: vm.sessionMastery.percentString,
                     label: "Session",
                     color: StudyTheme.accent)
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
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

    private var actionButtons: some View {
        VStack(spacing: StudySpacing.small) {
            Button { vm.restartReview(store: store) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Review Again").font(StudyFont.subtitle)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(PrimaryStudyButtonStyle())

            Button { vm.dismissReview() } label: {
                Text("Done").font(StudyFont.subtitle)
                    .frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(GhostStudyButtonStyle())
        }
    }
}
