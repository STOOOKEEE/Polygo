import Foundation
import XCTest
@testable import PolygoCore
@testable import PolygoSRS

final class SM2SchedulerTests: XCTestCase {
    private let scheduler = SM2Scheduler()
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private var cardID: CardID {
        CardID(rawValue: "card-srs-test")!
    }

    func testFirstAndSecondSuccessfulReviewsUseOneAndSixDays() {
        let first = scheduler.nextState(for: cardID, from: nil, rating: .good, at: date)
        XCTAssertEqual(first.cardID, cardID)
        XCTAssertEqual(first.repetition, 1)
        XCTAssertEqual(first.intervalDays, 1)
        XCTAssertEqual(first.dueAt, date.addingTimeInterval(86_400))
        XCTAssertEqual(first.lastReviewedAt, date)

        let secondDate = date.addingTimeInterval(86_400)
        let second = scheduler.nextState(for: cardID, from: first, rating: .good, at: secondDate)
        XCTAssertEqual(second.repetition, 2)
        XCTAssertEqual(second.intervalDays, 6)
        XCTAssertEqual(second.dueAt, secondDate.addingTimeInterval(6 * 86_400))
        XCTAssertEqual(second.lapseCount, 0)
    }

    func testQualityThreeIsAValidSuccessAndUsesSM2EaseFormula() {
        let state = scheduler.nextState(for: cardID, from: nil, rating: .hard, at: date)

        // EF' = 2.5 + (0.1 - 2 * (0.08 + 2 * 0.02)) = 2.36.
        XCTAssertEqual(state.repetition, 1)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.easeFactor, 2.36, accuracy: 0.000_001)
    }

    func testAgainResetsRepetitionAndIncrementsLapse() {
        let state = ReviewState(
            cardID: cardID,
            repetition: 4,
            intervalDays: 20,
            easeFactor: 1.8,
            dueAt: date,
            lastReviewedAt: date.addingTimeInterval(-20 * 86_400),
            lapseCount: 2
        )
        let next = scheduler.nextState(for: cardID, from: state, rating: .again, at: date)

        XCTAssertEqual(next.repetition, 0)
        XCTAssertEqual(next.intervalDays, 1)
        XCTAssertEqual(next.lapseCount, 3)
        XCTAssertEqual(next.dueAt, date.addingTimeInterval(86_400))
        XCTAssertEqual(next.lastReviewedAt, date)
        XCTAssertEqual(next.easeFactor, 1.3, accuracy: 0.000_001)
    }

    func testEaseFactorNeverFallsBelowMinimum() {
        var state: ReviewState? = nil
        for index in 0..<20 {
            state = scheduler.nextState(
                for: cardID,
                from: state,
                rating: .again,
                at: date.addingTimeInterval(Double(index) * 86_400)
            )
        }
        XCTAssertEqual(state?.easeFactor ?? 0, SM2Scheduler.minimumEaseFactor, accuracy: 0.000_001)
    }

    func testSameInputProducesExactlyTheSameState() {
        let previous = ReviewState(cardID: cardID, repetition: 3, intervalDays: 12, easeFactor: 2.2, dueAt: date)

        let first = scheduler.nextState(for: cardID, from: previous, rating: .easy, at: date)
        let second = scheduler.nextState(for: cardID, from: previous, rating: .easy, at: date)

        XCTAssertEqual(first, second)
    }

    func testLaterSuccessesMultiplyThePreviousIntervalByUpdatedEase() {
        let previous = ReviewState(cardID: cardID, repetition: 2, intervalDays: 6, easeFactor: 2.5, dueAt: date)

        let next = scheduler.nextState(for: cardID, from: previous, rating: .easy, at: date)

        // Easy raises EF to 2.6, so the six-day interval becomes 16 days.
        XCTAssertEqual(next.repetition, 3)
        XCTAssertEqual(next.intervalDays, 16)
        XCTAssertEqual(next.easeFactor, 2.6, accuracy: 0.000_001)
        XCTAssertEqual(next.dueAt, date.addingTimeInterval(16 * 86_400))
    }

    func testTransitionCarriesHistoryWithoutChangingState() {
        let transition = scheduler.review(for: cardID, from: nil, rating: .easy, at: date)

        XCTAssertEqual(transition.state.repetition, 1)
        XCTAssertEqual(transition.historyEntry.cardID, cardID)
        XCTAssertEqual(transition.historyEntry.rating, .easy)
        XCTAssertEqual(transition.historyEntry.reviewedAt, date)
        XCTAssertEqual(transition.historyEntry.previousRepetition, 0)
        XCTAssertEqual(transition.historyEntry.intervalDays, 1)
        XCTAssertEqual(transition.historyEntry.lapseCount, 0)
    }
}

final class ReviewDeckTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func card(_ rawValue: String) -> CardID {
        CardID(rawValue: rawValue)!
    }

    private func state(_ rawValue: String, dueAfter seconds: TimeInterval) -> ReviewState {
        ReviewState(cardID: card(rawValue), dueAt: now.addingTimeInterval(seconds))
    }

    func testDueQueueSortsByDateThenStableCardIDAndCanFilter() {
        let deck = ReviewDeck(states: [
            card("z-card"): state("z-card", dueAfter: 0),
            card("b-card"): state("b-card", dueAfter: -10),
            card("a-card"): state("a-card", dueAfter: -10),
            card("future"): state("future", dueAfter: 1)
        ])

        XCTAssertEqual(deck.dueCardIDs(at: now), [card("a-card"), card("b-card"), card("z-card")])
        XCTAssertEqual(deck.dueCardIDs(at: now, limit: 2), [card("a-card"), card("b-card")])
        XCTAssertEqual(
            deck.dueCards(at: now, matching: [card("z-card"), card("a-card")]).map(\.cardID),
            [card("a-card"), card("z-card")]
        )
    }

    func testSuspendingRemovesCardFromDueQueueAndResumeUsesInjectedDate() {
        let id = card("suspended")
        let deck = ReviewDeck(states: [id: ReviewState(cardID: id, dueAt: now)])
        let suspended = deck.suspending(cardID: id, at: now)

        XCTAssertTrue(suspended.suspendedCardIDs.contains(id))
        XCTAssertTrue(suspended.dueCards(at: now).isEmpty)
        XCTAssertEqual(suspended.state(for: id)?.dueAt, Date.distantFuture)

        let resumedAt = now.addingTimeInterval(2 * 86_400)
        let resumed = suspended.resuming(cardID: id, at: resumedAt)
        XCTAssertFalse(resumed.suspendedCardIDs.contains(id))
        XCTAssertEqual(resumed.dueCards(at: resumedAt).map(\.cardID), [id])
    }

    func testResetClearsHistoryAndMakesCardNew() {
        let id = card("reset-me")
        let first = ReviewDeck(states: [id: ReviewState(cardID: id, dueAt: now)])
            .reviewing(cardID: id, rating: .good, at: now)
        XCTAssertEqual(first.history[id]?.count, 1)

        let resetAt = now.addingTimeInterval(3 * 86_400)
        let reset = first.resetting(cardID: id, at: resetAt)
        let state = reset.state(for: id)
        XCTAssertEqual(state?.repetition, 0)
        XCTAssertEqual(state?.intervalDays, 0)
        XCTAssertEqual(state?.lapseCount, 0)
        XCTAssertEqual(state?.dueAt, resetAt)
        XCTAssertNil(reset.history[id])
    }
}
