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

    func testProviderAssessmentUsesItsVerdictAndKeepsLegacySpeechAnswersReadable() throws {
        let spec = ExerciseSpec.speaking(
            SpeakingExercise(
                header: header("exercise-pronunciation"),
                referenceText: "你好",
                referencePinyin: "nǐ hǎo",
                acceptedTranscripts: ["你好"],
                allowSelfRating: true
            )
        )
        let passingAssessment = SpeechPronunciationAssessment(
            providerID: "iflytek",
            verdict: .pass,
            providerScore: 0.93
        )
        let retryAssessment = SpeechPronunciationAssessment(
            providerID: "iflytek",
            verdict: .needsPractice,
            providerScore: 0.61
        )
        // A provider score does not make an inconclusive verdict evaluable.
        let uncertainAssessment = SpeechPronunciationAssessment(
            providerID: "iflytek",
            verdict: .inconclusive,
            providerScore: 0.55
        )
        XCTAssertTrue(passingAssessment.isEvaluable)
        XCTAssertTrue(retryAssessment.isEvaluable)
        XCTAssertFalse(uncertainAssessment.isEvaluable)
        for assessment in [passingAssessment, retryAssessment, uncertainAssessment] {
            let roundTrip = try JSONDecoder().decode(
                SpeechPronunciationAssessment.self,
                from: JSONEncoder().encode(assessment)
            )
            XCTAssertEqual(roundTrip, assessment)
        }

        let passing = SpeechAnswer(
            transcript: "",
            pronunciationAssessment: passingAssessment
        )
        let retry = SpeechAnswer(
            transcript: "",
            pronunciationAssessment: retryAssessment
        )
        let uncertain = SpeechAnswer(
            transcript: "",
            pronunciationAssessment: uncertainAssessment
        )

        let passingEvaluation = engine.evaluate(spec: spec, answer: .speech(passing))
        XCTAssertTrue(passingEvaluation.accepted)
        XCTAssertEqual(passingEvaluation.outcome, .correct)
        XCTAssertEqual(passingEvaluation.score, 0.93, accuracy: 0.0001)

        let retryEvaluation = engine.evaluate(spec: spec, answer: .speech(retry))
        XCTAssertFalse(retryEvaluation.accepted)
        XCTAssertEqual(retryEvaluation.outcome, .incorrect)
        XCTAssertEqual(retryEvaluation.score, 0.61, accuracy: 0.0001)

        let uncertainEvaluation = engine.evaluate(spec: spec, answer: .speech(uncertain))
        XCTAssertFalse(uncertainEvaluation.accepted)
        XCTAssertEqual(uncertainEvaluation.outcome, .unavailable)
        XCTAssertEqual(uncertainEvaluation.score, 0)

        let legacyJSON = Data(#"{"transcript":"你好","normalizedTranscript":"你好","confidence":null,"localeIdentifier":"zh-CN","recordingID":null}"#.utf8)
        let legacy = try JSONDecoder().decode(SpeechAnswer.self, from: legacyJSON)
        XCTAssertEqual(legacy.transcript, "你好")
        XCTAssertEqual(legacy.normalizedTranscript, "你好")
        XCTAssertNil(legacy.pronunciationAssessment)
        let legacyEvaluation = engine.evaluate(spec: spec, answer: .speech(legacy))
        XCTAssertTrue(legacyEvaluation.accepted)
        XCTAssertEqual(legacyEvaluation.outcome, .correct)

        let speechRoundTrip = try JSONDecoder().decode(
            ExerciseAnswer.self,
            from: JSONEncoder().encode(ExerciseAnswer.speech(.init(
                transcript: "你好",
                pronunciationAssessment: passingAssessment
            )))
        )
        XCTAssertEqual(
            speechRoundTrip,
            .speech(SpeechAnswer(transcript: "你好", pronunciationAssessment: passingAssessment))
        )
    }

    func testSkippingExerciseIsPersistedWithoutScoringOrMarkingItAnswered() throws {
        let spec = ExerciseSpec.speaking(
            SpeakingExercise(
                header: header("exercise-skipped"),
                referenceText: "你好",
                referencePinyin: "nǐ hǎo",
                acceptedTranscripts: ["你好"],
                allowSelfRating: true
            )
        )
        let skipped = engine.evaluate(spec: spec, answer: .skipped)
        XCTAssertFalse(skipped.accepted)
        XCTAssertEqual(skipped.outcome, .skipped)
        XCTAssertEqual(skipped.score, 0)

        let encoded = try JSONEncoder().encode(ExerciseAnswer.skipped)
        XCTAssertEqual(try JSONDecoder().decode(ExerciseAnswer.self, from: encoded), .skipped)

        let profileKey = profileID("profile-skipped")
        let lessonKey = lessonID("lesson-skipped")
        var snapshot = try reducer.reduce(
            .empty(now: now),
            event("skipped-onboarding", profileID: profileKey, lamport: 1, payload: .onboardingCompleted(profile: profileIDValue(profileKey)))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("skipped-start", profileID: profileKey, lamport: 2, payload: .lessonStarted(lessonID: lessonKey, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("skipped-evaluation", profileID: profileKey, lamport: 3, payload: .exerciseEvaluated(lessonID: lessonKey, blockID: blockID("block-skipped"), evaluation: skipped, at: now))
        )
        let progress = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(progress.lastEvaluations[spec.id], skipped)
        XCTAssertTrue(progress.answeredExerciseIDs.isEmpty)
        XCTAssertTrue(progress.correctExerciseIDs.isEmpty)
        XCTAssertTrue(progress.mistakeExerciseIDs.isEmpty)
        XCTAssertEqual(progress.attemptCount, 0)
        XCTAssertEqual(progress.bestScore, 0)
    }

    func testSkippedRoundTripKeepsZeroBilanThenAllowsProgression() throws {
        let profileKey = profileID("profile-skipped-progression")
        let lessonKey = lessonID("lesson-skipped-progression")
        let skippedSpec = ExerciseSpec.speaking(
            SpeakingExercise(
                header: header("exercise-skipped-progression"),
                referenceText: "你好",
                referencePinyin: "nǐ hǎo",
                acceptedTranscripts: ["你好"],
                allowSelfRating: true
            )
        )
        let followUpSpec = choiceSpec(correctChoiceID: "follow-up-right")
        let skipped = engine.evaluate(spec: skippedSpec, answer: .skipped)
        let followUp = engine.evaluate(spec: followUpSpec, answer: .choice(choiceID: "follow-up-right"))

        let skippedRoundTrip = try JSONDecoder().decode(
            ExerciseAnswer.self,
            from: JSONEncoder().encode(ExerciseAnswer.skipped)
        )
        XCTAssertEqual(skippedRoundTrip, .skipped)
        XCTAssertEqual(
            try JSONDecoder().decode(
                ExerciseEvaluation.self,
                from: JSONEncoder().encode(skipped)
            ),
            skipped
        )

        var snapshot = try reducer.reduce(
            .empty(now: now),
            event("skipped-progression-onboarding", profileID: profileKey, lamport: 1, payload: .onboardingCompleted(profile: profileIDValue(profileKey)))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("skipped-progression-start", profileID: profileKey, lamport: 2, payload: .lessonStarted(lessonID: lessonKey, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event(
                "skipped-progression-checkpoint",
                profileID: profileKey,
                lamport: 3,
                payload: .lessonCheckpointSaved(
                    lessonID: lessonKey,
                    exerciseIndex: 0,
                    exerciseID: skippedSpec.id,
                    answer: .skipped,
                    evaluation: nil,
                    dialogueDrafts: [:],
                    dialogueResults: [:],
                    at: now
                )
            )
        )
        snapshot = try reducer.reduce(
            snapshot,
            event(
                "skipped-progression-evaluation",
                profileID: profileKey,
                lamport: 4,
                payload: .exerciseEvaluated(lessonID: lessonKey, blockID: blockID("block-skipped-progression"), evaluation: skipped, at: now)
            )
        )

        let afterSkip = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(afterSkip.lastEvaluations[skippedSpec.id], skipped)
        XCTAssertEqual(afterSkip.currentExerciseIndex, 0)
        XCTAssertEqual(afterSkip.currentExerciseID, skippedSpec.id)
        XCTAssertEqual(afterSkip.answeredCount, 0)
        XCTAssertEqual(afterSkip.correctCount, 0)
        XCTAssertEqual(afterSkip.completionRate, 0)
        XCTAssertEqual(afterSkip.attemptCount, 0)
        XCTAssertEqual(afterSkip.bestScore, 0)
        XCTAssertTrue(afterSkip.mistakeExerciseIDs.isEmpty)
        XCTAssertNil(afterSkip.completedAt)

        snapshot = try reducer.reduce(
            snapshot,
            event(
                "skipped-progression-next-checkpoint",
                profileID: profileKey,
                lamport: 5,
                payload: .lessonCheckpointSaved(
                    lessonID: lessonKey,
                    exerciseIndex: 1,
                    exerciseID: followUpSpec.id,
                    answer: .choice(choiceID: "follow-up-right"),
                    evaluation: nil,
                    dialogueDrafts: [:],
                    dialogueResults: [:],
                    at: now.addingTimeInterval(1)
                )
            )
        )
        snapshot = try reducer.reduce(
            snapshot,
            event(
                "skipped-progression-follow-up",
                profileID: profileKey,
                lamport: 6,
                payload: .exerciseEvaluated(lessonID: lessonKey, blockID: blockID("block-follow-up"), evaluation: followUp, at: now.addingTimeInterval(2))
            )
        )

        let afterFollowUp = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(afterFollowUp.currentExerciseIndex, 1)
        XCTAssertEqual(afterFollowUp.currentExerciseID, followUpSpec.id)
        XCTAssertEqual(afterFollowUp.lastEvaluations[skippedSpec.id], skipped)
        XCTAssertEqual(afterFollowUp.lastEvaluations[followUpSpec.id], followUp)
        XCTAssertEqual(afterFollowUp.answeredCount, 1, "Le bilan doit exclure l’exercice passé")
        XCTAssertEqual(afterFollowUp.correctCount, 1)
        XCTAssertEqual(afterFollowUp.completionRate, 1)
        XCTAssertEqual(afterFollowUp.attemptCount, 1, "L’exercice passé ne doit pas augmenter les tentatives")
        XCTAssertEqual(afterFollowUp.bestScore, 1)
        XCTAssertTrue(afterFollowUp.mistakeExerciseIDs.isEmpty)
        XCTAssertNil(afterFollowUp.completedAt, "La progression seule ne doit pas enregistrer une fin de leçon")
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

    func testLessonCheckpointRestoresDraftAndVisibleEvaluationAcrossCodableRoundTrip() throws {
        let profileKey = profileID("profile-checkpoint")
        let lessonKey = lessonID("lesson-checkpoint")
        let exerciseKey = exerciseID("exercise-checkpoint")
        let evaluation = try ExerciseEvaluation(
            exerciseID: exerciseKey,
            outcome: .incorrect,
            score: 0,
            feedback: .unchecked(["fr": "Réessaie."]),
            accepted: false,
            normalizedAnswer: "nihao"
        )
        let answer = ExerciseAnswer.text("你好")

        var snapshot = try reducer.reduce(
            .empty(now: now),
            event("checkpoint-onboarding", profileID: profileKey, lamport: 1, payload: .onboardingCompleted(profile: profileIDValue(profileKey)))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("checkpoint-start", profileID: profileKey, lamport: 2, payload: .lessonStarted(lessonID: lessonKey, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("checkpoint-save", profileID: profileKey, lamport: 3, payload: .lessonCheckpointSaved(
                lessonID: lessonKey,
                exerciseIndex: 2,
                exerciseID: exerciseKey,
                answer: answer,
                evaluation: evaluation,
                dialogueDrafts: [:],
                dialogueResults: [:],
                at: now
            ))
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(ProgressSnapshot.self, from: encoded)
        let progress = try XCTUnwrap(restored.lessonProgress[lessonKey])
        XCTAssertEqual(progress.currentExerciseIndex, 2)
        XCTAssertEqual(progress.currentExerciseID, exerciseKey)
        XCTAssertEqual(progress.pendingAnswer, answer)
        XCTAssertEqual(progress.pendingEvaluation, evaluation)
        XCTAssertEqual(progress.lastEvaluations, [:])
    }

    func testRestartedLessonClearsThePreviousSessionCheckpoint() throws {
        let profileKey = profileID("profile-restart")
        let lessonKey = lessonID("lesson-restart")
        let exerciseKey = exerciseID("exercise-restart")
        let answer = ExerciseAnswer.choice(choiceID: "answer")
        var snapshot = try reducer.reduce(
            .empty(now: now),
            event("restart-start", profileID: profileKey, lamport: 1, payload: .lessonStarted(lessonID: lessonKey, at: now))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("restart-save", profileID: profileKey, lamport: 2, payload: .lessonCheckpointSaved(
                lessonID: lessonKey,
                exerciseIndex: 1,
                exerciseID: exerciseKey,
                answer: answer,
                evaluation: nil,
                dialogueDrafts: [:],
                dialogueResults: [:],
                at: now
            ))
        )
        snapshot = try reducer.reduce(
            snapshot,
            event("restart-reset", profileID: profileKey, lamport: 3, payload: .lessonRestarted(lessonID: lessonKey, at: now.addingTimeInterval(1)))
        )

        let progress = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(progress.currentExerciseIndex, 0)
        XCTAssertNil(progress.currentExerciseID)
        XCTAssertNil(progress.pendingAnswer)
        XCTAssertNil(progress.pendingEvaluation)
        XCTAssertTrue(progress.lastEvaluations.isEmpty)
        XCTAssertNil(progress.completedAt)
    }

    func testTerminalCheckpointKeepsAnUnfinishedLessonResettable() throws {
        let profileKey = profileID("profile-terminal")
        let lessonKey = lessonID("lesson-terminal")
        let terminal = event(
            "terminal-checkpoint",
            profileID: profileKey,
            lamport: 2,
            payload: .lessonCheckpointSaved(
                lessonID: lessonKey,
                exerciseIndex: 6,
                exerciseID: nil,
                answer: nil,
                evaluation: nil,
                dialogueDrafts: [:],
                dialogueResults: [:],
                at: now
            )
        )

        var snapshot = try reducer.reduce(
            .empty(now: now),
            event(
                "terminal-onboarding",
                profileID: profileKey,
                lamport: 1,
                payload: .onboardingCompleted(profile: profileIDValue(profileKey))
            )
        )
        snapshot = try reducer.reduce(snapshot, terminal)

        let terminalProgress = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(terminalProgress.currentExerciseIndex, 6)
        XCTAssertNil(terminalProgress.completedAt)

        snapshot = try reducer.reduce(
            snapshot,
            event(
                "terminal-complete",
                profileID: profileKey,
                lamport: 3,
                payload: .lessonCompleted(lessonID: lessonKey, at: now.addingTimeInterval(1))
            )
        )
        let completedProgress = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(completedProgress.currentExerciseIndex, 6)
        XCTAssertNotNil(completedProgress.completedAt)

        snapshot = try reducer.reduce(
            snapshot,
            event(
                "terminal-restart",
                profileID: profileKey,
                lamport: 4,
                payload: .lessonRestarted(lessonID: lessonKey, at: now.addingTimeInterval(2))
            )
        )
        let resetProgress = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertEqual(resetProgress.currentExerciseIndex, 0)
        XCTAssertNil(resetProgress.currentExerciseID)
        XCTAssertNil(resetProgress.pendingAnswer)
        XCTAssertNil(resetProgress.pendingEvaluation)
        XCTAssertNil(resetProgress.completedAt)
    }

    func testCheckpointCanClearVisibleFeedbackWithoutDroppingHistory() throws {
        let profileKey = profileID("profile-feedback-clear")
        let lessonKey = lessonID("lesson-feedback-clear")
        let exerciseKey = exerciseID("exercise-feedback-clear")
        let evaluation = try ExerciseEvaluation(
            exerciseID: exerciseKey,
            outcome: .incorrect,
            score: 0,
            feedback: .unchecked(["fr": "Réessaie."]),
            accepted: false
        )
        var snapshot = try reducer.reduce(
            .empty(now: now),
            event(
                "feedback-clear-onboarding",
                profileID: profileKey,
                lamport: 1,
                payload: .onboardingCompleted(profile: profileIDValue(profileKey))
            )
        )
        snapshot = try reducer.reduce(
            snapshot,
            event(
                "feedback-clear-evaluation",
                profileID: profileKey,
                lamport: 2,
                payload: .exerciseEvaluated(
                    lessonID: lessonKey,
                    blockID: blockID("feedback-clear-block"),
                    evaluation: evaluation,
                    at: now
                )
            )
        )
        snapshot = try reducer.reduce(
            snapshot,
            event(
                "feedback-clear-visible",
                profileID: profileKey,
                lamport: 3,
                payload: .lessonCheckpointSaved(
                    lessonID: lessonKey,
                    exerciseIndex: 0,
                    exerciseID: exerciseKey,
                    answer: nil,
                    evaluation: evaluation,
                    dialogueDrafts: [:],
                    dialogueResults: [:],
                    at: now
                )
            )
        )
        snapshot = try reducer.reduce(
            snapshot,
            event(
                "feedback-clear-retry",
                profileID: profileKey,
                lamport: 4,
                payload: .lessonCheckpointSaved(
                    lessonID: lessonKey,
                    exerciseIndex: 0,
                    exerciseID: exerciseKey,
                    answer: nil,
                    evaluation: nil,
                    dialogueDrafts: [:],
                    dialogueResults: [:],
                    at: now.addingTimeInterval(1)
                )
            )
        )
        let progress = try XCTUnwrap(snapshot.lessonProgress[lessonKey])
        XCTAssertNil(progress.pendingEvaluation)
        XCTAssertEqual(progress.lastEvaluations[exerciseKey], evaluation)
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
