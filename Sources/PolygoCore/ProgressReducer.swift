import Foundation

/// The core fallback transition is kept deterministic so a local store can
/// rebuild a snapshot before the optional SRS target is linked. PolygoSRS
/// exposes the same rule through `ReviewScheduler` for app composition.
public enum CoreReviewPlanner {
    public static func nextState(cardID: CardID, from state: ReviewState?, rating: ReviewRating, at date: Date) -> ReviewState {
        let previous = state ?? ReviewState(cardID: cardID, dueAt: date)
        let quality = rating.rawValue
        let easeDelta = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
        let ease = max(1.3, previous.easeFactor + easeDelta)

        if quality < ReviewRating.hard.rawValue {
            return ReviewState(cardID: cardID, repetition: 0, intervalDays: 1, easeFactor: ease, dueAt: date.addingTimeInterval(86_400), lastReviewedAt: date, lapseCount: previous.lapseCount + 1)
        }

        let repetition = previous.repetition + 1
        let interval: Int
        if repetition == 1 {
            interval = 1
        } else if repetition == 2 {
            interval = 6
        } else {
            interval = max(1, Int((Double(max(1, previous.intervalDays)) * ease).rounded()))
        }
        return ReviewState(cardID: cardID, repetition: repetition, intervalDays: interval, easeFactor: ease, dueAt: date.addingTimeInterval(Double(interval) * 86_400), lastReviewedAt: date, lapseCount: previous.lapseCount)
    }
}

public struct DefaultProgressReducer: ProgressReducer, Sendable {
    public init() {}

    public func reduce(_ snapshot: ProgressSnapshot, event: ProgressEvent) throws -> ProgressSnapshot {
        if snapshot.processedEventIDs.contains(event.eventID) {
            return snapshot
        }

        var profile = snapshot.profile
        if let current = profile, current.id != event.profileID {
            throw DomainError.eventProfileMismatch
        }

        var lessons = snapshot.lessonProgress
        var reviews = snapshot.reviewStates
        var activeRoute = snapshot.activeRoute

        switch event.payload {
        case .onboardingCompleted(let newProfile):
            guard newProfile.id == event.profileID else { throw DomainError.eventProfileMismatch }
            profile = newProfile

        case .lessonStarted(let lessonID, let date):
            let existing = lessons[lessonID] ?? LessonProgress(lessonID: lessonID)
            lessons[lessonID] = LessonProgress(
                lessonID: existing.lessonID,
                completedObjectiveIDs: existing.completedObjectiveIDs,
                completedAt: existing.completedAt,
                attemptCount: existing.attemptCount,
                bestScore: existing.bestScore,
                lastOpenedAt: date,
                answeredExerciseIDs: existing.answeredExerciseIDs,
                correctExerciseIDs: existing.correctExerciseIDs,
                mistakeExerciseIDs: existing.mistakeExerciseIDs,
                lastEvaluations: existing.lastEvaluations,
                currentExerciseIndex: existing.currentExerciseIndex,
                currentExerciseID: existing.currentExerciseID,
                pendingAnswer: existing.pendingAnswer,
                pendingEvaluation: existing.pendingEvaluation,
                dialogueDrafts: existing.dialogueDrafts,
                dialogueResults: existing.dialogueResults
            )
            activeRoute = "lesson/\(lessonID.rawValue)"

        case .lessonRestarted(let lessonID, let date):
            // Restarting is an explicit learner action. Clear the previous
            // lesson session so its old answer/feedback cannot be mistaken
            // for the new attempt, while retaining the fact that the lesson
            // has been opened in the active route.
            lessons[lessonID] = LessonProgress(
                lessonID: lessonID,
                lastOpenedAt: date
            )
            activeRoute = "lesson/\(lessonID.rawValue)"

        case .lessonCheckpointSaved(let lessonID, let exerciseIndex, let exerciseID, let answer, let evaluation, let dialogueDrafts, let dialogueResults, _):
            let existing = lessons[lessonID] ?? LessonProgress(lessonID: lessonID)
            lessons[lessonID] = LessonProgress(
                lessonID: existing.lessonID,
                completedObjectiveIDs: existing.completedObjectiveIDs,
                completedAt: existing.completedAt,
                attemptCount: existing.attemptCount,
                bestScore: existing.bestScore,
                lastOpenedAt: existing.lastOpenedAt,
                answeredExerciseIDs: existing.answeredExerciseIDs,
                correctExerciseIDs: existing.correctExerciseIDs,
                mistakeExerciseIDs: existing.mistakeExerciseIDs,
                lastEvaluations: existing.lastEvaluations,
                currentExerciseIndex: exerciseIndex,
                currentExerciseID: exerciseID,
                pendingAnswer: answer,
                pendingEvaluation: evaluation,
                dialogueDrafts: dialogueDrafts,
                dialogueResults: dialogueResults
            )

        case .exerciseEvaluated(let lessonID, _, let evaluation, _):
            let existing = lessons[lessonID] ?? LessonProgress(lessonID: lessonID)
            var answered = existing.answeredExerciseIDs
            var correct = existing.correctExerciseIDs
            var mistakes = existing.mistakeExerciseIDs
            var evaluations = existing.lastEvaluations
            answered.insert(evaluation.exerciseID)
            evaluations[evaluation.exerciseID] = evaluation
            if evaluation.accepted && evaluation.score >= 0.8 {
                correct.insert(evaluation.exerciseID)
                mistakes.remove(evaluation.exerciseID)
            } else {
                mistakes.insert(evaluation.exerciseID)
                correct.remove(evaluation.exerciseID)
            }
            let score = answered.isEmpty ? 0 : Double(correct.count) / Double(answered.count)
            lessons[lessonID] = LessonProgress(
                lessonID: lessonID,
                completedObjectiveIDs: existing.completedObjectiveIDs,
                completedAt: existing.completedAt,
                attemptCount: existing.attemptCount + 1,
                bestScore: max(existing.bestScore, score),
                lastOpenedAt: existing.lastOpenedAt,
                answeredExerciseIDs: answered,
                correctExerciseIDs: correct,
                mistakeExerciseIDs: mistakes,
                lastEvaluations: evaluations,
                currentExerciseIndex: existing.currentExerciseIndex,
                currentExerciseID: existing.currentExerciseID,
                pendingAnswer: existing.pendingAnswer,
                pendingEvaluation: existing.pendingEvaluation,
                dialogueDrafts: existing.dialogueDrafts,
                dialogueResults: existing.dialogueResults
            )

        case .lessonCompleted(let lessonID, let date):
            let existing = lessons[lessonID] ?? LessonProgress(lessonID: lessonID)
            lessons[lessonID] = LessonProgress(
                lessonID: lessonID,
                completedObjectiveIDs: existing.completedObjectiveIDs,
                completedAt: date,
                attemptCount: existing.attemptCount,
                bestScore: existing.bestScore,
                lastOpenedAt: existing.lastOpenedAt,
                answeredExerciseIDs: existing.answeredExerciseIDs,
                correctExerciseIDs: existing.correctExerciseIDs,
                mistakeExerciseIDs: existing.mistakeExerciseIDs,
                lastEvaluations: existing.lastEvaluations,
                currentExerciseIndex: existing.currentExerciseIndex,
                currentExerciseID: existing.currentExerciseID,
                pendingAnswer: existing.pendingAnswer,
                pendingEvaluation: existing.pendingEvaluation,
                dialogueDrafts: existing.dialogueDrafts,
                dialogueResults: existing.dialogueResults
            )

        case .flashcardAdded(let cardID, let date):
            if reviews[cardID] == nil {
                reviews[cardID] = ReviewState(cardID: cardID, dueAt: date)
            }

        case .flashcardReviewed(let cardID, let rating, let date):
            reviews[cardID] = CoreReviewPlanner.nextState(cardID: cardID, from: reviews[cardID], rating: rating, at: date)

        case .flashcardSuspended(let cardID, let suspended, let date):
            if suspended {
                reviews[cardID] = ReviewState(cardID: cardID, repetition: reviews[cardID]?.repetition ?? 0, intervalDays: reviews[cardID]?.intervalDays ?? 0, easeFactor: reviews[cardID]?.easeFactor ?? 2.5, dueAt: Date.distantFuture, lastReviewedAt: reviews[cardID]?.lastReviewedAt, lapseCount: reviews[cardID]?.lapseCount ?? 0)
            } else if let current = reviews[cardID] {
                reviews[cardID] = ReviewState(cardID: cardID, repetition: current.repetition, intervalDays: current.intervalDays, easeFactor: current.easeFactor, dueAt: date, lastReviewedAt: current.lastReviewedAt, lapseCount: current.lapseCount)
            }

        case .recordingSaved, .drawingSaved:
            break
        }

        var processed = snapshot.processedEventIDs
        processed.insert(event.eventID)
        return ProgressSnapshot(
            schemaVersion: snapshot.schemaVersion,
            profile: profile,
            lessonProgress: lessons,
            reviewStates: reviews,
            lastEventLamport: max(snapshot.lastEventLamport, event.lamport),
            generatedAt: event.occurredAt,
            processedEventIDs: processed,
            activeRoute: activeRoute
        )
    }
}

public extension ProgressSnapshot {
    func dueCards(at date: Date = Date()) -> [ReviewState] {
        reviewStates.values.filter { $0.dueAt <= date }.sorted {
            if $0.dueAt != $1.dueAt { return $0.dueAt < $1.dueAt }
            return $0.cardID.rawValue < $1.cardID.rawValue
        }
    }

    func difficultCardIDs() -> [CardID] {
        reviewStates.values.filter { $0.lapseCount > 0 }.sorted { $0.cardID.rawValue < $1.cardID.rawValue }.map(\.cardID)
    }
}
