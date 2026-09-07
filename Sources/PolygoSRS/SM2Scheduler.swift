import Foundation
import PolygoCore

/// A deterministic scheduler for the classic SM-2 algorithm.
///
/// The scheduler deliberately receives both the card identifier and the date
/// of the review.  It never reads the wall clock, which makes rebuilding a
/// progress snapshot and testing an event log reproducible.
public protocol ReviewScheduler: Sendable {
    func nextState(
        for cardID: CardID,
        from state: ReviewState?,
        rating: ReviewRating,
        at date: Date
    ) -> ReviewState
}

/// The result of a review, including the event-shaped information needed by a
/// store that keeps a review history separately from `ReviewState`.
public struct ReviewTransition: Codable, Hashable, Sendable {
    public let state: ReviewState
    public let historyEntry: ReviewHistoryEntry

    public init(state: ReviewState, historyEntry: ReviewHistoryEntry) {
        self.state = state
        self.historyEntry = historyEntry
    }
}

/// A single immutable review record.  `ReviewState` remains the compact cache
/// used by PolygoCore; this value lets a persistence layer retain every
/// transition without putting storage concerns in the scheduler.
public struct ReviewHistoryEntry: Codable, Hashable, Sendable {
    public let cardID: CardID
    public let rating: ReviewRating
    public let reviewedAt: Date
    public let previousRepetition: Int
    public let previousIntervalDays: Int
    public let previousEaseFactor: Double
    public let repetition: Int
    public let intervalDays: Int
    public let easeFactor: Double
    public let lapseCount: Int

    public init(
        cardID: CardID,
        rating: ReviewRating,
        reviewedAt: Date,
        previousRepetition: Int,
        previousIntervalDays: Int,
        previousEaseFactor: Double,
        repetition: Int,
        intervalDays: Int,
        easeFactor: Double,
        lapseCount: Int
    ) {
        self.cardID = cardID
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.previousRepetition = previousRepetition
        self.previousIntervalDays = previousIntervalDays
        self.previousEaseFactor = previousEaseFactor
        self.repetition = repetition
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.lapseCount = lapseCount
    }
}

/// Short aliases for clients that call a transition a review result or an
/// entry a review record.  They keep the public vocabulary flexible while
/// preserving one canonical representation on disk.
public typealias ReviewResult = ReviewTransition
public typealias ReviewRecord = ReviewHistoryEntry

public struct SM2Scheduler: ReviewScheduler, Sendable {
    public static let defaultEaseFactor = 2.5
    public static let minimumEaseFactor = 1.3
    public static let firstIntervalDays = 1
    public static let secondIntervalDays = 6
    public static let secondsPerDay: TimeInterval = 86_400

    public init() {}

    public func nextState(
        for cardID: CardID,
        from state: ReviewState?,
        rating: ReviewRating,
        at date: Date
    ) -> ReviewState {
        review(for: cardID, from: state, rating: rating, at: date).state
    }

    /// Computes both the compact next state and an immutable history entry.
    /// This is the same pure transition as `nextState`; no clock or random
    /// source is consulted.
    public func review(
        for cardID: CardID,
        from state: ReviewState?,
        rating: ReviewRating,
        at date: Date
    ) -> ReviewTransition {
        let previous = state ?? ReviewState(cardID: cardID, dueAt: date)
        let quality = Self.quality(for: rating)
        let ease = Self.updatedEaseFactor(previous.easeFactor, quality: quality)

        let repetition: Int
        let intervalDays: Int
        let lapseCount: Int

        if quality < 3 {
            // A lapse starts the learning sequence again and is always made
            // available tomorrow.  Keep the updated ease factor so repeated
            // lapses gradually make the item harder.
            repetition = 0
            intervalDays = Self.firstIntervalDays
            lapseCount = previous.lapseCount + 1
        } else {
            repetition = previous.repetition + 1
            lapseCount = previous.lapseCount
            switch repetition {
            case 1:
                intervalDays = Self.firstIntervalDays
            case 2:
                intervalDays = Self.secondIntervalDays
            default:
                let base = Double(max(Self.firstIntervalDays, previous.intervalDays))
                intervalDays = max(Self.firstIntervalDays, Int((base * ease).rounded()))
            }
        }

        let next = ReviewState(
            cardID: cardID,
            repetition: repetition,
            intervalDays: intervalDays,
            easeFactor: ease,
            dueAt: date.addingTimeInterval(Double(intervalDays) * Self.secondsPerDay),
            lastReviewedAt: date,
            lapseCount: lapseCount
        )
        let entry = ReviewHistoryEntry(
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
        return ReviewTransition(state: next, historyEntry: entry)
    }

    /// Resets a card to a new-card state at the supplied instant.
    public func reset(cardID: CardID, at date: Date) -> ReviewState {
        ReviewState(cardID: cardID, dueAt: date)
    }

    /// Marks a state as suspended while retaining its learning statistics.
    /// Suspension is represented by a distant due date because the core state
    /// is intentionally a small, backwards-compatible value type.
    public func suspend(_ state: ReviewState, at _: Date) -> ReviewState {
        ReviewState(
            cardID: state.cardID,
            repetition: state.repetition,
            intervalDays: state.intervalDays,
            easeFactor: state.easeFactor,
            dueAt: .distantFuture,
            lastReviewedAt: state.lastReviewedAt,
            lapseCount: state.lapseCount
        )
    }

    /// Resumes a suspended state at the supplied instant.
    public func resume(_ state: ReviewState, at date: Date) -> ReviewState {
        ReviewState(
            cardID: state.cardID,
            repetition: state.repetition,
            intervalDays: state.intervalDays,
            easeFactor: state.easeFactor,
            dueAt: date,
            lastReviewedAt: state.lastReviewedAt,
            lapseCount: state.lapseCount
        )
    }

    private static func quality(for rating: ReviewRating) -> Int {
        // ReviewRating is an Int enum.  Clamping here protects the transition
        // if a future decoder or migration supplies an out-of-range value.
        min(5, max(0, rating.rawValue))
    }

    private static func updatedEaseFactor(_ old: Double, quality: Int) -> Double {
        let safeOld = old.isFinite ? old : defaultEaseFactor
        let delta = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
        return max(minimumEaseFactor, safeOld + delta)
    }
}
