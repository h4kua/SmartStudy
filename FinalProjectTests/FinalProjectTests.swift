import XCTest
import SwiftUI
@testable import FinalProject

// MARK: - QuizQuestion & QuizSession Tests

final class QuizSessionTests: XCTestCase {

    private func makeQuestion(correctIndex: Int = 0) -> QuizQuestion {
        QuizQuestion(
            question: "Test question?",
            options: ["A", "B", "C", "D"],
            correctIndex: correctIndex,
            explanation: "Because A is correct.",
            difficulty: .beginner
        )
    }

    private func makeSession(questions: [QuizQuestion], answers: [Int]) -> QuizSession {
        QuizSession(
            title: "Test Quiz",
            subject: nil,
            difficulty: .beginner,
            questions: questions,
            userAnswers: answers
        )
    }

    func testScoreAllCorrect() {
        let questions = [makeQuestion(correctIndex: 0), makeQuestion(correctIndex: 2)]
        let session   = makeSession(questions: questions, answers: [0, 2])
        XCTAssertEqual(session.score, 2)
    }

    func testScoreAllWrong() {
        let questions = [makeQuestion(correctIndex: 0), makeQuestion(correctIndex: 1)]
        let session   = makeSession(questions: questions, answers: [3, 3])
        XCTAssertEqual(session.score, 0)
    }

    func testScorePartial() {
        let questions = [makeQuestion(correctIndex: 0), makeQuestion(correctIndex: 1), makeQuestion(correctIndex: 2)]
        let session   = makeSession(questions: questions, answers: [0, 9, 2])
        XCTAssertEqual(session.score, 2)
    }

    func testScoreEmpty() {
        let session = makeSession(questions: [], answers: [])
        XCTAssertEqual(session.score, 0)
    }

    func testPercentageFullScore() {
        let questions = [makeQuestion(), makeQuestion()]
        let session   = makeSession(questions: questions, answers: [0, 0])
        XCTAssertEqual(session.percentage, 1.0, accuracy: 0.001)
    }

    func testPercentageZeroScore() {
        let questions = [makeQuestion(correctIndex: 0), makeQuestion(correctIndex: 0)]
        let session   = makeSession(questions: questions, answers: [1, 1])
        XCTAssertEqual(session.percentage, 0.0, accuracy: 0.001)
    }

    func testPercentageHalf() {
        let questions = [makeQuestion(correctIndex: 0), makeQuestion(correctIndex: 0)]
        let session   = makeSession(questions: questions, answers: [0, 1])
        XCTAssertEqual(session.percentage, 0.5, accuracy: 0.001)
    }

    func testPercentageEmptyQuestionsIsZero() {
        let session = makeSession(questions: [], answers: [])
        XCTAssertEqual(session.percentage, 0.0, accuracy: 0.001)
    }

    func testGradeLabelExcellent() {
        let questions = Array(repeating: makeQuestion(correctIndex: 0), count: 10)
        let answers   = Array(repeating: 0, count: 10)
        let session   = makeSession(questions: questions, answers: answers)
        XCTAssertEqual(session.gradeLabel, "Excellent")
    }

    func testGradeLabelNeedsReview() {
        let questions = Array(repeating: makeQuestion(correctIndex: 0), count: 10)
        let answers   = Array(repeating: 1, count: 10)
        let session   = makeSession(questions: questions, answers: answers)
        XCTAssertEqual(session.gradeLabel, "Needs Review")
    }

    func testIsCompletedFalseByDefault() {
        let session = makeSession(questions: [makeQuestion()], answers: [0])
        XCTAssertFalse(session.isCompleted)
    }

    func testIsCompletedTrueWhenDateSet() {
        var session = makeSession(questions: [makeQuestion()], answers: [0])
        session.completedDate = Date()
        XCTAssertTrue(session.isCompleted)
    }

    func testTotalQuestions() {
        let questions = [makeQuestion(), makeQuestion(), makeQuestion()]
        let session   = makeSession(questions: questions, answers: [0, 0, 0])
        XCTAssertEqual(session.totalQuestions, 3)
    }
}

// MARK: - Flashcard & FlashcardDeck Tests

final class FlashcardTests: XCTestCase {

    private func makeCard(reviewCount: Int, knewItCount: Int) -> Flashcard {
        var card = Flashcard(front: "Q", back: "A", category: "Test", difficulty: .beginner)
        card.reviewCount = reviewCount
        card.knewItCount = knewItCount
        return card
    }

    func testMasteryPercentNoReviews() {
        let card = makeCard(reviewCount: 0, knewItCount: 0)
        XCTAssertEqual(card.masteryPercent, 0.0, accuracy: 0.001)
    }

    func testMasteryPercentAllKnew() {
        let card = makeCard(reviewCount: 5, knewItCount: 5)
        XCTAssertEqual(card.masteryPercent, 1.0, accuracy: 0.001)
    }

    func testMasteryPercentPartial() {
        let card = makeCard(reviewCount: 4, knewItCount: 3)
        XCTAssertEqual(card.masteryPercent, 0.75, accuracy: 0.001)
    }

    func testIsMasteredFalseNoReviews() {
        let card = makeCard(reviewCount: 0, knewItCount: 0)
        XCTAssertFalse(card.isMastered)
    }

    func testIsMasteredFalseBelowThreshold() {
        let card = makeCard(reviewCount: 10, knewItCount: 6) // 60% < 70%
        XCTAssertFalse(card.isMastered)
    }

    func testIsMasteredTrueAtThreshold() {
        let card = makeCard(reviewCount: 10, knewItCount: 7) // exactly 70%
        XCTAssertTrue(card.isMastered)
    }

    func testIsMasteredTrueAboveThreshold() {
        let card = makeCard(reviewCount: 10, knewItCount: 10)
        XCTAssertTrue(card.isMastered)
    }
}

final class FlashcardDeckTests: XCTestCase {

    private func makeDeck(cards: [Flashcard]) -> FlashcardDeck {
        FlashcardDeck(title: "Test Deck", subject: nil, cards: cards)
    }

    private func makeCard(reviewCount: Int, knewItCount: Int) -> Flashcard {
        var card = Flashcard(front: "Q", back: "A", category: "X", difficulty: .intermediate)
        card.reviewCount = reviewCount
        card.knewItCount = knewItCount
        return card
    }

    func testOverallMasteryEmptyDeck() {
        let deck = makeDeck(cards: [])
        XCTAssertEqual(deck.overallMastery, 0.0, accuracy: 0.001)
    }

    func testOverallMasteryNoReviews() {
        let cards = [makeCard(reviewCount: 0, knewItCount: 0),
                     makeCard(reviewCount: 0, knewItCount: 0)]
        let deck  = makeDeck(cards: cards)
        XCTAssertEqual(deck.overallMastery, 0.0, accuracy: 0.001)
    }

    func testOverallMasteryAllMastered() {
        let cards = [makeCard(reviewCount: 5, knewItCount: 5),
                     makeCard(reviewCount: 5, knewItCount: 5)]
        let deck  = makeDeck(cards: cards)
        XCTAssertEqual(deck.overallMastery, 1.0, accuracy: 0.001)
    }

    func testOverallMasteryHalf() {
        let mastered   = makeCard(reviewCount: 5, knewItCount: 5)
        let unmastered = makeCard(reviewCount: 5, knewItCount: 0)
        let deck = makeDeck(cards: [mastered, unmastered])
        XCTAssertEqual(deck.overallMastery, 0.5, accuracy: 0.001)
    }

    func testMasteredCardsCount() {
        let mastered1  = makeCard(reviewCount: 10, knewItCount: 9)
        let mastered2  = makeCard(reviewCount: 10, knewItCount: 7)
        let unmastered = makeCard(reviewCount: 10, knewItCount: 5)
        let deck = makeDeck(cards: [mastered1, mastered2, unmastered])
        XCTAssertEqual(deck.masteredCards, 2)
    }

    func testTotalCards() {
        let deck = makeDeck(cards: [makeCard(reviewCount: 0, knewItCount: 0),
                                    makeCard(reviewCount: 0, knewItCount: 0),
                                    makeCard(reviewCount: 0, knewItCount: 0)])
        XCTAssertEqual(deck.totalCards, 3)
    }

    func testTotalReviews() {
        let cards = [makeCard(reviewCount: 3, knewItCount: 2),
                     makeCard(reviewCount: 5, knewItCount: 3)]
        let deck  = makeDeck(cards: cards)
        XCTAssertEqual(deck.totalReviews, 8)
    }
}

// MARK: - AnalyzedDocument Tests

final class AnalyzedDocumentTests: XCTestCase {

    private func makeDoc(text: String) -> AnalyzedDocument {
        AnalyzedDocument(
            title: "Test",
            originalText: text,
            summary: "Summary.",
            keyConcepts: [],
            definitions: [:],
            suggestedQuestions: []
        )
    }

    func testWordCountBasic() {
        let doc = makeDoc(text: "Hello world this is a test")
        XCTAssertEqual(doc.wordCount, 6)
    }

    func testWordCountEmpty() {
        let doc = makeDoc(text: "")
        XCTAssertEqual(doc.wordCount, 0)
    }

    func testWordCountSingleWord() {
        let doc = makeDoc(text: "Photosynthesis")
        XCTAssertEqual(doc.wordCount, 1)
    }

    func testIsTodayDefault() {
        let doc = makeDoc(text: "test")
        XCTAssertTrue(doc.isToday)
    }
}

// MARK: - Helper extension tests

final class HelperTests: XCTestCase {

    func testPercentStringRounding() {
        XCTAssertEqual((0.875).percentString, "88%")
        XCTAssertEqual((1.0).percentString,   "100%")
        XCTAssertEqual((0.0).percentString,   "0%")
        XCTAssertEqual((0.5).percentString,   "50%")
    }

    func testMinutesToHoursStringMinutesOnly() {
        XCTAssertEqual(45.minutesToHoursString, "45m")
    }

    func testMinutesToHoursStringHoursOnly() {
        XCTAssertEqual(120.minutesToHoursString, "2h")
    }

    func testMinutesToHoursStringMixed() {
        XCTAssertEqual(90.minutesToHoursString, "1h 30m")
    }

    func testColorHexValid() {
        let color = Color(hex: "#4A8EFF")
        XCTAssertNotNil(color)
    }

    func testColorHexValidWithoutHash() {
        let color = Color(hex: "4A8EFF")
        XCTAssertNotNil(color)
    }

    func testColorHexInvalidTooShort() {
        let color = Color(hex: "#FFF")
        XCTAssertNil(color)
    }

    func testColorHexInvalidEmpty() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }
}

// MARK: - LearningStore Tests

@MainActor
final class LearningStoreTests: XCTestCase {

    private func makeStore() -> LearningStore {
        let store = LearningStore()
        store.quizSessions.removeAll()
        store.flashcardDecks.removeAll()
        store.analyzedDocuments.removeAll()
        return store
    }

    private func makeSession(score: Int, total: Int, completed: Bool = true) -> QuizSession {
        let correct   = Array(0..<score).map { _ in 0 }
        let incorrect = Array(0..<(total - score)).map { _ in 1 }
        var session = QuizSession(
            title: "Test",
            subject: nil,
            difficulty: .intermediate,
            questions: Array(repeating: QuizQuestion(
                question: "Q?",
                options: ["A", "B", "C", "D"],
                correctIndex: 0,
                explanation: "A",
                difficulty: .intermediate
            ), count: total),
            userAnswers: correct + incorrect
        )
        if completed { session.completedDate = Date() }
        return session
    }

    func testTotalQuizzesTakenOnlyCountsCompleted() {
        let store = makeStore()
        store.addQuizSession(makeSession(score: 8, total: 10, completed: true))
        store.addQuizSession(makeSession(score: 5, total: 10, completed: false))
        XCTAssertEqual(store.totalQuizzesTaken, 1)
    }

    func testAverageQuizScoreEmpty() {
        let store = makeStore()
        XCTAssertEqual(store.averageQuizScore, 0.0, accuracy: 0.001)
    }

    func testAverageQuizScoreSingle() {
        let store = makeStore()
        store.addQuizSession(makeSession(score: 8, total: 10))
        XCTAssertEqual(store.averageQuizScore, 0.8, accuracy: 0.001)
    }

    func testAverageQuizScoreMultiple() {
        let store = makeStore()
        store.addQuizSession(makeSession(score: 6, total: 10))  // 60%
        store.addQuizSession(makeSession(score: 10, total: 10)) // 100%
        XCTAssertEqual(store.averageQuizScore, 0.8, accuracy: 0.001)
    }

    func testBestQuizScoreEmpty() {
        let store = makeStore()
        XCTAssertEqual(store.bestQuizScore, 0.0, accuracy: 0.001)
    }

    func testBestQuizScore() {
        let store = makeStore()
        store.addQuizSession(makeSession(score: 5, total: 10))
        store.addQuizSession(makeSession(score: 9, total: 10))
        XCTAssertEqual(store.bestQuizScore, 0.9, accuracy: 0.001)
    }

    func testAddAndDeleteQuizSession() {
        let store   = makeStore()
        let session = makeSession(score: 5, total: 10)
        store.addQuizSession(session)
        XCTAssertEqual(store.quizSessions.count, 1)
        store.deleteQuizSession(id: session.id)
        XCTAssertEqual(store.quizSessions.count, 0)
    }

    func testAddAndDeleteFlashcardDeck() {
        let store = makeStore()
        let deck  = FlashcardDeck(title: "Biology", subject: nil, cards: [])
        store.addFlashcardDeck(deck)
        XCTAssertEqual(store.flashcardDecks.count, 1)
        store.deleteFlashcardDeck(id: deck.id)
        XCTAssertEqual(store.flashcardDecks.count, 0)
    }

    func testTotalFlashcardsReviewed() {
        let store = makeStore()
        var card1 = Flashcard(front: "Q1", back: "A1", category: "X", difficulty: .beginner)
        card1.reviewCount = 3
        var card2 = Flashcard(front: "Q2", back: "A2", category: "X", difficulty: .beginner)
        card2.reviewCount = 7
        let deck = FlashcardDeck(title: "Test", subject: nil, cards: [card1, card2])
        store.addFlashcardDeck(deck)
        XCTAssertEqual(store.totalFlashcardsReviewed, 10)
    }

    func testLast7DaysActivityReturns7Items() {
        let store = makeStore()
        XCTAssertEqual(store.last7DaysActivity.count, 7)
    }

    func testHasActivityTodayAfterAddingSession() {
        let store = makeStore()
        store.addQuizSession(makeSession(score: 5, total: 10))
        XCTAssertTrue(store.hasActivity(on: Date()))
    }

    func testUpdateQuizSession() {
        let store   = makeStore()
        var session = makeSession(score: 5, total: 10, completed: false)
        store.addQuizSession(session)
        session.completedDate = Date()
        store.updateQuizSession(session)
        XCTAssertTrue(store.quizSessions.first?.isCompleted ?? false)
    }
}
