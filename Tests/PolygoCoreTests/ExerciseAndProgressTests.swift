import Foundation
import XCTest
@testable import PolygoCore

final class ExerciseAndProgressTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let engine = DefaultExerciseEngine()
    private let reducer = DefaultProgressReducer()

    private func exerciseID(_ rawValue: String) -> ExerciseID {
        ExerciseID(rawValue: rawValue)!
    }

    private func lessonID(_ rawValue: String = "lesson-test") -> LessonID {
        LessonID(rawValue: rawValue)!
    }

    private func blockID(_ rawValue: String = "block-test") -> BlockID {
        BlockID(rawValue: rawValue)!
    }

    private func cardID(_ rawValue: String = "card-test") -> CardID {
        CardID(rawValue: rawValue)!
    }

    private func profileID(_ rawValue: String = "profile-test") -> ProfileID {
        ProfileID(rawValue: rawValue)!
    }

    private func deviceID(_ rawValue: String = "device-test") -> DeviceID {
        DeviceID(rawValue: rawValue)!
    }

    private func event(
        _ rawValue: String,
        profileID: ProfileID,
        lamport: UInt64,
        payload: ProgressEventPayload,
        at date: Date? = nil
    ) -> ProgressEvent {
        ProgressEvent(
            eventID: EventID(rawValue: rawValue)!,
            profileID: profileID,
            deviceID: deviceID(),
            lamport: lamport,
            occurredAt: date ?? now,
            payload: payload
        )
    }

    private func profile(_ id: ProfileID) -> LearnerProfile {
        LearnerProfile(
            id: id,
            goal: .conversation,
            dailyMinutes: 10,
            selectedCourseID: CourseID(rawValue: "mandarin-starter")!,
            createdAt: now
        )
    }

    private func header(_ rawValue: String = "exercise-test") -> ExerciseHeader {
        ExerciseHeader(
            id: exerciseID(rawValue),
            prompt: .unchecked(["fr": "Réponds"]),
            objectiveIDs: ["objective-test"]
        )
    }

    private func choiceSpec(correctChoiceID: String = "right") -> ExerciseSpec {
        .choice(
            ChoiceExercise(
                header: header(),
                choices: [
                    Choice(id: "left", label: .unchecked(["fr": "Non"])) ,
                    Choice(id: correctChoiceID, label: .unchecked(["fr": "Oui"]))
                ],
                correctChoiceID: correctChoiceID
            )
        )
    }

    func testTextNormalizerFoldsPinyinDiacriticsPunctuationAndCase() {
        XCTAssertEqual(TextNormalizer.normalize("  Nǐ, hǎo！ "), "nihao")
        XCTAssertEqual(TextNormalizer.normalize("你好？\n"), "你好")
        XCTAssertEqual(TextNormalizer.normalize("Nǐ hǎo", caseSensitive: true), "Nǐhǎo")
        XCTAssertEqual(TextNormalizer.normalize("ABC", caseSensitive: true), "ABC")
        XCTAssertEqual(TextNormalizer.normalize("ABC", caseSensitive: false), "abc")
    }

    func testFillBlankUsesNormalizedAcceptedVariantsAndHonorsCaseSensitivity() {
        let normalized = ExerciseSpec.fillBlank(
            FillBlankExercise(
                header: header(),
                sentence: "我___安。",
                acceptedAnswers: ["叫"],
                caseSensitive: false
            )
        )
        let accepted = engine.evaluate(spec: normalized, answer: .text(" 叫。 "))
        XCTAssertTrue(accepted.accepted)
        XCTAssertEqual(accepted.outcome, .correct)
        XCTAssertEqual(accepted.normalizedAnswer, "叫")

        let caseSensitive = ExerciseSpec.fillBlank(
            FillBlankExercise(
                header: header("exercise-case"),
                sentence: "___",
                acceptedAnswers: ["ABC"],
                caseSensitive: true
            )
        )
        XCTAssertFalse(engine.evaluate(spec: caseSensitive, answer: .text("abc")).accepted)
        XCTAssertTrue(engine.evaluate(spec: caseSensitive, answer: .text("ABC")).accepted)
    }

    func testEngineReportsWrongAnswerShapeAndInvalidEvaluationScores() throws {
        let wrongShape = engine.evaluate(spec: choiceSpec(), answer: .text("right"))
        XCTAssertFalse(wrongShape.accepted)
        XCTAssertEqual(wrongShape.outcome, .incorrect)
        XCTAssertEqual(wrongShape.score, 0)
        XCTAssertEqual(wrongShape.normalizedAnswer, nil)

        XCTAssertThrowsError(
            try ExerciseEvaluation(
                exerciseID: exerciseID("invalid-score"),
                outcome: .correct,
                score: 1.01,
                feedback: .unchecked(["fr": "invalide"]),
                accepted: true
            )
        ) { error in
            XCTAssertEqual(error as? DomainError, .invalidScore(1.01))
        }
    }

    func testSpeakingComparesTextOnlyAndExposesSelfRatingWhenTranscriptDiffers() {
        let spec = ExerciseSpec.speaking(
            SpeakingExercise(
                header: header(),
                referenceText: "你好",
                referencePinyin: "nǐ hǎo",
                acceptedTranscripts: ["你好", "nǐ hǎo"],
                allowSelfRating: true
            )
        )

        let matching = engine.evaluate(
            spec: spec,
            answer: .speech(SpeechAnswer(transcript: "Nǐ hǎo！", confidence: 0.01))
        )
        XCTAssertTrue(matching.accepted)
        XCTAssertEqual(matching.outcome, .correct)
        XCTAssertEqual(matching.score, 1)
        XCTAssertEqual(matching.normalizedAnswer, "nihao")

        let mismatch = engine.evaluate(
            spec: spec,
            answer: .speech(SpeechAnswer(transcript: "再见", confidence: 0.99))
        )
        XCTAssertFalse(mismatch.accepted)
        XCTAssertEqual(mismatch.outcome, .partial)
        XCTAssertEqual(mismatch.score, 0.5)

        let selfReported = engine.evaluate(spec: spec, answer: .selfRating(.good))
        XCTAssertTrue(selfReported.accepted)
        XCTAssertEqual(selfReported.outcome, .selfReported)
        XCTAssertEqual(selfReported.score, 0.9)
        XCTAssertEqual(selfReported.normalizedAnswer, "good")
    }

    func testSelfReportedRatingsAreDeterministicAndFlashcardRequiresAChoice() {
        let spec = ExerciseSpec.flashcard(
            FlashcardExercise(header: header("exercise-card"), cardID: cardID())
        )
        let expected: [(SelfRating, Double)] = [
            (.again, 0.2),
            (.hard, 0.6),
            (.good, 0.9),
            (.easy, 1)
        ]

        for (rating, score) in expected {
            let result = engine.evaluate(spec: spec, answer: .selfRating(rating))
            XCTAssertTrue(result.accepted)
            XCTAssertEqual(result.outcome, .selfReported)
            XCTAssertEqual(result.score, score)
        }

        let unavailable = engine.evaluate(spec: spec, answer: .choice(choiceID: "good"))
        XCTAssertFalse(unavailable.accepted)
        XCTAssertEqual(unavailable.outcome, .unavailable)
        XCTAssertEqual(unavailable.score, 0)
    }

    func testProgressionRecordsOnboardingLessonAttemptCompletionAndCards() throws {
        let profileKey = profileID()
        let lessonKey = lessonID()
        let cardKey = cardID()
        let evaluation = try ExerciseEvaluation(
            exerciseID: exerciseID("exercise-test"),
            outcome: .correct,
            score: 1,
            feedback: .unchecked(["fr": "Bonne réponse."]),
            accepted: true,
            normalizedAnswer: "right"
        )

        var snapshot = ProgressSnapshot.empty(now: now)
        snapshot = try reducer.reduce(
            snapshot,
            event("onboarding", profileID: profileKey, lamport: 1, payload: .onboardingCompleted(profile: profileIDValue(profileKey)))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("lesson-started", profileID: profileKey, lamport: 2, payload: .lessonStarted(lessonID: lessonKey, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("exercise-correct", profileID: profileKey, lamport: 3, payload: .exerciseEvaluated(lessonID: lessonKey, blockID: blockID(), evaluation: evaluation, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("lesson-completed", profileID: profileKey, lamport: 4, payload: .lessonCompleted(lessonID: lessonKey, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("card-added", profileID: profileKey, lamport: 5, payload: .flashcardAdded(cardID: cardKey, at: now))
        )

        let progress = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(snapshot.profile?.id, profileKey)
        XCTAssertEqual(progress.lastOpenedAt, now)
        XCTAssertEqual(progress.completedAt, now)
        XCTAssertEqual(progress.attemptCount, 1)
        XCTAssertEqual(progress.answeredExerciseIDs, Set([evaluation.exerciseID]))
        XCTAssertEqual(progress.correctExerciseIDs, Set([evaluation.exerciseID]))
        XCTAssertTrue(progress.mistakeExerciseIDs.isEmpty)
        XCTAssertEqual(progress.bestScore, 1)
        XCTAssertEqual(snapshot.activeRoute, "lesson/lesson-test")
        XCTAssertEqual(snapshot.reviewStates[cardKey]?.dueAt, now)
        XCTAssertEqual(snapshot.dueCards(at: now).map(\.cardID), [cardKey])
    }

    func testProgressionIsIdempotentForTheSameEventAndCardAddsDoNotReplaceState() throws {
        let profileID = profileID("profile-idempotence")
        let cardID = cardID("card-idempotence")
        let add = event(
            "card-add-idempotent",
            profileID: profileID,
            lamport: 1,
            payload: .flashcardAdded(cardID: cardID, at: now)
        )
        let first = try reducer.reduce(.empty(now: now), add)
        let sameEvent = try reducer.reduce(first, add)
        XCTAssertEqual(sameEvent, first)
        XCTAssertEqual(sameEvent.processedEventIDs.count, 1)

        let reviewed = try reducer.reduce(
            first,
            event(
                "card-review-idempotence",
                profileID: profileID,
                lamport: 2,
                payload: .flashcardReviewed(cardID: cardID, rating: .good, at: now)
            )
        )
        let stateAfterReview = try XCTUnwrap(reviewed.reviewStates[cardID])
        let secondAdd = try reducer.reduce(
            reviewed,
            event(
                "card-add-again",
                profileID: profileID,
                lamport: 3,
                payload: .flashcardAdded(cardID: cardID, at: now.addingTimeInterval(30))
            )
        )
        XCTAssertEqual(secondAdd.reviewStates.count, 1)
        XCTAssertEqual(secondAdd.reviewStates[cardID], stateAfterReview)
    }

    func testCorrectingAnExerciseKeepsOneAnswerCountAndUpdatesTheBestResult() throws {
        let profileID = profileID("profile-attempts")
        let lessonID = lessonID("lesson-attempts")
        let exerciseKey = exerciseID("exercise-attempts")
        let wrong = try ExerciseEvaluation(
            exerciseID: exerciseKey,
            outcome: .incorrect,
            score: 0,
            feedback: .unchecked(["fr": "Réessaie."]),
            accepted: false
        )
        let correct = try ExerciseEvaluation(
            exerciseID: exerciseKey,
            outcome: .correct,
            score: 1,
            feedback: .unchecked(["fr": "Bonne réponse."]),
            accepted: true
        )

        var snapshot = ProgressSnapshot.empty(now: now)
        snapshot = try reducer.reduce(
            snapshot,
            event("attempt-wrong", profileID: profileID, lamport: 1, payload: .exerciseEvaluated(lessonID: lessonID, blockID: blockID("block-attempts"), evaluation: wrong, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("attempt-correct", profileID: profileID, lamport: 2, payload: .exerciseEvaluated(lessonID: lessonID, blockID: blockID("block-attempts"), evaluation: correct, at: now.addingTimeInterval(10)))
        )

        let progress = try XCTUnwrap(snapshot.lessonProgress[lessonID])
        XCTAssertEqual(progress.answeredCount, 1)
        XCTAssertEqual(progress.correctCount, 1)
        XCTAssertEqual(progress.attemptCount, 2)
        XCTAssertEqual(progress.bestScore, 1)
        XCTAssertTrue(progress.mistakeExerciseIDs.isEmpty)
        XCTAssertEqual(progress.lastEvaluations[exerciseKey], correct)
    }

    func testReducerRejectsEventsForAnotherProfile() throws {
        let firstProfile = profileID("profile-one")
        let secondProfile = profileID("profile-two")
        let onboarding = event(
            "profile-one-onboarding",
            profileID: firstProfile,
            lamport: 1,
            payload: .onboardingCompleted(profile: profileIDValue(firstProfile))
        )
        let snapshot = try reducer.reduce(.empty(now: now), onboarding)

        XCTAssertThrowsError(
            try reducer.reduce(
                snapshot,
                event("profile-two-event", profileID: secondProfile, lamport: 2, payload: .lessonStarted(lessonID: lessonID(), at: now))
            )
        ) { error in
            XCTAssertEqual(error as? DomainError, .eventProfileMismatch)
        }
    }

    private func profileIDValue(_ id: ProfileID) -> LearnerProfile {
        profile(id)
    }
}
