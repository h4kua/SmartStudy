import Foundation
import SwiftUI

@MainActor
final class FlashcardsViewModel: ObservableObject {

    // MARK: - Generation

    @Published var topic          = ""
    @Published var cardCount      = 15
    @Published var isGenerating   = false
    @Published var showGenerateSheet = false
    @Published var errorMessage: String?

    // MARK: - Review session

    @Published var activeDeck: FlashcardDeck?
    @Published var reviewCards:   [Flashcard] = []
    @Published var reviewIndex    = 0
    @Published var isFlipped      = false
    @Published var showReview     = false
    @Published var sessionKnewCount = 0
    @Published var sessionComplete  = false

    // MARK: - Computed

    var currentCard: Flashcard? {
        guard reviewIndex < reviewCards.count else { return nil }
        return reviewCards[reviewIndex]
    }

    var reviewProgress: Double {
        guard !reviewCards.isEmpty else { return 0 }
        return Double(reviewIndex) / Double(reviewCards.count)
    }

    var isLastCard: Bool { reviewIndex == reviewCards.count - 1 }

    var sessionMastery: Double {
        guard !reviewCards.isEmpty else { return 0 }
        return Double(sessionKnewCount) / Double(reviewCards.count)
    }

    // MARK: - Generate deck

    func generateDeck(store: LearningStore) async {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Please enter a topic."; return }

        isGenerating = true
        errorMessage = nil

        do {
            let cards = try await GroqService.shared.generateFlashcards(
                topic: trimmed,
                count: cardCount
            )
            guard !cards.isEmpty else { throw GroqError.emptyResponse }

            let deck = FlashcardDeck(title: trimmed, subject: nil, cards: cards)
            store.addFlashcardDeck(deck)
            showGenerateSheet = false
            startReview(deck: deck)
        } catch {
            errorMessage = (error as? GroqError)?.errorDescription ?? error.localizedDescription
        }
        isGenerating = false
    }

    // MARK: - Start / restart review

    /// Smart review: due cards first, then rest shuffled.
    func startReview(deck: FlashcardDeck) {
        activeDeck      = deck
        let due     = deck.cards.filter(\.isDueForReview).shuffled()
        let notDue  = deck.cards.filter { !$0.isDueForReview }.shuffled()
        reviewCards     = due + notDue
        reviewIndex     = 0
        isFlipped       = false
        sessionKnewCount = 0
        sessionComplete  = false
        showReview       = true
    }

    func restartReview(store: LearningStore) {
        guard let deck = activeDeck else { return }
        let latest = store.flashcardDecks.first(where: { $0.id == deck.id }) ?? deck
        startReview(deck: latest)
    }

    // MARK: - Card interaction

    func flipCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            isFlipped.toggle()
        }
    }

    /// quality: 0 = Knew It, 1 = Unsure, 2 = Forgot
    func markCard(quality: Int, store: LearningStore) {
        guard var deck = activeDeck, reviewIndex < reviewCards.count else { return }

        var card = reviewCards[reviewIndex]
        card.reviewCount += 1
        card.lastReviewed = Date()
        if quality == 0 {
            card.knewItCount += 1
            sessionKnewCount += 1
        }
        reviewCards[reviewIndex] = card

        if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
            deck.cards[idx] = card
        }
        deck.lastReviewedDate = Date()

        if isLastCard {
            activeDeck = deck
            store.updateFlashcardDeck(deck)
            // Apply SM-2 for last card
            store.applySpacedRepetition(cardId: card.id, inDeck: deck.id, quality: quality)
            sessionComplete = true
        } else {
            activeDeck = deck
            store.updateFlashcardDeck(deck)
            store.applySpacedRepetition(cardId: card.id, inDeck: deck.id, quality: quality)
            withAnimation(.easeInOut(duration: 0.25)) {
                reviewIndex += 1
                isFlipped = false
            }
        }
    }

    func markKnew(store: LearningStore)       { markCard(quality: 0, store: store) }
    func markUnsure(store: LearningStore)     { markCard(quality: 1, store: store) }
    func markDidNotKnow(store: LearningStore) { markCard(quality: 2, store: store) }

    // MARK: - Dismiss

    func dismissReview() {
        showReview      = false
        activeDeck      = nil
        reviewCards     = []
        reviewIndex     = 0
        isFlipped       = false
        sessionComplete  = false
    }

    // MARK: - Due count helper

    func dueCount(for deck: FlashcardDeck) -> Int {
        deck.cards.filter(\.isDueForReview).count
    }
}
