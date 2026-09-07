import Foundation
import PolygoCore

/// An immutable collection of card states and their optional local history.
/// The deck is deliberately independent of SwiftUI and of persistence; a
/// store can serialize it or derive it from the authoritative event log.
public struct ReviewDeck: Codable, Hashable, Sendable {
    public let states: [CardID: ReviewState]
    public let history: [CardID: [ReviewHistoryEntry]]
    public let suspendedCardIDs: Set<CardID>

    public init(
        states: [CardID: ReviewState] = [:],
        history: [CardID: [ReviewHistoryEntry]] = [:],
        suspendedCardIDs: Set<CardID> = []
    ) {
        self.states = states
        self.history = history
        self.suspendedCardIDs = suspendedCardIDs
    }

    public var count: Int { states.count }
    public var isEmpty: Bool { states.isEmpty }

    public func state(for cardID: CardID) -> ReviewState? {
        states[cardID]
    }

    /// Returns due cards sorted by due date and then by their stable opaque ID.
    /// This tie-breaker keeps two devices and two runs in the same order.
    public func dueCards(at date: Date, limit: Int? = nil) -> [ReviewState] {
        let sorted = states.values
            .filter { !suspendedCardIDs.contains($0.cardID) && $0.dueAt <= date }
            .sorted(by: ReviewDeck.order)
        guard let limit else { return sorted }
        return Array(sorted.prefix(max(0, limit)))
    }

    public func dueCardIDs(at date: Date, limit: Int? = nil) -> [CardID] {
        dueCards(at: date, limit: limit).map(\.cardID)
    }

    /// A named alias useful to callers that model the due list as a queue.
    public func queue(at date: Date, limit: Int? = nil) -> [ReviewState] {
        dueCards(at: date, limit: limit)
    }

    /// Filters the deck to a known set of IDs and applies the same due ordering.
    public func dueCards(
        at date: Date,
        matching cardIDs: Set<CardID>,
        limit: Int? = nil
    ) -> [ReviewState] {
        let filtered = states.values
            .filter {
                cardIDs.contains($0.cardID)
                    && !suspendedCardIDs.contains($0.cardID)
                    && $0.dueAt <= date
            }
            .sorted(by: ReviewDeck.order)
        guard let limit else { return filtered }
        return Array(filtered.prefix(max(0, limit)))
    }

    public func cards(matching cardIDs: Set<CardID>) -> [ReviewState] {
        states.values
            .filter { cardIDs.contains($0.cardID) }
            .sorted(by: ReviewDeck.order)
    }

    /// Adds a new card due at the supplied instant. Existing states are kept;
    /// adding an already-known card is idempotent.
    public func adding(cardID: CardID, at date: Date) -> ReviewDeck {
        guard states[cardID] == nil else { return self }
        var next = states
        next[cardID] = ReviewState(cardID: cardID, dueAt: date)
        return ReviewDeck(states: next, history: history, suspendedCardIDs: suspendedCardIDs)
    }

    public func adding(_ state: ReviewState) -> ReviewDeck {
        var next = states
        next[state.cardID] = state
        return ReviewDeck(states: next, history: history, suspendedCardIDs: suspendedCardIDs)
    }

    /// Applies one review and appends its event-shaped history record.
    /// Suspended cards are ignored until explicitly resumed.
    public func reviewing(
        cardID: CardID,
        rating: ReviewRating,
        at date: Date,
        scheduler: any ReviewScheduler = SM2Scheduler()
    ) -> ReviewDeck {
        guard let previous = states[cardID], !suspendedCardIDs.contains(cardID) else {
            return self
        }
        let transition = scheduler.transition(for: cardID, from: previous, rating: rating, at: date)
        var nextStates = states
        nextStates[cardID] = transition.state
        var nextHistory = history
        nextHistory[cardID, default: []].append(transition.historyEntry)
        return ReviewDeck(states: nextStates, history: nextHistory, suspendedCardIDs: suspendedCardIDs)
    }

    /// Convenience spelling for clients that use a verb on the deck.
    public func review(
        cardID: CardID,
        rating: ReviewRating,
        at date: Date,
        scheduler: any ReviewScheduler = SM2Scheduler()
    ) -> ReviewDeck {
        reviewing(cardID: cardID, rating: rating, at: date, scheduler: scheduler)
    }

    public func suspending(cardID: CardID, at date: Date) -> ReviewDeck {
        let scheduler = SM2Scheduler()
        let current = states[cardID] ?? ReviewState(cardID: cardID, dueAt: date)
        var next = states
        next[cardID] = scheduler.suspend(current, at: date)
        var suspended = suspendedCardIDs
        suspended.insert(cardID)
        return ReviewDeck(states: next, history: history, suspendedCardIDs: suspended)
    }

    public func suspend(cardID: CardID, at date: Date) -> ReviewDeck {
        suspending(cardID: cardID, at: date)
    }

    public func resuming(cardID: CardID, at date: Date) -> ReviewDeck {
        guard let current = states[cardID] else { return self }
        var next = states
        next[cardID] = SM2Scheduler().resume(current, at: date)
        var suspended = suspendedCardIDs
        suspended.remove(cardID)
        return ReviewDeck(states: next, history: history, suspendedCardIDs: suspended)
    }

    public func resume(cardID: CardID, at date: Date) -> ReviewDeck {
        resuming(cardID: cardID, at: date)
    }

    /// Clears a card's scheduling statistics and history, making it due now at
    /// the injected instant.
    public func resetting(cardID: CardID, at date: Date) -> ReviewDeck {
        var next = states
        next[cardID] = ReviewState(cardID: cardID, dueAt: date)
        var nextHistory = history
        nextHistory.removeValue(forKey: cardID)
        var suspended = suspendedCardIDs
        suspended.remove(cardID)
        return ReviewDeck(states: next, history: nextHistory, suspendedCardIDs: suspended)
    }

    public func reset(cardID: CardID, at date: Date) -> ReviewDeck {
        resetting(cardID: cardID, at: date)
    }

    private static func order(_ lhs: ReviewState, _ rhs: ReviewState) -> Bool {
        if lhs.dueAt != rhs.dueAt { return lhs.dueAt < rhs.dueAt }
        return lhs.cardID.rawValue < rhs.cardID.rawValue
    }
}

private extension ReviewScheduler {
    func transition(
        for cardID: CardID,
        from state: ReviewState?,
        rating: ReviewRating,
        at date: Date
    ) -> ReviewTransition {
        if let sm2 = self as? SM2Scheduler {
            return sm2.review(for: cardID, from: state, rating: rating, at: date)
        }
        let next = nextState(for: cardID, from: state, rating: rating, at: date)
        let previous = state ?? ReviewState(cardID: cardID, dueAt: date)
        return ReviewTransition(
            state: next,
            historyEntry: ReviewHistoryEntry(
                cardID: cardID,
                rating: rating,
                reviewedAt: date,
                previousRepetition: previous.repetition,
                previousIntervalDays: previous.intervalDays,
                previousEaseFactor: previous.easeFactor,
                repetition: next.repetition,
                intervalDays: next.intervalDays,
                easeFactor: next.easeFactor,
                lapseCount: next.lapseCount
            )
        )
    }
}

public typealias SRSDeck = ReviewDeck
