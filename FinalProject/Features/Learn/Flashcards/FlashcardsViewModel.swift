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

    func startReview(deck: FlashcardDeck) {
        activeDeck      = deck
        reviewCards     = deck.cards.shuffled()
        reviewIndex     = 0
        isFlipped       = false
        sessionKnewCount = 0
        sessionComplete  = false
        showReview       = true
    }

    func restartReview(store: LearningStore) {
        guard let deck = activeDeck else { return }
        // Reload latest version from store
        let latest = store.flashcardDecks.first(where: { $0.id == deck.id }) ?? deck
        startReview(deck: latest)
    }

    // MARK: - Card interaction

    func flipCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            isFlipped.toggle()
        }
    }

    func markKnew(store: LearningStore)       { advanceCard(knew: true,  store: store) }
    func markDidNotKnow(store: LearningStore) { advanceCard(knew: false, store: store) }

    // MARK: - Dismiss

    func dismissReview() {
        showReview      = false
        activeDeck      = nil
        reviewCards     = []
        reviewIndex     = 0
        isFlipped       = false
        sessionComplete  = false
    }

    // MARK: - Private

    private func advanceCard(knew: Bool, store: LearningStore) {
        guard var deck = activeDeck, reviewIndex < reviewCards.count else { return }

        // Update the card stats
        var card = reviewCards[reviewIndex]
        card.reviewCount += 1
        card.lastReviewed = Date()
        if knew {
            card.knewItCount += 1
            sessionKnewCount += 1
        }
        reviewCards[reviewIndex] = card

        // Sync back into deck
        if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
            deck.cards[idx] = card
        }

        if isLastCard {
            deck.lastReviewedDate = Date()
            activeDeck = deck
            store.updateFlashcardDeck(deck)
            sessionComplete = true
        } else {
            activeDeck = deck
            store.updateFlashcardDeck(deck)
            withAnimation(.easeInOut(duration: 0.25)) {
                reviewIndex += 1
                isFlipped = false
            }
        }
    }
}
