import SwiftUI

struct FlashcardsView: View {
    @EnvironmentObject var store: LearningStore
    @StateObject private var vm = FlashcardsViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: StudySpacing.large) {
                newDeckButton
                if !store.flashcardDecks.isEmpty { deckList }
                else                             { emptyState }
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, StudySpacing.xxLarge)
        }
        .sheet(isPresented: $vm.showGenerateSheet) { generateSheet }
        .fullScreenCover(isPresented: $vm.showReview) {
            FlashcardReviewView(vm: vm)
                .environmentObject(store)
        }
    }

    // MARK: - New deck button

    private var newDeckButton: some View {
        Button { vm.showGenerateSheet = true } label: {
            HStack(spacing: StudySpacing.small) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("New Flashcard Deck")
                    .font(StudyFont.subtitle)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
        }
        .buttonStyle(PrimaryStudyButtonStyle())
    }

    // MARK: - Deck list

    private var deckList: some View {
        StudyCard(title: "My Decks") {
            VStack(spacing: StudySpacing.small) {
                ForEach(store.flashcardDecks) { deck in
                    Button { vm.startReview(deck: deck) } label: {
                        deckRow(deck)
                    }
                    if deck.id != store.flashcardDecks.last?.id {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
            }
        }
    }

    private func deckRow(_ deck: FlashcardDeck) -> some View {
        HStack(spacing: StudySpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(StudyTheme.longBreakColor.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(StudyTheme.longBreakColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(deck.title)
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(deck.totalCards) cards")
                    if deck.totalReviews > 0 {
                        Text("·")
                        Text(deck.overallMastery.percentString + " mastered")
                    }
                }
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
            }

            Spacer()

            if deck.totalReviews > 0 {
                masteryRing(deck.overallMastery)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(StudyTheme.tertiaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private func masteryRing(_ mastery: Double) -> some View {
        ZStack {
            Circle()
                .stroke(StudyTheme.surface2, lineWidth: 3)
                .frame(width: 32, height: 32)
            Circle()
                .trim(from: 0, to: mastery)
                .stroke(StudyTheme.success, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(-90))
            Text("\(Int(mastery * 100))%")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(StudyTheme.success)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        StudyCard {
            VStack(spacing: StudySpacing.medium) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 40))
                    .foregroundStyle(StudyTheme.tertiaryText)
                Text("No flashcard decks yet")
                    .font(StudyFont.cardTitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text("Tap \"New Flashcard Deck\" to generate cards on any topic, or analyze a document to create them automatically.")
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, StudySpacing.small)
        }
    }

    // MARK: - Generate sheet

    private var generateSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {

                    VStack(spacing: StudySpacing.small) {
                        ZStack {
                            Circle().fill(StudyTheme.accentSoft).frame(width: 60, height: 60)
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(StudyTheme.accent)
                        }
                        Text("New Flashcard Deck")
                            .font(StudyFont.cardTitle)
                            .foregroundStyle(StudyTheme.primaryText)
                        Text("Enter a topic and the AI will generate study flashcards for you.")
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, StudySpacing.medium)

                    // Topic
                    sheetSection("Topic") {
                        TextField("e.g. Photosynthesis", text: $vm.topic)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                            .padding(StudySpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(StudyTheme.surface2)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                            )
                    }

                    // Card count
                    sheetSection("Number of Cards") {
                        HStack(spacing: StudySpacing.small) {
                            ForEach([10, 15, 20, 30], id: \.self) { count in
                                Button { vm.cardCount = count } label: {
                                    Text("\(count)")
                                        .font(StudyFont.subtitle)
                                        .foregroundStyle(vm.cardCount == count ? .white : StudyTheme.secondaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(vm.cardCount == count ? StudyTheme.accent : StudyTheme.surface2)
                                        )
                                }
                            }
                        }
                    }

                    if let err = vm.errorMessage {
                        HStack(spacing: StudySpacing.small) {
                            Image(systemName: "exclamationmark.triangle")
                            Text(err).font(StudyFont.caption)
                        }
                        .foregroundStyle(StudyTheme.danger)
                        .padding(StudySpacing.medium)
                        .background(RoundedRectangle(cornerRadius: 12).fill(StudyTheme.danger.opacity(0.10)))
                    }

                    Button {
                        Task { await vm.generateDeck(store: store) }
                    } label: {
                        Group {
                            if vm.isGenerating {
                                HStack(spacing: 8) { ProgressView().tint(.white); Text("Generating...") }
                            } else {
                                Text("Generate Flashcards")
                            }
                        }
                        .font(StudyFont.subtitle)
                        .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(PrimaryStudyButtonStyle())
                    .disabled(vm.isGenerating || vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.showGenerateSheet = false }
                        .foregroundStyle(StudyTheme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func sheetSection<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: StudySpacing.small) {
            Text(label.uppercased())
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
                .tracking(0.8)
            content()
        }
    }
}
